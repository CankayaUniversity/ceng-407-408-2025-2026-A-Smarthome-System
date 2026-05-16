-- ================================================================
-- Supabase Setup v6 — Identity corrections (run after v5 + fix)
-- 1. Assign: default label-only (preserve enrollment photo)
-- 2. Revert assign via face_label_actions
-- 3. Unlink wrong resident detection
-- ================================================================

-- Extend allowed audit actions
ALTER TABLE public.face_label_actions
  DROP CONSTRAINT IF EXISTS face_label_actions_action_check;

ALTER TABLE public.face_label_actions
  ADD CONSTRAINT face_label_actions_action_check
  CHECK (action IN (
    'assign_resident',
    'mark_false_positive',
    'merge_profiles',
    'revert_assign',
    'unlink_from_resident'
  ));

-- ── Assign: label-only by default + rich metadata for revert ─────
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

  IF old_profile_id IS NOT NULL THEN
    UPDATE public.unknown_face_profiles
    SET status = 'promoted',
        promoted_resident_id = p_resident_id,
        last_seen_at = now()
    WHERE id = old_profile_id;
  END IF;

  action_meta := jsonb_build_object(
    'snapshot_path', CASE WHEN cam_found THEN cam_row.snapshot_path ELSE NULL END,
    'event_id', CASE WHEN cam_found THEN cam_row.event_id ELSE NULL END,
    'previous_classification', face_row.classification,
    'previous_resident_id', face_row.resident_id,
    'previous_unknown_profile_id', old_profile_id,
    'previous_event_type', prev_event_type,
    'previous_event_message', prev_event_message,
    'enrollment_updated', p_use_snapshot_for_enrollment,
    'previous_photo_path', prev_photo_path,
    'previous_embedding', prev_embedding
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

-- ── Revert a manual assign ─────────────────────────────────────
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

  SELECT evf.* INTO face_row
  FROM public.event_faces evf
  WHERE evf.id = src.event_face_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'linked event_face not found');
  END IF;

  UPDATE public.event_faces
  SET classification = COALESCE(meta->>'previous_classification', 'unknown'),
      resident_id = NULLIF(meta->>'previous_resident_id', '')::uuid,
      unknown_profile_id = NULLIF(meta->>'previous_unknown_profile_id', '')::uuid
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

  IF src.from_unknown_profile_id IS NOT NULL THEN
    UPDATE public.unknown_face_profiles
    SET status = 'active',
        promoted_resident_id = NULL,
        last_seen_at = now()
    WHERE id = src.from_unknown_profile_id;
  END IF;

  INSERT INTO public.face_label_actions (
    actor_user_id, action, event_face_id, from_unknown_profile_id, to_resident_id, metadata
  )
  VALUES (
    auth.uid(),
    'revert_assign',
    src.event_face_id,
    src.from_unknown_profile_id,
    src.to_resident_id,
    jsonb_build_object('source_action_id', p_action_id)
  )
  RETURNING id INTO revert_id;

  RETURN jsonb_build_object('success', true, 'revert_action_id', revert_id);
END;
$$;

-- ── Unlink a detection from resident (wrong person) ──────────────
CREATE OR REPLACE FUNCTION public.unlink_event_face_from_resident(
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
  cam_row RECORD;
  cam_found BOOLEAN := false;
  prev_event_type TEXT;
  prev_event_message TEXT;
  prev_resident_id UUID;
  action_meta JSONB;
  new_action_id UUID;
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

  IF face_row.classification IS DISTINCT FROM 'resident'
     OR face_row.resident_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'event_face is not linked to a resident');
  END IF;

  prev_resident_id := face_row.resident_id;

  SELECT * INTO cam_row FROM public.camera_events WHERE id = face_row.camera_event_id;
  cam_found := FOUND;

  prev_event_type := NULL;
  prev_event_message := NULL;
  IF cam_found AND cam_row.event_id IS NOT NULL THEN
    SELECT e.event_type, e.message
    INTO prev_event_type, prev_event_message
    FROM public.events e
    WHERE e.id = cam_row.event_id;
  END IF;

  UPDATE public.event_faces
  SET classification = 'unknown',
      resident_id = NULL,
      unknown_profile_id = face_row.unknown_profile_id
  WHERE id = p_event_face_id;

  IF cam_found AND cam_row.event_id IS NOT NULL THEN
    UPDATE public.events
    SET event_type = 'stranger_detected',
        message = 'Detection unlinked from resident (marked as unknown).'
    WHERE id = cam_row.event_id;
  END IF;

  action_meta := jsonb_build_object(
    'snapshot_path', CASE WHEN cam_found THEN cam_row.snapshot_path ELSE NULL END,
    'event_id', CASE WHEN cam_found THEN cam_row.event_id ELSE NULL END,
    'previous_classification', face_row.classification,
    'previous_resident_id', prev_resident_id,
    'previous_unknown_profile_id', face_row.unknown_profile_id,
    'previous_event_type', prev_event_type,
    'previous_event_message', prev_event_message
  );

  INSERT INTO public.face_label_actions (
    actor_user_id, action, event_face_id, to_resident_id, metadata
  )
  VALUES (
    auth.uid(), 'unlink_from_resident', p_event_face_id, prev_resident_id, action_meta
  )
  RETURNING id INTO new_action_id;

  RETURN jsonb_build_object('success', true, 'action_id', new_action_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.assign_event_face_to_resident(UUID, UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revert_face_label_action(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlink_event_face_from_resident(UUID) TO authenticated;
