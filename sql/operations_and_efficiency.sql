/*
=====================================================
Purpose:
- Evaluate route-level operational performance and efficiency
- Identify revenue productivity, transit delays, detention contributors, and idle time patterns
- Analyze delivery cycle time and downtime to highlight execution bottlenecks
=====================================================
*/

-- 1. which routes generate the highest revenue per mile?
with route_revenue as (
select 
	r.route_id, 
    r.origin_city, 
    r.destination_city, 
    r.typical_distance_miles,
    count(trip_id) as trip_count,
    round(sum(l.revenue),2) as total_base_revenue,
    sum(t.actual_distance_miles) as total_miles,
    round(round(sum(l.revenue),2)/sum(t.actual_distance_miles),2) as revenue_per_mile
from routes as r
join loads as l on r.route_id = l.route_id
join trips as t on t.load_id = l.load_id
group by 1,2,3,4)
select *, dense_rank() over (order by revenue_per_mile desc) as route_rank
from route_revenue;

-- 2. where is the largest gap between planned vs actual transit time?
with route_duration as (
select 
	r.route_id, 
    r.origin_city, 
    r.destination_city,
    r.typical_transit_days as planned_transit_days,
    round(avg(t.actual_duration_hours/24),2) as avg_actual_transit_days
from routes as r
join loads as l on r.route_id = l.route_id
join trips as t on t.load_id = l.load_id
group by 1,2,3,4)
select *, 
	round(avg_actual_transit_days-planned_transit_days,2) as early_completion_days,
    round((avg_actual_transit_days-planned_transit_days)*100/planned_transit_days,2) as schedule_adherence_gap
from route_duration;

-- 3. Which failities contribute most to detention time?
with detention_events as (
select 
	f.facility_id, 
    f.facility_name, 
    f.facility_type,
    f.city,
    f.state,
    round(sum(d.detention_minutes/60),2) as total_detention_hours,
    count(d.event_id) as number_of_events
from delivery_events as d
join facilities as f on f.facility_id = d.facility_id
where d.detention_minutes > 0
group by 1,2,3,4,5)
select *, 
	total_detention_hours/number_of_events as avg_detention_per_event
from detention_events
order by total_detention_hours desc;

-- 4. what percentage of trips experience idle_time route-wise? 
select 
	r.route_id, 
    r.origin_city, 
    r.destination_city,
    round(sum(t.idle_time_hours),2) as total_idletime_hours,
    count(t.trip_id) as total_trips,
    round(round(sum(t.idle_time_hours),2)/count(r.route_id),2) as avg_idletime_hours
from routes as r
join loads as l on r.route_id = l.route_id
join trips as t on t.load_id = l.load_id
group by 1,2,3;

-- 5. How much downtime do trips experience on average by route?
select 
	r.route_id, 
    r.origin_city, 
    r.destination_city,
    round(avg(t.actual_duration_hours/24),2) as avg_transit_days,
    round(stddev(t.actual_duration_hours/24),2) as transit_time_std_dev,
    round(min(t.actual_duration_hours/24),2) as min_transit_days,
    round(max(t.actual_duration_hours/24),2) as max_transit_days,
    count(t.trip_id) as trip_count
from routes as r
join loads as l on r.route_id = l.route_id
join trips as t on t.load_id = l.load_id
group by 1,2,3;

-- 6. what is the avaerage delivery cycle time by route?
with pickup as (
select 
	load_id, event_type,
	actual_datetime as pickup_time
from delivery_events
where event_type = 'pickup'),
delivery as (
select 
	load_id, event_type,
    actual_datetime as delivery_time 
from delivery_events 
where event_type='delivery')
select 
	r.route_id, 
    r.origin_city, 
    r.destination_city,
    avg(timestampdiff(day, p.pickup_time, d.delivery_time)) as avg_pickup_to_delivery_days,
    min(timestampdiff(day, p.pickup_time, d.delivery_time)) as min_cycle_days,
    r.typical_transit_days as planned_transit_days,
    count(d.event_type) as delivery_count
from routes as r
join loads as l on r.route_id = l.route_id
join pickup as p on p.load_id = l.load_id
join delivery as d on p.load_id = d.load_id
group by 1,2,3,6;
