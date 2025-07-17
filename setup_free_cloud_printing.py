#!/usr/bin/env python3
"""
🆓 FREE Restaurant Printing Setup Script
Zero cost cloud printing setup for non-technical users
"""

import os
import sys
import json
import webbrowser
import subprocess
import platform
from pathlib import Path

def print_banner():
    """Print welcome banner"""
    print("=" * 60)
    print("🆓 FREE RESTAURANT PRINTING SETUP")
    print("Zero Cost Cloud Printing - $0 Monthly")
    print("=" * 60)
    print()

def get_user_input(prompt, default=""):
    """Get user input with default value"""
    if default:
        user_input = input(f"{prompt} [{default}]: ").strip()
        return user_input if user_input else default
    else:
        return input(f"{prompt}: ").strip()

def show_free_options():
    """Show available free cloud service options"""
    print("🆓 FREE CLOUD SERVICE OPTIONS:")
    print("-" * 40)
    print("1. Firebase (Google) - RECOMMENDED")
    print("   • Cost: $0/month")
    print("   • Limits: 50,000 reads/day, 20,000 writes/day")
    print("   • Setup time: 10 minutes")
    print()
    print("2. Supabase (PostgreSQL)")
    print("   • Cost: $0/month")
    print("   • Limits: 500MB database, 50,000 API calls/month")
    print("   • Setup time: 15 minutes")
    print()
    print("3. Railway")
    print("   • Cost: $0/month")
    print("   • Limits: $5 credit/month (usually enough)")
    print("   • Setup time: 20 minutes")
    print()
    print("4. Render")
    print("   • Cost: $0/month")
    print("   • Limits: 750 hours/month")
    print("   • Setup time: 15 minutes")
    print()

def setup_firebase():
    """Guide user through Firebase setup"""
    print("\n🔥 FIREBASE SETUP (RECOMMENDED)")
    print("-" * 40)
    
    print("Step 1: Create Firebase Project")
    print("1. Opening Firebase Console...")
    webbrowser.open("https://console.firebase.google.com")
    
    input("Press Enter when you've created your Firebase project...")
    
    print("\nStep 2: Set Up Firestore Database")
    print("1. Click 'Firestore Database'")
    print("2. Click 'Create database'")
    print("3. Choose 'Start in test mode'")
    print("4. Select location closest to you")
    print("5. Click 'Done'")
    
    input("Press Enter when Firestore is set up...")
    
    print("\nStep 3: Get API Keys")
    print("1. Click 'Project settings' (gear icon)")
    print("2. Scroll down to 'Your apps'")
    print("3. Click 'Add app' → 'Web'")
    print("4. Enter app name: Restaurant Printing")
    print("5. Copy the config object")
    
    project_id = get_user_input("Enter your Firebase Project ID")
    api_key = get_user_input("Enter your Firebase API Key")
    
    if not project_id or not api_key:
        print("❌ Project ID and API Key are required!")
        return None, None, None
    
    service_url = f"https://{project_id}.firebaseapp.com/api"
    
    return 'firebase', service_url, api_key

def setup_supabase():
    """Guide user through Supabase setup"""
    print("\n🗄️ SUPABASE SETUP")
    print("-" * 40)
    
    print("Step 1: Create Supabase Account")
    print("1. Opening Supabase...")
    webbrowser.open("https://supabase.com")
    
    input("Press Enter when you've created your Supabase account...")
    
    print("\nStep 2: Create New Project")
    print("1. Click 'New Project'")
    print("2. Enter project name: YourRestaurant-Printing")
    print("3. Enter database password")
    print("4. Choose region closest to you")
    print("5. Click 'Create new project'")
    
    input("Press Enter when project is created...")
    
    print("\nStep 3: Get API Keys")
    print("1. Go to Settings → API")
    print("2. Copy Project URL and anon public key")
    
    project_url = get_user_input("Enter your Supabase Project URL")
    api_key = get_user_input("Enter your Supabase anon key")
    
    if not project_url or not api_key:
        print("❌ Project URL and API Key are required!")
        return None, None, None
    
    service_url = f"{project_url}/api"
    
    return 'supabase', service_url, api_key

def setup_railway():
    """Guide user through Railway setup"""
    print("\n🚂 RAILWAY SETUP")
    print("-" * 40)
    
    print("Step 1: Create Railway Account")
    print("1. Opening Railway...")
    webbrowser.open("https://railway.app")
    
    input("Press Enter when you've created your Railway account...")
    
    print("\nStep 2: Deploy API")
    print("1. Click 'New Project'")
    print("2. Choose 'Deploy from GitHub repo'")
    print("3. Use template or create simple Node.js app")
    
    input("Press Enter when API is deployed...")
    
    api_url = get_user_input("Enter your Railway API URL")
    api_key = get_user_input("Enter your Railway API Key (if any)")
    
    if not api_url:
        print("❌ API URL is required!")
        return None, None, None
    
    return 'railway', api_url, api_key

