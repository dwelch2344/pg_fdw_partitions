CREATE OR REPLACE FUNCTION shared.upsert_identity(
  p_uuid   UUID,
  p_name   VARCHAR,
  p_region VARCHAR,
  p_note   VARCHAR
) RETURNS VARCHAR AS $$

DECLARE
  v_identity shared.identity;
  v_update BOOLEAN;
  v_count BIGINT;
  v_is_owner BOOLEAN := FALSE;
BEGIN
  INSERT INTO shared.identity (uuid, region, note)
    select p_uuid, p_region, p_note
    WHERE 'inserted' = set_config('upsert.action', 'inserted', true)
  ON CONFLICT (uuid) DO UPDATE SET
    note = p_note
    WHERE 'updated' = set_config('upsert.action', 'updated', true)
  returning * into v_identity;

  v_update := current_setting('upsert.action') = 'updated';
  raise warning 'updating: %', v_update;

  IF v_identity.region != p_region THEN
    raise exception 'Unable to move Identity % from region % to region %', p_uuid, v_identity.region, p_region;
  END IF;

  IF v_update THEN
    -- sync the identity remotely
    UPDATE ${remote1ns}.identity i SET
      note = p_note
    WHERE i.uuid = p_uuid;
    UPDATE ${remote2ns}.identity i SET
      note = p_note
    WHERE i.uuid = p_uuid;
  ELSE
    -- insert the identity remotely
    INSERT INTO ${remote1ns}.identity (uuid, region, note, created_on)
    select p_uuid, p_region, p_note, v_identity.created_on;
    INSERT INTO ${remote2ns}.identity (uuid, region, note, created_on)
    select p_uuid, p_region, p_note, v_identity.created_on;
  END IF;


  -- now handle the actual PII
  IF p_region = '${localNs}' THEN 
    v_is_owner := true;
    IF v_update THEN
      WITH t1 as (
        UPDATE ${localNs}.identity_details d
        SET
          name = p_name
        WHERE d.uuid = p_uuid
        RETURNING *
      )
      SELECT count(*) from t1 into v_count;
      IF v_count != 1 THEN
        RAISE EXCEPTION 'Unexpected update count for Identity % details in % region; affected % rows', p_uuid, '${localNs}', v_count;
      END IF;
    ELSE
      INSERT INTO ${localNs}.identity_details (uuid, region, name) VALUES
        (p_uuid, p_region, p_name);
    END IF;
  END IF;

  IF p_region = '${remote1ns}' THEN
    IF v_update THEN
      WITH t1 as (
        UPDATE ${remote1ns}.identity_details d
        SET
          name = p_name
        WHERE d.uuid = p_uuid
        RETURNING *
      )
      SELECT count(*) from t1 into v_count;
      IF v_count != 1 THEN
        RAISE EXCEPTION 'Unexpected update count for Identity % details in % region; affected % rows', p_uuid, '${remote1ns}', v_count;
      END IF;
    ELSE
      INSERT INTO ${remote1ns}.identity_details (uuid, region, name) VALUES
        (p_uuid, p_region, p_name);
    END IF;
  END IF;

  IF p_region = '${remote2ns}' THEN
    IF v_update THEN
      WITH t1 as (
        UPDATE ${remote2ns}.identity_details d
        SET
          name = p_name
        WHERE d.uuid = p_uuid
        RETURNING *
      )
      SELECT count(*) from t1 into v_count;
      IF v_count != 1 THEN
        RAISE EXCEPTION 'Unexpected update count for Identity % details in % region; affected % rows', p_uuid, '${remote2ns}', v_count;
      END IF;
    ELSE
      INSERT INTO ${remote2ns}.identity_details (uuid, region, name) VALUES
        (p_uuid, p_region, p_name);
    END IF;
  END IF;

  RETURN concat_ws(' ', p_uuid::VARCHAR, v_update::VARCHAR, v_is_owner::VARCHAR);
END;
$$
LANGUAGE plpgsql
STRICT
SECURITY DEFINER;