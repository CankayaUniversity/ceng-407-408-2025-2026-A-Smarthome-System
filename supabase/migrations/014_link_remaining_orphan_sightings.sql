-- Link orphan sightings after 013. Run steps 1–2 first; step 3 uses a PL/pgSQL loop.
-- Supabase RLS warning on TEMP → "Run without RLS".

-- 1) Audit path → existing camera_events
UPDATE public.unknown_face_sightings ufs
SET camera_event_id = ce.id
FROM public.event_faces ef
JOIN LATERAL (
  SELECT fla.metadata->>'snapshot_path' AS p
  FROM public.face_label_actions fla
  WHERE fla.event_face_id = ef.id
    AND fla.metadata->>'snapshot_path' IS NOT NULL
  ORDER BY fla.created_at DESC
  LIMIT 1
) audit ON true
JOIN public.camera_events ce ON ce.snapshot_path = audit.p
WHERE ufs.event_face_id = ef.id
  AND ufs.camera_event_id IS NULL;

-- 2) Profile representative path → existing camera_events
UPDATE public.unknown_face_sightings ufs
SET camera_event_id = ce.id
FROM public.unknown_face_profiles ufp
JOIN public.camera_events ce ON ce.snapshot_path = ufp.representative_snapshot_path
WHERE ufs.unknown_face_profile_id = ufp.id
  AND ufs.camera_event_id IS NULL
  AND ufp.representative_snapshot_path IS NOT NULL;

-- 3) Remaining orphans: one new event + camera_event per audit path
DO $$
DECLARE
  r RECORD;
  v_device_id UUID;
  v_event_id UUID;
  v_cam_id UUID;
BEGIN
  SELECT id INTO v_device_id FROM public.devices ORDER BY created_at NULLS LAST LIMIT 1;
  IF v_device_id IS NULL THEN
    SELECT id INTO v_device_id FROM public.devices LIMIT 1;
  END IF;

  FOR r IN
    SELECT
      ufs.id AS sighting_id,
      ufs.created_at AS sighting_at,
      (
        SELECT fla.metadata->>'snapshot_path'
        FROM public.face_label_actions fla
        WHERE fla.event_face_id = ufs.event_face_id
          AND fla.metadata->>'snapshot_path' IS NOT NULL
        ORDER BY fla.created_at DESC
        LIMIT 1
      ) AS snapshot_path
    FROM public.unknown_face_sightings ufs
    WHERE ufs.camera_event_id IS NULL
      AND ufs.event_face_id IS NOT NULL
  LOOP
    IF r.snapshot_path IS NULL THEN
      CONTINUE;
    END IF;

    SELECT id INTO v_cam_id
    FROM public.camera_events
    WHERE snapshot_path = r.snapshot_path
    LIMIT 1;

    IF v_cam_id IS NULL THEN
      INSERT INTO public.events (device_id, event_type, priority, message, status, created_at)
      VALUES (
        v_device_id,
        'stranger_detected',
        'high',
        'Recovered snapshot (pass 2)',
        'acknowledged',
        r.sighting_at
      )
      RETURNING id INTO v_event_id;

      INSERT INTO public.camera_events (event_id, snapshot_path, human_detected, face_count, created_at)
      VALUES (v_event_id, r.snapshot_path, true, 1, r.sighting_at)
      RETURNING id INTO v_cam_id;
    END IF;

    UPDATE public.unknown_face_sightings
    SET camera_event_id = v_cam_id
    WHERE id = r.sighting_id;

    UPDATE public.event_faces ef
    SET camera_event_id = v_cam_id
    FROM public.unknown_face_sightings ufs
    WHERE ufs.id = r.sighting_id
      AND ef.id = ufs.event_face_id;
  END LOOP;
END $$;

SELECT
  (SELECT COUNT(*) FROM public.camera_events) AS camera_events_total,
  (SELECT COUNT(*) FROM public.unknown_face_sightings WHERE camera_event_id IS NULL) AS sightings_still_orphan;
