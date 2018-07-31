
-- create remote 1
CREATE SERVER IF NOT EXISTS ${remote1ns}
  FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '${remote1host}', dbname '${remote1db}', port '${remote1port}');
CREATE USER MAPPING IF NOT EXISTS
FOR "${localUser}"
  SERVER ${remote1ns} OPTIONS ( user '${remote1user}', password '${remote1pass}');
create schema if not exists ${remote1ns};
CREATE FOREIGN TABLE ${remote1ns}.identity_details
  PARTITION OF shared.identity_details FOR VALUES IN ('${remote1ns}')
SERVER ${remote1ns};
CREATE FOREIGN TABLE ${remote1ns}.identity (
  uuid   UUID NOT NULL,
  customer_uuid UUID NOT NULL,
  region CHAR(3) NOT NULL,
  gender VARCHAR,
  note   TEXT,
  created_on TIMESTAMP NOT NULL
)
SERVER ${remote1ns} OPTIONS ( table_name 'identity', schema_name 'shared');
CREATE FOREIGN TABLE ${remote1ns}.trigger_cache (
  uuid UUID,
  all_data JSONB NOT NULL,
  local_data JSONB NOT NULL,
  created_on TIMESTAMP NOT NULL DEFAULT transaction_timestamp()
)
SERVER ${remote1ns} OPTIONS ( table_name 'trigger_cache', schema_name '${remote1ns}');

-- create remote 2
CREATE SERVER IF NOT EXISTS ${remote2ns}
  FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host '${remote2host}', dbname '${remote2db}', port '${remote2port}');
CREATE USER MAPPING IF NOT EXISTS
FOR "${localUser}"
  SERVER ${remote2ns} OPTIONS ( user '${remote2user}', password '${remote2pass}');
create schema if not exists ${remote2ns};
CREATE FOREIGN TABLE ${remote2ns}.identity_details
  PARTITION OF shared.identity_details FOR VALUES IN ('${remote2ns}')
SERVER ${remote2ns};
CREATE FOREIGN TABLE ${remote2ns}.identity (
  uuid   UUID NOT NULL,
  customer_uuid UUID NOT NULL,
  region CHAR(3) NOT NULL,
  gender VARCHAR,
  note   TEXT,
  created_on TIMESTAMP NOT NULL
)
SERVER ${remote2ns} OPTIONS ( table_name 'identity', schema_name 'shared');
CREATE FOREIGN TABLE ${remote2ns}.trigger_cache (
  uuid UUID,
  all_data JSONB NOT NULL,
  local_data JSONB NOT NULL,
  created_on TIMESTAMP NOT NULL DEFAULT transaction_timestamp()
)
SERVER ${remote2ns} OPTIONS ( table_name 'trigger_cache', schema_name '${remote2ns}');