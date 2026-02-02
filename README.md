# 🏦 Kameti - Committee App

> **A modern, secure committee management application built with Flutter and Supabase**

[![Flutter](https://img.shields.io/badge/Flutter-3.24.5-blue.svg)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-Backend-green.svg)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg)](https://github.com/saadkhan2003/Kameti)

Kameti (کمیٹی) is a comprehensive committee management system that helps you organize rotating savings and credit associations (ROSCAs), also known as "committees" in South Asian communities. Manage members, track payments, handle payouts, and stay organized with real-time synchronization across all your devices.

---

## ✨ Features

### 🎯 Core Functionality
- **Committee Management**: Create and manage multiple committees with custom rules
- **Member Tracking**: Add, edit, and remove committee members with detailed profiles
- **Payment Management**: Track monthly contributions and payment status
- **Payout System**: Automated payout scheduling and member selection
- **Real-time Sync**: Changes sync instantly across all devices using Supabase Realtime
- **Offline Support**: Works offline with automatic sync when connection is restored

### 🔐 Security & Authentication
- **Supabase Auth**: Secure email/password and Google Sign-In
- **Row Level Security (RLS)**: Database-level security policies
- **PIN Protection**: Admin panel secured with 4-digit PIN
- **Encrypted Storage**: Sensitive data encrypted using Hive

### 📱 User Experience
- **Modern UI/UX**: Clean, intuitive interface with dark theme support
- **Multi-language**: Support for English and Urdu
- **Responsive Design**: Optimized for phones, tablets, and web
- **Force Update System**: Ensure users are on the latest version
- **Admin Panel**: Manage app configuration remotely without app updates

### 📊 Advanced Features
- **Payment History**: Complete audit trail of all transactions
- **Due Date Tracking**: Never miss a payment with smart notifications
- **Member Shuffling**: Randomize payout order for fairness
- **Committee Reports**: Generate detailed reports and summaries
- **Data Export**: Export committee data for backup or analysis

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (3.24.5 or higher)
- Dart SDK (3.5.4 or higher)
- Android Studio / Xcode (for mobile development)
- Node.js (for migration scripts)
- Supabase account ([Sign up free](https://supabase.com))

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/saadkhan2003/Kameti.git
   cd Kameti
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

4. **Configure Supabase**
   
   See [Supabase Setup Guide](scripts/supabase_setup_guide.md) for detailed instructions.

   Quick setup:
   ```bash
   # Run database migrations
   # Copy contents of scripts/setup_remote_config.sql to Supabase SQL Editor
   # Copy contents of scripts/setup_security_rls.sql to Supabase SQL Editor
   ```

5. **Run the app**
   ```bash
   # For development
   flutter run

   # For web
   flutter run -d chrome

   # For Android release
   flutter build appbundle --release
   ```

---

## 📱 Supabase Setup

### 1. Create Supabase Project

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Click "New Project"
3. Fill in project details and wait for initialization

### 2. Get Your Credentials

1. Navigate to **Settings** → **API**
2. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon/public key** → `SUPABASE_ANON_KEY`
   - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` (⚠️ Keep secret!)

3. Add to `.env` file:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
   ```

### 3. Run Database Migrations

Execute these SQL files in order (via Supabase SQL Editor):

1. `scripts/setup_remote_config.sql` - Remote config & force update
2. `scripts/setup_security_rls.sql` - Row Level Security policies

### 4. Test Connection

```bash
flutter run
# App should connect and show login screen
```

---

## 🔄 Migrating from Firebase

If you're migrating from an existing Firebase installation:

### Migration Guide

See detailed guide: [`scripts/MIGRATION_GUIDE.md`](scripts/MIGRATION_GUIDE.md)

**Quick Steps:**

1. **Export Firebase data**
   ```bash
   cd scripts
   node export_firebase_data.js
   ```

2. **Set up Supabase** (follow steps above)

3. **Migrate users**
   ```bash
   node migrate_users.js
   ```
   
   > ⚠️ **Important**: Users must reset their passwords after migration

4. **Migrate committees & data**
   ```bash
   node migrate.js
   ```

5. **Verify migration**
   ```bash
   node check_user_data.js
   node check_committee_details.js
   ```

---

## 🎨 Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── committee.dart
│   ├── member.dart
│   └── payment.dart
├── screens/                     # UI screens
│   ├── auth/                    # Authentication screens
│   ├── host/                    # Committee host screens
│   ├── admin/                   # Admin panel
│   └── splash_screen.dart
├── services/                    # Business logic
│   ├── auth_service.dart        # Authentication
│   ├── supabase_service.dart    # Supabase operations
│   ├── realtime_sync_service.dart  # Real-time sync
│   ├── remote_config_service.dart  # Force update
│   └── local_storage_service.dart  # Offline data
├── utils/                       # Utilities
│   ├── app_theme.dart
│   └── constants.dart
└── widgets/                     # Reusable components

scripts/
├── setup_remote_config.sql      # Remote config setup
├── setup_security_rls.sql       # Security policies
├── migrate_users.js             # User migration
├── migrate.js                   # Data migration
└── MIGRATION_GUIDE.md           # Migration docs

android/                         # Android-specific code
ios/                            # iOS-specific code
web/                            # Web-specific code
```

---

## 🔒 Security Features

### Row Level Security (RLS)

All Supabase tables are protected with RLS policies:

- ✅ Users can only access their own committees
- ✅ Users can only see members of committees they host
- ✅ Payment data is private to committee hosts
- ✅ App configuration is read-only for clients

See: [`scripts/RLS_SECURITY_GUIDE.md`](scripts/RLS_SECURITY_GUIDE.md)

### Admin Panel

Access the admin panel to manage app configuration:

1. Long-press **"Settings"** in the drawer (Host Dashboard)
2. Enter admin PIN (default: `1234`)
3. Configure:
   - Force update settings
   - Minimum app version
   - Update messages
   - Store URLs
   - Change admin PIN

See: [`scripts/ADMIN_PIN_GUIDE.md`](scripts/ADMIN_PIN_GUIDE.md)

### Force Update System

Ensure users are on the latest version:

- Remote configuration via Supabase
- Block outdated app versions
- Customizable update messages
- Direct link to app stores

See: [`scripts/force_update_guide.md`](scripts/force_update_guide.md)

---

## 🛠️ Build & Deploy

### Development Build

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

### Production Build

```bash
# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS App (for App Store)
flutter build ipa --release

# Web
flutter build web --release
```

### Release Configuration

**Android:**
- Update version in `pubspec.yaml`
- Configure signing in `android/key.properties`
- Build: `flutter build appbundle --release`
- Output: `build/app/outputs/bundle/release/app-release.aab`

**iOS:**
- Update version in `pubspec.yaml`
- Configure signing in Xcode
- Build: `flutter build ipa --release`
- Upload via Xcode or Transporter

---

## 📦 Dependencies

### Core
- **flutter**: ^3.24.5
- **supabase_flutter**: ^2.8.1
- **hive**: ^2.2.3 (Local storage)
- **hive_flutter**: ^1.1.0

### UI/UX
- **google_fonts**: ^6.3.2
- **flutter_svg**: ^2.0.16
- **introduction_screen**: ^3.1.17

### Authentication
- **google_sign_in**: ^6.3.0
- **local_auth**: ^2.3.0

### Utilities
- **url_launcher**: ^6.3.1
- **share_plus**: ^10.1.4
- **connectivity_plus**: ^6.1.5
- **intl**: ^0.19.0
- **flutter_dotenv**: ^5.2.1

### Development
- **flutter_lints**: ^5.0.0
- **build_runner**: ^2.4.13
- **hive_generator**: ^2.1.0

See [`pubspec.yaml`](pubspec.yaml) for complete list.

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Getting Started

1. Fork the repository
2. Create a feature branch
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. Make your changes
4. Run tests
   ```bash
   flutter test
   ```
5. Commit your changes
   ```bash
   git commit -m "feat: Add amazing feature"
   ```
6. Push to your fork
   ```bash
   git push origin feature/amazing-feature
   ```
7. Open a Pull Request

### Commit Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Run `flutter analyze` before committing
- Format code: `dart format .`

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Authors

- **Saad Khan** - [@saadkhan2003](https://github.com/saadkhan2003)

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev/) - Amazing cross-platform framework
- [Supabase](https://supabase.com/) - Open source Firebase alternative
- [Hive](https://docs.hivedb.dev/) - Fast, lightweight local database
- Community contributors and testers

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/saadkhan2003/Kameti/issues)
- **Discussions**: [GitHub Discussions](https://github.com/saadkhan2003/Kameti/discussions)
- **Email**: msaad.official6@gmail.com


---

**Built with ❤️ by the Kameti team**

*Making committee management simple, secure, and accessible for everyone.*
