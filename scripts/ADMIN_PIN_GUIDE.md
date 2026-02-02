# How to Change Admin PIN

## Quick Reference

### Current Setup
- **Default PIN:** `1234`
- **Storage:** Supabase `app_config` table (remotely changeable!)

---

## Method 1: Change via Supabase SQL (Easiest) ⚡

Run this in Supabase SQL Editor:

```sql
-- Change PIN to 9876
SELECT update_config('admin_pin', '9876');
```

**Or update directly:**
```sql
UPDATE app_config 
SET config_value = '9876', updated_at = NOW()
WHERE config_key = 'admin_pin';
```

✅ **No app rebuild needed!** Changes apply on next app launch.

---

## Method 2: Add PIN Field to Admin Panel UI

You can add a PIN change field directly in the Admin Config Screen:

1. Open the Admin Panel (long-press Settings → enter current PIN)
2. Scroll to new "Security" section
3. Enter new PIN
4. Save

**I can add this UI for you if you want!** Just let me know.

---

## Method 3: Hardcode in App (Not Recommended)

Edit [`lib/screens/host/host_dashboard_screen.dart`](file:///mnt/data/farhan/Committee_App%20%282%29/lib/screens/host/host_dashboard_screen.dart) line ~902:

Change this:
```dart
final correctPin = remoteConfig.getString('admin_pin', defaultValue: '1234');
```

To:
```dart
final correctPin = '9876'; // Your new hardcoded PIN
```

❌ **Not recommended:** Requires app rebuild every time you want to change PIN.

---

## Security Tips

1. **Use a strong 4-digit PIN** (avoid 1234, 0000, 1111)
2. **Don't share publicly** (remove from screenshots before sharing)
3. **Change periodically** for better security
4. **Store securely** - only you should know it

---

## Current PIN Location

The PIN is checked in:
- [`lib/screens/host/host_dashboard_screen.dart`](file:///mnt/data/farhan/Committee_App%20%282%29/lib/screens/host/host_dashboard_screen.dart) (PIN dialog)

And stored in:
- Supabase `app_config` table → `admin_pin` key

---

## Example: Change PIN to 5678

```sql
-- In Supabase SQL Editor
SELECT update_config('admin_pin', '5678');

-- Verify change
SELECT config_value 
FROM app_config 
WHERE config_key = 'admin_pin';
```

Done! New PIN is `5678`.
