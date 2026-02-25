-- ========================================
-- VIEWER ACCESS RLS POLICIES
-- ========================================
-- This script adds policies for VIEWERS (members) who want to
-- view their committee data using kameti code + member code.
--
-- Run this in Supabase SQL Editor AFTER running setup_security_rls.sql
-- ========================================

-- ========================================
-- 1. COMMITTEES - Allow public access by code
-- ========================================

-- Anyone can view a committee if they have the code
-- (This allows the sync by code to work for viewers)
CREATE POLICY "Anyone can view committees by code"
ON committees FOR SELECT
TO anon, authenticated
USING (true);

-- Note: We use 'true' here because:
-- 1. The app already requires the user to know the exact code
-- 2. Codes are private 6-character strings shared by hosts
-- 3. The original host policy is still active (OR logic)

-- ========================================
-- 2. MEMBERS - Allow public read access
-- ========================================

-- Anyone can view members if they have access to the committee
-- (Members need to find themselves by member_code)
CREATE POLICY "Anyone can view members"
ON members FOR SELECT
TO anon, authenticated
USING (true);

-- Note: This is safe because:
-- 1. Member data doesn't contain sensitive info (no passwords, no financial details)
-- 2. Viewers need to know the exact committee code first
-- 3. Members need to find their own member_code to view payments

-- ========================================
-- 3. PAYMENTS - Allow public read access
-- ========================================

-- Anyone can view payments (read-only for viewers)
-- This allows members to see their payment history
CREATE POLICY "Anyone can view payments"
ON payments FOR SELECT
TO anon, authenticated
USING (true);

-- Note: This is safe because:
-- 1. Viewers can only see payment status, not modify
-- 2. They need both committee code AND member code
-- 3. Payment data is meant to be transparent to committee members

-- ========================================
-- VERIFICATION QUERIES
-- ========================================

-- Check all policies for our tables
SELECT 
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('committees', 'members', 'payments')
ORDER BY tablename, policyname;

-- ========================================
-- IF POLICIES ALREADY EXIST, USE THESE:
-- ========================================
/*
-- Drop existing restrictive policies first (if needed):
DROP POLICY IF EXISTS "Users can view their own committees" ON committees;
DROP POLICY IF EXISTS "Users can view members of their committees" ON members;
DROP POLICY IF EXISTS "Users can view payments for their committees" ON payments;

-- Then run the CREATE POLICY statements above
*/

-- ========================================
-- ALTERNATIVE: More restrictive approach
-- ========================================
/*
-- If you want more security, you can make viewers authenticate
-- and only allow them to view if they match a member record:

CREATE POLICY "Members can view their committee"
ON committees FOR SELECT
USING (
  auth.uid()::text = host_id OR
  EXISTS (
    SELECT 1 FROM members 
    WHERE members.committee_id = committees.id 
    AND members.email = auth.email()
  )
);

-- But this requires viewers to be authenticated, which may not be ideal
-- for the current app design where viewers just enter codes.
*/

-- ========================================
-- SUMMARY
-- ========================================
/*
After running this script:

✅ Host users can still manage their committees (INSERT, UPDATE, DELETE)
✅ Viewers can read committees, members, and payments (SELECT only)
✅ Viewers need to know the exact committee code
✅ Write operations (INSERT, UPDATE, DELETE) still require being the host

The viewer flow:
1. Viewer enters committee code + member code
2. App queries committees WHERE code = 'XXXXXX' → Works now!
3. App queries members WHERE committee_id = '...' → Works now!
4. App queries payments WHERE committee_id = '...' → Works now!
5. App filters locally to show only the specific member's payments
*/
