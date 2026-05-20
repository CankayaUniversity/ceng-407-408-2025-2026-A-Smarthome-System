-- EMERGENCY: stop deleting rows on every events INSERT.
-- Run this immediately in Supabase SQL Editor if Surveillance / snapshots look empty.

DROP TRIGGER IF EXISTS events_retention_prune ON public.events;

-- Optional: keep function for manual alert-only cleanup later:
-- SELECT public.prune_events_retention();
