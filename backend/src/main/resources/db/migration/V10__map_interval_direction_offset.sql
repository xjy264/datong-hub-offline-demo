ALTER TABLE map_interval
  ADD COLUMN direction_offset DECIMAL(6,2) NOT NULL DEFAULT 0 AFTER base_stations;
