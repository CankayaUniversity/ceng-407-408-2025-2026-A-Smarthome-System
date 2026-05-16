-- ================================================================
-- Supabase Setup v4 — RBAC hardening, household, resident accounts
-- Run in Supabase SQL Editor after supabase_setup_v3.sql
-- ================================================================

-- ── residents.account_email (login link tracking) ───────────────
ALTER TABLE residents ADD COLUMN IF NOT EXISTS account_email TEXT;
ALTER TABLE residents ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- ── Household (single-home deployment) ────────────────────────
CREATE TABLE IF NOT EXISTS household_settings (
  id          INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  name        TEXT NOT NULL DEFAULT 'My Smart Home',
  address     TEXT,
  updated_at  TIMESTAMPTZ DEFAULT now()
);

INSERT INTO household_settings (id, name)
VALUES (1, 'My Smart Home')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE household_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "household_select_auth" ON household_settings;
CREATE POLICY "household_select_auth"
  ON household_settings FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "household_update_admin" ON household_settings;
CREATE POLICY "household_update_admin"
  ON household_settings FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ── Helper: is current user admin? ──────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── Residents: admin-only write ─────────────────────────────────
DROP POLICY IF EXISTS "residents_insert_auth" ON residents;
DROP POLICY IF EXISTS "residents_update_auth" ON residents;
DROP POLICY IF EXISTS "residents_delete_auth" ON residents;

CREATE POLICY "residents_insert_admin"
  ON residents FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "residents_update_admin"
  ON residents FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "residents_delete_admin"
  ON residents FOR DELETE
  USING (public.is_admin());

-- ── Devices: admin-only room assignment ─────────────────────────
DROP POLICY IF EXISTS "devices_update_auth" ON devices;

CREATE POLICY "devices_update_admin"
  ON devices FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
