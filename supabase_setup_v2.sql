-- ================================================================
-- Supabase Setup v2 — Authorization & Role-Based Access
-- Run this in Supabase SQL Editor after supabase_setup.sql
-- ================================================================

-- ── Ensure photo_path is nullable (safe no-op if already is) ───
ALTER TABLE residents ALTER COLUMN photo_path DROP NOT NULL;

-- ── Profiles: Admin can read/update all profiles ───────────────
-- Drop old single-owner policy and replace with multi-role policy
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own_or_admin"
  ON profiles FOR SELECT
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile; admin can update anyone's
DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON profiles;
CREATE POLICY "profiles_update_own_or_admin"
  ON profiles FOR UPDATE
  USING (
    auth.uid() = id
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ── Residents: Admin & resident can CRUD ───────────────────────
-- (Existing policies already use auth.role() = 'authenticated', which covers both)
-- No changes needed for residents table RLS.

-- ── Verify (run separately to check) ───────────────────────────
-- SELECT schemaname, tablename, policyname, cmd
-- FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles'
-- ORDER BY policyname;
