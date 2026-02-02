# 🔐 Google Sign-In Setup for Supabase

## Quick Setup (5 minutes)

### Step 1: Create OAuth Credentials in Google Cloud

**Go to:** https://console.cloud.google.com/apis/credentials?project=kameti-chit-fund-manager

**Create Android Client:**
1. Click "Create Credentials" → "OAuth 2.0 Client ID"
2. Application type: **Android**
3. Package name: `com.kameti.app`
4. SHA-1 fingerprint: `F1:5F:BD:49:41:DA:CA:31:D2:11:F8:E7:AA:95:50:4D:FD:84:DD:54`
5. Click "Create"

**Create Web Client:**
1. Click "Create Credentials" → "OAuth 2.0 Client ID"  
2. Application type: **Web application**
3. Name: "Kameti Web Client"
4. Click "Create"
5. **⚠️ IMPORTANT**: Copy the **Client ID** (looks like: `123456-abcdef.apps.googleusercontent.com`)

---

### Step 2: Configure Supabase

**Go to:** https://supabase.com/dashboard/project/eegsyatcjylbabbhnhhb/auth/providers

1. **Enable Google** provider
2. Paste the **Web Client ID** into "Client ID" field
3. Click on "Get Client Secret" link → Copy from Google Cloud Console
4. Paste into "Client Secret" field
5. Click "Save"

---

### Step 3: Test Google Sign-In

1. Build and run your app
2. Tap "Continue with Google"
3. Should work! ✅

---

## SHA-1 Fingerprints

**From Play Console (Production):**
```
SHA-1: F1:5F:BD:49:41:DA:CA:31:D2:11:F8:E7:AA:95:50:4D:FD:84:DD:54
```

**For Debug (Local Testing):**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

Add BOTH SHA-1 fingerprints (debug + production) to the Android OAuth client!

---

## Troubleshooting

**Error: "Sign in failed"**
- Check if both SHA-1 fingerprints are added
- Verify package name is exactly `com.kameti.app`
- Make sure Supabase Google provider is enabled

**Error: "Invalid client"**
- Double-check Web Client ID in Supabase matches Google Cloud
- Regenerate credentials if needed

---

**That's it!** Google Sign-In will work on both Android and web. 🎉
