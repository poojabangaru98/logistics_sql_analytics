/*
=====================================================
Purpose:
- Analyze utilization patterns of trucks and trailers using trip-level time decomposition
- Evaluate fleet capacity balance, asset productivity, and downtime
- Assess the relationship between asset age, utilization, and maintenance performance
=====================================================
*/

-- Trip-level time decomposition view
create or replace view active_hr_info as
with pickup as (
select load_id, trip_id, actual_datetime, detention_minutes, min(actual_datetime) over (order by actual_datetime) as start_date,
	str_to_date((date_format(actual_datetime, '%Y-%m-01')),'%Y-%m-%d') as dispatch_month
from delivery_events
where event_type = 'pickup'),
delivery as (
select load_id, trip_id, actual_datetime, detention_minutes, max(actual_datetime) over (order by actual_datetime desc) as end_date
from delivery_events
where event_type = 'delivery')
select p.load_id, p.trip_id, p.dispatch_month,
	p.detention_minutes as pickup_detention_min,
	d.detention_minutes as delivery_detention_min,
	timestampdiff(hour, p.actual_datetime, d.actual_datetime) as consignment_time_hr,
    timestampdiff(hour, p.start_date, d.end_date) as total_available_hr
from pickup as p
join delivery as d on p.load_id = d.load_id and p.trip_id = d.trip_id;


-- 1. How evenly is fleet capacity utilized across active trucks?
create or replace view utilization_rate_truck as
WITH trip_totals AS (
select
	trp.truck_id,
	count(trp.trip_id) as total_trips,
    round(sum(trp.actual_distance_miles),2) as total_miles,
    round(sum(act.consignment_time_hr),2) as total_consignment_time_hr,
    sum(distinct act.total_available_hr) as available_hr
from trips as trp
join active_hr_info as act on act.trip_id = trp.trip_id
-- where truck_id != 'unknown'
group by 1),
maint_totals AS (
SELECT 
	truck_id, 
    round(SUM(downtime_hours),2) AS downtime
FROM maintenance_records
GROUP BY truck_id)
SELECT 
    t.truck_id,
    t.unit_number,
    t.status,
    tt.total_trips AS total_trips,
    tt.total_miles AS total_miles,
    tt.total_consignment_time_hr,
    mt.downtime AS total_downtime_hours,
    ROUND((tt.total_consignment_time_hr / tt.available_hr),2) AS utilization_rate
FROM trucks AS t
LEFT JOIN trip_totals tt ON t.truck_id = tt.truck_id
LEFT JOIN maint_totals mt ON t.truck_id = mt.truck_id
WHERE t.status != 'Inactive'
order by utilization_rate asc;

-- 2. How does truck age impact utilization and maintenance performance?
select
	u.truck_id,
    t.model_year,
    year(now()) - t.model_year as truck_age_years,
    u.total_trips,
    u.total_miles,
    u.utilization_rate,
    round(sum(m_rec.total_cost),2) as maintenance_cost
from utilization_rate_truck as u
join trucks as t on t.truck_id = u.truck_id
join maintenance_records as m_rec on m_rec.truck_id = u.truck_id
where u.utilization_rate is not null
group by 1,2,3,4,5,6
order by truck_age_years desc, maintenance_cost desc;

-- 3. Which trucks generate the highest revenue per operating day?
select 
	t.truck_id,
    t.unit_number,
    sum(act.consignment_time_hr/24) as normalized_active_days,
    round(sum(l.revenue),2) as total_revenue,
    round(sum(l.revenue)/sum(act.consignment_time_hr/24), 2) as revenue_per_active_day,
    count(trp.trip_id) as total_trips
from trucks as t
join trips as trp on trp.truck_id = t.truck_id
join loads as l on l.load_id = trp.load_id
join active_hr_info as act on act.trip_id = trp.trip_id
where t.truck_id != 'unknown'
group by 1,2
order by revenue_per_active_day desc;

-- 4. Which trucks experience the highest downtime?
select 
	t.truck_id, 
    t.unit_number,
    round(sum(m_rec.downtime_hours),2) as total_downtime_hours,
    count(m_rec.maintenance_id) as downtime_events,
    round(sum(m_rec.downtime_hours)/count(m_rec.maintenance_id),2) as avg_downtime_per_event,
    u.utilization_rate
from maintenance_records as m_rec
join trucks as t on t.truck_id = m_rec.truck_id
join utilization_rate_truck as u on u.truck_id = t.truck_id
where u.status != 'Inactive'
group by 1,2,6
order by total_downtime_hours desc;

-- 5. How efficiently are trailers being utilized?
with active_hr_trailer as (
select 
	trp.trailer_id, 
    count(trp.trip_id) as total_trips,
    sum(act.consignment_time_hr) as total_active_hr,
    sum(distinct act.total_available_hr) as total_available_hr
from trips as trp
join active_hr_info as act on act.trip_id = trp.trip_id
where trp.trailer_id != 'unknown'
group by 1)
select 
	act_tr.trailer_id,
    t.trailer_number,
    t.trailer_type,
    t.status,
    act_tr.total_trips,
    (act_tr.total_active_hr/act_tr.total_available_hr) as utilization_rate
from trailers as t
join active_hr_trailer as act_tr on act_tr.trailer_id = t.trailer_id
order by utilization_rate asc;
