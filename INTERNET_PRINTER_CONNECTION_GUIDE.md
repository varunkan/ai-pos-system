# 🌐 Internet Restaurant Printing Setup Guide
## Connect All POS App Instances to Restaurant Printers via Internet

This guide will help you set up a **cloud-based printing system** that allows any POS app instance (home, mobile, tablet) to print directly to your restaurant's thermal printers over the internet.

---

## 🎯 What You'll Achieve

✅ **Print from anywhere** - Home, mobile, tablet, any device  
✅ **Real-time printing** - Orders print instantly at restaurant  
✅ **Automatic routing** - Orders go to correct kitchen stations  
✅ **Offline resilience** - Orders queue when internet is down  
✅ **Multi-printer support** - All your kitchen printers work  
✅ **Secure connections** - Encrypted, authenticated printing  

---

## 🏗️ System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   POS App       │    │   Cloud Service │    │   Restaurant    │
│   (Any Device)  │───▶│   (Relay)       │───▶│   Printers      │
│                 │    │                 │    │                 │
│ • Home          │    │ • Order Queue   │    │ • Kitchen       │
│ • Mobile        │    │ • Authentication│    │ • Bar           │
│ • Tablet        │    │ • Routing       │    │ • Tandoor       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## 📋 Prerequisites

### At Your Restaurant:
- ✅ Epson thermal printers (TM-T88VI, TM-M30III, etc.)
- ✅ Router with admin access
- ✅ Stable internet connection (minimum 10 Mbps)
- ✅ Printers connected to network (WiFi or Ethernet)
- ✅ Computer to run printer bridge software

### At Your Home/Remote Locations:
- ✅ POS app installed on devices
- ✅ Internet connection
- ✅ Cloud service account

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Set Up Cloud Service

1. **Sign up for cloud printing service:**
   ```
   Visit: https://restaurant-print.cloud
   Create account for your restaurant
   Choose plan: Basic ($29/month) or Pro ($49/month)
   ```

2. **Get your credentials:**
   - Restaurant ID: `rest_abc123def456`
   - API Key: `sk_live_xyz789abc123`
   - Service URL: `https://restaurant-print.cloud/api/v1`

### Step 2: Configure Restaurant Printers

1. **Install printer bridge software at restaurant:**
   ```bash
   # Download and install on restaurant computer
   wget https://restaurant-print.cloud/download/bridge
   chmod +x bridge
   ./bridge --install
   ```

2. **Configure bridge with your printers:**
   ```bash
   ./bridge --configure
   # Enter your restaurant ID and API key
   # Add your printer IP addresses
   ```

3. **Start the bridge service:**
   ```bash
   ./bridge --start
   # Bridge will now relay print jobs to your printers
   ```

### Step 3: Configure POS App

1. **Open POS app settings:**
   - Go to **Admin Panel** → **Settings** → **Cloud Printing**

2. **Enter cloud service details:**
   ```
   Service URL: https://restaurant-print.cloud/api/v1
   Restaurant ID: rest_abc123def456
   API Key: sk_live_xyz789abc123
   ```

3. **Test connection:**
   - Click **Test Cloud Connection**
   - Should show "Connected successfully"

---

## 🔧 Detailed Setup Instructions

### Method 1: Cloud Service (Recommended)

#### Restaurant Side Setup:

1. **Prepare your printers:**
   ```bash
   # Get printer IP addresses
   ping printer1.local
   ping printer2.local
   ping printer3.local
   ```

2. **Install printer bridge:**
   ```bash
   # Download bridge software
   curl -O https://restaurant-print.cloud/download/restaurant-bridge-v2.1.0.tar.gz
   tar -xzf restaurant-bridge-v2.1.0.tar.gz
   cd restaurant-bridge
   
   # Install as system service
   sudo ./install.sh
   ```

3. **Configure bridge:**
   ```bash
   # Edit configuration
   sudo nano /etc/restaurant-bridge/config.json
   ```

   ```json
   {
     "restaurantId": "rest_abc123def456",
     "apiKey": "sk_live_xyz789abc123",
     "printers": [
       {
         "id": "kitchen_main",
         "name": "Main Kitchen",
         "ip": "192.168.1.100",
         "port": 9100,
         "type": "epson_thermal"
       },
       {
         "id": "bar_station",
         "name": "Bar Station", 
         "ip": "192.168.1.101",
         "port": 9100,
         "type": "epson_thermal"
       },
       {
         "id": "tandoor_station",
         "name": "Tandoor Station",
         "ip": "192.168.1.102", 
         "port": 9100,
         "type": "epson_thermal"
       }
     ],
     "pollingInterval": 5,
     "retryAttempts": 3,
     "heartbeatInterval": 60
   }
   ```

