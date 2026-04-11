-- ================================================================
-- Supabase Setup for Smart Home System
-- Works with the EXISTING database schema.
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- ================================================================

-- ── Profiles table (links Supabase Auth to app) ─────────────
-- The existing "users" table has its own auth. This new table
-- bridges Supabase Auth for the React client.
CREATE TABLE IF NOT EXISTS profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT,
  name        TEXT,
  role        TEXT DEFAULT 'resident',
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- ── Add missing columns to existing tables (safe, no-op if exists) ──
ALTER TABLE events ADD COLUMN IF NOT EXISTS acknowledged BOOLEAN DEFAULT false;
ALTER TABLE residents ADD COLUMN IF NOT EXISTS person_id TEXT;
ALTER TABLE residents ADD COLUMN IF NOT EXISTS photo_path TEXT;
ALTER TABLE residents ADD COLUMN IF NOT EXISTS embedding JSONB;

-- ── residents.user_id must reference Supabase Auth (React login), not legacy public.users ──
-- Error without this: insert violates foreign key constraint "residents_user_id_fkey"
ALTER TABLE residents DROP CONSTRAINT IF EXISTS residents_user_id_fkey;

-- Orphan links (old public.users ids, etc.): clear instead of deleting resident rows
-- (avoids FK errors from event_faces → residents)
ALTER TABLE residents ALTER COLUMN user_id DROP NOT NULL;

UPDATE residents
SET user_id = NULL
WHERE user_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = residents.user_id);

ALTER TABLE residents
  ADD CONSTRAINT residents_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


-- ================================================================
-- Row Level Security (RLS)
-- ================================================================

ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE events          ENABLE ROW LEVEL SECURITY;
ALTER TABLE residents       ENABLE ROW LEVEL SECURITY;
ALTER TABLE camera_events   ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_faces     ENABLE ROW LEVEL SECURITY;

-- Profiles
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Devices
DROP POLICY IF EXISTS "devices_select_auth" ON devices;
CREATE POLICY "devices_select_auth"
  ON devices FOR SELECT USING (auth.role() = 'authenticated');

-- Sensor readings
DROP POLICY IF EXISTS "sensor_readings_select_auth" ON sensor_readings;
CREATE POLICY "sensor_readings_select_auth"
  ON sensor_readings FOR SELECT USING (auth.role() = 'authenticated');

-- Events
DROP POLICY IF EXISTS "events_select_auth" ON events;
CREATE POLICY "events_select_auth"
  ON events FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "events_update_ack" ON events;
CREATE POLICY "events_update_ack"
  ON events FOR UPDATE
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Residents
DROP POLICY IF EXISTS "residents_select_auth" ON residents;
CREATE POLICY "residents_select_auth"
  ON residents FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "residents_insert_auth" ON residents;
CREATE POLICY "residents_insert_auth"
  ON residents FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "residents_update_auth" ON residents;
CREATE POLICY "residents_update_auth"
  ON residents FOR UPDATE USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "residents_delete_auth" ON residents;
CREATE POLICY "residents_delete_auth"
  ON residents FOR DELETE USING (auth.role() = 'authenticated');

-- Camera events + event faces
DROP POLICY IF EXISTS "camera_events_select_auth" ON camera_events;
CREATE POLICY "camera_events_select_auth"
  ON camera_events FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "event_faces_select_auth" ON event_faces;
CREATE POLICY "event_faces_select_auth"
  ON event_faces FOR SELECT USING (auth.role() = 'authenticated');

-- Optional: resident_faces (used by Residents UI when present)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'resident_faces'
  ) THEN
    ALTER TABLE resident_faces ENABLE ROW LEVEL SECURITY;
    EXECUTE 'DROP POLICY IF EXISTS "resident_faces_select_auth" ON resident_faces';
    EXECUTE $policy$
      CREATE POLICY "resident_faces_select_auth"
        ON resident_faces FOR SELECT USING (auth.role() = 'authenticated')
    $policy$;
    EXECUTE 'DROP POLICY IF EXISTS "resident_faces_insert_auth" ON resident_faces';
    EXECUTE $policy$
      CREATE POLICY "resident_faces_insert_auth"
        ON resident_faces FOR INSERT WITH CHECK (auth.role() = 'authenticated')
    $policy$;
    EXECUTE 'DROP POLICY IF EXISTS "resident_faces_update_auth" ON resident_faces';
    EXECUTE $policy$
      CREATE POLICY "resident_faces_update_auth"
        ON resident_faces FOR UPDATE USING (auth.role() = 'authenticated')
    $policy$;
    EXECUTE 'DROP POLICY IF EXISTS "resident_faces_delete_auth" ON resident_faces';
    EXECUTE $policy$
      CREATE POLICY "resident_faces_delete_auth"
        ON resident_faces FOR DELETE USING (auth.role() = 'authenticated')
    $policy$;
  END IF;
END $$;

-- Verify RLS policies (run in SQL Editor; expect one row per policy above)
-- SELECT schemaname, tablename, policyname, cmd, permissive
-- FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;


-- ================================================================
-- Enable Realtime for key tables
-- ================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'sensor_readings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE sensor_readings;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE events;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'camera_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE camera_events;
  END IF;
END $$;


-- ================================================================
-- Storage bucket policies (event-snapshots)
-- Without these, the React client (anon key + authenticated role)
-- cannot upload resident photos and the gateway cannot download them.
-- Policies are RLS rules on storage.objects.
-- ================================================================

DROP POLICY IF EXISTS "event_snapshots_select" ON storage.objects;
CREATE POLICY "event_snapshots_select"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'event-snapshots');

DROP POLICY IF EXISTS "event_snapshots_insert" ON storage.objects;
CREATE POLICY "event_snapshots_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'event-snapshots' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "event_snapshots_update" ON storage.objects;
CREATE POLICY "event_snapshots_update"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'event-snapshots' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "event_snapshots_delete" ON storage.objects;
CREATE POLICY "event_snapshots_delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'event-snapshots' AND auth.role() = 'authenticated');


-- ================================================================
-- Auto-create profile on Supabase Auth signup
-- ================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'resident')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
