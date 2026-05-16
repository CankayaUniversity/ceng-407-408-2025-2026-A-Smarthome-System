-- v9: Admin RPC — resident login badge status (re-run safe)
-- Run in Supabase SQL Editor

-- Return type changed (added force_password_change) — must drop first on re-run
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
DECLARE
  caller_role TEXT;
BEGIN
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();

  IF caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
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
  'Admin-only: email confirmation, last sign-in, and force_password_change for resident badges.';