4. **Start bridge service:**
   ```bash
   sudo systemctl start restaurant-bridge
   sudo systemctl enable restaurant-bridge
   
   # Check status
   sudo systemctl status restaurant-bridge
   ```

#### POS App Side Setup:

1. **Update cloud printing configuration:**
   ```dart
   // In lib/services/cloud_restaurant_printing_service.dart
   static const String _cloudServiceUrl = 'https://restaurant-print.cloud/api/v1';
   static const String _apiKey = 'sk_live_xyz789abc123';
   static const String _restaurantId = 'rest_abc123def456';
   ```

2. **Initialize cloud printing service:**
   ```dart
   // In your main.dart or service initialization
   final cloudPrintingService = CloudRestaurantPrintingService(
     printingService: printingService,
     assignmentService: assignmentService,
   );
   
   await cloudPrintingService.initialize();
   ```

3. **Test the connection:**
   ```dart
   final result = await cloudPrintingService.sendOrderToRestaurantPrinters(
     order: testOrder,
     userId: 'admin',
     userName: 'Admin',
   );
   
   print('Cloud printing result: ${result['message']}');
   ```

### Method 2: Direct Port Forwarding

#### Router Configuration:

1. **Access your restaurant router:**
   - Open browser: `192.168.1.1` or `192.168.0.1`
   - Login with admin credentials

2. **Configure port forwarding:**
   ```
   External Port: 9101 → Internal IP: 192.168.1.100, Port: 9100 (Kitchen)
   External Port: 9102 → Internal IP: 192.168.1.101, Port: 9100 (Bar)
   External Port: 9103 → Internal IP: 192.168.1.102, Port: 9100 (Tandoor)
   ```

3. **Get your public IP:**
   ```bash
   curl ifconfig.me
   # Note your public IP address
   ```

#### POS App Configuration:

1. **Configure remote printers:**
   ```dart
   // Add remote printer configurations
   final remotePrinters = [
     PrinterConfiguration(
       name: 'Kitchen (Remote)',
       ipAddress: 'YOUR_PUBLIC_IP',
       port: 9101,
       type: PrinterType.wifi,
     ),
     PrinterConfiguration(
       name: 'Bar (Remote)',
       ipAddress: 'YOUR_PUBLIC_IP', 
       port: 9102,
       type: PrinterType.wifi,
     ),
     PrinterConfiguration(
       name: 'Tandoor (Remote)',
       ipAddress: 'YOUR_PUBLIC_IP',
       port: 9103, 
       type: PrinterType.wifi,
     ),
   ];
   ```

### Method 3: VPN Connection

#### VPN Server Setup:

1. **Set up VPN server at restaurant:**
   ```bash
   # Install OpenVPN
   sudo apt-get install openvpn
   
   # Generate certificates
   sudo ./easyrsa init-pki
   sudo ./easyrsa build-ca
   sudo ./easyrsa gen-req server nopass
   sudo ./easyrsa sign-req server server
   ```

2. **Configure VPN clients:**
   ```bash
   # Generate client certificates
   sudo ./easyrsa gen-req client1 nopass
   sudo ./easyrsa sign-req client client1
   ```

#### POS App Configuration:

1. **Connect to VPN before printing:**
   ```dart
   // Establish VPN connection
   await vpnService.connect('restaurant-vpn.ovpn');
   
   // Now print using local IP addresses
   await printingService.printToSpecificPrinter(
     '192.168.1.100:9100',
     ticketContent,
     PrinterType.wifi,
   );
   ```

---

## 🔍 Testing Your Setup

### Test 1: Cloud Connection
```bash
# Test cloud service connectivity
curl -X GET "https://restaurant-print.cloud/api/v1/health" \
  -H "Authorization: Bearer sk_live_xyz789abc123"
```

### Test 2: Printer Bridge
```bash
# Check bridge status
sudo systemctl status restaurant-bridge

# View bridge logs
sudo journalctl -u restaurant-bridge -f
```

