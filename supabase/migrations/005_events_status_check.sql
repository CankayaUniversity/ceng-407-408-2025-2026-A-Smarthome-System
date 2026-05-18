-- Align events.status with gateway + web (AlertsPage uses status = 'acknowledged').
-- Run in Supabase SQL Editor if inserts fail with events_status_check.
--
-- Inspect current constraint:
--   SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'events_status_check';

ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_status_check;

ALTER TABLE public.events
  ADD CONSTRAINT events_status_check
  CHECK (status IN ('pending', 'acknowledged'));

ALTER TABLE public.events
  ALTER COLUMN status SET DEFAULT 'pending';
