create extension if not exists "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- drop schema if exists shared, usa, gbr, aus cascade;

create schema if not exists shared;
create table if not exists shared.identity (
  uuid   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  manager_uuid   UUID NULL REFERENCES shared.identity(uuid)
    CHECK (manager_uuid is not null OR uuid != manager_uuid),
  region CHAR(3) NOT NULL,
  note   TEXT,
  created_on TIMESTAMP NOT NULL DEFAULT transaction_timestamp()
);
-- TODO keep shared.identity in sync?


-- Create the parent table, along with the local partition
create table if not exists shared.identity_details (
  id     SERIAL,
  uuid   UUID    NOT NULL,
  region CHAR(3) NOT NULL,
  name   VARCHAR NOT NULL
)
  PARTITION BY LIST (region);
create schema if not exists ${localNs};
create table if not exists ${localNs}.identity_details
  partition of shared.identity_details for values in ('${localNs}');