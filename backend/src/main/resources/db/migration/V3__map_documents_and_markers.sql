CREATE TABLE IF NOT EXISTS map_document (
  id VARCHAR(80) PRIMARY KEY,
  name VARCHAR(128) NOT NULL,
  pdf_bucket VARCHAR(128) NULL,
  pdf_object_name VARCHAR(512) NULL,
  background_bucket VARCHAR(128) NULL,
  background_object_name VARCHAR(512) NULL,
  background_url VARCHAR(512) NOT NULL,
  width INT NOT NULL,
  height INT NOT NULL,
  created_by BIGINT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS map_marker (
  id VARCHAR(80) PRIMARY KEY,
  map_id VARCHAR(80) NOT NULL,
  station_id VARCHAR(64) NOT NULL,
  position_x DECIMAL(10,2) NOT NULL,
  position_y DECIMAL(10,2) NOT NULL,
  size DECIMAL(6,2) NOT NULL DEFAULT 8.00,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_map_marker_map (map_id),
  INDEX idx_map_marker_station (station_id),
  CONSTRAINT fk_map_marker_map FOREIGN KEY (map_id) REFERENCES map_document(id) ON DELETE CASCADE,
  CONSTRAINT fk_map_marker_station FOREIGN KEY (station_id) REFERENCES map_station(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO map_document (id, name, background_url, width, height, created_by, created_at)
VALUES ('default-map', '默认地图', '/assets/full-map.svg', 1191, 842, 1, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE name = VALUES(name), background_url = VALUES(background_url), width = VALUES(width), height = VALUES(height);

INSERT INTO map_marker (id, map_id, station_id, position_x, position_y, size, created_at, updated_at)
SELECT CONCAT('default-marker-', id), 'default-map', id, position_x, position_y, GREATEST(size * 2, 8), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM map_station s
WHERE NOT EXISTS (
  SELECT 1 FROM map_marker m WHERE m.id = CONCAT('default-marker-', s.id)
);
