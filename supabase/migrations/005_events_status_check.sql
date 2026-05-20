-- Fix events.status values, then align CHECK with gateway + web.
-- Run the whole script in Supabase SQL Editor (order matters).

-- 1) Drop old constraint so updates are allowed
ALTER TABLE public.events DROP CONSTRAINT IF EXISTS events_status_check;

-- 2) Normalize existing rows (active/open/etc. → pending or acknowledged)
UPDATE public.events
SET status = 'acknowledged'
WHERE status IS DISTINCT FROM 'acknowledged'
  AND (
    acknowledged_at IS NOT NULL
    OR acknowledged IS TRUE
  );

UPDATE public.events
SET status = 'pending'
WHERE status IS NULL
   OR status NOT IN ('pending', 'acknowledged');

-- 3) Re-apply constraint + default for new inserts from Pi gateway
ALTER TABLE public.events
  ADD CONSTRAINT events_status_check
  CHECK (status IN ('pending', 'acknowledged'));

ALTER TABLE public.events
  ALTER COLUMN status SET DEFAULT 'pending';
