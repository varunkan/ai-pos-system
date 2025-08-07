#!/bin/bash

echo "🔧 FIXING FIREBASE PROJECT MISMATCH"
echo "==================================="
echo "The issue is that you have two different Firebase projects:"
echo "- App config: dineai-pos-system"
echo "- CLI project: ai-pos-system-dev"
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

echo "Current Firebase Configuration:"
echo "=============================="
echo "Project ID in app: dineai-pos-system"
echo "Project ID in CLI: ai-pos-system-dev"
echo ""

print_warning "This mismatch is causing the sync issues!"

echo ""
echo "SOLUTION OPTIONS:"
echo "================"
echo "1. Use the existing project (dineai-pos-system)"
echo "2. Switch to the CLI project (ai-pos-system-dev)"
echo "3. Create a new unified project"
echo ""

read -p "Choose option (1/2/3): " choice

case $choice in
    1)
        print_info "Using existing project: dineai-pos-system"
        firebase use dineai-pos-system 2>/dev/null || {
            print_error "Project not found in Firebase CLI"
            print_info "You need to add this project to Firebase CLI"
            echo "Run: firebase projects:add dineai-pos-system"
        }
        ;;
    2)
        print_info "Switching to CLI project: ai-pos-system-dev"
        print_warning "This will require updating the app configuration"
        firebase use ai-pos-system-dev
        print_info "Now you need to update lib/firebase_options.dart"
        print_info "Run: flutterfire configure --project=ai-pos-system-dev"
        ;;
    3)
        print_info "Creating new unified project..."
        firebase projects:create ai-pos-system-unified
        firebase use ai-pos-system-unified
        print_info "Now configure the app:"
        print_info "Run: flutterfire configure --project=ai-pos-system-unified"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🔧 NEXT STEPS:"
echo "=============="
echo "1. Ensure Firebase project is properly configured"
echo "2. Run: ./bulletproof_sync.sh"
echo "3. Test synchronization between emulators"
echo ""
print_info "The key is to use the SAME Firebase project for both CLI and app!" 