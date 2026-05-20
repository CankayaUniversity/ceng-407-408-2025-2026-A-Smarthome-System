-- Rename legacy sensor_type `water` → `soil_moisture` (plant soil probe, not leak detection).

UPDATE public.sensor_readings
SET sensor_type = 'soil_moisture'
WHERE sensor_type = 'water';
