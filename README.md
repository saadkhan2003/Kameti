# Kameti

Kameti is a Flutter app for managing ROSCA-style committees (rotating savings groups), with host and member workflows, offline-first local storage, and Supabase cloud sync.

## What It Does

- Host workflow:
  - Create and manage committees
  - Add/remove members and assign payout order
  - Track payments by cycle
  - Review member payment proofs
  - View committee analytics
- Member/viewer workflow:
  - Join using committee code + member code
  - View personal payment status and schedule
  - Upload payment proof
- Platform features:
  - Offline-first local database (Hive)
  - Cloud sync + realtime updates (Supabase)
  - Email/password + Google OAuth auth
  - Biometric app lock
  - Push notifications (FCM)
  - In-app update checks (remote config)
  - Ads (AdMob)

## Tech Stack

- Flutter (Dart)
- Hive (`committees`, `members`, `payments`, local settings)
- Supabase (Auth, Postgres, Realtime, RLS)
- Firebase Messaging (push notifications)
- Google Mobile Ads
- Netlify (web deployment)

## Project Structure

```text
lib/
  main.dart
  models/                 # committee/member/payment/payment_proof models
  services/               # auth, db, sync, supabase, notifications, ads
  screens/                # auth, host, member, viewer, splash, onboarding
  ui/                     # shared design system (theme, widgets)
  utils/
scripts/                  # SQL setup scripts and utility templates
assets/
  env                     # runtime env file read by flutter_dotenv
```

## Prerequisites

- Flutter SDK compatible with project (`sdk: ^3.7.0` in `pubspec.yaml`)
- Dart SDK (bundled with Flutter)
- Supabase project
- Android Studio / Xcode for mobile builds
- (Optional) Firebase project for FCM

## Environment Variables

This app loads env vars from `assets/env` (not `.env`).

Create `assets/env`:

```bash
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Notes:
- `lib/supabase_config.dart` reads only these two keys.
- Ensure `assets/env` is included in Flutter assets (already configured in `pubspec.yaml`).

## Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Generate Hive adapters (if models changed):

```bash
dart run build_runner build --delete-conflicting-outputs
```

3. Configure Supabase SQL (order matters):

- Run `scripts/setup_remote_config.sql`
- Run `scripts/setup_security_rls.sql`
- Run `scripts/add_viewer_rls_policies.sql`
- Run `scripts/setup_payment_proofs.sql`

4. (Optional) Configure Firebase for push notifications:

- Android: provide `android/app/google-services.json`
- iOS: add `GoogleService-Info.plist`

## Running the App

Mobile:

```bash
flutter run
```

Web:

```bash
flutter run -d chrome
```

## Build

Android APK:

```bash
flutter build apk --release
```

Web:

```bash
flutter build web --release --no-tree-shake-icons
```

## Data & Sync Model

- Local-first writes go to Hive.
- `SyncService` uploads/downloads committee/member/payment diffs to Supabase.
- `RealtimeSyncService` listens to Supabase Postgres changes and updates local Hive.
- Full sync runs on startup for authenticated host users.

## Auth Model

- Supabase Auth supports:
  - Email/password
  - Email OTP verification
  - Google OAuth
- Unverified users are blocked from normal signed-in host flow until verification.

## Remote Config / Force Update

App reads `app_config` table values via `RemoteConfigService`, including:

- `force_update_enabled`
- `min_android_version`
- `min_ios_version`
- update dialog text and store URLs

## Deployment (Web on Netlify)

`netlify.toml` is already configured to:

- clone Flutter in CI if missing
- inject `SUPABASE_URL` and `SUPABASE_ANON_KEY` into `assets/env`
- build and publish `build/web`

Set Netlify environment variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Common Commands

```bash
# Analyze
flutter analyze

# Test
flutter test

# Clean
flutter clean

# Regenerate model adapters
dart run build_runner build --delete-conflicting-outputs
```

## Current App Identity

- Android package: `com.kameti.app`
- App version source: `pubspec.yaml` (`version: 1.2.1+24` at time of writing)

## Notes

- The app currently includes both Supabase and Firebase dependencies. Supabase is the primary backend for app data; Firebase is used for FCM.
- If RLS policies already exist in your Supabase project, review SQL scripts before re-running to avoid policy conflicts.
