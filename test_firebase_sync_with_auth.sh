#!/bin/bash

echo "🔥 Testing Firebase Sync with Authentication"
echo "============================================="

# Check if emulators are connected
echo "📱 Checking emulator connections..."
adb devices | grep emulator

if [ $? -eq 0 ]; then
    echo "✅ Emulators are connected"
else
    echo "❌ No emulators found"
    exit 1
fi

echo ""
echo "🔄 Restarting apps with fresh authentication..."
echo ""

# Force stop and clear apps
echo "⚠️  Force stopping apps..."
adb -s emulator-5554 shell am force-stop com.restaurantpos.ai_pos_system.debug
adb -s emulator-5556 shell am force-stop com.restaurantpos.ai_pos_system.debug

echo "🧹 Clearing app data..."
adb -s emulator-5554 shell pm clear com.restaurantpos.ai_pos_system.debug
adb -s emulator-5556 shell pm clear com.restaurantpos.ai_pos_system.debug

# Wait a moment
sleep 2

# Launch apps
echo "🚀 Launching apps..."
adb -s emulator-5554 shell am start -n com.restaurantpos.ai_pos_system.debug/com.restaurantpos.ai_pos_system.MainActivity
adb -s emulator-5556 shell am start -n com.restaurantpos.ai_pos_system.debug/com.restaurantpos.ai_pos_system.MainActivity

echo ""
echo "🎯 TESTING INSTRUCTIONS"
echo "======================="
echo ""
echo "📱 On BOTH Emulators (5554 & 5556):"
echo ""
echo "1. Wait for the app to load (you should see a login screen)"
echo ""
echo "2. Login with these credentials:"
echo "   Restaurant Email: demo@restaurant.com"
echo "   User ID: admin"
echo "   Password: admin123"
echo "   (Or use PIN: 1234)"
echo ""
echo "3. After successful login, you should see the main POS dashboard"
echo ""
echo "4. Test Firebase Sync:"
echo "   - On Emulator 5554: Go to 'New Order' → Add items → Save order"
echo "   - On Emulator 5556: Go to 'Orders' → Check if the order appears"
echo ""
echo "5. Test Menu Items Sync:"
echo "   - On Emulator 5554: Go to 'Menu Items' → You should see:"
echo "     • Bruschetta ($8.99)"
echo "     • Margherita Pizza ($16.99)"
echo "     • Chicken Alfredo ($18.99)"
echo "     • Tiramisu ($9.99)"
echo "     • Iced Latte ($4.99)"
echo "   - On Emulator 5556: Go to 'Menu Items' → Should see the same items"
echo ""
echo "6. Test Categories Sync:"
echo "   - Both emulators should show:"
echo "     • Appetizers"
echo "     • Main Course"
echo "     • Desserts"
echo "     • Beverages"
echo ""
echo "🔍 EXPECTED RESULTS:"
echo "==================="
echo "✅ Both emulators show identical menu items"
echo "✅ Both emulators show identical categories"
echo "✅ Orders created on one device appear on the other"
echo "✅ Real-time updates work between devices"
echo "✅ Firebase real-time sync is active"
echo ""
echo "❌ If sync is NOT working:"
echo "========================="
echo "1. Check if both emulators are logged in with the same credentials"
echo "2. Check if you see 'Firebase' or 'sync' messages in the app logs"
echo "3. Try creating a new order and wait 10-15 seconds"
echo "4. If still not working, run: ./fix_firebase_sync.sh"
echo ""
echo "📊 VERIFICATION:"
echo "==============="
echo "To verify data is in Firebase, run:"
echo "source firebase_env/bin/activate && python3 check_and_restore_data.py"
echo ""
echo "🎉 Both emulators should now be fully synchronized with Firebase!" 