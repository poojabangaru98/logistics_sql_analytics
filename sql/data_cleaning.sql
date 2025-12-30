/*
=====================================================
Purpose:
- Enforce data integrity using primary and foreign keys
- Standardize datetime formats
- Handle missing identifiers using placeholder values
- Prepare schema for analytical queries
=====================================================
*/

/* =====================================================
   DIMENSION TABLES
   - Enforce NOT NULL and PRIMARY KEY constraints
   - Standardize datetime columns
===================================================== */

-- Customers
-- Set customer_id as NOT NULL and PRIMARY KEY
alter table customers modify column customer_id text not null;
alter table customers modify column customer_id varchar(50) primary key;
-- Convert contract_start_date to DATE/DATETIME
update customers set contract_start_date = str_to_date(contract_start_date, '%m/%d/%Y');
alter table customers modify column contract_start_date date;

-- Drivers
-- Set driver_id as NOT NULL and PRIMARY KEY
alter table drivers modify column driver_id text not null;
alter table drivers modify column driver_id varchar(50) primary key;
-- Convert hire_date, termination_date, date_of_birth
-- drivers table(hire_date) -- 
update drivers set hire_date = str_to_date(hire_date, '%m/%d/%Y');
alter table drivers modify column hire_date date;
-- drivers table(termination_date) -- 
update drivers set termination_date = null where termination_date = '';
update drivers set termination_date = str_to_date(termination_date, '%m/%d/%Y');
alter table drivers modify column termination_date date;
-- drivers table(date_of_birth) -- 
update drivers set date_of_birth = str_to_date(date_of_birth, '%m/%d/%Y');
alter table drivers modify column date_of_birth date;

-- Trucks
-- Set truck_id as NOT NULL and PRIMARY KEY
alter table trucks modify column truck_id text not null;
alter table trucks modify column truck_id varchar(50) primary key;
-- Convert acquisition_date
update trucks set acquisition_date = str_to_date(acquisition_date, '%m/%d/%Y');
alter table trucks modify column acquisition_date date;

-- Trailers
-- Set trailer_id as NOT NULL and PRIMARY KEY
alter table trailers modify column trailer_id text not null;
alter table trailers modify column trailer_id varchar(50) primary key;
-- Convert acquisition_date
update trailers set acquisition_date = str_to_date(acquisition_date, '%m/%d/%Y');
alter table trailers modify column acquisition_date date;

-- Routes
-- Set route_id as NOT NULL and PRIMARY KEY
alter table routes modify column route_id text not null;
alter table routes modify column route_id varchar(50) primary key;

-- Facilities
-- Set facility_id as NOT NULL and PRIMARY KEY
alter table facilities modify column facility_id text not null;
alter table facilities modify column facility_id varchar(50) primary key;

/* =====================================================
   FACT TABLES
   - Enforce PRIMARY KEYS
   - Prepare for FOREIGN KEY constraints
===================================================== */

-- Loads
-- Set load_id as NOT NULL and PRIMARY KEY
alter table loads modify column load_id text not null;
alter table loads modify column load_id varchar(50) primary key;

-- Trips
-- Set trip_id as NOT NULL and PRIMARY KEY
alter table trips modify column trip_id text not null;
alter table trips modify column trip_id varchar(50) primary key;

-- Delivery Events
-- Set event_id as NOT NULL and PRIMARY KEY
alter table delivery_events modify column event_id text not null;
alter table delivery_events modify column event_id varchar(50) primary key;

-- Fuel Purchases
-- Set purchase_id as NOT NULL and PRIMARY KEY
alter table fuel_purchases modify column fuel_purchase_id text not null;
alter table fuel_purchases modify column fuel_purchase_id varchar(50) primary key;

-- Maintenance Records
-- Set maintenance_id as NOT NULL and PRIMARY KEY
alter table maintenance_records modify column maintenance_id text not null;
alter table maintenance_records modify column maintenance_id varchar(50) primary key;

-- Safety Incidents
-- Set incident_id as NOT NULL and PRIMARY KEY
alter table safety_incidents modify column incident_id text not null;
alter table safety_incidents modify column incident_id varchar(50) primary key;

