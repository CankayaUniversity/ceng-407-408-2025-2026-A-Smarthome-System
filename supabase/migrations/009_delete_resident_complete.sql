-- Delete resident row and linked auth account (admin). Unlink on auth-only delete.

CREATE OR REPLACE FUNCTION public.delete_resident_complete(p_resident_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  caller_role TEXT;
  auth_id UUID;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  SELECT auth_user_id INTO auth_id
  FROM public.residents
  WHERE id = p_resident_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Resident not found');
  END IF;

  DELETE FROM public.residents WHERE id = p_resident_id;

  IF auth_id IS NOT NULL AND auth_id <> auth.uid() THEN
    DELETE FROM auth.users WHERE id = auth_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_resident_complete(UUID) TO authenticated;

-- When removing a login from Settings, clear resident link (keep face profile).
CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  caller_role TEXT;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();

  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  IF target_user_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'You cannot delete your own account');
  END IF;

  UPDATE public.residents
  SET auth_user_id = NULL, account_email = NULL, user_id = NULL
  WHERE auth_user_id = target_user_id;

  DELETE FROM auth.users WHERE id = target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
