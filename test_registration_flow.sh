#!/bin/bash

# Test Registration Flow
# This script tests the complete registration process

echo "🧪 Testing Registration Flow"
echo "============================="

# Check if emulators are connected
echo "📱 Checking emulator connections..."
adb devices

echo ""
echo "🎯 Registration Flow Test Instructions"
echo "======================================"
echo "1. On Emulator 5554 (Pixel Tablet):"
echo "   - Open the POS app"
echo "   - You should see the login screen"
echo "   - Click on 'Don't have an account? Register' link"
echo "   - You should now see the registration screen"
echo ""
echo "2. Fill out the registration form:"
echo "   - Restaurant Name: Test Restaurant"
echo "   - Restaurant Email: test@restaurant.com"
echo "   - Admin Name: Admin User"
echo "   - Admin Password: admin123"
echo "   - Admin PIN: 1234"
echo ""
echo "3. Click 'Create Restaurant' button"
echo ""
echo "4. Expected Results:"
echo "   - Registration should complete successfully"
echo "   - You should see a success dialog"
echo "   - App should redirect to login screen"
echo "   - You should be able to login with the created credentials"
echo ""
echo "5. Test Login:"
echo "   - Restaurant Email: test@restaurant.com"
echo "   - User ID: admin"
echo "   - Password: admin123"
echo "   - Or use PIN: 1234"
echo ""
echo "📊 Monitoring logs for any errors..."
echo ""

# Monitor logs for registration-related events
adb -s emulator-5554 logcat -s "flutter" | grep -i "registration\|login\|firebase\|error\|exception\|auth\|tenant\|restaurant" --line-buffered 