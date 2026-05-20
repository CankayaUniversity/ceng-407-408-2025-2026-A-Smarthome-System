-- Repair cluster/sighting thumbnails after camera_events were removed (007 CASCADE).
-- Storage JPEGs in bucket event-snapshots are usually still present.

-- 1) Re-link sightings → camera_events via surviving event_faces
UPDATE public.unknown_face_sightings ufs
SET camera_event_id = ef.camera_event_id
FROM public.event_faces ef
WHERE ufs.event_face_id = ef.id
  AND ufs.camera_event_id IS NULL
  AND ef.camera_event_id IS NOT NULL;

-- 2) Check remaining orphans (expect lower count; May 16 rows may stay null)
SELECT
  COUNT(*) AS total_sightings,
  COUNT(*) FILTER (WHERE camera_event_id IS NULL) AS orphan_sightings,
  COUNT(*) FILTER (WHERE camera_event_id IS NOT NULL) AS linked_sightings
FROM public.unknown_face_sightings;

-- 3) Orphans that still have event_face + path in audit log (UI can use metadata)
SELECT
  ufs.id,
  ufs.created_at,
  ef.id AS event_face_id,
  ef.camera_event_id,
  (
    SELECT fla.metadata->>'snapshot_path'
    FROM public.face_label_actions fla
    WHERE fla.event_face_id = ef.id
      AND fla.metadata->>'snapshot_path' IS NOT NULL
    ORDER BY fla.created_at DESC
    LIMIT 1
  ) AS snapshot_path_from_audit
FROM public.unknown_face_sightings ufs
LEFT JOIN public.event_faces ef ON ef.id = ufs.event_face_id
WHERE ufs.camera_event_id IS NULL
ORDER BY ufs.created_at DESC
LIMIT 30;