/* =====================================================
   DATETIME STANDARDIZATION – FACT TABLES
===================================================== */

-- Maintenance Records
-- Convert maintenance_date to DATE/DATETIME
update maintenance_records set maintenance_date = str_to_date(maintenance_date, '%m/%d/%Y');
alter table maintenance_records modify column maintenance_date date;

-- Safety Incidents
-- Convert incident_date
update safety_incidents set incident_date = str_to_date(incident_date, '%m/%d/%Y %H:%i');
alter table safety_incidents modify column incident_date datetime;

-- Fuel Purchases
-- Convert purchase_date
update fuel_purchases set purchase_date = str_to_date(purchase_date, '%m/%d/%Y %H:%i');
alter table fuel_purchases modify column purchase_date datetime;

-- Loads
-- Convert load_date
update loads set load_date = str_to_date(load_date, '%m/%d/%Y');
alter table loads modify column load_date date;

-- Trips
-- Convert dispatch_date
update trips set dispatch_date = str_to_date(dispatch_date, '%m/%d/%Y');
alter table trips modify column dispatch_date date;

-- Delivery Events
-- Convert scheduled_datetime and actual_datetime
alter table delivery_events drop column scheduled_datetime;
alter table delivery_events drop column actual_datetime;
alter table delivery_events rename column `scheduled_datetime_[0]` to scheduled_datetime;
alter table delivery_events rename column `actual_datetime_[0]` to actual_datetime;
-- Scheduled_datetime
update delivery_events set scheduled_datetime = str_to_date(scheduled_datetime, '%m/%d/%Y %H:%i');
alter table delivery_events modify column scheduled_datetime datetime;
-- Actual_datetime
update delivery_events set actual_datetime = str_to_date(actual_datetime, '%m/%d/%Y %H:%i');
alter table delivery_events modify column actual_datetime datetime;

/* =====================================================
   DATA NORMALIZATION & MISSING VALUES
===================================================== */

-- Disable safe update mode where required
SET SQL_SAFE_UPDATES = 0;

-- Replace NULL identifiers with 'Unknown'

-- Fuel Purchases
-- for truck_id
update fuel_purchases set truck_id = 'Unknown' where truck_id = '';
-- for driver_id
update fuel_purchases set driver_id = 'Unknown' where driver_id = '';

-- Trips
-- for driver_id
update trips set driver_id = 'Unknown' where driver_id = '';
-- for truck_id
update trips set truck_id = 'Unknown' where truck_id = '';
-- for trailer_id
update trips set trailer_id = 'Unknown' where trailer_id = '';

-- Safety Incidents
-- for driver_id
update safety_incidents set driver_id = 'Unknown' where driver_id = '';
-- for truck_id
update safety_incidents set truck_id = 'Unknown' where truck_id = '';

/* =====================================================
   PLACEHOLDER RECORDS
   - Ensure foreign key consistency
===================================================== */

-- Insert 'Unknown' row into:
-- trucks table
insert into trucks (truck_id) values ('Unknown');
-- drivers table
insert into drivers (driver_id) values ('Unknown');
-- trailers table
insert into trailers (trailer_id) values ('Unknown');

/* =====================================================
   FOREIGN KEY CONSTRAINTS
===================================================== */

-- Maintenance Records
-- Set truck_id as NOT NULL
alter table maintenance_records modify column truck_id varchar(50) not null;
-- FK: truck_id → trucks(truck_id)
alter table maintenance_records add constraint fk_maintenance_truck foreign key (truck_id) references trucks(truck_id);

-- Fuel Purchases
-- Set trip_id, truck_id, driver_id as NOT NULL
alter table fuel_purchases modify column trip_id varchar(50) not null;
alter table fuel_purchases modify column truck_id varchar(50) not null;
alter table fuel_purchases modify column driver_id varchar(50) not null;
-- FK: trip_id → trips(trip_id)
alter table fuel_purchases add constraint fk_fuel_purchases_trip foreign key (trip_id) references trips(trip_id);
-- FK: truck_id → trucks(truck_id)
alter table fuel_purchases add constraint fk_fuel_purchases_truck foreign key (truck_id) references trucks(truck_id);
-- FK: driver_id → drivers(driver_id)
alter table fuel_purchases add constraint fk_fuel_purchases_driver foreign key (driver_id) references drivers(driver_id);

