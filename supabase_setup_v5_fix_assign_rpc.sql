-- Hotfix: assign_event_face_to_resident — "column reference ef.* is ambiguous"
-- Run this in Supabase SQL Editor (safe to re-run).

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
