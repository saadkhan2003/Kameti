#!/bin/bash
set -e

echo "🔧 Installing Flutter SDK..."

# Download and extract Flutter SDK
if [ ! -d "flutter" ]; then
  echo "📦 Downloading Flutter ${FLUTTER_VERSION:-stable}..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
fi

# Add Flutter to PATH
export PATH="$PATH:$PWD/flutter/bin"

# Enable web support
echo "🌐 Enabling Flutter web..."
flutter config --enable-web

# Get dependencies
echo "📚 Getting dependencies..."
flutter pub get

# Build for web
echo "🏗️  Building web app..."
flutter build web --release --web-renderer canvaskit

echo "✅ Build complete!"