-- Safety Incidents
-- Set trip_id, truck_id, driver_id as NOT NULL
alter table safety_incidents modify column trip_id varchar(50) not null;
alter table safety_incidents modify column truck_id varchar(50) not null;
alter table safety_incidents modify column driver_id varchar(50) not null;
-- FK: trip_id → trips(trip_id)
alter table safety_incidents add constraint fk_safety_incidents_trip foreign key (trip_id) references trips(trip_id);
-- FK: truck_id → trucks(truck_id)
alter table safety_incidents add constraint fk_safety_incidents_truck foreign key (truck_id) references trucks(truck_id);
-- FK: driver_id → drivers(driver_id)
alter table safety_incidents add constraint fk_safety_incidents_driver foreign key (driver_id) references drivers(driver_id);

-- Loads
-- Set customer_id, route_id as NOT NULL
alter table loads modify column customer_id varchar(50) not null;
alter table loads modify column route_id varchar(50) not null;
-- FK: customer_id → customers(customer_id)
alter table loads add constraint fk_loads_customer foreign key (customer_id) references customers(customer_id);
-- FK: route_id → routes(route_id)
alter table loads add constraint fk_loads_route foreign key (route_id) references routes(route_id);

-- Trips
-- Set load_id, driver_id, truck_id, trailer_id as NOT NULL
alter table trips modify column load_id varchar(50) not null;
alter table trips modify column driver_id varchar(50) not null;
alter table trips modify column truck_id varchar(50) not null;
alter table trips modify column trailer_id varchar(50) not null;
-- FK: load_id → loads(load_id)
alter table trips add constraint fk_trips_load foreign key (load_id) references loads(load_id);
-- FK: driver_id → drivers(driver_id)
alter table trips add constraint fk_trips_driver foreign key (driver_id) references drivers(driver_id);
-- FK: truck_id → trucks(truck_id)
alter table trips add constraint fk_trips_truck foreign key (truck_id) references trucks(truck_id);
-- FK: trailer_id → trailers(trailer_id)
alter table trips add constraint fk_trips_trailer foreign key (trailer_id) references trailers(trailer_id);

-- Delivery Events
-- Set load_id, trip_id, facility_id as NOT NULL
alter table delivery_events modify column load_id varchar(50) not null;
alter table delivery_events modify column trip_id varchar(50) not null;
alter table delivery_events modify column facility_id varchar(50) not null;
-- FK: load_id → loads(load_id)
alter table delivery_events add constraint fk_delivery_events_load foreign key (load_id) references loads(load_id);
-- FK: trip_id → trips(trip_id)
alter table delivery_events add constraint fk_delivery_events_trip foreign key (trip_id) references trips(trip_id);
-- FK: facility_id → facilities(facility_id)
alter table delivery_events add constraint fk_delivery_events_facility foreign key (facility_id) references facilities(facility_id);

/* =====================================================
   METRICS TABLES
   - Datetime normalization only
===================================================== */

-- Driver Monthly Metrics
-- Convert month column
update driver_monthly_metrics set month = str_to_date(month, '%m/%d/%Y');
alter table driver_monthly_metrics modify column month date;

-- Truck Utilization Metrics
-- Convert month column
update truck_utilization_metrics set month = str_to_date(month, '%m/%d/%Y');
alter table truck_utilization_metrics modify column month date;

/* =====================================================
   INDEXING
   - Composite and single-column indexes
   - Optimized for analytical joins
===================================================== */

-- Set driver_id as NOT NULL
alter table driver_monthly_metrics modify column driver_id varchar(50) not null;
-- Set driver_id as NOT NULL
alter table truck_utilization_metrics modify column truck_id varchar(50) not null;

create index idx_driver_month on driver_monthly_metrics (driver_id, month);
create index idx_truck_month on truck_utilization_metrics (truck_id, month);
