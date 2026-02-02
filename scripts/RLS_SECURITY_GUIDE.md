# 🔒 Row Level Security (RLS) Setup Guide

## What is RLS?

**Row Level Security** is Supabase's way of ensuring users can only access their own data. Without it, anyone with your app's API keys could read/modify ALL data in your database. 🚨

---

## Current Status

Your tables are marked **UNRESTRICTED** because RLS is disabled:
- ❌ `committees` - Anyone can see all committees
- ❌ `members` - Anyone can see all members
- ❌ `payments` - Anyone can see all payments

**This is fine for development, but DANGEROUS for production!**

---

## How to Enable Security

### Step 1: Run the Security Script

```bash
# In Supabase Dashboard:
# 1. Go to SQL Editor
# 2. Click "New Query"
# 3. Paste the contents of setup_security_rls.sql
# 4. Click "Run"
```

Or from your project:
```bash
cd scripts
cat setup_security_rls.sql
# Copy and paste in Supabase SQL Editor
```

### Step 2: Verify It Worked

After running the script, check the Table Editor in Supabase Dashboard. The "UNRESTRICTED" badges should be **GONE** ✅

---

## What the Security Policies Do

### 1. Committees Table
**Before RLS:**
```sql
-- Anyone can query all committees
SELECT * FROM committees; -- Returns ALL committees
```

**After RLS:**
```sql
-- Users only see their own committees
SELECT * FROM committees; -- Returns only committees where host_id = current user
```

### 2. Members Table
**Before RLS:**
```sql
-- Anyone can see all members
SELECT * FROM members; -- Returns ALL members
```

**After RLS:**
```sql
-- Users only see members of their committees
SELECT * FROM members; -- Returns only members of committees you host
```

### 3. Payments Table
**Before RLS:**
```sql
-- Anyone can see all payments
SELECT * FROM payments; -- Returns ALL payments (privacy risk!)
```

**After RLS:**
```sql
-- Users only see payments for their committees
SELECT * FROM payments; -- Returns only payments for your committees
```

### 4. App_Config Table
**Special case - stays public!**
```sql
-- Everyone can read (needed for force update)
SELECT * FROM app_config; -- Returns config (OK, not sensitive)

-- Only authenticated users can update (admin panel)
UPDATE app_config SET ... -- Only works if logged in
```

---

## Testing the Security

### Test 1: Create Two Users

```dart
// User A (you)
final userA = await authService.signUp('usera@example.com');

// User B (test attacker)
final userB = await authService.signUp('userb@example.com');
```

### Test 2: Create Data as User A

```dart
// Login as User A
await authService.signIn('usera@example.com');

// Create a committee
final committeeA = await supabase.from('committees').insert({
  'name': 'User A Committee',
  'host_id': userA.id,
  // ... other fields
}).select().single();

print('Committee A ID: ${committeeA['id']}');
```

### Test 3: Try to Access as User B (Should Fail)

```dart
// Login as User B
await authService.signOut();
await authService.signIn('userb@example.com');

// Try to access User A's committee
final result = await supabase
  .from('committees')
  .select()
  .eq('id', committeeA['id'])  // User A's committee ID
  .maybeSingle();

print(result); // Should be null! User B can't see User A's data ✅
```

### Expected Result:
- ✅ User B gets **empty result** or **null**
- ✅ User B **cannot** see User A's committees, members, or payments
- ✅ Security is working!

---

## Troubleshooting

### "Error: new row violates row-level security policy"

This means you're trying to insert/update data that doesn't match your own `auth.uid()`.

**Fix:** Make sure you're logged in and the `host_id` matches your user ID:
```dart
final user = authService.currentUser!;
await supabase.from('committees').insert({
  'host_id': user.id,  // ✅ Must match your user ID
  // ... other fields
});
```

### "Cannot read/update data after enabling RLS"

You're probably not logged in or your session expired.

**Fix:**
```dart
// Check if user is logged in
final user = authService.currentUser;
if (user == null) {
  // User needs to log in first!
  await authService.signIn(email, password);
}
```

### "app_config returns empty"

This shouldn't happen since `app_config` is public. If it does:

**Fix:**
```sql
-- Re-run the app_config policy
DROP POLICY IF EXISTS "Anyone can read app config" ON app_config;

CREATE POLICY "Anyone can read app config"
ON app_config FOR SELECT
TO PUBLIC
USING (true);
```

---

## When to Run This

### ⏰ Timing:

1. ✅ **Before first production deploy** - Essential!
2. ✅ **After migrating from Firebase** - Do it now
3. ✅ **After setup_remote_config.sql** - Run in this order

### 📋 Deployment Checklist:

- [ ] Run `setup_remote_config.sql`
- [ ] Run `setup_security_rls.sql` ← **YOU ARE HERE**
- [ ] Verify "UNRESTRICTED" badges are gone
- [ ] Test with two user accounts
- [ ] Deploy app to production

---

## Impact on Your App

### ✅ What Still Works:
- Users can create committees
- Users can see their own committees
- Users can add members to their committees
- Users can track payments
- Force update checks (app_config is public)
- Admin panel (authenticated users only)

### ❌ What Breaks (Intentionally):
- Users **cannot** see other users' committees
- Users **cannot** see other users' members
- Users **cannot** see other users' payments
- Unauthenticated users **cannot** read sensitive data

### 🔧 Code Changes Needed:

**None!** Your existing app code will work exactly the same. RLS is transparent to your app. The policies automatically enforce security based on `auth.uid()`.

---

## Rollback (Emergency)

If something goes wrong and you need to disable RLS:

```sql
-- WARNING: This removes all security!
ALTER TABLE committees DISABLE ROW LEVEL SECURITY;
ALTER TABLE members DISABLE ROW LEVEL SECURITY;
ALTER TABLE payments DISABLE ROW LEVEL SECURITY;
```

**Don't do this in production unless it's an emergency!**

---

## Summary

| Table | RLS Status | Who Can Access |
|-------|-----------|----------------|
| `committees` | ✅ Enabled | Only the host (creator) |
| `members` | ✅ Enabled | Only the committee host |
| `payments` | ✅ Enabled | Only the committee host |
| `app_config` | ✅ Enabled | Everyone (read), Authenticated (write) |

**Security Level: 🔒 PRODUCTION READY**

Run the script now to secure your data! 🛡️
