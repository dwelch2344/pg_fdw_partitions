


DROP FUNCTION IF EXISTS util.generate_data(BIGINT);
CREATE OR REPLACE FUNCTION util.generate_data(p_upper_bound BIGINT)
  RETURNS
    --TABLE(region TEXT, instances BIGINT, regs VARCHAR[])
    JSONB
  AS $$
DECLARE
  v_m_firsts VARCHAR[];
  v_m_lasts VARCHAR[];
  v_f_firsts VARCHAR[];
  v_f_lasts VARCHAR[];
  v_emails VARCHAR[];

  v_companies UUID[];

  p_input JSONB;
BEGIN



  select array_agg(public.uuid_generate_v4())
  from generate_series(1, 2 + CEIL(p_upper_bound / 10)::INT )
  into v_companies;

  select
    array_agg(md.first_name order by md.email) filter (where gender = 'Male') m_first,
    array_agg(md.last_name order by md.email) filter (where gender = 'Male') m_last,
    array_agg(md.first_name order by md.email) filter (where gender = 'Female') f_first,
    array_agg(md.last_name order by md.email) filter (where gender = 'Female') f_last,
    array_agg(md.email) emails
  FROM util.mock_data md
  INTO v_m_firsts, v_m_lasts, v_f_firsts, v_f_lasts, v_emails;


  WITH r as (
      select idx, random() as rand
      from generate_series(1, p_upper_bound) idx
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
  )
  select JSONB_AGG(json_build_object(
    'uuid', uuid_generate_v4(),
    'name', p.name,
    'customer_uuid', util.random(v_companies),
    'email', regexp_replace(p.name, '[^a-zA-Z0-9]', '') || '@mailinator.com',
    'region', p.region,
    'gender', p.gender,
    'note', 'Random was ' || p.rand
  )) FROM persons p
  INTO p_input;



  return p_input;
--   return query select null ::TEXT, null ::BIGINT, null ::VARCHAR[];
END;
$$
LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION shared.upsert(p_data JSONB, p_local JSONB)
  RETURNS
    --TABLE(region TEXT, instances BIGINT, regs VARCHAR[])
    JSONB
AS $$
DECLARE
  v_usa JSONB;
  v_gbr JSONB;
  v_aus JSONB;
  v_insert_uuid UUID;
  v_current JSONB;
  v_trash BIGINT;
  v_result JSONB;
BEGIN

  IF p_local IS NOT NULL THEN
    raise warning 'Running local';

    -- insert everything into the mirror
    with data as (
        select
          j.uuid,
          j.name,
          j.customer_uuid,
          j.manager_uuid,
          j.email,
          j.gender,
          j.region,
          j.note,
          i.uuid IS NOT NULL as is_update
        from jsonb_to_recordset(p_data) as j(
             uuid UUID,
             name VARCHAR,
             customer_uuid UUID,
             manager_uuid UUID,
             email VARCHAR,
             gender VARCHAR,
             region VARCHAR,
             note VARCHAR
             )
          LEFT JOIN shared.identity i ON i.uuid = j.uuid
    ), local_ident_new as (
      INSERT INTO shared.identity (uuid, customer_uuid, manager_uuid, region, gender, note, created_on)
        SELECT d.uuid, d.customer_uuid, d.manager_uuid, d.region, d.gender, d.note, transaction_timestamp()
        FROM data d
        WHERE d.is_update = false
    ), local_ident_update as (
      update shared.identity i
      SET
        customer_uuid = d.customer_uuid,
        manager_uuid = d.manager_uuid,
        gender        = d.gender,
        note          = d.note
      FROM data d
      WHERE d.is_update = true and i.uuid = d.uuid
    )
    select count(1) FROM data into v_trash;

    RAISE WARNING 'Inserted % all into %', v_trash, '${localNs}';


    -- UPDATE LOCAL DETAILS ONLY
    with data as (
        select
          j.uuid,
          j.name,
          j.customer_uuid,
          j.email,
          j.gender,
          j.region,
          j.note,
          i.uuid IS NOT NULL as is_update
        from jsonb_to_recordset(p_local) as j(
             uuid UUID,
             name VARCHAR,
             customer_uuid UUID,
             email VARCHAR,
             gender VARCHAR,
             region VARCHAR,
             note VARCHAR
             )
          LEFT JOIN ${localNs}.identity_details i ON i.uuid = j.uuid
    ) , usa_details_new as (
      INSERT INTO ${localNs}.identity_details (uuid, customer_uuid, region, name, email)
        SELECT d.uuid, d.customer_uuid, d.region, d.name, d.email
        FROM data d
        WHERE d.is_update = false
    ), usa_details_update as (
      update ${localNs}.identity_details i
      SET
        name = d.name,
        customer_uuid = d.customer_uuid,
        email = d.email
      FROM data d
      WHERE d.is_update = true and d.uuid = i.uuid
    )
    select count(1) FROM data into v_trash;

    RAISE WARNING 'Inserted % details into %', v_trash, '${localNs}';
    raise warning 'Local data %', p_local;

    return '{ "mode": "local"}'::JSONB;
  END IF;

  raise warning 'Not running local';


  -- OTHERWISE split up the data and route it accordingly

  select
    coalesce(jsonb_agg(d) filter (where d ->> 'region' = 'usa'), '[]'::JSONB),
    coalesce(jsonb_agg(d) filter (where d ->> 'region' = 'gbr'), '[]'::JSONB),
    coalesce(jsonb_agg(d) filter (where d ->> 'region' = 'aus'), '[]'::JSONB)
  from jsonb_array_elements(p_data) d
  into v_usa, v_gbr, v_aus;

  raise warning '%', v_usa;

  select public.uuid_generate_v4() INTO v_insert_uuid;

  insert into usa.trigger_cache(uuid, all_data, local_data)
    select v_insert_uuid, p_data, v_usa;
  raise warning 'Completed usa';

  insert into gbr.trigger_cache(uuid, all_data, local_data)
    select v_insert_uuid, p_data, v_gbr;
  raise warning 'Completed gbr';

  insert into aus.trigger_cache(uuid, all_data, local_data)
    select v_insert_uuid, p_data, v_aus;
  raise warning 'Completed aus';

  with data as (
      select
        j.uuid,
        j.name,
        j.customer_uuid,
        j.manager_uuid,
        j.email,
        j.gender,
        j.region,
        j.note,
        i.uuid IS NOT NULL as is_update
      from jsonb_to_recordset(p_data) as j(
           uuid UUID,
           name VARCHAR,
           customer_uuid UUID,
           manager_uuid UUID,
           email VARCHAR,
           gender VARCHAR,
           region VARCHAR,
           note VARCHAR
           )
        LEFT JOIN shared.identity i ON i.uuid = j.uuid
  )
  select jsonb_build_object(
    'usa_updated', count(1) filter (where region = 'usa' and is_update),
    'usa_created', count(1) filter (where region = 'usa' and not is_update),
    'gbr_updated', count(1) filter (where region = 'gbr' and is_update),
    'gbr_created', count(1) filter (where region = 'gbr' and not is_update),
    'aus_updated', count(1) filter (where region = 'aus' and is_update),
    'aus_created', count(1) filter (where region = 'aus' and not is_update)
  )
  from data d
  into v_result;

  raise warning 'Completed v_result';


  RETURN v_result;
