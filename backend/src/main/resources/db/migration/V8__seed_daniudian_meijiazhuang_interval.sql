INSERT INTO station_profile (station_id, name, notes, workshop_id, updated_at) VALUES
  ('red-45508-28550', '梅家庄', '', NULL, CURRENT_TIMESTAMP),
  ('red-46797-28560', '大牛店', '', NULL, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE name = VALUES(name), updated_at = CURRENT_TIMESTAMP;

INSERT INTO map_interval (id, map_id, marker_a_id, marker_b_id, base_stations)
SELECT 'interval-daniudian-meijiazhuang', marker_a.map_id, marker_a.id, marker_b.id,
       CONCAT('茶坞K220+550基站', CHAR(10), '茶坞东K221+550基站', CHAR(10), '茶坞西K550+551基站')
FROM map_marker marker_a
JOIN map_marker marker_b ON marker_b.map_id = marker_a.map_id
WHERE marker_a.id = 'default-marker-red-46797-28560'
  AND marker_b.id = 'default-marker-red-45508-28550'
  AND NOT EXISTS (
    SELECT 1 FROM map_interval existing
    WHERE existing.map_id = marker_a.map_id
      AND ((existing.marker_a_id = marker_a.id AND existing.marker_b_id = marker_b.id)
        OR (existing.marker_a_id = marker_b.id AND existing.marker_b_id = marker_a.id))
  );
