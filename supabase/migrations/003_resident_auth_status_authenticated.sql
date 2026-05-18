-- Allow any signed-in household user to read resident login badges (not admin-only).
-- Re-run safe. Required for Residents page when logged in as resident role.

DROP FUNCTION IF EXISTS public.get_auth_users_status(UUID[]);

CREATE OR REPLACE FUNCTION public.get_auth_users_status(user_ids UUID[])
RETURNS TABLE (
  user_id UUID,
  email TEXT,
  email_confirmed_at TIMESTAMPTZ,
  last_sign_in_at TIMESTAMPTZ,
  force_password_change BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: sign in required';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email::TEXT,
    u.email_confirmed_at,
    u.last_sign_in_at,
    COALESCE(
      (u.raw_user_meta_data->>'force_password_change')::boolean,
      false
    ) AS force_password_change
  FROM auth.users u
  WHERE u.id = ANY(user_ids);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_auth_users_status(UUID[]) TO authenticated;

COMMENT ON FUNCTION public.get_auth_users_status(UUID[]) IS
  'Authenticated users: login badge fields for residents (email confirmed, last sign-in, force_password_change).';
