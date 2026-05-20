-- Run in Supabase SQL Editor. Part A = diagnose, Part B = fix (run B after reading A).

-- ═══ A) DIAGNOSE: why 18 orphans did not link ═══
SELECT
  ufs.id AS sighting_id,
  ufs.created_at,
  ufs.event_face_id,
  ufs.camera_event_id,
  (
    SELECT fla.metadata->>'snapshot_path'
    FROM public.face_label_actions fla
    WHERE fla.event_face_id = ufs.event_face_id
      AND fla.metadata->>'snapshot_path' IS NOT NULL
    ORDER BY fla.created_at DESC
    LIMIT 1
  ) AS audit_path,
  ufp.representative_snapshot_path AS profile_path,
  (
    SELECT ce.id
    FROM public.camera_events ce
    WHERE ce.snapshot_path = (
      SELECT fla.metadata->>'snapshot_path'
      FROM public.face_label_actions fla
      WHERE fla.event_face_id = ufs.event_face_id
        AND fla.metadata->>'snapshot_path' IS NOT NULL
      ORDER BY fla.created_at DESC
      LIMIT 1
    )
    LIMIT 1
  ) AS matching_cam_id
FROM public.unknown_face_sightings ufs
LEFT JOIN public.unknown_face_profiles ufp ON ufp.id = ufs.unknown_face_profile_id
WHERE ufs.camera_event_id IS NULL
ORDER BY ufs.created_at;

-- ═══ B) FIX: force-link where audit path matches an existing camera_events row ═══
UPDATE public.unknown_face_sightings ufs
SET camera_event_id = sub.ce_id
FROM (
  SELECT
    ufs2.id AS sighting_id,
    (
      SELECT ce.id
      FROM public.camera_events ce
      WHERE ce.snapshot_path = (
        SELECT fla.metadata->>'snapshot_path'
        FROM public.face_label_actions fla
        WHERE fla.event_face_id = ufs2.event_face_id
          AND fla.metadata->>'snapshot_path' IS NOT NULL
        ORDER BY fla.created_at DESC
        LIMIT 1
      )
      LIMIT 1
    ) AS ce_id
  FROM public.unknown_face_sightings ufs2
  WHERE ufs2.camera_event_id IS NULL
) sub
WHERE ufs.id = sub.sighting_id
  AND sub.ce_id IS NOT NULL;

-- ═══ C) FIX: create camera_event for orphans that have audit_path but no matching row ═══
DO $$
DECLARE
  r RECORD;
  v_device UUID;
  v_ev UUID;
  v_cam UUID;
  v_path TEXT;
BEGIN
  SELECT id INTO v_device FROM public.devices ORDER BY created_at NULLS LAST LIMIT 1;

  FOR r IN
    SELECT ufs.id AS sighting_id, ufs.event_face_id, ufs.created_at AS sighting_at
    FROM public.unknown_face_sightings ufs
    WHERE ufs.camera_event_id IS NULL
  LOOP
    v_path := NULL;
    SELECT fla.metadata->>'snapshot_path' INTO v_path
    FROM public.face_label_actions fla
    WHERE fla.event_face_id = r.event_face_id
      AND fla.metadata->>'snapshot_path' IS NOT NULL
    ORDER BY fla.created_at DESC
    LIMIT 1;

    IF v_path IS NULL THEN
      SELECT ufp.representative_snapshot_path INTO v_path
      FROM public.unknown_face_sightings ufs
      JOIN public.unknown_face_profiles ufp ON ufp.id = ufs.unknown_face_profile_id
      WHERE ufs.id = r.sighting_id;
    END IF;

    IF v_path IS NULL OR btrim(v_path) = '' THEN
      CONTINUE;
    END IF;

    SELECT id INTO v_cam FROM public.camera_events WHERE snapshot_path = v_path LIMIT 1;

    IF v_cam IS NULL THEN
      INSERT INTO public.events (device_id, event_type, priority, message, status, created_at)
      VALUES (v_device, 'stranger_detected', 'high', 'Recovered (014b)', 'acknowledged', r.sighting_at)
      RETURNING id INTO v_ev;

      INSERT INTO public.camera_events (event_id, snapshot_path, human_detected, face_count, created_at)
      VALUES (v_ev, v_path, true, 1, r.sighting_at)
      RETURNING id INTO v_cam;
    END IF;

    UPDATE public.unknown_face_sightings SET camera_event_id = v_cam WHERE id = r.sighting_id;

    IF r.event_face_id IS NOT NULL THEN
      UPDATE public.event_faces SET camera_event_id = v_cam WHERE id = r.event_face_id;
    END IF;
  END LOOP;
END $$;

-- ═══ D) Summary ═══
SELECT
  (SELECT COUNT(*) FROM public.camera_events) AS camera_events_total,
  (SELECT COUNT(*) FROM public.unknown_face_sightings WHERE camera_event_id IS NULL) AS sightings_still_orphan;
