#!/bin/bash

echo "🔄 AI POS System Emulator Synchronization"
echo "=========================================="

# Check if emulators are connected
echo "📱 Checking emulator connections..."
adb devices | grep emulator

if [ $? -ne 0 ]; then
    echo "❌ No emulators found. Please start your emulators first."
    exit 1
fi

# Get list of connected emulators
EMULATORS=$(adb devices | grep emulator | cut -f1)

echo "✅ Found emulators: $EMULATORS"

# Install latest APK on all emulators
echo "📦 Installing latest APK on all emulators..."
for emulator in $EMULATORS; do
    echo "Installing on $emulator..."
    adb -s $emulator install -r releases/ai_pos_system_latest.apk
done

# Launch app on all emulators
echo "🚀 Launching app on all emulators..."
for emulator in $EMULATORS; do
    echo "Launching on $emulator..."
    adb -s $emulator shell monkey -p com.restaurantpos.ai_pos_system.debug -c android.intent.category.LAUNCHER 1
done

echo "✅ Synchronization complete!"
echo "📱 Both emulators are now running the same version of AI POS System" 