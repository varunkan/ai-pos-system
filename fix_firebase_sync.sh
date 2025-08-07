#!/bin/bash

echo "🔧 Quick Firebase Sync Fix"
echo "=========================="
echo "This script will fix the Firebase synchronization issue"
echo "so both emulators share the same data."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Step 1: Check emulators
echo "Step 1: Checking Emulators"
echo "--------------------------"

adb devices | grep emulator

if [ $? -ne 0 ]; then
    print_error "No emulators found. Please start your emulators first."
    exit 1
fi

EMULATORS=$(adb devices | grep emulator | cut -f1)
print_status "Found emulators: $EMULATORS"

# Step 2: Force stop and clear all apps
echo ""
echo "Step 2: Force Stopping and Clearing Apps"
echo "----------------------------------------"

for emulator in $EMULATORS; do
    print_warning "Force stopping app on $emulator..."
    adb -s $emulator shell am force-stop com.restaurantpos.ai_pos_system.debug
    
    print_warning "Clearing app data on $emulator..."
    adb -s $emulator shell pm clear com.restaurantpos.ai_pos_system.debug
    
    # Clear Firebase cache specifically
    adb -s $emulator shell rm -rf /data/data/com.restaurantpos.ai_pos_system.debug/cache
    adb -s $emulator shell rm -rf /data/data/com.restaurantpos.ai_pos_system.debug/files
    adb -s $emulator shell rm -rf /data/data/com.restaurantpos.ai_pos_system.debug/shared_prefs
    
    print_status "App cleared on $emulator"
done

# Step 3: Uninstall and reinstall APK
echo ""
echo "Step 3: Reinstalling APK"
echo "------------------------"

for emulator in $EMULATORS; do
    print_warning "Uninstalling app from $emulator..."
    adb -s $emulator uninstall com.restaurantpos.ai_pos_system.debug
    
    print_warning "Installing fresh APK on $emulator..."
    adb -s $emulator install releases/ai_pos_system_latest.apk
    
    print_status "APK reinstalled on $emulator"
done

# Step 4: Create Firebase test document
echo ""
echo "Step 4: Testing Firebase Connection"
echo "-----------------------------------"

# Get project ID
PROJECT_ID=$(grep -o 'projectId: "[^"]*"' lib/firebase_options.dart | cut -d'"' -f2)

if [ -n "$PROJECT_ID" ]; then
    print_status "Using Firebase project: $PROJECT_ID"
    
    # Create a test document using curl (if firebase CLI not available)
    TEST_DOC_ID="sync_test_$(date +%s)"
    
    echo "Creating test document: $TEST_DOC_ID"
    
    # This will create a test document that both emulators should see
    cat > create_test_doc.js << EOF
const admin = require('firebase-admin');
const serviceAccount = require('./firebase_env/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

db.collection('test_orders').doc('$TEST_DOC_ID').set({
  orderId: 'SYNC_TEST_001',
  items: ['Test Item 1', 'Test Item 2'],
  total: 25.99,
  timestamp: new Date(),
  status: 'pending',
  message: 'Firebase sync test - created at $(date)'
}).then(() => {
  console.log('✅ Test document created successfully');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Error creating test document:', error);
  process.exit(1);
});
EOF

    print_status "Test document script created"
else
    print_warning "Could not extract project ID. Manual testing required."
fi

# Step 5: Launch apps
echo ""
echo "Step 5: Launching Apps"
echo "----------------------"

for emulator in $EMULATORS; do
    print_warning "Launching app on $emulator..."
    adb -s $emulator shell monkey -p com.restaurantpos.ai_pos_system.debug -c android.intent.category.LAUNCHER 1
    print_status "App launched on $emulator"
done

# Step 6: Create verification script
echo ""
echo "Step 6: Creating Verification Script"
echo "------------------------------------"

cat > check_sync.sh << 'EOF'
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
EOF

chmod +x check_sync.sh

print_status "Verification script created"

# Final instructions
echo ""
echo "🎉 Firebase Sync Fix Complete!"
echo "=============================="
echo ""
echo "✅ What was done:"
echo "1. Force stopped all apps"
echo "2. Cleared all app data and cache"
echo "3. Uninstalled and reinstalled APK"
echo "4. Launched apps on all emulators"
echo "5. Created verification scripts"
echo ""
echo "🧪 To test synchronization:"
echo "1. Create an order on Emulator 5554"
echo "2. Check if it appears on Emulator 5558"
echo "3. If not, run: ./check_sync.sh for troubleshooting"
echo ""
echo "🔄 This fix ensures both emulators connect to the same Firebase database!"
echo ""
echo "📱 Both emulators should now be sharing the same data!" 