-- Surveillance history must survive alert/event pruning.
-- camera_events + snapshots are independent of push-notification rows in `events`.

-- 1) Deleting an `events` row must not remove camera history
ALTER TABLE public.camera_events
  DROP CONSTRAINT IF EXISTS camera_events_event_id_fkey;

ALTER TABLE public.camera_events
  ADD CONSTRAINT camera_events_event_id_fkey
  FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE SET NULL;

-- 2) Only prune environmental/alert events (not face/security events tied to snapshots)
CREATE OR REPLACE FUNCTION public.prune_events_retention()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
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
