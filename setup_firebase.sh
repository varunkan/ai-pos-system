#!/bin/bash

# AI POS System - Firebase Setup Script
# This script helps you set up Firebase for cross-platform hosting

echo "🚀 AI POS System - Firebase Setup"
echo "=================================="

# Check if Node.js is installed
if ! command -v npm &> /dev/null; then
    echo "❌ Node.js and npm are required. Please install Node.js first:"
    echo "   https://nodejs.org/"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is required. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Install Firebase CLI
echo "📦 Installing Firebase CLI..."
npm install -g firebase-tools

# Install FlutterFire CLI
echo "📦 Installing FlutterFire CLI..."
dart pub global activate flutterfire_cli

echo ""
echo "🔥 Firebase Setup Instructions:"
echo "1. Login to Firebase:"
echo "   firebase login"
echo ""
echo "2. Create or select a Firebase project:"
echo "   firebase projects:create your-pos-system-id"
echo "   # OR select existing project"
echo "   firebase use your-existing-project-id"
echo ""
echo "3. Configure Firebase for your Flutter app:"
echo "   flutterfire configure"
echo "   # This will create firebase_options.dart"
echo ""
echo "4. Enable required Firebase services in console:"
echo "   - Firestore Database"
echo "   - Authentication"
echo "   - Hosting"
echo "   - Analytics (optional)"
echo ""
echo "5. Initialize Firebase hosting:"
echo "   firebase init hosting"
echo "   # Select 'build/web' as public directory"
echo "   # Configure as single-page app: Yes"
echo ""
echo "6. Build and deploy web app:"
echo "   flutter build web --release"
echo "   firebase deploy --only hosting"
echo ""
echo "🌐 Web Hosting URLs:"
echo "   Production: https://your-project-id.web.app"
echo "   Custom domain: Configure in Firebase Console"
echo ""
echo "📱 Mobile App Distribution:"
echo "   Android: flutter build appbundle --release"
echo "   iOS: flutter build ios --release"
echo ""
echo "📊 Next Steps:"
echo "   1. Set up Firestore security rules"
echo "   2. Configure authentication methods"
echo "   3. Test cross-platform synchronization"
echo "   4. Deploy to app stores"
echo ""
echo "📖 For detailed instructions, see HOSTING_DEPLOYMENT_GUIDE.md"
echo ""
echo "🎯 Ready to start? Run: firebase login" 