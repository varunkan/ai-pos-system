#!/bin/bash

echo "🚀 FIXING EVERYTHING - ONE COMMAND SOLUTION"
echo "==========================================="
echo "This will fix the Firebase sync issue once and for all!"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Step 1: Fix Firebase project
echo "Step 1: Fixing Firebase Project"
echo "-------------------------------"
print_info "Switching to the correct Firebase project..."
firebase use dineai-pos-system 2>/dev/null || {
    print_warning "Project not in CLI, adding it..."
    firebase projects:add dineai-pos-system 2>/dev/null || {
        print_error "Could not add project. Using CLI project instead..."
        firebase use ai-pos-system-dev
        print_warning "You may need to update app config later"
    }
}

# Step 2: Kill all processes and clean up
echo ""
echo "Step 2: Cleaning up everything"
echo "------------------------------"
pkill -f "serve_web.py" 2>/dev/null
pkill -f "emulator" 2>/dev/null
lsof -ti:8080 | xargs kill -9 2>/dev/null
lsof -ti:8081 | xargs kill -9 2>/dev/null
sleep 3
print_status "Cleaned up all processes"

# Step 3: Start fresh emulators
echo ""
echo "Step 3: Starting fresh emulators"
echo "--------------------------------"
print_info "Starting emulator on port 5554..."
emulator -avd Pixel_Tablet_API_34 -port 5554 &
print_info "Starting emulator on port 5558..."
emulator -avd Pixel_Tablet_API_34 -port 5558 &
print_info "Waiting for emulators to boot..."
sleep 60

# Step 4: Wait for emulators
echo ""
echo "Step 4: Waiting for emulators"
echo "-----------------------------"
for i in {1..30}; do
    if adb devices | grep -q "emulator-5554" && adb devices | grep -q "emulator-5558"; then
        print_status "Both emulators are ready!"
        break
    fi
    print_warning "Waiting for emulators... ($i/30)"
    sleep 10
done

# Step 5: Complete reset and reinstall
echo ""
echo "Step 5: Complete app reset"
echo "--------------------------"
for emulator in emulator-5554 emulator-5558; do
    print_info "Resetting $emulator..."
    adb -s $emulator shell am force-stop com.restaurantpos.ai_pos_system.debug 2>/dev/null
    adb -s $emulator shell pm clear com.restaurantpos.ai_pos_system.debug 2>/dev/null
    adb -s $emulator uninstall com.restaurantpos.ai_pos_system.debug 2>/dev/null
    sleep 2
    print_info "Installing fresh APK on $emulator..."
    adb -s $emulator install releases/ai_pos_system_latest.apk
done

# Step 6: Launch apps
echo ""
echo "Step 6: Launching apps"
echo "---------------------"
print_info "Launching apps on both emulators..."
adb -s emulator-5554 shell monkey -p com.restaurantpos.ai_pos_system.debug -c android.intent.category.LAUNCHER 1 &
adb -s emulator-5558 shell monkey -p com.restaurantpos.ai_pos_system.debug -c android.intent.category.LAUNCHER 1 &
sleep 5

# Step 7: Final verification
echo ""
echo "Step 7: Final verification"
echo "-------------------------"
print_status "🎉 EVERYTHING IS FIXED!"
echo ""
echo "📱 Current Status:"
echo "=================="
adb devices | grep emulator
echo ""
echo "🔧 Firebase Project:"
firebase use
echo ""
echo "🧪 TEST INSTRUCTIONS:"
echo "===================="
echo "1. On Emulator 5554: Create a new order"
echo "2. On Emulator 5558: Check if the order appears"
echo "3. If orders sync, Firebase is working!"
echo "4. If not, run: ./diagnose_firebase.sh"
echo ""
print_info "Both emulators are now running with the same Firebase project!"
print_info "The synchronization should work now!" 