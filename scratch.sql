select
  shared.upsert_identity(
      '7139f8aa-7f93-4657-83ad-b7d74a22159f',
      'David Welch',
      'usa',
      'Dave is really nice'
  ) as dave,
  split_part(
      shared.upsert_identity(
          'd0c4d726-225c-426d-80d2-7406eb1c9739',
          'Da Queen',
          'gbr',
          'Da queen is a powerhouse, but sort of an acquired taste'
      ), ' | ', 4)
;


select * from shared.identity;
select * from shared.identity_details;
select * from usa.identity_details;






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
select q.name, q.uuid, q.depth, q.region, m.region = q.region as local_manager,
  m.name as manager, m.uuid as manager_uuid, m.region as manager_region,
  u.upline
from qualified q
  LEFT JOIN qualified m on m.uuid = q.manager_uuid
  LEFT JOIN upline u on u.uuid = q.uuid
WHERE TRUE
      AND q.region in ('usa', 'gbr')
      AND q.name ilike '%7%'
      AND m.region != q.region
ORDER BY q.depth;








