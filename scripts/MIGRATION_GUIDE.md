# Server-Side Migration Guide (Firestore -> Supabase)

This script allows you to transfer ALL data from Firebase Firestore to Supabase directly, without relying on the mobile app.

## Prerequisites
1. **Node.js**: Ensure Node.js is installed on your computer.

## Setup Steps

### 1. Get Firebase Admin Key
1. Go to [Firebase Console](https://console.firebase.google.com).
2. Open your project.
3. Click the ⚙️ icon (Project Settings) > **Service accounts**.
4. Click **Generate new private key**.
5. Save the file and rename it to `serviceAccountKey.json`.
6. Move this file into this `scripts/` folder.

### 2. Configure Supabase Credentials
1. Open `.env` in the root of your project.
2. Ensure `SUPABASE_URL` is set.
3. Add `SUPABASE_SERVICE_ROLE_KEY` (Get this from Supabase Dashboard > Settings > API).
   > **Warning:** Do NOT put the Service Role Key in your Flutter app! It allows bypassing all security rules. Only use it here.

### 3. Install Dependencies
Open a terminal in this `scripts/` folder:
```bash
cd scripts
npm install
```

### 4. Run Migration
```bash
npm start
```

## What it does
- Connects to Firestore using Admin SDK (bypassing quota issues for reads usually).
- Connects to Supabase.
- Downloads `committees`, `members`, `payments`.
- Transforms data to match PostgreSQL schema (snake_case).
- Uploads to Supabase.

> **Note:** If you hit `RESOURCE_EXHAUSTED` even on reads, you might need to wait for the quota to reset (midnight Pacific Time) or temporarily upgrade Firebase to Blaze (Pay-as-you-go).

## OPTIONAL: User Account Migration
If you want to migrate user accounts (Emails) so they don't have to "Sign Up" manually:

1.  Run: `node migrate_users.js`
2.  **What it does:**
    *   Imports all emails from Firebase Auth.
    *   Creates them in Supabase Auth (without passwords).
    *   **UPDATES** the `committees` table to link data to the new Supabase User IDs.
3.  **User Experience:**
    *   Users open the app.
    *   They click "Log In" -> "Forgot Password".
    *   All their data is already there!

### ⚠️ Important: Email Rate Limits
Supabase's built-in email service has strict rate limits (e.g., 30 emails/hour) to prevent spam.
If the script fails with `email rate limit exceeded`:
1.  **Solution A (Recommended):** Go to Supabase > Project Settings > Auth > Rate Limits and try to increase it.
2.  **Solution B (Best):** Configure **Custom SMTP** (e.g., Gmail, Resend, SendGrid) in Supabase Settings. This removes the strict limits.
3.  **Solution C (Slow):** The script works but will wait (exponential backoff) and take a long time.


