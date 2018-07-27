# Postgres Partitioning via FDW

This is a proof of concept showing how one could solve
Data Residency (aka Data Sovereignty) issues in Postgres
with `Declarative Table Partitioning` and `Foreign Data Wrappers (FDW)`.
It spins up 3 docker containers, each representing a region
of the world.

### NOTE on Stored Procedure nastiness
Because Postgres 10's Partitioning doesen't support routing to Foreign Tables
on insert / update, we create a PLPGSQL to do that in each database and
manually keep the non-PII `shared.identity` table mirrored and manually
route to the appropriate partitioned table. Postgres 11 (in beta at time
of this writing) alleviates the need for most-if-not-all of this.


# Getting Started

Ensure you have Flyway CLI installed, then simply run the following:
```
./init.sh migrate
```


Once complete, your databases will be initialized. See the `docker-compose.yml`
for connection information.

# Seeing it in action

Connect to the USA database and run each of the following and pay
attention to the results. There should be nothing present.

```
select * from shared.identity;
select * from shared.identity_details;
select * from usa.identity_details;
```

So let's go ahead and create some peoples.

```
select
  shared.upsert_identity(
      '7139f8aa-7f93-4657-83ad-b7d74a22159f',
      'David Welch',
      'usa',
      'Dave is really nice'
  ) as dave,
  shared.upsert_identity(
      'd0c4d726-225c-426d-80d2-7406eb1c9739',
      'Da Queen',
      'gbr',
      'Da queen is a powerhouse, but sort of an acquired taste'
  ) as queen,
  shared.upsert_identity(
      uuid_generate_v4(),
      'Someone Random',
      'aus',
      'This will always make someone new'
  ) as rando,

  true as dummy
;
```

Each cell shows the UUID generated, a boolean on whether the operation
created a new identity + details or updated an existing one, and a boolean
indicating whether or not _this_ database was the owner of said new person.

Inspect the outputs again and you'll notice you have data where it should be.

```
select * from shared.identity;
select * from shared.identity_details;
select * from usa.identity_details;
```

Similarly, if you check the GBR / AUS  databases you'll see similar results.

### GBR

```
select * from shared.identity;
select * from shared.identity_details;
select * from gbr.identity_details;
```

### AUS

```
select * from shared.identity;
select * from shared.identity_details;
select * from aus.identity_details;
```


### Aftermath

If you re-run the original statement, you'll see the USA and GBR people
are updated, but a new duplicate of the third person is created.

# Getting more data

Let's get a bunch of people and build a few manager hierarchies.

```
select * from util.generate_identities(1, 10000, false);
```

The results show you how many people you generated in each region.
Now let's make hierarchies.

```
select * from util.create_manager_tree(15);
```

This will select a random non-managed identity, and build a org structure
under them with 15 levels of depth. Each level of depth gets that many
employees under the selected random manager. The result is the top
manager's UUID.

### Queries on that hierarchy

Let's search for all people under that person.

```
WITH targets AS (
    SELECT
      i.*
    FROM shared.hierarchy t
      INNER JOIN shared.hierarchy i ON i.path[t.depth] = t.uuid
    WHERE t.uuid = '__ROOT_PERSON_UUID_HERE__' :: UUID
), qualified AS (
    SELECT
      d.name,
      t.*
    FROM shared.identity_details d
      LEFT JOIN targets t on t.uuid = d.uuid
    WHERE d.uuid in ((
      SELECT t2.uuid FROM targets t2
    ))
), upline AS (
  select
    c.uuid,
    array_agg(q.name ORDER BY q.depth) as upline
  from qualified c
    LEFT JOIN qualified q ON c.path @> array[q.uuid]
  WHERE c.manager_uuid IS NOT NULL
  GROUP BY c.uuid
)
select q.name, q.uuid, q.depth, q.region,
  m.name as manager, m.uuid as manager_uuid, m.region as manager_region,
  u.upline
from qualified q
  LEFT JOIN qualified m on m.uuid = q.manager_uuid
  LEFT JOIN upline u on u.uuid = q.uuid
-- WHERE q.region in ('usa', 'gbr')
ORDER BY q.depth;
```

Notice we do end up pulling cross region names, but only after identifying
our potential pool of people. In this example we want to show ALL names
up the hierarchy, but in most cases where you don't need that, you could
filter out PII once your targets are identified and reduce the number of
regions hit.

# Take aways


Logistically, for our usecase this might work well. We'll only have a
handful of entities and a handful of regional databases. Joins over
the network can be super painful, so we'll need to manage that. But
nothing we can't work around (as we'll prove with benchmarks)

There's more logic in the DB than I'd like, but again with PG 11
that will (hopefully) be unnecessary.




# Hierarchical resolution

One of the major things to solve with this is issues with hierarchy. So let's
generate a big list of people and then sort through them.

```
WITH targets AS (
    SELECT
      i.*
    FROM shared.hierarchy t
      INNER JOIN shared.hierarchy i ON i.path[t.depth] = t.uuid
    WHERE t.uuid = '09a06d2e-a2e3-49a1-b3b6-a8a520fafc6c' :: UUID
), qualified AS (
    SELECT
      d.name,
      t.*
    FROM shared.identity_details d
      LEFT JOIN targets t on t.uuid = d.uuid
    WHERE d.uuid in ((
      SELECT t2.uuid FROM targets t2
    ))
), upline AS (
  select
    c.uuid,
    array_agg(q.name ORDER BY q.depth) as upline
  from qualified c
    LEFT JOIN qualified q ON c.path @> array[q.uuid]
  WHERE c.manager_uuid IS NOT NULL
  GROUP BY c.uuid
)
select q.name, q.uuid, q.depth, q.region,
  m.name as manager, m.uuid as manager_uuid, m.region as manager_region,
  u.upline
from qualified q
  LEFT JOIN qualified m on m.uuid = q.manager_uuid
  LEFT JOIN upline u on u.uuid = q.uuid
WHERE q.region in ('usa', 'gbr')
ORDER BY q.depth;
```