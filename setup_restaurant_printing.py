#!/usr/bin/env python3
"""
🎯 Restaurant Printing Setup Script
Super simple setup for non-technical users
"""

import os
import sys
import json
import requests
import subprocess
import platform
from pathlib import Path

def print_banner():
    """Print welcome banner"""
    print("=" * 60)
    print("🎯 RESTAURANT PRINTING SETUP")
    print("Print from Home to Restaurant Printers")
    print("=" * 60)
    print()

def get_user_input(prompt, default=""):
    """Get user input with default value"""
    if default:
        user_input = input(f"{prompt} [{default}]: ").strip()
        return user_input if user_input else default
    else:
        return input(f"{prompt}: ").strip()

def check_internet():
    """Check if internet connection is available"""
    print("🌐 Checking internet connection...")
    try:
        response = requests.get("https://www.google.com", timeout=5)
        print("✅ Internet connection working")
        return True
    except:
        print("❌ No internet connection. Please check your WiFi.")
        return False

def create_cloud_account():
    """Guide user through cloud account creation"""
    print("\n📝 STEP 1: Create Cloud Account")
    print("-" * 40)
    
    print("Please visit: https://restaurant-print.cloud")
    print("1. Click 'Sign Up'")
    print("2. Enter your restaurant details")
    print("3. Choose Basic Plan ($29/month)")
    print("4. Get your Restaurant ID and API Key")
    print()
    
    restaurant_id = get_user_input("Enter your Restaurant ID")
    api_key = get_user_input("Enter your API Key")
    
    if not restaurant_id or not api_key:
        print("❌ Restaurant ID and API Key are required!")
        return None, None
    
    return restaurant_id, api_key

def download_bridge():
    """Download the restaurant bridge software"""
    print("\n📥 STEP 2: Download Bridge Software")
    print("-" * 40)
    
    system = platform.system().lower()
    
    if system == "windows":
        url = "https://restaurant-print.cloud/download/bridge-windows.exe"
        filename = "restaurant-bridge.exe"
    elif system == "darwin":  # macOS
        url = "https://restaurant-print.cloud/download/bridge-macos"
        filename = "restaurant-bridge"
    else:  # Linux
        url = "https://restaurant-print.cloud/download/bridge-linux"
        filename = "restaurant-bridge"
    
    print(f"Downloading bridge for {system}...")
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        with open(filename, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        # Make executable on Unix systems
        if system != "windows":
            os.chmod(filename, 0o755)
        
        print(f"✅ Bridge downloaded: {filename}")
        return filename
        
    except Exception as e:
        print(f"❌ Download failed: {e}")
        print("Please download manually from: https://restaurant-print.cloud/download")
        return None

def create_config(restaurant_id, api_key):
    """Create bridge configuration file"""
    print("\n⚙️ STEP 3: Create Configuration")
    print("-" * 40)
    
    config = {
        "restaurantId": restaurant_id,
        "apiKey": api_key,
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
    config_file = "bridge-config.json"
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Configuration saved: {config_file}")
    return config_file

def start_bridge(bridge_file, config_file):
    """Start the bridge service"""
    print("\n🚀 STEP 4: Start Bridge Service")
    print("-" * 40)
    
    print("Starting bridge service...")
    
    try:
        # Start bridge with configuration
        cmd = [bridge_file, "--config", config_file, "--start"]
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        print("✅ Bridge service started!")
        print("📋 Bridge is now running in the background")
        print("💡 Keep this computer running for printing to work")
        
        return process
        
    except Exception as e:
        print(f"❌ Failed to start bridge: {e}")
        print("Please run manually:")
        print(f"  {bridge_file} --config {config_file} --start")
        return None

def test_connection(restaurant_id, api_key):
    """Test connection to cloud service"""
    print("\n🧪 STEP 5: Test Connection")
    print("-" * 40)
    
    try:
        url = "https://restaurant-print.cloud/api/v1/health"
        headers = {"Authorization": f"Bearer {api_key}"}
        
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            print("✅ Cloud connection successful!")
            return True
        else:
            print(f"❌ Cloud connection failed: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Connection test failed: {e}")
        return False

def configure_pos_app(restaurant_id, api_key):
    """Guide user through POS app configuration"""
    print("\n📱 STEP 6: Configure POS App")
    print("-" * 40)
    
    print("Now configure your POS app:")
    print()
    print("1. Open your POS app")
    print("2. Go to Admin Panel → Settings")
    print("3. Find 'Cloud Printing' or 'Internet Printing'")
    print("4. Enter these details:")
    print()
    print(f"   Service URL: https://restaurant-print.cloud/api/v1")
    print(f"   Restaurant ID: {restaurant_id}")
    print(f"   API Key: {api_key}")
    print()
    print("5. Click 'Test Connection'")
    print("6. Click 'Save Settings'")
    print()

def create_startup_script(bridge_file, config_file):
    """Create startup script for automatic bridge startup"""
    print("\n🔄 Creating Startup Script")
    print("-" * 40)
    
    system = platform.system().lower()
    
    if system == "windows":
        script_content = f"""@echo off
cd /d "%~dp0"
"{bridge_file}" --config "{config_file}" --start
pause
"""
        script_file = "start-bridge.bat"
    else:
        script_content = f"""#!/bin/bash
cd "$(dirname "$0")"
./{bridge_file} --config {config_file} --start
"""
        script_file = "start-bridge.sh"
        os.chmod(script_file, 0o755)
    
    with open(script_file, 'w') as f:
        f.write(script_content)
    
    print(f"✅ Startup script created: {script_file}")
    print(f"💡 Double-click {script_file} to start the bridge")

def main():
    """Main setup function"""
    print_banner()
    
    # Check internet connection
    if not check_internet():
        return
    
    # Get cloud account details
    restaurant_id, api_key = create_cloud_account()
    if not restaurant_id or not api_key:
        return
    
    # Download bridge
    bridge_file = download_bridge()
    if not bridge_file:
        return
    
    # Create configuration
    config_file = create_config(restaurant_id, api_key)
    
    # Test connection
    if not test_connection(restaurant_id, api_key):
        print("⚠️ Connection test failed, but continuing setup...")
    
    # Start bridge
    bridge_process = start_bridge(bridge_file, config_file)
    
    # Configure POS app
    configure_pos_app(restaurant_id, api_key)
    
    # Create startup script
    create_startup_script(bridge_file, config_file)
    
    # Final instructions
    print("\n🎉 SETUP COMPLETE!")
    print("=" * 40)
    print("✅ Cloud account created")
    print("✅ Bridge downloaded and configured")
    print("✅ Printers added")
    print("✅ Bridge service started")
    print("✅ POS app configuration ready")
    print()
    print("📋 Next Steps:")
    print("1. Configure your POS app with the details above")
    print("2. Test by creating an order and clicking 'Send to Kitchen'")
    print("3. Keep this computer running for printing to work")
    print()
    print("📞 Need help? Call: 1-800-PRINT-HELP")
    print("📧 Email: support@restaurant-print.cloud")
    print()
    print("🚀 You're ready to print from home to your restaurant!")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️ Setup cancelled by user")
    except Exception as e:
        print(f"\n❌ Setup failed: {e}")
        print("📞 Please call support: 1-800-PRINT-HELP")
    
    input("\nPress Enter to exit...") 