CREATE SCHEMA IF NOT EXISTS util;
CREATE OR REPLACE FUNCTION util.random( a anyarray, OUT x anyelement )
  RETURNS anyelement AS
$$
BEGIN
  IF a = '{}' THEN
    x := NULL::TEXT;
  ELSE
    WHILE x IS NULL LOOP
      x := a[floor(array_lower(a, 1) + (random()*( array_upper(a, 1) -  array_lower(a, 1)+1) ) )::int];
    END LOOP;
  END IF;
END
$$ LANGUAGE plpgsql
VOLATILE RETURNS NULL ON NULL INPUT;


DROP FUNCTION IF EXISTS util.generate_identities(BIGINT, BIGINT);
CREATE OR REPLACE FUNCTION util.generate_identities(lr BIGINT, ur BIGINT)
RETURNS TABLE(region TEXT, instances BIGINT, regs VARCHAR[]) AS $$
DECLARE
  v_m_firsts VARCHAR[];
  v_m_lasts VARCHAR[];
  v_f_firsts VARCHAR[];
  v_f_lasts VARCHAR[];
  v_emails VARCHAR[];

  v_companies UUID[];
BEGIN

  select array_agg(uuid_generate_v4())
  from generate_series(1, 4)
  into v_companies;

  select
    array_agg(md.first_name order by md.email) filter (where gender = 'Male') m_first,
    array_agg(md.last_name order by md.email) filter (where gender = 'Male') m_last,
    array_agg(md.first_name order by md.email) filter (where gender = 'Female') f_first,
    array_agg(md.last_name order by md.email) filter (where gender = 'Female') f_last,
    array_agg(md.email) emails
  FROM util.mock_data md
  INTO v_m_firsts, v_m_lasts, v_f_firsts, v_f_lasts, v_emails;

  RETURN QUERY
    WITH r as (
      select idx, random() as rand
      from generate_series(lr, ur) idx
    ), persons as (
      select *,
        case
          WHEN r.rand <= 0.4 THEN 'gbr'
          WHEN r.rand > 0.4 AND r.rand < 0.7 THEN 'aus'
          ELSE 'usa'
        end as region,
        case
          WHEN r.rand <= 0.4 THEN 'Male'
          WHEN r.rand > 0.4 AND r.rand < 0.8 THEN 'Female'
          ELSE null
        end gender,
        case
          WHEN r.rand <= 0.5 THEN concat_ws(' ', util.random(v_m_firsts), util.random(v_m_lasts))
          ELSE concat_ws(' ', util.random(v_f_firsts), util.random(v_f_lasts))
        end as name
      from r
    ), inserts as (
      SELECT
        shared.upsert_identity(
          uuid_generate_v4(),
          p.name,
          util.random(v_companies),
          util.random(v_emails),
          p.gender,
          p.region,
          'The random was ' || p.rand
        ) as data,
        p
      FROM persons p
    ), parsed as (
        select
          split_part(i.data, ' | ', 4) as reg,
          p::VARCHAR as data
        from inserts i
    )
    select p.reg, count(1), array_agg(p.data)
    from parsed p
    group by 1;
END;
$$
LANGUAGE plpgsql
STRICT
SECURITY DEFINER;




DROP FUNCTION IF EXISTS util.create_manager_tree(BIGINT);
CREATE OR REPLACE FUNCTION util.create_manager_tree(p_depth BIGINT)
  RETURNS TABLE(root UUID, stats JSONB) AS $$
DECLARE
  v_root UUID;
  v_pool_ids UUID[];
  v_pool shared.identity_details[] := '{}';
  v_current UUID;
  v_update JSONB;
  v_row JSONB;
BEGIN

  SELECT uuid
  FROM shared.identity i
  WHERE i.manager_uuid IS NULL
  ORDER BY random()
  INTO v_root
  ;

  raise warning 'Selected root: %', v_root;

  v_update = '[]'::JSONB;
  v_current := v_root;

  WITH targets as (
      SELECT i.uuid
      FROM shared.identity i
      WHERE i.manager_uuid IS NULL AND i.uuid != v_root
      ORDER BY random()
      LIMIT ((p_depth * (p_depth + 1)) / 2)
  )
  SELECT array_agg(t.uuid) FROM targets t into v_pool_ids;

  raise warning 'Pool IDs: %', v_pool_ids;

  SELECT array_agg(d)
  FROM shared.identity_details d
  WHERE d.uuid = ANY( v_pool_ids )
  INTO v_pool;

  raise warning 'Pool: %', v_pool;

  FOR idx IN 1..p_depth LOOP
    raise warning 'itr %', idx;

    WITH t1 AS (
      select
        i.uuid, i.customer_uuid, i.region,
        t.name, t.email, i.gender, i.note,
        v_current manager_uuid
      from unnest(v_pool) t
        LEFT join shared.identity i on i.uuid = t.uuid
      WHERE TRUE
            AND i.uuid != v_root
            AND i.uuid not in ((
        select (u->>'uuid')::UUID
        from jsonb_array_elements(v_update) u
      ))
      LIMIT idx
    ), t2 as (
      select
        t.manager_uuid as uuid,
        json_agg(t) as data
      from t1 t
      group by 1
    )
    SELECT t.data
    FROM t2 t
    LIMIT 1
    INTO v_row;


    select v_update || v_row into v_update;
    raise warning 'Current: %', v_current;
    raise warning 'Row: %', v_row;
    raise warning 'update %', v_update;


    select (u->>'uuid')::UUID
    from jsonb_array_elements(v_row) u
    order by random()
    limit 1
    into v_current;
    raise warning 'Next: %', v_current;


    IF v_current IS NULL THEN
      RAISE WARNING 'Exiting early at depth %', idx;
    ELSE

    END IF;

  END LOOP;

  raise warning 'Beginning';
  select * from shared.upsert(v_update, null) into v_row;
  raise warning 'Ending';

  RETURN QUERY
    select v_root, v_row;
END;
$$
LANGUAGE plpgsql
STRICT
SECURITY DEFINER;


