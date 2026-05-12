-- ================================================================
-- Supabase Setup v3 — Admin RPC Functions
-- Run this in Supabase SQL Editor
-- ================================================================

-- ── delete_auth_user: Admin-only auth user deletion via RPC ────
-- SECURITY DEFINER lets this function run with postgres-level
-- access to auth.users, while the internal check enforces admin-only.
CREATE OR REPLACE FUNCTION public.delete_auth_user(target_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role TEXT;
BEGIN
  -- Verify caller is authenticated admin
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();

  IF caller_role IS DISTINCT FROM 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: admin role required');
  END IF;

  -- Prevent self-deletion
  IF target_user_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'You cannot delete your own account');
  END IF;

  -- Delete from auth.users (cascades to public.profiles via FK)
  DELETE FROM auth.users WHERE id = target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Grant execute permission to authenticated users
-- (the function itself enforces admin-only internally)
GRANT EXECUTE ON FUNCTION public.delete_auth_user(UUID) TO authenticated;
