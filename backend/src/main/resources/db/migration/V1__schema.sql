CREATE TABLE IF NOT EXISTS sys_user (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  real_name VARCHAR(64) NOT NULL,
  phone VARCHAR(32),
  status VARCHAR(32) NOT NULL DEFAULT 'ENABLED',
  approval_status VARCHAR(32) NOT NULL DEFAULT 'APPROVED',
  is_super_admin TINYINT(1) NOT NULL DEFAULT 0,
  last_login_time DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT(1) NOT NULL DEFAULT 0,
  INDEX idx_sys_user_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS map_station (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(128) NOT NULL,
  auto_name VARCHAR(128) NOT NULL,
  type VARCHAR(32) NOT NULL,
  color VARCHAR(16) NOT NULL,
  line_name VARCHAR(128) NOT NULL DEFAULT '',
  mileage VARCHAR(64) NOT NULL DEFAULT '',
  position_x DECIMAL(10,2) NOT NULL,
  position_y DECIMAL(10,2) NOT NULL,
  size DECIMAL(6,2) NOT NULL DEFAULT 4.40,
  default_workshop_id VARCHAR(64) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_map_station_workshop (default_workshop_id),
  INDEX idx_map_station_position (position_y, position_x)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS station_profile (
  station_id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(128) NOT NULL DEFAULT '',
  notes TEXT,
  workshop_id VARCHAR(64),
  updated_by BIGINT,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_station_profile_station FOREIGN KEY (station_id) REFERENCES map_station(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS station_folder (
  id VARCHAR(80) PRIMARY KEY,
  station_id VARCHAR(64) NOT NULL,
  parent_id VARCHAR(80) NULL,
  name VARCHAR(128) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_station_folder_station (station_id, parent_id, sort_order),
  CONSTRAINT fk_station_folder_station FOREIGN KEY (station_id) REFERENCES map_station(id) ON DELETE CASCADE,
  CONSTRAINT fk_station_folder_parent FOREIGN KEY (parent_id) REFERENCES station_folder(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS station_image (
  id VARCHAR(80) PRIMARY KEY,
  station_id VARCHAR(64) NOT NULL,
  folder_id VARCHAR(80) NOT NULL,
  name VARCHAR(160) NOT NULL,
  content_type VARCHAR(100) NOT NULL,
  size_bytes BIGINT NOT NULL DEFAULT 0,
  bucket VARCHAR(128) NOT NULL,
  object_name VARCHAR(512) NOT NULL,
  created_by BIGINT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_station_image_station (station_id),
  INDEX idx_station_image_folder (folder_id),
  CONSTRAINT fk_station_image_station FOREIGN KEY (station_id) REFERENCES map_station(id) ON DELETE CASCADE,
  CONSTRAINT fk_station_image_folder FOREIGN KEY (folder_id) REFERENCES station_folder(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO sys_user (id, username, password, real_name, phone, status, approval_status, is_super_admin, deleted)
VALUES (1, 'admin', '$2y$10$JLYTEoDd2O7bkkA9W176He7tuLuAMKNQ4baclBgz02t4mD8FO3joW', '系统管理员', '00000000000', 'ENABLED', 'APPROVED', 1, 0)
ON DUPLICATE KEY UPDATE real_name = VALUES(real_name);
