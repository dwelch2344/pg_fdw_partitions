select * from shared.upsert(util.generate_data(10000), null); -- 11s
select * from shared.upsert(util.generate_data(100000), null); -- 31s
select * from shared.hierarchy;
select * from util.create_manager_tree(15); -- 88ec65aa-6ca0-48a6-9075-331ceca50305



with stats as (
select
  (select count(1) from usa.identity_details) as usa,
  (select count(1) from gbr.identity_details) as gbr,
  (select count(1) from aus.identity_details) as aus
)
select
  s.*,
  s.usa + s.gbr + s.aus as all_regions,
  (select count(1) from shared.identity) as identity
from stats s;


select * from shared.identity;
select * from shared.identity_details;
select * from usa.identity_details;


with targets as (
  select
--     array_agg(uuid) uuids
    i.uuid uuids
  from shared.identity i
  order by random()
  limit 5
)
select *
from shared.identity_details d
--   cross join targets t
where true
--   and d.uuid = any( t.uuids )
--   and d.uuid = '260549d9-a525-4d46-b74d-16351a83fdc6'::uuid
  and d.uuid = ANY( select uuids from targets )
;

select * from util.create_manager_tree(15);

select *
from shared.identity i
where i.manager_uuid is not null;

select *
from shared.identity i
  left join shared.identity_details d on d.uuid = i.uuid
where d.name ilike 'Pers%1000%'
order by d.id is null desc, d.id;


-- region	instances
-- usa	29690
-- aus	30291
-- gbr	40019


select *
from shared.identity_details;

select i.region, count(1)
from shared.identity i
group by 1;

select i.region, count(1), array_agg(uuid)
from shared.identity_details i
group by 1;


WITH targets AS (
    SELECT
      i.*
    FROM shared.hierarchy t
      LEFT JOIN shared.identity_details d on d.uuid = t.uuid
      INNER JOIN shared.hierarchy i ON i.path[t.depth] = t.uuid
    WHERE d.name like 'Carin Spiring'
), qualified AS (
    SELECT
      d.name,
      t.*
    FROM shared.identity_details d
      LEFT JOIN targets t on t.uuid = d.uuid
    WHERE d.uuid in ((
      SELECT t2.uuid
      FROM targets t2
    ))
-- ) select * from qualified;
), upline AS (
    select
      c.uuid,
      array_agg(q.name ORDER BY q.depth) as upline
    from qualified c
      LEFT JOIN qualified q ON c.path @> array[q.uuid]
    WHERE c.manager_uuid IS NOT NULL
    GROUP BY c.uuid
)
select q.name, q.uuid, q.depth, q.region, m.region = q.region as local_manager,
  m.name as manager, m.uuid as manager_uuid, m.region as manager_region,
  array_to_string(u.upline, ' > ' ) upline
from qualified q
  LEFT JOIN qualified m on m.uuid = q.manager_uuid
  LEFT JOIN upline u on u.uuid = q.uuid
WHERE TRUE
--       AND q.region in ('usa', 'gbr')
--       AND q.name ilike '%7%'
      AND m.region != q.region
ORDER BY q.depth;

select *
from shared.hierarchy t
where t.manager_uuid is not null;




SELECT
  d.name, d.email, i.*
FROM shared.hierarchy t
  INNER JOIN shared.hierarchy i ON i.path[t.depth] = t.uuid
  LEFT JOIN shared.identity_details d on d.uuid = i.uuid
WHERE t.uuid = '3434ac37-41fb-491a-bb13-4e43801da1c6' :: UUID;


select region, count(1)
from shared.hierarchy t
where
  created_on = '2018-07-30 14:00:41.472060'
group by region;
--   AND t.path @> array['4e924aaa-0b22-4f4e-957e-4d405b3b742b'::UUID];


select d.name, d.email, i.*
from shared.identity i
  LEFT JOIN shared.identity_details d on d.uuid = i.uuid
WHERE TRUE
  and d.uuid = '52f1f4df-ee65-4004-8bd0-01cdd6119eff'
-- where uuid = '8ab7af19-26dd-48e3-984c-e611b15c5a91'
;



SELECT
  i.*,
  1              AS depth,
  ARRAY [i.uuid] AS path
FROM shared.identity i
WHERE i.manager_uuid IS NOT NULL;

WITH RECURSIVE rel_tree AS (
  SELECT
    i.*,
    1              AS depth,
    ARRAY [i.uuid] AS path
  FROM shared.identity i
  WHERE i.manager_uuid IS NULL
  UNION ALL
  SELECT
    i.*,
    p.depth + 1,
    p.path || i.uuid
  FROM shared.identity i
    INNER JOIN rel_tree p ON p.uuid = i.manager_uuid
  WHERE i.manager_uuid IS NOT NULL
)
SELECT *
FROM rel_tree t
-- WHERE t.manager_uuid IS NOT NULL
ORDER BY t.depth, t.path;











WITH targets AS (
    SELECT i.*
    FROM shared.hierarchy t
      --       LEFT JOIN shared.identity_details d on d.uuid = t.uuid
      INNER JOIN shared.hierarchy i ON i.path [t.depth] = t.uuid
    WHERE t.uuid = (:target_uuid) :: UUID
), grouping AS (
    select
      array_agg(t.uuid) filter (where t.region = 'usa') as usa,
      array_agg(t.uuid) filter (where t.region = 'gbr') as gbr,
      array_agg(t.uuid) filter (where t.region = 'aus') as aus
    from targets t
), usas as (
    select usa.*
    from grouping g
      left join usa.identity_details usa on usa.uuid = any (g.usa)
), gbrs as (
    select gbr.*
    from grouping g
      left join gbr.identity_details gbr on gbr.uuid = any (g.gbr)
)
select * from usas
union
select * from gbrs
;






select * from shared.search_hierarchy('88ec65aa-6ca0-48a6-9075-331ceca50305'::UUID, null, null);

select * from shared.search_hierarchy('88ec65aa-6ca0-48a6-9075-331ceca50305'::UUID, array['usa', 'aus'], null);

select * from shared.search_hierarchy('88ec65aa-6ca0-48a6-9075-331ceca50305'::UUID, array['usa', 'aus'], true);

select *
from shared.search_hierarchy('88ec65aa-6ca0-48a6-9075-331ceca50305'::UUID, array['usa', 'aus'], true) sh
where sh.name ilike any( array['%Ingaber%', '%SHANON%'])
;


-- bad
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
      and d.uuid = any( t.uuids );

-- Good
with targets as (
    select
      i.uuid uuids
    from shared.identity i
    order by random()
    limit 5
)
select *
from shared.identity_details d
where true
      and d.uuid = ANY( select uuids from targets );

select * from shared.identity_details d where d.uuid = '696d77db-2516-4030-b00e-21a32a6914c1'::uuid;