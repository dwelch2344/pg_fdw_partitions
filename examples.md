# Examples

## Smart Querying

Postgres' FDW is what allows remote querying to occur. The primary
mechanism for optimization (at least until PG11 is released, afaict)
is through the `where ...` clause in your query. The docs state this
where clause is sent to the remote, and any non-requested fields are
omitted (to preserve bandwidth).

As such, avoid querying remote tables without a very explicit `where`
clause. Also, due to the nature of `join`s and projections being
performed before the `where` clause, subqueries and CTEs tend to be
much more efficient than joining results.

_For Example:_


```sql
-- Bad: XXX seconds @ ~3M rec across 3 databases
with targets as (
  select
    array_agg(uuid) uuids
  from shared.identity i
  order by random()
  limit 5
)
select *
from shared.identity_details d
  cross join targets t
where true
  and d.uuid = any( t.uuids )
```

The cross join on targets, though in memory and cached, means that all
of the remotes data would need to be retrieved before the clause is
applied. Obviously, if you have 3M+ records, this is going to suck.

Conversely, a subquery is still rather performant.

```sql
-- Bad: 10 seconds @ ~3M rec across 3 databases
with targets as (
  select
    i.uuid uuids
  from shared.identity i
  order by random()
  limit 5
)
select *
from shared.identity_details d
  cross join targets t
where true
  and d.uuid = ANY( select uuids from targets )
```