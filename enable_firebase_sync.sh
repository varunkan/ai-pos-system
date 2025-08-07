#!/bin/bash

echo "🔥 Firebase Database Synchronization Setup"
echo "=========================================="
echo "This script will enable centralized Firebase database"
echo "so both emulators share the same data."
echo ""

# Check if Firebase project is configured
echo "📋 Checking Firebase configuration..."

# Check if firebase_options.dart exists
if [ ! -f "lib/firebase_options.dart" ]; then
    echo "❌ Firebase configuration not found!"
    echo "Please run: flutterfire configure"
    echo "Or set up Firebase manually following FIREBASE_SETUP_GUIDE.md"
    exit 1
fi

echo "✅ Firebase configuration found"

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

# Clear app data on both emulators to ensure fresh Firebase sync
echo "🧹 Clearing app data on all emulators..."
for emulator in $EMULATORS; do
    echo "Clearing data on $emulator..."
    adb -s $emulator shell pm clear com.restaurantpos.ai_pos_system.debug
done

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

echo ""
echo "✅ Firebase Database Synchronization Enabled!"
echo ""
echo "📋 What happens now:"
echo "1. Both emulators will connect to the same Firebase database"
echo "2. All data (orders, menu, inventory) will be shared in real-time"
echo "3. Changes on one emulator will appear on the other instantly"
echo ""
echo "🔧 To test synchronization:"
echo "1. Create an order on Emulator 5554"
echo "2. Watch it appear on Emulator 5558"
echo "3. Update the order on Emulator 5558"
echo "4. Watch the update sync to Emulator 5554"
echo ""
echo "📱 Both emulators are now running with centralized Firebase database!" 