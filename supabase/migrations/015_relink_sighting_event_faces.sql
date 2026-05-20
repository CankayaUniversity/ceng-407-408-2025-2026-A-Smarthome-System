-- Restore Move / Ungroup / Resident buttons on Identity sighting timeline.
-- 014b linked camera_event_id via profile representative path but left event_face_id NULL.
-- Buttons require event_faces (RPCs use p_event_face_id).

-- 1) Link sightings → existing event_faces on same camera_event
UPDATE public.unknown_face_sightings ufs
SET event_face_id = sub.ef_id
FROM (
  SELECT
    ufs2.id AS sighting_id,
    (
      SELECT ef.id
      FROM public.event_faces ef
      WHERE ef.camera_event_id = ufs2.camera_event_id
      ORDER BY ef.id
      LIMIT 1
    ) AS ef_id
  FROM public.unknown_face_sightings ufs2
  WHERE ufs2.event_face_id IS NULL
    AND ufs2.camera_event_id IS NOT NULL
) sub
WHERE ufs.id = sub.sighting_id
  AND sub.ef_id IS NOT NULL;

-- 2) Stub event_faces for recovered camera_events that have no face row yet
INSERT INTO public.event_faces (camera_event_id, classification, unknown_profile_id)
SELECT DISTINCT ON (ce.id)
  ce.id,
  'unknown',
  ufs.unknown_face_profile_id
FROM public.unknown_face_sightings ufs
JOIN public.camera_events ce ON ce.id = ufs.camera_event_id
WHERE ufs.event_face_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.event_faces ef WHERE ef.camera_event_id = ce.id
  )
ORDER BY ce.id, ufs.created_at DESC;

-- 3) Link sightings → newly created (or still missing) event_faces
UPDATE public.unknown_face_sightings ufs
SET event_face_id = sub.ef_id
FROM (
  SELECT
    ufs2.id AS sighting_id,
    (
      SELECT ef.id
      FROM public.event_faces ef
      WHERE ef.camera_event_id = ufs2.camera_event_id
      ORDER BY ef.id
      LIMIT 1
    ) AS ef_id
  FROM public.unknown_face_sightings ufs2
  WHERE ufs2.event_face_id IS NULL
    AND ufs2.camera_event_id IS NOT NULL
) sub
WHERE ufs.id = sub.sighting_id
  AND sub.ef_id IS NOT NULL;

-- 4) Keep profile id on face rows in sync
UPDATE public.event_faces ef
SET unknown_profile_id = ufs.unknown_face_profile_id
FROM public.unknown_face_sightings ufs
WHERE ef.camera_event_id = ufs.camera_event_id
  AND ef.unknown_profile_id IS DISTINCT FROM ufs.unknown_face_profile_id
  AND ufs.unknown_face_profile_id IS NOT NULL;

SELECT
  (SELECT COUNT(*) FROM public.unknown_face_sightings WHERE camera_event_id IS NULL) AS sightings_orphan_cam,
  (SELECT COUNT(*) FROM public.unknown_face_sightings WHERE event_face_id IS NULL) AS sightings_missing_event_face;
