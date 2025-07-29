#!/bin/bash

# Script to run the Flutter app on Pixel Tablet by default
# Usage: ./run_tablet.sh [debug|release|profile]

set -e

echo "🚀 Running Flutter POS App on Pixel Tablet..."

# Check if Pixel Tablet emulator is running
TABLET_RUNNING=$(adb devices | grep "emulator-" | head -1 | awk '{print $1}')

if [ -z "$TABLET_RUNNING" ]; then
    echo "📱 Starting Pixel Tablet emulator..."
    flutter emulators --launch Pixel_Tablet_API_34 &
    
    # Wait for emulator to boot
    echo "⏳ Waiting for emulator to start..."
    sleep 10
    
    # Wait for device to be ready
    adb wait-for-device
    echo "✅ Emulator is ready!"
fi

# Determine build mode
MODE=${1:-debug}
TARGET="lib/main_dev.dart"

case $MODE in
    "release")
        echo "🏗️  Building and running in release mode..."
        flutter run --release --target=$TARGET -d Pixel_Tablet_API_34
        ;;
    "profile")
        echo "🏗️  Building and running in profile mode..."
        flutter run --profile --target=$TARGET -d Pixel_Tablet_API_34
        ;;
    "debug"|*)
        echo "🏗️  Building and running in debug mode..."
        flutter run --debug --target=$TARGET -d Pixel_Tablet_API_34
        ;;
esac

echo "🎉 App is running on Pixel Tablet!" 