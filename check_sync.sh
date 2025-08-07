#!/bin/bash

echo "🔍 Checking Firebase Synchronization"
echo "===================================="

# Check if emulators are connected
EMULATORS=$(adb devices | grep emulator | cut -f1)

if [ -z "$EMULATORS" ]; then
    echo "❌ No emulators found"
    exit 1
fi

echo "✅ Found emulators: $EMULATORS"
echo ""

echo "📱 Manual Test Instructions:"
echo "============================"
echo ""
echo "1. On Emulator 5554:"
echo "   - Open the POS app"
echo "   - Go to 'New Order'"
echo "   - Add some items"
echo "   - Save the order with name 'SYNC_TEST_$(date +%s)'"
echo ""
echo "2. On Emulator 5558:"
echo "   - Open the POS app"
echo "   - Go to 'Orders' or 'Active Orders'"
echo "   - Look for the order you just created"
echo ""
echo "3. Expected Result:"
echo "   - If you see the order on both emulators: ✅ SYNC WORKING"
echo "   - If you don't see the order: ❌ SYNC BROKEN"
echo ""
echo "4. If sync is broken:"
echo "   - Run: ./fix_firebase_sync.sh"
echo "   - Or run: ./robust_firebase_sync.sh"
echo ""
echo "🔧 Quick Fix Commands:"
echo "======================"
echo "To force sync: ./fix_firebase_sync.sh"
echo "To monitor: ./monitor_firebase_sync.sh"
echo "To verify: ./verify_sync.sh"
