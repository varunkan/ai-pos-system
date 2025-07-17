#!/usr/bin/env python3
"""
🔍 Restaurant IP & Printer Finder
Helps find your restaurant's public IP and local printer information
"""

import requests
import socket
import subprocess
import platform
import json
from datetime import datetime

def get_public_ip():
    """Get restaurant's public IP address"""
    try:
        print("🌐 Getting your restaurant's public IP address...")
        response = requests.get('https://api.ipify.org?format=json', timeout=5)
        public_ip = response.json()['ip']
        print(f"✅ Your restaurant's public IP: {public_ip}")
        return public_ip
    except Exception as e:
        print(f"❌ Could not get public IP: {e}")
        return None

def get_local_ip():
    """Get local IP address"""
    try:
        # Get local IP by connecting to a remote host
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        print(f"🏠 Your local IP: {local_ip}")
        return local_ip
    except Exception as e:
        print(f"❌ Could not get local IP: {e}")
        return None

def scan_network_for_printers():
    """Scan local network for potential printers"""
    print("\n🔍 Scanning local network for printers...")
    
    local_ip = get_local_ip()
    if not local_ip:
        print("❌ Cannot scan without local IP")
        return []
    
    # Extract network prefix (e.g., 192.168.1 from 192.168.1.100)
    network_prefix = '.'.join(local_ip.split('.')[:-1])
    
    found_printers = []
    common_printer_ports = [9100, 515, 631, 80, 443]
    
    print(f"📡 Scanning {network_prefix}.* network...")
    
    for i in range(1, 255):
        ip = f"{network_prefix}.{i}"
        
        # Quick ping test
        try:
            if platform.system().lower() == "windows":
                result = subprocess.run(['ping', '-n', '1', '-w', '1000', ip], 
                                      capture_output=True, text=True, timeout=2)
            else:
                result = subprocess.run(['ping', '-c', '1', '-W', '1', ip], 
                                      capture_output=True, text=True, timeout=2)
            
            if result.returncode == 0:
                # Device is online, check for printer ports
                for port in common_printer_ports:
                    try:
                        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                        sock.settimeout(1)
                        result = sock.connect_ex((ip, port))
                        sock.close()
                        
                        if result == 0:
                            found_printers.append({
                                'ip': ip,
                                'port': port,
                                'type': 'potential_printer'
                            })
                            print(f"🖨️  Found potential printer: {ip}:{port}")
                            break
                    except:
                        continue
                        
        except:
            continue
    
    return found_printers

def create_printer_config(public_ip, local_ip, found_printers):
    """Create printer configuration file"""
    config = {
        'restaurant_info': {
            'public_ip': public_ip,
            'local_ip': local_ip,
            'scan_date': datetime.now().isoformat()
        },
        'printers': found_printers,
        'setup_instructions': {
            'step1': f"Your restaurant's public IP is: {public_ip}",
            'step2': "For cloud printing, you'll need to:",
            'step3': "1. Set up port forwarding on your router",
            'step4': "2. Forward ports 9100, 515, 631 to your printer IPs",
            'step5': "3. Use the public IP + port in your cloud setup"
        }
    }
    
    with open('restaurant_network_info.json', 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"\n✅ Network information saved to: restaurant_network_info.json")
    return config

def main():
    print("=" * 60)
    print("🔍 RESTAURANT IP & PRINTER FINDER")
    print("=" * 60)
    print()
    
    # Get public IP
    public_ip = get_public_ip()
    
    # Get local IP
    local_ip = get_local_ip()
    
    # Scan for printers
    found_printers = scan_network_for_printers()
    
    # Create configuration
    if public_ip or local_ip:
        config = create_printer_config(public_ip, local_ip, found_printers)
        
        print("\n📋 SUMMARY:")
        print("-" * 40)
        if public_ip:
            print(f"🌐 Public IP: {public_ip}")
        if local_ip:
            print(f"🏠 Local IP: {local_ip}")
        print(f"🖨️  Found {len(found_printers)} potential printers")
        
        if found_printers:
            print("\n🖨️  PRINTERS FOUND:")
            for printer in found_printers:
                print(f"   • {printer['ip']}:{printer['port']}")
        
        print("\n💡 NEXT STEPS:")
        print("1. Use the public IP in your cloud printing setup")
        print("2. Configure port forwarding on your router")
        print("3. Test printer connections")
        
    else:
        print("❌ Could not get network information")

if __name__ == "__main__":
    main() 