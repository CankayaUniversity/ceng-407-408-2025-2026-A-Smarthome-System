-- Recover Surveillance + cluster thumbnails when Storage still has JPEGs
-- but camera_events / events rows were removed (007 CASCADE).
-- Run AFTER 011 (disable prune) and 012 (relink). Safe to run more than once.
-- Supabase RLS warning on TEMP tables → choose "Run without RLS".

-- ── A) Paths for orphan sightings (audit log + profile representative) ──
CREATE TEMP TABLE _recover_paths ON COMMIT DROP AS
SELECT DISTINCT ON (ufs.id)
  ufs.id AS sighting_id,
  ufs.event_face_id,
  ufs.created_at AS sighting_at,
  COALESCE(
    (
      SELECT fla.metadata->>'snapshot_path'
      FROM public.face_label_actions fla
      WHERE fla.event_face_id = ufs.event_face_id
        AND fla.metadata->>'snapshot_path' IS NOT NULL
      ORDER BY fla.created_at DESC
      LIMIT 1
    ),
    ufp.representative_snapshot_path
  ) AS snapshot_path
FROM public.unknown_face_sightings ufs
JOIN public.unknown_face_profiles ufp ON ufp.id = ufs.unknown_face_profile_id
WHERE ufs.camera_event_id IS NULL
  AND ufs.event_face_id IS NOT NULL
ORDER BY ufs.id, ufs.created_at DESC;

-- ── B) Re-create pruned events rows (UUID is embedded in snapshot filename) ──
INSERT INTO public.events (id, device_id, event_type, priority, message, status, created_at)
SELECT
  (substring(rp.snapshot_path FROM '(?:unknown_snapshots|resident_snapshots)/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_'))::uuid,
  COALESCE(
    (SELECT id FROM public.devices ORDER BY created_at NULLS LAST LIMIT 1),
    (SELECT id FROM public.devices LIMIT 1)
  ),
  'stranger_detected',
  'high',
  'Recovered snapshot (historical)',
  'acknowledged',
  rp.sighting_at
FROM _recover_paths rp
WHERE rp.snapshot_path IS NOT NULL
  AND rp.snapshot_path ~ '(unknown_snapshots|resident_snapshots)/[0-9a-f]{8}-'
  AND NOT EXISTS (
    SELECT 1 FROM public.events e
    WHERE e.id = (substring(rp.snapshot_path FROM '(?:unknown_snapshots|resident_snapshots)/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_'))::uuid
  )
ON CONFLICT (id) DO NOTHING;

-- ── C) Re-create camera_events (valid PostgreSQL: CTE + temp table, not CREATE AS INSERT) ──
CREATE TEMP TABLE _new_camera (id uuid, snapshot_path text) ON COMMIT DROP;

WITH ins AS (
  INSERT INTO public.camera_events (event_id, snapshot_path, human_detected, face_count, created_at)
  SELECT
    (substring(rp.snapshot_path FROM '(?:unknown_snapshots|resident_snapshots)/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_'))::uuid,
    rp.snapshot_path,
    true,
    1,
    rp.sighting_at
  FROM _recover_paths rp
  WHERE rp.snapshot_path IS NOT NULL
    AND rp.snapshot_path ~ '(unknown_snapshots|resident_snapshots)/[0-9a-f]{8}-'
    AND EXISTS (
      SELECT 1 FROM public.events e
      WHERE e.id = (substring(rp.snapshot_path FROM '(?:unknown_snapshots|resident_snapshots)/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_'))::uuid
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.camera_events ce
      WHERE ce.snapshot_path = rp.snapshot_path
    )
  RETURNING id, snapshot_path
)
INSERT INTO _new_camera (id, snapshot_path)
SELECT id, snapshot_path FROM ins;

CREATE TEMP TABLE _all_camera (id uuid, snapshot_path text) ON COMMIT DROP;

INSERT INTO _all_camera (id, snapshot_path)
SELECT id, snapshot_path FROM _new_camera
UNION
SELECT ce.id, ce.snapshot_path
FROM public.camera_events ce
JOIN _recover_paths rp ON rp.snapshot_path = ce.snapshot_path;

-- ── D) Wire sightings + event_faces ──
UPDATE public.unknown_face_sightings ufs
SET camera_event_id = ac.id
FROM _recover_paths rp
JOIN _all_camera ac ON ac.snapshot_path = rp.snapshot_path
WHERE ufs.id = rp.sighting_id
  AND ufs.camera_event_id IS NULL;

UPDATE public.event_faces ef
SET camera_event_id = ac.id
FROM _recover_paths rp
JOIN _all_camera ac ON ac.snapshot_path = rp.snapshot_path
WHERE ef.id = rp.event_face_id
  AND (ef.camera_event_id IS NULL OR ef.camera_event_id IS DISTINCT FROM ac.id);

-- ── E) Result summary ──
SELECT
  (SELECT COUNT(*) FROM public.camera_events) AS camera_events_total,
  (SELECT COUNT(*) FROM public.unknown_face_sightings WHERE camera_event_id IS NULL) AS sightings_still_orphan,
  (SELECT COUNT(*) FROM _recover_paths WHERE snapshot_path IS NULL) AS paths_not_found_in_audit;
