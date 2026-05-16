-- ================================================================
-- v8 — Assign / revert one sighting without closing the whole cluster
-- Run in Supabase SQL Editor after v7
-- ================================================================

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
  prev_event_type TEXT;
  prev_event_message TEXT;
  prev_photo_path TEXT;
  prev_embedding JSONB;
  action_meta JSONB;
  new_action_id UUID;
  remaining INT;
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

  IF face_row.classification = 'resident' AND face_row.resident_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'event_face is already assigned to a resident');
  END IF;

  SELECT * INTO cam_row FROM public.camera_events WHERE id = face_row.camera_event_id;
  cam_found := FOUND;
  old_profile_id := face_row.unknown_profile_id;

  prev_event_type := NULL;
  prev_event_message := NULL;
  IF cam_found AND cam_row.event_id IS NOT NULL THEN
    SELECT e.event_type, e.message
    INTO prev_event_type, prev_event_message
    FROM public.events e
    WHERE e.id = cam_row.event_id;
  END IF;

  prev_photo_path := NULL;
  prev_embedding := NULL;
  IF p_use_snapshot_for_enrollment THEN
    SELECT r.photo_path, r.embedding
    INTO prev_photo_path, prev_embedding
    FROM public.residents r
    WHERE r.id = p_resident_id;
  END IF;

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

  -- Remove only this photo from the visitor cluster; keep profile active for siblings
  IF old_profile_id IS NOT NULL THEN
    DELETE FROM public.unknown_face_sightings WHERE event_face_id = p_event_face_id;
    PERFORM public.recalc_unknown_profile_stats(old_profile_id);

    SELECT COUNT(*)::int INTO remaining
    FROM public.unknown_face_sightings
    WHERE unknown_face_profile_id = old_profile_id;

    IF remaining = 0 THEN
      UPDATE public.unknown_face_profiles
      SET status = 'promoted',
          promoted_resident_id = p_resident_id,
          last_seen_at = now()
      WHERE id = old_profile_id AND status = 'active';
    END IF;
  END IF;

  action_meta := jsonb_build_object(
    'snapshot_path', CASE WHEN cam_found THEN cam_row.snapshot_path ELSE NULL END,
    'event_id', CASE WHEN cam_found THEN cam_row.event_id ELSE NULL END,
    'camera_event_id', face_row.camera_event_id,
    'previous_classification', face_row.classification,
    'previous_resident_id', face_row.resident_id,
    'previous_unknown_profile_id', old_profile_id,
    'previous_event_type', prev_event_type,
    'previous_event_message', prev_event_message,
    'enrollment_updated', p_use_snapshot_for_enrollment,
    'previous_photo_path', prev_photo_path,
    'previous_embedding', prev_embedding,
    'removed_from_cluster', old_profile_id IS NOT NULL
  );

  INSERT INTO public.face_label_actions (
    actor_user_id, action, event_face_id, from_unknown_profile_id, to_resident_id, metadata
  )
  VALUES (
    auth.uid(), 'assign_resident', p_event_face_id, old_profile_id, p_resident_id, action_meta
  )
  RETURNING id INTO new_action_id;

  RETURN jsonb_build_object(
    'success', true,
    'resident_id', p_resident_id,
    'action_id', new_action_id,
    'enrollment_updated', p_use_snapshot_for_enrollment
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.revert_face_label_action(
  p_action_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
  src RECORD;
  meta JSONB;
  face_row RECORD;
  cam_row RECORD;
  cam_found BOOLEAN := false;
  event_id_val UUID;
  revert_id UUID;
  profile_id UUID;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  SELECT * INTO src
  FROM public.face_label_actions
  WHERE id = p_action_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'action not found');
  END IF;

  IF src.action IS DISTINCT FROM 'assign_resident' THEN
    RETURN jsonb_build_object('success', false, 'error', 'only assign_resident actions can be reverted');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.face_label_actions r
    WHERE r.action = 'revert_assign'
      AND r.metadata->>'source_action_id' = p_action_id::text
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'this action was already reverted');
  END IF;

  meta := COALESCE(src.metadata, '{}'::jsonb);
  profile_id := NULLIF(meta->>'previous_unknown_profile_id', '')::uuid;

  SELECT evf.* INTO face_row
  FROM public.event_faces evf
  WHERE evf.id = src.event_face_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'linked event_face not found');
  END IF;

  UPDATE public.event_faces
  SET classification = COALESCE(meta->>'previous_classification', 'unknown'),
      resident_id = NULLIF(meta->>'previous_resident_id', '')::uuid,
      unknown_profile_id = profile_id
  WHERE id = src.event_face_id;

  SELECT * INTO cam_row FROM public.camera_events WHERE id = face_row.camera_event_id;
  cam_found := FOUND;
  event_id_val := NULLIF(meta->>'event_id', '')::uuid;

  IF event_id_val IS NOT NULL THEN
    UPDATE public.events
    SET event_type = COALESCE(meta->>'previous_event_type', 'stranger_detected'),
        message = COALESCE(
          meta->>'previous_event_message',
          'Reverted manual resident assignment.'
        )
    WHERE id = event_id_val;
  ELSIF cam_found AND cam_row.event_id IS NOT NULL THEN
    UPDATE public.events
    SET event_type = COALESCE(meta->>'previous_event_type', 'stranger_detected'),
        message = COALESCE(
          meta->>'previous_event_message',
          'Reverted manual resident assignment.'
        )
    WHERE id = cam_row.event_id;
  END IF;

  IF (meta->>'enrollment_updated')::boolean IS TRUE
     AND src.to_resident_id IS NOT NULL THEN
    UPDATE public.residents
    SET photo_path = NULLIF(meta->>'previous_photo_path', ''),
        embedding = meta->'previous_embedding'
    WHERE id = src.to_resident_id;
  END IF;

  IF profile_id IS NOT NULL AND (meta->>'removed_from_cluster')::boolean IS TRUE THEN
    UPDATE public.unknown_face_profiles
    SET status = 'active',
        promoted_resident_id = NULL,
        last_seen_at = now()
    WHERE id = profile_id;

    IF NOT EXISTS (
      SELECT 1 FROM public.unknown_face_sightings ufs
      WHERE ufs.event_face_id = src.event_face_id
    ) THEN
      INSERT INTO public.unknown_face_sightings (
        unknown_face_profile_id, event_face_id, camera_event_id
      )
      VALUES (
        profile_id,
        src.event_face_id,
        COALESCE(NULLIF(meta->>'camera_event_id', '')::uuid, face_row.camera_event_id)
      );
    END IF;

    PERFORM public.recalc_unknown_profile_stats(profile_id);
  END IF;

  INSERT INTO public.face_label_actions (
    actor_user_id, action, event_face_id, from_unknown_profile_id, to_resident_id, metadata
  )
  VALUES (
    auth.uid(),
    'revert_assign',
    src.event_face_id,
    profile_id,
    src.to_resident_id,
    jsonb_build_object('source_action_id', p_action_id)
  )
  RETURNING id INTO revert_id;

  RETURN jsonb_build_object('success', true, 'revert_action_id', revert_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_event_face_to_resident(UUID, UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revert_face_label_action(UUID) TO authenticated;
