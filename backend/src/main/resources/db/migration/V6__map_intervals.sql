CREATE TABLE IF NOT EXISTS map_interval (
  id VARCHAR(80) PRIMARY KEY,
  map_id VARCHAR(80) NOT NULL,
  marker_a_id VARCHAR(80) NOT NULL,
  marker_b_id VARCHAR(80) NOT NULL,
  base_stations TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_map_interval_map (map_id),
  INDEX idx_map_interval_marker_a (marker_a_id),
  INDEX idx_map_interval_marker_b (marker_b_id),
  CONSTRAINT fk_map_interval_map FOREIGN KEY (map_id) REFERENCES map_document(id) ON DELETE CASCADE,
  CONSTRAINT fk_map_interval_marker_a FOREIGN KEY (marker_a_id) REFERENCES map_marker(id) ON DELETE CASCADE,
  CONSTRAINT fk_map_interval_marker_b FOREIGN KEY (marker_b_id) REFERENCES map_marker(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO map_interval (id, map_id, marker_a_id, marker_b_id, base_stations)
SELECT 'interval-daniudian-meijiazhuang', marker_a.map_id, marker_a.id, marker_b.id,
       CONCAT('茶坞K220+550基站', CHAR(10), '茶坞东K221+550基站', CHAR(10), '茶坞西K550+551基站')
FROM map_marker marker_a
JOIN map_station station_a ON station_a.id = marker_a.station_id
LEFT JOIN station_profile profile_a ON profile_a.station_id = station_a.id
JOIN map_marker marker_b ON marker_b.map_id = marker_a.map_id AND marker_b.id <> marker_a.id
JOIN map_station station_b ON station_b.id = marker_b.station_id
LEFT JOIN station_profile profile_b ON profile_b.station_id = station_b.id
WHERE COALESCE(NULLIF(profile_a.name, ''), station_a.name) = '大牛店'
  AND COALESCE(NULLIF(profile_b.name, ''), station_b.name) = '梅家庄'
ORDER BY marker_a.map_id, marker_a.id, marker_b.id
LIMIT 1;
