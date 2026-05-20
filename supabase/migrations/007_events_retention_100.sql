-- Keep only the latest 100 rows in public.events to limit storage growth.

CREATE OR REPLACE FUNCTION public.prune_events_retention()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Alert-only retention (see 010_surveillance_retention_fix.sql for full policy)
  DELETE FROM public.events e
  USING (
    SELECT id
    FROM public.events
    WHERE event_type IN (
      'fire_alert',
      'fire_alert_cleared',
      'low_moisture',
      'moisture_restored',
      'flood',
      'flood_cleared',
      'gas',
      'gas_alert'
    )
    ORDER BY created_at DESC
    OFFSET 100
  ) stale
  WHERE e.id = stale.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_prune_events_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.prune_events_retention();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS events_retention_prune ON public.events;

CREATE TRIGGER events_retention_prune
  AFTER INSERT ON public.events
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_prune_events_after_insert();

-- One-time trim for existing data
SELECT public.prune_events_retention();
