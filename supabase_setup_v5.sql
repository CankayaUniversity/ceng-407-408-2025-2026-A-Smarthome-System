-- ================================================================
-- Supabase Setup v5 — Unknown face profiles, sightings, labeling
-- Run in Supabase SQL Editor after supabase_setup_v4.sql
-- ================================================================

-- ── Unknown visitor profiles (recurring strangers) ─────────────
CREATE TABLE IF NOT EXISTS unknown_face_profiles (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  display_label               TEXT NOT NULL DEFAULT 'Unknown visitor',
  sighting_count              INT NOT NULL DEFAULT 1,
  centroid_embedding          JSONB,
  representative_snapshot_path TEXT,
  status                      TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'merged', 'promoted')),
  promoted_resident_id        UUID REFERENCES residents(id) ON DELETE SET NULL,
  first_seen_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_unknown_profiles_active
  ON unknown_face_profiles (status, last_seen_at DESC);

-- ── Link each detection to a profile ───────────────────────────
CREATE TABLE IF NOT EXISTS unknown_face_sightings (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unknown_face_profile_id UUID NOT NULL REFERENCES unknown_face_profiles(id) ON DELETE CASCADE,
  event_face_id           UUID REFERENCES event_faces(id) ON DELETE SET NULL,
  camera_event_id         UUID REFERENCES camera_events(id) ON DELETE SET NULL,
  match_distance          DOUBLE PRECISION,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_unknown_sightings_profile
  ON unknown_face_sightings (unknown_face_profile_id, created_at DESC);

-- ── event_faces → unknown profile ────────────────────────────────
ALTER TABLE event_faces
  ADD COLUMN IF NOT EXISTS unknown_profile_id UUID
  REFERENCES unknown_face_profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_event_faces_unknown_profile
  ON event_faces (unknown_profile_id);

-- ── Audit trail for manual labeling (admin) ──────────────────────
CREATE TABLE IF NOT EXISTS face_label_actions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action                  TEXT NOT NULL
    CHECK (action IN ('assign_resident', 'mark_false_positive', 'merge_profiles')),
  event_face_id           UUID REFERENCES event_faces(id) ON DELETE SET NULL,
  from_unknown_profile_id UUID REFERENCES unknown_face_profiles(id) ON DELETE SET NULL,
  to_resident_id          UUID REFERENCES residents(id) ON DELETE SET NULL,
  metadata                JSONB,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── RLS ──────────────────────────────────────────────────────────
ALTER TABLE unknown_face_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE unknown_face_sightings ENABLE ROW LEVEL SECURITY;
ALTER TABLE face_label_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "unknown_profiles_select_auth" ON unknown_face_profiles;
CREATE POLICY "unknown_profiles_select_auth"
  ON unknown_face_profiles FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "unknown_profiles_write_admin" ON unknown_face_profiles;
CREATE POLICY "unknown_profiles_write_admin"
  ON unknown_face_profiles FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "unknown_sightings_select_auth" ON unknown_face_sightings;
CREATE POLICY "unknown_sightings_select_auth"
  ON unknown_face_sightings FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "unknown_sightings_write_admin" ON unknown_face_sightings;
CREATE POLICY "unknown_sightings_write_admin"
  ON unknown_face_sightings FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "face_label_actions_select_admin" ON face_label_actions;
CREATE POLICY "face_label_actions_select_admin"
  ON face_label_actions FOR SELECT
  USING (public.is_admin());

DROP POLICY IF EXISTS "face_label_actions_insert_admin" ON face_label_actions;
CREATE POLICY "face_label_actions_insert_admin"
  ON face_label_actions FOR INSERT
  WITH CHECK (public.is_admin() AND actor_user_id = auth.uid());

-- Gateway (service role) writes profiles/sightings — bypasses RLS.

-- ── Admin: assign unknown detection to resident ──────────────────
CREATE OR REPLACE FUNCTION public.assign_event_face_to_resident(
  p_event_face_id UUID,
  p_resident_id UUID,
  p_use_snapshot_for_enrollment BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  face_row RECORD;
  cam_row RECORD;
  cam_found BOOLEAN := false;
  old_profile_id UUID;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  SELECT evf.*
  INTO face_row
  FROM public.event_faces evf
  WHERE evf.id = p_event_face_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'event_face not found');
  END IF;

  SELECT * INTO cam_row FROM public.camera_events WHERE id = face_row.camera_event_id;
  cam_found := FOUND;
  old_profile_id := face_row.unknown_profile_id;

  UPDATE public.event_faces
  SET classification = 'resident',
      resident_id = p_resident_id,
      unknown_profile_id = NULL
  WHERE id = p_event_face_id;

  IF cam_found AND cam_row.event_id IS NOT NULL THEN
    UPDATE public.events
    SET event_type = 'resident_entry',
        message = 'Manually identified resident (corrected from unknown).'
    WHERE id = cam_row.event_id;
  END IF;

  IF p_use_snapshot_for_enrollment AND cam_found AND cam_row.snapshot_path IS NOT NULL THEN
    UPDATE public.residents
    SET photo_path = cam_row.snapshot_path,
        embedding = NULL
    WHERE id = p_resident_id;
  END IF;

  IF old_profile_id IS NOT NULL THEN
    UPDATE public.unknown_face_profiles
    SET status = 'promoted',
        promoted_resident_id = p_resident_id,
        last_seen_at = now()
    WHERE id = old_profile_id;
  END IF;

  INSERT INTO public.face_label_actions (actor_user_id, action, event_face_id, from_unknown_profile_id, to_resident_id)
  VALUES (auth.uid(), 'assign_resident', p_event_face_id, old_profile_id, p_resident_id);

  RETURN jsonb_build_object('success', true, 'resident_id', p_resident_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_event_face_to_resident(UUID, UUID, BOOLEAN) TO authenticated;

-- ── Optional: drop legacy resident_faces (run only after confirming empty/unused) ──
-- DROP TABLE IF EXISTS public.resident_faces CASCADE;
