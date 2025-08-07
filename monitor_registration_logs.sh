#!/bin/bash

# Monitor Registration Logs
# This script monitors the app logs during restaurant registration

echo "🔍 Registration Process Monitor"
echo "================================"

# Check if emulators are connected
echo "📱 Checking emulator connections..."
adb devices

echo ""
echo "🎯 Monitoring Registration Process"
echo "=================================="
echo "This script will monitor the app logs during registration."
echo "Keep this terminal open while you register a new restaurant."
echo ""
echo "📋 Instructions:"
echo "1. Open the POS app on one of the emulators"
echo "2. Try to register a new restaurant"
echo "3. Watch the logs below for any errors or issues"
echo "4. Press Ctrl+C to stop monitoring"
echo ""

# Monitor logs for registration-related events
echo "📊 Starting log monitoring..."
echo "Looking for: registration, login, firebase, error, exception"
echo ""

adb -s emulator-5554 logcat -s "flutter" | grep -i "registration\|login\|firebase\|error\|exception\|auth\|tenant\|restaurant" --line-buffered 