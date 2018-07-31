
CREATE OR REPLACE FUNCTION ${localNs}.trigger_cache_trigger()
  RETURNS TRIGGER AS $$
BEGIN
  perform shared.upsert(NEW.all_data, NEW.local_data);
  return NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER insert_trigger_cache
  AFTER INSERT ON ${localNs}.trigger_cache
  FOR EACH ROW EXECUTE PROCEDURE ${localNs}.trigger_cache_trigger();