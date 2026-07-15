ALTER TABLE map_interval
  ADD COLUMN position_x DECIMAL(10,2) NULL AFTER direction_offset,
  ADD COLUMN position_y DECIMAL(10,2) NULL AFTER position_x,
  ADD COLUMN interval_length DECIMAL(10,2) NULL AFTER position_y,
  ADD COLUMN direction_angle DECIMAL(6,2) NULL AFTER interval_length;

UPDATE map_interval interval_row
JOIN map_marker marker_a ON marker_a.id = interval_row.marker_a_id
JOIN map_marker marker_b ON marker_b.id = interval_row.marker_b_id
SET interval_row.position_x = (marker_a.position_x + marker_b.position_x) / 2,
    interval_row.position_y = (marker_a.position_y + marker_b.position_y) / 2,
    interval_row.interval_length = GREATEST(2, SQRT(POW(marker_b.position_x - marker_a.position_x, 2) + POW(marker_b.position_y - marker_a.position_y, 2)) - 2),
    interval_row.direction_angle = MOD(DEGREES(ATAN2(marker_b.position_y - marker_a.position_y, marker_b.position_x - marker_a.position_x)) + interval_row.direction_offset + 540, 360) - 180;

ALTER TABLE map_interval
  MODIFY marker_a_id VARCHAR(80) NULL,
  MODIFY marker_b_id VARCHAR(80) NULL,
  MODIFY position_x DECIMAL(10,2) NOT NULL DEFAULT 0,
  MODIFY position_y DECIMAL(10,2) NOT NULL DEFAULT 0,
  MODIFY interval_length DECIMAL(10,2) NOT NULL DEFAULT 12,
  MODIFY direction_angle DECIMAL(6,2) NOT NULL DEFAULT 0;
