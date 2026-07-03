UPDATE map_marker m
JOIN map_station s ON m.map_id = 'default-map' AND m.id = CONCAT('default-marker-', s.id)
SET m.size = s.size
WHERE m.size <> s.size;