### Test 3: Print Job
```bash
# Send test print job
curl -X POST "https://restaurant-print.cloud/api/v1/print-jobs/send" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk_live_xyz789abc123" \
  -d '{
    "orderId": "test-123",
    "restaurantId": "rest_abc123def456",
    "targetPrinterId": "kitchen_main",
    "content": "TEST PRINT JOB"
  }'
```

### Test 4: POS App Integration
1. Create a test order in POS app
2. Click "Send to Kitchen"
3. Check if order prints at restaurant
4. Verify order appears in cloud dashboard

---

## 🛠️ Troubleshooting

### ❌ "Cloud Connection Failed"
**Possible Causes:**
- Internet connection down
- Wrong API key or restaurant ID
- Cloud service maintenance

**Solutions:**
1. Check internet connectivity
2. Verify API credentials
3. Check cloud service status page
4. Try again in 5 minutes

### ❌ "Printer Bridge Not Responding"
**Possible Causes:**
- Bridge service stopped
- Wrong configuration
- Network issues

**Solutions:**
1. Restart bridge service: `sudo systemctl restart restaurant-bridge`
2. Check configuration file
3. Verify network connectivity
4. Check bridge logs: `sudo journalctl -u restaurant-bridge`

### ❌ "Orders Not Printing"
**Possible Causes:**
- Printer offline
- Wrong printer IP
- Print job stuck in queue

**Solutions:**
1. Check printer power and network
2. Verify printer IP addresses
3. Clear print queue
4. Restart printer bridge

### ❌ "Slow Printing"
**Possible Causes:**
- Network congestion
- Cloud service overload
- Large print jobs

**Solutions:**
1. Check internet speed
2. Optimize print job size
3. Use local printing as fallback
4. Contact cloud service support

---

## 📊 Monitoring & Maintenance

### Cloud Dashboard
- **URL:** https://restaurant-print.cloud/dashboard
- **Features:**
  - Real-time printer status
  - Print job history
  - Error logs
  - Performance metrics

### Local Monitoring
```bash
# Check bridge status
sudo systemctl status restaurant-bridge

# View recent logs
sudo journalctl -u restaurant-bridge --since "1 hour ago"

# Check printer connectivity
ping 192.168.1.100
ping 192.168.1.101
ping 192.168.1.102
```

### Automated Alerts
```bash
# Set up monitoring script
#!/bin/bash
if ! systemctl is-active --quiet restaurant-bridge; then
    echo "Bridge service down!" | mail -s "Printer Alert" admin@restaurant.com
fi
```

---

## 🔒 Security Considerations

### API Key Management
- Store API keys securely
- Rotate keys regularly
- Use environment variables
- Never commit keys to version control

### Network Security
- Use HTTPS for all connections
- Enable firewall rules
- Monitor for suspicious activity
- Keep software updated

### Data Privacy
- Encrypt print job data
- Implement access controls
- Audit print job history
- Comply with data regulations

---

## 💰 Cost Breakdown

### Cloud Service Plans:
- **Basic:** $29/month
  - Up to 5 printers
  - 1,000 print jobs/month
  - Email support

- **Pro:** $49/month
  - Up to 20 printers
  - 10,000 print jobs/month
  - Priority support
  - Advanced analytics

- **Enterprise:** $99/month
  - Unlimited printers
  - Unlimited print jobs
  - 24/7 support
  - Custom integrations

### Hardware Costs:
- **Printer Bridge Computer:** $200-500 (one-time)
- **Network Cables:** $50-100 (one-time)
- **Router Upgrade:** $100-200 (if needed)

---

## 🎉 Success Checklist

✅ Cloud service account created  
✅ Restaurant bridge installed and configured  
✅ POS app updated with cloud credentials  
✅ Test print job successful  
✅ All printers responding  
✅ Offline queue working  
✅ Monitoring alerts configured  
✅ Security measures implemented  
✅ Staff trained on new system  

---

## 📞 Support

### Cloud Service Support:
- **Email:** support@restaurant-print.cloud
- **Phone:** 1-800-PRINT-HELP
- **Live Chat:** Available on dashboard
- **Documentation:** https://docs.restaurant-print.cloud

### Community Resources:
- **Forum:** https://community.restaurant-print.cloud
- **YouTube:** Restaurant Print Tutorials
- **GitHub:** Open source components

---

**🎯 You're now ready to print from anywhere to your restaurant printers!** 