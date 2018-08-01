create extension if not exists "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SCHEMA IF EXISTS shared, util cascade;
DROP SERVER IF EXISTS ${remote1ns} cascade;
DROP SERVER IF EXISTS ${remote2ns} cascade;

-- drop schema if exists shared, usa, gbr, aus cascade;

create schema if not exists shared;
create table if not exists shared.identity (
  uuid   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_uuid UUID NOT NULL,
  manager_uuid   UUID NULL CHECK (manager_uuid is not null OR uuid != manager_uuid),
  region CHAR(3) NOT NULL,
  gender VARCHAR,
  note   TEXT,
  created_on TIMESTAMP NOT NULL DEFAULT transaction_timestamp()
);
-- TODO keep shared.identity in sync?


-- Create the parent table, along with the local partition
create table if not exists shared.identity_details (
  id     SERIAL,
  uuid   UUID    NOT NULL,
  customer_uuid UUID NOT NULL,
  region CHAR(3) NOT NULL,
  name   VARCHAR NOT NULL,
  email  VARCHAR
) PARTITION BY LIST (region);


create schema if not exists ${localNs};
create table if not exists ${localNs}.identity_details
  partition of shared.identity_details for values in ('${localNs}');
CREATE INDEX IF NOT EXISTS idx_uuid ON ${localNs}.identity_details (uuid);
CREATE INDEX IF NOT EXISTS idx_customer_uuid ON ${localNs}.identity_details (customer_uuid);
CREATE INDEX IF NOT EXISTS idx_region ON ${localNs}.identity_details (region);
CREATE INDEX IF NOT EXISTS idx_region_customer_uuid ON ${localNs}.identity_details (region, customer_uuid);
CREATE INDEX IF NOT EXISTS idx_name ON ${localNs}.identity_details (name);
CREATE INDEX IF NOT EXISTS idx_name_customer_uuid ON ${localNs}.identity_details (name, customer_uuid);
CREATE INDEX IF NOT EXISTS idx_email ON ${localNs}.identity_details (email);
CREATE INDEX IF NOT EXISTS idx_email_customer_uuid ON ${localNs}.identity_details (email, customer_uuid);


create table if not exists ${localNs}.trigger_cache (
  uuid UUID PRIMARY KEY default uuid_generate_v4(),
  all_data JSONB NOT NULL,
  local_data JSONB NOT NULL,
  created_on TIMESTAMP NOT NULL DEFAULT transaction_timestamp()
);