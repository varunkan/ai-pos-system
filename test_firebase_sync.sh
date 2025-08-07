#!/bin/bash

echo "🧪 Firebase Synchronization Test"
echo "================================"
echo "This script will test if both emulators are properly"
echo "connected to Firebase and can share data."
echo ""

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

echo ""
echo "🔧 Testing Steps:"
echo "1. On Emulator 5554: Create a test order"
echo "2. On Emulator 5558: Check if the order appears"
echo "3. On Emulator 5558: Update the order"
echo "4. On Emulator 5554: Check if the update appears"
echo ""

echo "📋 Manual Test Instructions:"
echo "============================"
echo ""
echo "Step 1: Create Test Order on Emulator 5554"
echo "-------------------------------------------"
echo "1. Open the POS app on Emulator 5554"
echo "2. Go to 'New Order'"
echo "3. Add some items to the order"
echo "4. Save the order with a unique name like 'TEST-SYNC-001'"
echo ""
echo "Step 2: Verify on Emulator 5558"
echo "--------------------------------"
echo "1. Open the POS app on Emulator 5558"
echo "2. Go to 'Orders' or 'Active Orders'"
echo "3. Look for the order 'TEST-SYNC-001'"
echo "4. If you see it, Firebase sync is working! ✅"
echo ""
echo "Step 3: Update Order on Emulator 5558"
echo "-------------------------------------"
echo "1. On Emulator 5558, open the test order"
echo "2. Add or modify some items"
echo "3. Save the changes"
echo ""
echo "Step 4: Verify Update on Emulator 5554"
echo "--------------------------------------"
echo "1. On Emulator 5554, refresh the orders list"
echo "2. Open the test order"
echo "3. Check if the changes from Emulator 5558 appear"
echo "4. If yes, real-time sync is working! ✅"
echo ""

echo "🎯 Expected Results:"
echo "==================="
echo "✅ Orders created on one emulator appear on the other"
echo "✅ Updates made on one emulator sync to the other"
echo "✅ Menu items and inventory are shared"
echo "✅ All data is synchronized in real-time"
echo ""

echo "🚨 If sync is not working:"
echo "=========================="
echo "1. Check internet connection on both emulators"
echo "2. Verify Firebase project is active"
echo "3. Check Firebase console for any errors"
echo "4. Restart the app on both emulators"
echo ""

echo "📱 Both emulators should now be sharing the same Firebase database!" 