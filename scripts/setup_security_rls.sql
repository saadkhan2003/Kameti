-- ========================================
-- Row Level Security (RLS) Setup
-- ========================================
-- This script enables RLS on all tables and creates policies
-- so users can only access their own data.
--
-- Run this in Supabase SQL Editor AFTER running setup_remote_config.sql
-- ========================================

-- ========================================
-- 1. COMMITTEES TABLE
-- ========================================

-- Enable RLS
ALTER TABLE committees ENABLE ROW LEVEL SECURITY;

-- Users can see committees they host
CREATE POLICY "Users can view their own committees"
ON committees FOR SELECT
USING (auth.uid()::text = host_id);

-- Users can create committees (they become the host)
CREATE POLICY "Users can create committees"
ON committees FOR INSERT
WITH CHECK (auth.uid()::text = host_id);

-- Users can update their own committees
CREATE POLICY "Users can update their own committees"
ON committees FOR UPDATE
USING (auth.uid()::text = host_id)
WITH CHECK (auth.uid()::text = host_id);

-- Users can delete their own committees
CREATE POLICY "Users can delete their own committees"
ON committees FOR DELETE
USING (auth.uid()::text = host_id);

-- ========================================
-- 2. MEMBERS TABLE
-- ========================================

-- Enable RLS
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- Users can see members of committees they host
CREATE POLICY "Users can view members of their committees"
ON members FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = members.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- Users can add members to their committees
CREATE POLICY "Users can add members to their committees"
ON members FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = members.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- Users can update members in their committees
CREATE POLICY "Users can update members in their committees"
ON members FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = members.committee_id 
    AND committees.host_id = auth.uid()::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = members.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- Users can delete members from their committees
CREATE POLICY "Users can delete members from their committees"
ON members FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = members.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- ========================================
-- 3. PAYMENTS TABLE
-- ========================================

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Users can view payments for their committees
CREATE POLICY "Users can view payments for their committees"
ON payments FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = payments.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- Users can create payments for their committees
CREATE POLICY "Users can create payments for their committees"
ON payments FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = payments.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- Users can update payments for their committees
CREATE POLICY "Users can update payments for their committees"
ON payments FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = payments.committee_id 
    AND committees.host_id = auth.uid()::text
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = payments.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- Users can delete payments for their committees
CREATE POLICY "Users can delete payments from their committees"
ON payments FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM committees 
    WHERE committees.id = payments.committee_id 
    AND committees.host_id = auth.uid()::text
  )
);

-- ========================================
-- 4. APP_CONFIG TABLE (Public Read)
-- ========================================

-- Enable RLS on app_config
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Anyone can read config (needed for force update check)
CREATE POLICY "Anyone can read app config"
ON app_config FOR SELECT
TO PUBLIC
USING (true);

-- Only authenticated users can update config (admin panel)
CREATE POLICY "Authenticated users can update app config"
ON app_config FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- ========================================
-- VERIFICATION
-- ========================================

-- Check which tables have RLS enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('committees', 'members', 'payments', 'app_config')
ORDER BY tablename;

-- View all policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- ========================================
-- NOTES
-- ========================================

/*
What this does:

1. COMMITTEES
   - Users can only see/edit/delete committees where they are the host
   - Users can create new committees (they become the host)

2. MEMBERS
   - Users can only see/edit/delete members of committees they host
   - Prevents users from seeing members of other people's committees

3. PAYMENTS
   - Users can only see/edit/delete payments for committees they host
   - Ensures payment data privacy

4. APP_CONFIG
   - Everyone can read (needed for force update)
   - Only authenticated users can update (admin panel)

Security Benefits:
✅ Data isolation - users can only access their own data
✅ No accidental data leaks
✅ Protects against malicious users
✅ Industry-standard security practice

FIX APPLIED:
- Added ::text type casting to auth.uid() to match host_id column type
- This fixes the "uuid = text" operator error

Testing:
- Create a test user
- Try to access another user's committee ID directly
- Should return empty result or error
*/
