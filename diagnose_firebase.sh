#!/bin/bash

echo "🔍 FIREBASE DIAGNOSTIC TOOL"
echo "============================"
echo "This will check what's wrong with Firebase sync"
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

# Check 1: Firebase configuration file
echo "Check 1: Firebase Configuration File"
echo "------------------------------------"
if [ -f "lib/firebase_options.dart" ]; then
    print_status "Firebase configuration file exists"
    echo "Project ID: $(grep -o 'projectId: "[^"]*"' lib/firebase_options.dart | cut -d'"' -f2)"
    echo "App ID: $(grep -o 'appId: "[^"]*"' lib/firebase_options.dart | cut -d'"' -f2 | head -1)"
else
    print_error "Firebase configuration file missing!"
    echo "Run: flutterfire configure"
fi

# Check 2: Emulator status
echo ""
echo "Check 2: Emulator Status"
echo "-----------------------"
adb devices | grep emulator
if [ $? -eq 0 ]; then
    print_status "Emulators are connected"
else
    print_error "No emulators found!"
fi

# Check 3: App installation
echo ""
echo "Check 3: App Installation"
echo "------------------------"
for emulator in $(adb devices | grep emulator | cut -f1); do
    echo "Checking $emulator..."
    if adb -s $emulator shell pm list packages | grep -q "ai_pos_system"; then
        print_status "App installed on $emulator"
        echo "Version: $(adb -s $emulator shell dumpsys package com.restaurantpos.ai_pos_system.debug | grep versionName | head -1)"
    else
        print_error "App not installed on $emulator"
    fi
done

# Check 4: Internet connectivity
echo ""
echo "Check 4: Internet Connectivity"
echo "-----------------------------"
for emulator in $(adb devices | grep emulator | cut -f1); do
    echo "Testing internet on $emulator..."
    if adb -s $emulator shell ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_status "Internet working on $emulator"
    else
        print_error "No internet on $emulator"
    fi
done

# Check 5: Firebase project status
echo ""
echo "Check 5: Firebase Project Status"
echo "-------------------------------"
if command -v firebase >/dev/null 2>&1; then
    print_status "Firebase CLI installed"
    firebase projects:list 2>/dev/null | head -5
else
    print_warning "Firebase CLI not installed"
    echo "Install with: npm install -g firebase-tools"
fi

# Check 6: App logs for Firebase errors
echo ""
echo "Check 6: Recent App Logs"
echo "-----------------------"
for emulator in $(adb devices | grep emulator | cut -f1); do
    echo "Recent logs from $emulator:"
    adb -s $emulator logcat -d | grep -i "firebase\|error\|exception" | tail -5
    echo ""
done

# Check 7: Database service status
echo ""
echo "Check 7: Database Service Status"
echo "-------------------------------"
for emulator in $(adb devices | grep emulator | cut -f1); do
    echo "Database services on $emulator:"
    adb -s $emulator shell dumpsys activity activities | grep -A 5 -B 5 "ai_pos_system" | head -10
    echo ""
done

echo ""
echo "🔧 RECOMMENDED FIXES:"
echo "===================="
echo ""
echo "If Firebase sync is not working:"
echo "1. Run: ./bulletproof_sync.sh"
echo "2. Check Firebase console for project settings"
echo "3. Verify Firestore rules allow read/write"
echo "4. Ensure both emulators have internet access"
echo "5. Check if Firebase project is in the correct region"
echo ""
echo "Quick test: Create an order on one emulator and check if it appears on the other" 