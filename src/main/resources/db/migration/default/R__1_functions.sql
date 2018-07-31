
CREATE OR REPLACE FUNCTION shared.upsert_identity(
  p_uuid   UUID,
  p_name   VARCHAR,
  p_customer_uuid UUID,
  p_email  VARCHAR,
  p_gender VARCHAR,
  p_region VARCHAR,
  p_note   VARCHAR
) RETURNS VARCHAR AS $$
DECLARE
  v_identity shared.identity;
  v_update BOOLEAN;
  v_count BIGINT;
  v_is_owner BOOLEAN := FALSE;
BEGIN
  INSERT INTO shared.identity (uuid, customer_uuid, gender, region, note)
    select p_uuid, p_customer_uuid, p_gender, p_region, p_note
    WHERE 'inserted' = set_config('upsert.action', 'inserted', true)
  ON CONFLICT (uuid) DO UPDATE SET
    customer_uuid = p_customer_uuid,
    gender = p_gender,
    note = p_note
    WHERE 'updated' = set_config('upsert.action', 'updated', true)
  returning * into v_identity;

  v_update := current_setting('upsert.action') = 'updated';
--   raise warning 'updating: %', v_update;

--   v_count = split_part(p_name, ' ', 2)::BIGINT;
--   IF v_count % 1000 = 0 THEN
--     raise warning 'Hit person %', p_name;
--   END IF;

  IF v_identity.region != p_region THEN
    raise exception 'Unable to move Identity % from region % to region %', p_uuid, v_identity.region, p_region;
  END IF;

  IF v_update THEN
    -- sync the identity remotely
    UPDATE ${remote1ns}.identity i SET
      customer_uuid = p_customer_uuid,
      gender = p_gender,
      note = p_note
    WHERE i.uuid = p_uuid;
    UPDATE ${remote2ns}.identity i SET
      customer_uuid = p_customer_uuid,
      gender = p_gender,
      note = p_note
    WHERE i.uuid = p_uuid;
  ELSE
    -- insert the identity remotely
    INSERT INTO ${remote1ns}.identity (uuid, customer_uuid, gender, region, note, created_on)
    select p_uuid, p_customer_uuid, p_gender, p_region, p_note, v_identity.created_on;
    INSERT INTO ${remote2ns}.identity (uuid, customer_uuid, gender, region, note, created_on)
    select p_uuid, p_customer_uuid, p_gender, p_region, p_note, v_identity.created_on;
  END IF;


  -- now handle the actual PII
  IF p_region = '${localNs}' THEN 
    v_is_owner := true;
    IF v_update THEN
      WITH t1 as (
        UPDATE ${localNs}.identity_details d
        SET
          customer_uuid = p_customer_uuid,
          name = p_name,
          email = p_email
        WHERE d.uuid = p_uuid
        RETURNING *
      )
      SELECT count(*) from t1 into v_count;
      IF v_count != 1 THEN
        RAISE EXCEPTION 'Unexpected update count for Identity % details in % region; affected % rows', p_uuid, '${localNs}', v_count;
      END IF;
    ELSE
      INSERT INTO ${localNs}.identity_details (uuid, customer_uuid, region, name, email) VALUES
        (p_uuid, p_customer_uuid, p_region, p_name, p_email);
    END IF;
  END IF;

  IF p_region = '${remote1ns}' THEN
    IF v_update THEN
      WITH t1 as (
        UPDATE ${remote1ns}.identity_details d
        SET
          customer_uuid = p_customer_uuid,
          name = p_name,
          email = p_email
        WHERE d.uuid = p_uuid
        RETURNING *
      )
      SELECT count(*) from t1 into v_count;
      IF v_count != 1 THEN
        RAISE EXCEPTION 'Unexpected update count for Identity % details in % region; affected % rows', p_uuid, '${remote1ns}', v_count;
      END IF;
    ELSE
      INSERT INTO ${remote1ns}.identity_details (uuid, customer_uuid, region, name, email) VALUES
        (p_uuid, p_customer_uuid, p_region, p_name, p_email);
    END IF;
  END IF;

  IF p_region = '${remote2ns}' THEN
    IF v_update THEN
      WITH t1 as (
        UPDATE ${remote2ns}.identity_details d
        SET
          customer_uuid = p_customer_uuid,
          name = p_name,
          email = p_email
        WHERE d.uuid = p_uuid
        RETURNING *
      )
      SELECT count(*) from t1 into v_count;
      IF v_count != 1 THEN
        RAISE EXCEPTION 'Unexpected update count for Identity % details in % region; affected % rows', p_uuid, '${remote2ns}', v_count;
      END IF;
    ELSE
      INSERT INTO ${remote2ns}.identity_details (uuid, customer_uuid, region, name, email) VALUES
      (p_uuid, p_customer_uuid, p_region, p_name, p_email);
    END IF;
  END IF;

  RETURN concat_ws(' | ', p_uuid::VARCHAR, v_update::VARCHAR, v_is_owner::VARCHAR, p_region);
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER;







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
DROP FUNCTION IF EXISTS util.create_manager_tree(BIGINT, JSONB);
CREATE OR REPLACE FUNCTION util.create_manager_tree(p_depth BIGINT)
  RETURNS TABLE(root UUID, stats JSONB) AS $$
DECLARE
  v_root UUID;
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

  -- fail if empty

  v_update = '[]'::JSONB;
  v_current := v_root;

  FOR idx IN 1..p_depth LOOP
    WITH targets as (
      SELECT i.*
      FROM shared.identity i
      WHERE i.manager_uuid IS NULL
        AND i.uuid != v_root
        AND i.uuid not in ((
          select (u->>'uuid')::UUID
          from jsonb_array_elements(v_update) u
        ))
      ORDER BY random()
    ), t1 AS (
      select
        t.uuid, t.customer_uuid, t.region,
        d.name, d.email, t.gender, t.note,
        v_current manager_uuid
      from targets t
        LEFT join shared.identity_details d on d.uuid = t.uuid
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