END;
$$
LANGUAGE PLPGSQL;



DROP FUNCTION IF EXISTS shared.search_hierarchy(p_target_uuid UUID, p_regions VARCHAR[], p_manager_out_of_region BOOLEAN);
CREATE OR REPLACE FUNCTION shared.search_hierarchy(p_target_uuid UUID, p_regions VARCHAR[], p_manager_out_of_region BOOLEAN)
  RETURNS TABLE (name VARCHAR, uuid UUID, depth INT, region CHAR(3), local_manager BOOLEAN, manager VARCHAR, manager_uuid UUID, manager_region CHAR(3), upline TEXT, path UUID[])
AS
$$
DECLARE
  v_usa UUID[];
  v_gbr UUID[];
  v_aus UUID[];
BEGIN
  WITH targets AS (
      SELECT i.*
      FROM shared.hierarchy t
        INNER JOIN shared.hierarchy i ON i.path [t.depth] = t.uuid
      WHERE t.uuid = (p_target_uuid) :: UUID
  )
  select
    array_agg(t.uuid) filter (where t.region = 'usa') as usa,
    array_agg(t.uuid) filter (where t.region = 'gbr') as gbr,
    array_agg(t.uuid) filter (where t.region = 'aus') as aus
  from targets t
  into v_usa, v_gbr, v_aus;

  raise warning 'Usa: %', v_usa;
  raise warning 'Gbr: %', v_gbr;
  raise warning 'Aus: %', v_aus;


  return query
  WITH targets AS (
    select d.*
    from usa.identity_details d where d.uuid = any (v_usa)
    UNION
    select d.*
    from gbr.identity_details d where d.uuid = any (v_gbr)
    UNION
    select d.*
    from aus.identity_details d where d.uuid = any (v_aus)
  ), qualified AS (
      select t.*, h.manager_uuid, h.path, h.depth
      from targets t
        LEFT JOIN shared.hierarchy h on h.uuid = t.uuid
  ), upline AS (
      select
        c.uuid,
        array_agg(q.name ORDER BY q.depth) as upline
      from qualified c
        LEFT JOIN qualified q ON c.path @> array[q.uuid]
      WHERE c.manager_uuid IS NOT NULL
      GROUP BY c.uuid
  )
  select
    q.name,
    q.uuid,
    q.depth,
    q.region,
    m.region = q.region as local_manager,
    m.name as manager,
    m.uuid as manager_uuid,
    m.region as manager_region,
    array_to_string(u.upline, ' > ' ) upline,
    q.path
  from qualified q
    LEFT JOIN qualified m on m.uuid = q.manager_uuid
    LEFT JOIN upline u on u.uuid = q.uuid
  WHERE TRUE
        AND ( p_regions IS NULL OR q.region = ANY (p_regions) )
        AND ( p_manager_out_of_region != TRUE OR m.region != q.region )
  ORDER BY q.depth
  ;

END;
$$
LANGUAGE plpgsql;
