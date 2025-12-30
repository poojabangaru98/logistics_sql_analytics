/*
=====================================================
Purpose:
- Analyze cost and profitability drivers across loads, routes, customers, and assets
- Assess exposure to fuel cost volatility using trip-level fuel cost aggregation
- Evaluate the impact of maintenance and safety-related costs on asset profitability
=====================================================
*/

-- creating a view of total_fuel_cost_per_trip
create or replace view fuel_cost_incurred_per_trip as
select
	trp.trip_id,
    (case when sum(fp.total_cost) is null then 0
		else sum(fp.total_cost) end) as fuel_cost_per_trip
from trips as trp
left join fuel_purchases as fp on trp.trip_id = fp.trip_id
group by 1;

-- 1. Which loads appear most exposed to fuel cost volatility?
select
	l.load_id,
    l.customer_id,
    l.route_id,
    l.load_type,
    l.revenue,
    round(ftrp.fuel_cost_per_trip, 2) as fuel_cost_per_load,
    round(l.revenue - ftrp.fuel_cost_per_trip, 2) as load_profit,
    round((l.revenue - ftrp.fuel_cost_per_trip)/l.revenue, 2) as profit_margin
from loads as l
join trips as t on t.load_id = l.load_id
join fuel_cost_incurred_per_trip as ftrp on ftrp.trip_id = t.trip_id
order by profit_margin asc;

-- 2. Which routes generate strong margins versus high revenue with weak profitability?
select 
	r.route_id,
    r.origin_city,
    r.destination_city,
    round(sum(l.revenue),2) as total_revenue,
    round(sum(ftrp.fuel_cost_per_trip),2) as total_fuel_cost,
    round(sum(l.revenue) - sum(ftrp.fuel_cost_per_trip),2) as route_profit,
    round((sum(l.revenue) - sum(ftrp.fuel_cost_per_trip))/sum(l.revenue),2) as profit_margin,
    round((sum(l.revenue) - sum(ftrp.fuel_cost_per_trip))/sum(t.actual_distance_miles),2) as profit_per_mile
from routes as r
join loads as l on r.route_id = l.route_id
join trips as t on t.load_id = l.load_id
join fuel_cost_incurred_per_trip as ftrp on ftrp.trip_id = t.trip_id
group by 1,2,3
order by profit_margin desc;

-- 3. Are high-revenue-potential customers actually profitable?
select 
	c.customer_id,
    c.customer_name,
    c.customer_type,
    c.annual_revenue_potential,
    round(sum(l.revenue),2) as actual_total_revenue,
    round(sum(ftrp.fuel_cost_per_trip), 2) as total_customer_wise_cost,
    round(sum(l.revenue) - sum(ftrp.fuel_cost_per_trip), 2) as customer_wise_profit,
    round((sum(l.revenue) - sum(ftrp.fuel_cost_per_trip))/sum(l.revenue), 2) as profit_margin,
    count(l.load_id) as number_of_loads
from customers as c
join loads as l on l.customer_id = c.customer_id
join trips as t on t.load_id = l.load_id
join fuel_cost_incurred_per_trip as ftrp on ftrp.trip_id = t.trip_id
group by 1,2,3,4
order by c.annual_revenue_potential desc;

-- 4. How do maintenance costs affect truck-level profitability?
with updated_tp as (
	select t.truck_id, sum(t.actual_distance_miles) as miles, sum(l.revenue) as revenue
    from trips t
    join loads l on l.load_id = t.load_id
    group by t.truck_id),
fuel_purch as (
	select truck_id, sum(total_cost) as total_fuel_cost
    from fuel_purchases 
    group by truck_id),
m_rec as (
	select truck_id, sum(total_cost) as m_rec_cost
    from maintenance_records
    group by truck_id)
select 
	m_rec.truck_id, 
    (year(now()) - tr.model_year) as truck_age_years,
    round(u.revenue,2) as total_revenue,
    round(m_rec_cost,2) as total_maintenance_cost,
    u.miles as total_miles,
    round(m_rec_cost/u.miles,3) as maintenance_cost_per_mile,
    round(total_fuel_cost,2) as total_fuel_cost,
    round(u.revenue - total_fuel_cost,2) as profit,
    round((u.revenue - total_fuel_cost)/u.revenue,2) as profit_margin
from m_rec 
left join trucks tr on tr.truck_id = m_rec.truck_id
left join updated_tp u on u.truck_id = m_rec.truck_id
left join fuel_purch f on f.truck_id = m_rec.truck_id
where u.revenue is not null
order by maintenance_cost_per_mile desc;

-- 5. Which assets drive the highest safety-related financial losses?
select 
	truck_id,
    round(sum(vehicle_damage_cost),2) as total_vehicle_damage_cost,
    round(sum(cargo_damage_cost),2) as total_cargo_damage_cost,
    round(sum(claim_amount),2) as total_claim_amount,
    count(incident_id) as total_incident_count
from safety_incidents
group by 1
having total_claim_amount != 0
order by total_claim_amount desc;
