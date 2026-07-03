CREATE TABLE IF NOT EXISTS map_workshop (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(128) NOT NULL,
  color VARCHAR(32) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_map_workshop_sort (sort_order, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO map_workshop (id, code, name, color, sort_order) VALUES
  (1, 'north', '北部车间', '#0f766e', 10),
  (2, 'middle', '中部车间', '#1d4ed8', 20),
  (3, 'south', '南部车间', '#9f5f1a', 30),
  (4, 'east', '东部车间', '#7c3aed', 40)
ON DUPLICATE KEY UPDATE
  code = VALUES(code),
  name = VALUES(name),
  color = VALUES(color),
  sort_order = VALUES(sort_order);
