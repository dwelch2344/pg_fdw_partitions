-- select
--   shared.upsert_identity(
--       '7139f8aa-7f93-4657-83ad-b7d74a22159f',
--       'David Welch',
--       'usa',
--       'Dave is really nice'
--   ) as dave,
--   split_part(
--       shared.upsert_identity(
--           'd0c4d726-225c-426d-80d2-7406eb1c9739',
--           'Da Queen',
--           'gbr',
--           'Da queen is a powerhouse, but sort of an my' acquired taste'
--       ), ' | ', 4)
-- ;


select * from shared.identity;
select * from shared.identity_details;
select * from usa.identity_details;



select * from util.generate_identities(1, 1000);
select * from util.generate_identities(1001, 10000);
select * from util.generate_identities(10001, 11000);


-- select * util.generate_identities(1000, 5000);
-- select * util.generate_identities(5001, 6000);
-- select * from util.generate_identities(6001, 7000);
-- select * from util.generate_identities(7001, 8000);
-- select * from util.generate_identities(8001, 9000);


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
ORDER BY t.depth, t.path