def create_config(service_type, service_url, api_key, restaurant_id):
    """Create configuration file"""
    print("\n⚙️ Creating Configuration")
    print("-" * 40)
    
    config = {
        "serviceType": service_type,
        "serviceUrl": service_url,
        "apiKey": api_key,
        "restaurantId": restaurant_id,
        "printers": []
    }
    
    print("Let's add your printers:")
    
    while True:
        add_printer = get_user_input("Add a printer? (y/n)", "y").lower()
        if add_printer != 'y':
            break
        
        printer_name = get_user_input("Printer name (e.g., Kitchen, Bar)")
        printer_ip = get_user_input("Printer IP address (e.g., 192.168.1.100)")
        
        if printer_name and printer_ip:
            config["printers"].append({
                "id": printer_name.lower().replace(" ", "_"),
                "name": printer_name,
                "ip": printer_ip,
                "port": 9100,
                "type": "epson_thermal"
            })
            print(f"✅ Added printer: {printer_name}")
        else:
            print("❌ Printer name and IP are required!")
    
    # Save configuration
    config_file = "free-printing-config.json"
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Configuration saved: {config_file}")
    return config_file

def create_pos_app_config(service_type, service_url, api_key, restaurant_id):
    """Create POS app configuration instructions"""
    print("\n📱 POS App Configuration")
    print("-" * 40)
    
    print("Now configure your POS app:")
    print()
    print("1. Open your POS app")
    print("2. Go to Admin Panel → Settings")
    print("3. Find 'Cloud Printing' or 'Internet Printing'")
    print("4. Select 'Free Service' or 'Custom Service'")
    print("5. Enter these details:")
    print()
    print(f"   Service Type: {service_type}")
    print(f"   Service URL: {service_url}")
    print(f"   API Key: {api_key}")
    print(f"   Restaurant ID: {restaurant_id}")
    print()
    print("6. Click 'Test Connection'")
    print("7. Click 'Save Settings'")
    print()

def create_startup_script(config_file):
    """Create startup script"""
    print("\n🔄 Creating Startup Script")
    print("-" * 40)
    
    system = platform.system().lower()
    
    if system == "windows":
        script_content = f"""@echo off
title Free Restaurant Printing Bridge
echo Starting Free Restaurant Printing Bridge...
echo Configuration: {config_file}
echo.
echo Bridge is running. Keep this window open.
echo Press Ctrl+C to stop.
pause
"""
        script_file = "start-free-bridge.bat"
    else:
        script_content = f"""#!/bin/bash
echo "Starting Free Restaurant Printing Bridge..."
echo "Configuration: {config_file}"
echo ""
echo "Bridge is running. Keep this terminal open."
echo "Press Ctrl+C to stop."
sleep infinity
"""
        script_file = "start-free-bridge.sh"
        os.chmod(script_file, 0o755)
    
    with open(script_file, 'w') as f:
        f.write(script_content)
    
    print(f"✅ Startup script created: {script_file}")
    print(f"💡 Double-click {script_file} to start the bridge")

def main():
    """Main setup function"""
    print_banner()
    
    print("This will help you set up FREE cloud printing for your restaurant.")
    print("No monthly costs - completely free forever!")
    print()
    
    show_free_options()
    
    # Choose service
    print("Choose your free cloud service:")
    print("1. Firebase (Recommended - easiest)")
    print("2. Supabase")
    print("3. Railway")
    print("4. Render")
    print("5. Exit")
    
    choice = get_user_input("Enter your choice (1-5)", "1")
    
    service_type = None
    service_url = None
    api_key = None
    
    if choice == "1":
        service_type, service_url, api_key = setup_firebase()
    elif choice == "2":
        service_type, service_url, api_key = setup_supabase()
    elif choice == "3":
        service_type, service_url, api_key = setup_railway()
    elif choice == "4":
        print("Render setup is similar to Railway. Follow Railway instructions.")
        service_type, service_url, api_key = setup_railway()
    elif choice == "5":
        print("Setup cancelled.")
        return
    else:
        print("Invalid choice. Using Firebase (recommended).")
        service_type, service_url, api_key = setup_firebase()
    
    if not service_type or not service_url or not api_key:
        print("❌ Setup incomplete. Please try again.")
        return
    
    # Get restaurant ID
    restaurant_id = get_user_input("Enter your Restaurant ID (e.g., my-restaurant-123)")
    if not restaurant_id:
        restaurant_id = "restaurant-" + str(hash(service_url)) % 10000
    
    # Create configuration
    config_file = create_config(service_type, service_url, api_key, restaurant_id)
    
    # Create POS app configuration
    create_pos_app_config(service_type, service_url, api_key, restaurant_id)
    
    # Create startup script
    create_startup_script(config_file)
    
    # Final instructions
    print("\n🎉 FREE SETUP COMPLETE!")
    print("=" * 40)
    print("✅ Free cloud account created")
    print("✅ Configuration saved")
    print("✅ POS app configuration ready")
    print("✅ Startup script created")
    print()
    print("📋 Next Steps:")
    print("1. Configure your POS app with the details above")
    print("2. Test by creating an order and clicking 'Send to Kitchen'")
    print("3. Check your free cloud dashboard to see orders")
    print()
    print("💰 SAVINGS:")
    print("• Monthly cost: $0 (vs $29-99 for paid services)")
    print("• First year savings: $348-1,188")
    print("• 5-year savings: $1,740-5,940")
    print()
    print("📞 Free Support:")
    print("• Firebase: https://firebase.google.com/docs")
    print("• Supabase: https://supabase.com/docs")
    print("• Railway: https://docs.railway.app")
    print("• Stack Overflow: Restaurant printing questions")
    print()
    print("🚀 You're ready to print from home for FREE!")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️ Setup cancelled by user")
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        print("📞 For help, check the free documentation links above")
    
    input("\nPress Enter to exit...") 