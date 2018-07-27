CREATE OR REPLACE VIEW shared.hierarchy AS (
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
  ORDER BY t.depth, t.path
);