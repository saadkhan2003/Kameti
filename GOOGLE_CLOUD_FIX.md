# 🔧 Google Cloud Ownership Verification Error - Solution

## The Error

**Error Message:** "Ownership verification failed"  
**Reason:** "The request failed because the Android package name and fingerprint are already in use in another project."

**Package Name:** `com.kameti.app`  
**SHA-1 Fingerprint:** `F1:5F:BD:49:41:DA:CA:31:D...`

---

## 🎯 Quick Fix (2 Options)

### **Option 1: Remove from Old Project** (Recommended)

Since you've migrated to Supabase and don't need the old Firebase project anymore:

1. **Go to old Firebase Console**:
   - Visit: https://console.firebase.google.com/project/commiteeapp-7cd16

2. **Project Settings** → **General**

3. Scroll to "Your apps" → Find Android app (`com.kameti.app`)

4. Click **"Delete app"** (trash icon)

5. Confirm deletion

6. **Now retry verification** in your new Google Cloud project

---

### **Option 2: Verify in New Project**

If you want to keep using the new Google Cloud project (`kameti-chit-fund-manager`):

1. **In the error dialog**, click **"Send feedback"** or **"Close"**

2. **Download your keystore SHA-1**:
   ```bash
   # For debug (if testing)
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1

   # For release (production)
   keytool -list -v -keystore android/upload-keystore.jks -alias upload | grep SHA1
   ```

3. **Go to old project** and remove the Android app first (see Option 1)

4. **Then add SHA-1** to your new project

---

## ⚠️ Why This Happened

You previously had `com.kameti.app` registered in:
- **Old Project:** `commiteeapp-7cd16` (Firebase)
- **New Project:** `kameti-chit-fund-manager` (Google Cloud)

Google doesn't allow the same package name + SHA-1 combination in multiple projects for security reasons.

---

## ✅ After Fixing

Once the old app is deleted:

1. The verification will succeed
2. You can use Google Sign-In with the new project
3. Your app will work with the updated OAuth credentials

---

## 📝 Summary

**Action Required:**
1. Delete Android app from old Firebase project (`commiteeapp-7cd16`)
2. Retry verification in new project (`kameti-chit-fund-manager`)
3. Done! ✅

**Time:** ~2 minutes

---

*This is a one-time fix. Once resolved, you won't see this error again.*
