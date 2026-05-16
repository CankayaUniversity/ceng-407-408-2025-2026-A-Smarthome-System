-- ================================================================
-- Supabase Setup v7 — Visitor labels, merge, move, rename, dismiss
-- Run after supabase_setup_v6_identity_corrections.sql
-- ================================================================

ALTER TABLE public.unknown_face_profiles
  DROP CONSTRAINT IF EXISTS unknown_face_profiles_status_check;

ALTER TABLE public.unknown_face_profiles
  ADD CONSTRAINT unknown_face_profiles_status_check
  CHECK (status IN ('active', 'merged', 'promoted', 'dismissed'));

ALTER TABLE public.face_label_actions
  DROP CONSTRAINT IF EXISTS face_label_actions_action_check;

ALTER TABLE public.face_label_actions
  ADD CONSTRAINT face_label_actions_action_check
  CHECK (action IN (
    'assign_resident',
    'mark_false_positive',
    'merge_profiles',
    'revert_assign',
    'unlink_from_resident',
    'rename_profile',
    'move_sighting',
    'dismiss_profile'
  ));

-- Recalculate sighting_count / last_seen from sightings table
CREATE OR REPLACE FUNCTION public.recalc_unknown_profile_stats(p_profile_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cnt INT;
  last_ts TIMESTAMPTZ;
BEGIN
  SELECT COUNT(*)::int, MAX(created_at)
  INTO cnt, last_ts
  FROM public.unknown_face_sightings
  WHERE unknown_face_profile_id = p_profile_id;

  UPDATE public.unknown_face_profiles
  SET sighting_count = GREATEST(cnt, 0),
      last_seen_at = COALESCE(last_ts, first_seen_at, now())
  WHERE id = p_profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.rename_unknown_face_profile(
  p_profile_id UUID,
  p_display_label TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  trimmed TEXT;
  old_label TEXT;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  trimmed := NULLIF(TRIM(p_display_label), '');
  IF trimmed IS NULL OR LENGTH(trimmed) > 80 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Label must be 1–80 characters');
  END IF;

  SELECT display_label INTO old_label
  FROM public.unknown_face_profiles
  WHERE id = p_profile_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Active profile not found');
  END IF;

  UPDATE public.unknown_face_profiles
  SET display_label = trimmed
  WHERE id = p_profile_id;

  INSERT INTO public.face_label_actions (actor_user_id, action, from_unknown_profile_id, metadata)
  VALUES (
    auth.uid(), 'rename_profile', p_profile_id,
    jsonb_build_object('old_label', old_label, 'new_label', trimmed)
  );

  RETURN jsonb_build_object('success', true, 'display_label', trimmed);
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_unknown_face_profiles(
  p_source_profile_id UUID,
  p_target_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  src RECORD;
  tgt RECORD;
  new_count INT;
  merged_centroid JSONB;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  IF p_source_profile_id = p_target_profile_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot merge a profile into itself');
  END IF;

  SELECT * INTO src FROM public.unknown_face_profiles
  WHERE id = p_source_profile_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Source profile not found or not active');
  END IF;

  SELECT * INTO tgt FROM public.unknown_face_profiles
  WHERE id = p_target_profile_id AND status = 'active';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target profile not found or not active');
  END IF;

  UPDATE public.unknown_face_sightings
  SET unknown_face_profile_id = p_target_profile_id
  WHERE unknown_face_profile_id = p_source_profile_id;

  UPDATE public.event_faces
  SET unknown_profile_id = p_target_profile_id
  WHERE unknown_profile_id = p_source_profile_id;

  merged_centroid := COALESCE(tgt.centroid_embedding, src.centroid_embedding);

  PERFORM public.recalc_unknown_profile_stats(p_target_profile_id);

  SELECT sighting_count INTO new_count
  FROM public.unknown_face_profiles WHERE id = p_target_profile_id;

  UPDATE public.unknown_face_profiles
  SET centroid_embedding = merged_centroid,
      last_seen_at = GREATEST(tgt.last_seen_at, src.last_seen_at),
      representative_snapshot_path = COALESCE(
        tgt.representative_snapshot_path,
        src.representative_snapshot_path
      )
  WHERE id = p_target_profile_id;

  UPDATE public.unknown_face_profiles
  SET status = 'merged',
      sighting_count = 0,
      last_seen_at = now()
  WHERE id = p_source_profile_id;

  INSERT INTO public.face_label_actions (
    actor_user_id, action, from_unknown_profile_id, to_resident_id, metadata
  )
  VALUES (
    auth.uid(),
    'merge_profiles',
    p_source_profile_id,
    NULL,
    jsonb_build_object(
      'source_profile_id', p_source_profile_id,
      'target_profile_id', p_target_profile_id,
      'target_sighting_count', new_count
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'target_profile_id', p_target_profile_id,
    'sighting_count', new_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.move_event_face_to_unknown_profile(
  p_event_face_id UUID,
  p_target_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  face_row RECORD;
  old_profile_id UUID;
  cam_row RECORD;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  SELECT evf.* INTO face_row
  FROM public.event_faces evf
  WHERE evf.id = p_event_face_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'event_face not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.unknown_face_profiles
    WHERE id = p_target_profile_id AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Target profile not found or not active');
  END IF;

  old_profile_id := face_row.unknown_profile_id;

  UPDATE public.event_faces
  SET unknown_profile_id = p_target_profile_id,
      classification = 'unknown',
      resident_id = NULL
  WHERE id = p_event_face_id;

  SELECT * INTO cam_row FROM public.camera_events WHERE id = face_row.camera_event_id;

  UPDATE public.unknown_face_sightings
  SET unknown_face_profile_id = p_target_profile_id
  WHERE event_face_id = p_event_face_id;

  IF NOT FOUND THEN
    INSERT INTO public.unknown_face_sightings (
      unknown_face_profile_id, event_face_id, camera_event_id
    )
    VALUES (
      p_target_profile_id,
      p_event_face_id,
      face_row.camera_event_id
    );
  END IF;

  IF old_profile_id IS NOT NULL AND old_profile_id IS DISTINCT FROM p_target_profile_id THEN
    PERFORM public.recalc_unknown_profile_stats(old_profile_id);
  END IF;
  PERFORM public.recalc_unknown_profile_stats(p_target_profile_id);

  INSERT INTO public.face_label_actions (
    actor_user_id, action, event_face_id, from_unknown_profile_id, metadata
  )
  VALUES (
    auth.uid(),
    'move_sighting',
    p_event_face_id,
    old_profile_id,
    jsonb_build_object(
      'from_profile_id', old_profile_id,
      'target_profile_id', p_target_profile_id
    )
  );

  RETURN jsonb_build_object('success', true, 'target_profile_id', p_target_profile_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.ungroup_event_face(
  p_event_face_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  face_row RECORD;
  old_profile_id UUID;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  SELECT evf.* INTO face_row FROM public.event_faces evf WHERE evf.id = p_event_face_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'event_face not found');
  END IF;

  old_profile_id := face_row.unknown_profile_id;

  UPDATE public.event_faces
  SET unknown_profile_id = NULL
  WHERE id = p_event_face_id;

  DELETE FROM public.unknown_face_sightings WHERE event_face_id = p_event_face_id;

  IF old_profile_id IS NOT NULL THEN
    PERFORM public.recalc_unknown_profile_stats(old_profile_id);
  END IF;

  INSERT INTO public.face_label_actions (
    actor_user_id, action, event_face_id, from_unknown_profile_id, metadata
  )
  VALUES (
    auth.uid(), 'move_sighting', p_event_face_id, old_profile_id,
    jsonb_build_object('ungrouped', true)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.dismiss_unknown_face_profile(
  p_profile_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  UPDATE public.unknown_face_profiles
  SET status = 'dismissed',
      last_seen_at = now()
  WHERE id = p_profile_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Active profile not found');
  END IF;

  UPDATE public.event_faces
  SET unknown_profile_id = NULL
  WHERE unknown_profile_id = p_profile_id;

  INSERT INTO public.face_label_actions (actor_user_id, action, from_unknown_profile_id)
  VALUES (auth.uid(), 'dismiss_profile', p_profile_id);

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rename_unknown_face_profile(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.merge_unknown_face_profiles(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.move_event_face_to_unknown_profile(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ungroup_event_face(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_unknown_face_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recalc_unknown_profile_stats(UUID) TO authenticated;
