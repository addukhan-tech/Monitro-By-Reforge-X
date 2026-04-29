-- ============================================================
--  MONITRO V3  —  Run this in Supabase SQL Editor
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ORGANIZATIONS
CREATE TABLE IF NOT EXISTS organizations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  code        TEXT NOT NULL UNIQUE,
  created_by  UUID,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- PROFILES (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name       TEXT,
  email           TEXT,
  role            TEXT DEFAULT 'member' CHECK (role IN ('manager','co_manager','member')),
  organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  is_online       BOOLEAN DEFAULT FALSE,
  is_sharing      BOOLEAN DEFAULT FALSE,
  last_seen       TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ATTENDANCE
CREATE TABLE IF NOT EXISTS attendance (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  date            DATE NOT NULL DEFAULT CURRENT_DATE,
  first_share_at  TIMESTAMPTZ DEFAULT NOW(),
  total_minutes   INT DEFAULT 0,
  UNIQUE(user_id, date)
);

-- REWARDS
CREATE TABLE IF NOT EXISTS rewards (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  winner_id       UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  month           TEXT NOT NULL,
  attendance_days INT DEFAULT 0,
  reward_note     TEXT,
  given_by        UUID REFERENCES profiles(id),
  given_at        TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE organizations  ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance      ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards         ENABLE ROW LEVEL SECURITY;

-- Orgs: anyone can read if member, anyone can insert (to create)
CREATE POLICY "org_read"   ON organizations FOR SELECT USING (TRUE);
CREATE POLICY "org_insert" ON organizations FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "org_update" ON organizations FOR UPDATE USING (
  created_by = auth.uid()
);

-- Profiles
CREATE POLICY "profiles_read_org" ON profiles FOR SELECT USING (
  organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
  OR id = auth.uid()
);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "profiles_update_manager" ON profiles FOR UPDATE USING (
  organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
  AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('manager','co_manager')
);

-- Attendance
CREATE POLICY "attendance_read_org" ON attendance FOR SELECT USING (
  organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
);
CREATE POLICY "attendance_insert_own" ON attendance FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "attendance_update_own" ON attendance FOR UPDATE USING (user_id = auth.uid());

-- Rewards
CREATE POLICY "rewards_read_org" ON rewards FOR SELECT USING (
  organization_id = (SELECT organization_id FROM profiles WHERE id = auth.uid())
);
CREATE POLICY "rewards_insert_manager" ON rewards FOR INSERT WITH CHECK (
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('manager','co_manager')
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users FOR EACH ROW
  EXECUTE PROCEDURE public.handle_new_user();

-- Realtime
BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE profiles, attendance, rewards, organizations;
COMMIT;
