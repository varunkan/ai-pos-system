#!/bin/bash

# Setup script for convenient Flutter POS development aliases
# Source this file: source setup_aliases.sh

echo "🛠️  Setting up Flutter POS development aliases..."

# Alias to run on Pixel Tablet in debug mode
alias run-pos="flutter run --debug --target=lib/main_dev.dart -d Pixel_Tablet_API_34"

# Alias to run on Pixel Tablet in release mode
alias run-pos-release="flutter run --release --target=lib/main_dev.dart -d Pixel_Tablet_API_34"

# Alias to build APK for Pixel Tablet
alias build-pos="flutter build apk --target=lib/main_dev.dart --debug"

# Alias to install and run APK on Pixel Tablet
alias install-pos="adb install -r build/app/outputs/flutter-apk/app-debug.apk && adb shell am start -n com.restaurantpos.ai_pos_system.debug/com.restaurantpos.ai_pos_system.MainActivity"

# Alias to start Pixel Tablet emulator
alias start-tablet="flutter emulators --launch Pixel_Tablet_API_34"

# Alias to check devices
alias check-devices="flutter devices"

# Alias to clean and rebuild
alias clean-pos="flutter clean && flutter pub get && flutter build apk --target=lib/main_dev.dart --debug"

echo "✅ Aliases set up successfully!"
echo ""
echo "Available commands:"
echo "  run-pos          - Run app on Pixel Tablet (debug)"
echo "  run-pos-release  - Run app on Pixel Tablet (release)"
echo "  build-pos        - Build APK for development"
echo "  install-pos      - Install and launch APK on Pixel Tablet"
echo "  start-tablet     - Start Pixel Tablet emulator"
echo "  check-devices    - List available devices"
echo "  clean-pos        - Clean, rebuild, and build APK"
echo ""
echo "💡 To make these permanent, add 'source $(pwd)/setup_aliases.sh' to your ~/.bashrc or ~/.zshrc" 