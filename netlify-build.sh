#!/bin/bash
set -e

echo "🔧 Installing Flutter SDK..."

# Download and extract Flutter SDK from stable channel
if [ ! -d "flutter" ]; then
  echo "📦 Downloading Flutter stable..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git flutter
fi

# Add Flutter to PATH
export PATH="$PATH:$PWD/flutter/bin"

# Show versions
echo "Flutter version:"
flutter --version
echo "Dart version:"
dart --version

# Enable web support
echo "🌐 Enabling Flutter web..."
flutter config --enable-web

# Get dependencies with retry
echo "📚 Getting dependencies..."
for i in {1..3}; do
  if flutter pub get; then
    break
  fi
  echo "Retry $i/3..."
  sleep 5
done

# Build for web
echo "🏗️  Building web app..."
flutter build web --release

echo "✅ Build complete!"
