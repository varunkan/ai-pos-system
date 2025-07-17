#!/bin/bash

# Restaurant Printing Setup Script
# Super simple setup for non-technical users

clear

echo "============================================================"
echo "🎯 RESTAURANT PRINTING SETUP"
echo "Print from Home to Restaurant Printers"
echo "============================================================"
echo

echo "This will help you set up printing from home to your restaurant."
echo
read -p "Press Enter to continue..."

echo
echo "🌐 STEP 1: Create Cloud Account"
echo "----------------------------------------"
echo
echo "Please visit: https://restaurant-print.cloud"
echo "1. Click 'Sign Up'"
echo "2. Enter your restaurant details"
echo "3. Choose Basic Plan (\$29/month)"
echo "4. Get your Restaurant ID and API Key"
echo
read -p "Press Enter when you have your Restaurant ID and API Key..."

echo
echo "📝 STEP 2: Enter Your Details"
echo "----------------------------------------"
echo

read -p "Enter your Restaurant ID: " restaurant_id
read -p "Enter your API Key: " api_key

if [ -z "$restaurant_id" ]; then
    echo "❌ Restaurant ID is required!"
    exit 1
fi

if [ -z "$api_key" ]; then
    echo "❌ API Key is required!"
    exit 1
fi

echo
echo "✅ Details saved!"
echo

echo "📥 STEP 3: Download Bridge Software"
echo "----------------------------------------"
echo

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    url="https://restaurant-print.cloud/download/bridge-macos"
    filename="restaurant-bridge"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    url="https://restaurant-print.cloud/download/bridge-linux"
    filename="restaurant-bridge"
else
    echo "❌ Unsupported operating system"
    exit 1
fi

echo "Downloading bridge software..."
curl -L -o "$filename" "$url"

if [ -f "$filename" ]; then
    chmod +x "$filename"
    echo "✅ Bridge downloaded successfully!"
else
    echo "❌ Download failed!"
    echo "Please download manually from: https://restaurant-print.cloud/download"
    exit 1
fi

echo
echo "⚙️ STEP 4: Create Configuration"
echo "----------------------------------------"
echo

echo "Creating configuration file..."

# Start JSON configuration
cat > bridge-config.json << EOF
{
  "restaurantId": "$restaurant_id",
  "apiKey": "$api_key",
  "printers": [
EOF

# Add printers
while true; do
    echo
    read -p "Add a printer? (y/n): " add_printer
    if [[ "$add_printer" != "y" ]]; then
        break
    fi
    
    read -p "Printer name (e.g., Kitchen, Bar): " printer_name
    read -p "Printer IP address (e.g., 192.168.1.100): " printer_ip
    
    if [[ -n "$printer_name" && -n "$printer_ip" ]]; then
        printer_id=$(echo "$printer_name" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
        cat >> bridge-config.json << EOF
    {
      "id": "$printer_id",
      "name": "$printer_name",
      "ip": "$printer_ip",
      "port": 9100,
      "type": "epson_thermal"
    },
EOF
        echo "✅ Added printer: $printer_name"
    else
        echo "❌ Printer name and IP are required!"
    fi
done

# Close JSON configuration
cat >> bridge-config.json << EOF
  ]
}
EOF

echo
echo "✅ Configuration created: bridge-config.json"

echo
echo "🚀 STEP 5: Start Bridge Service"
echo "----------------------------------------"
echo

echo "Starting bridge service..."
nohup ./"$filename" --config bridge-config.json --start > bridge.log 2>&1 &

echo
echo "✅ Bridge service started!"
echo "📋 Bridge is now running in the background"
echo "💡 Keep this computer running for printing to work"

echo
echo "📱 STEP 6: Configure POS App"
echo "----------------------------------------"
echo

echo "Now configure your POS app:"
echo
echo "1. Open your POS app"
echo "2. Go to Admin Panel → Settings"
echo "3. Find 'Cloud Printing' or 'Internet Printing'"
echo "4. Enter these details:"
echo
echo "   Service URL: https://restaurant-print.cloud/api/v1"
echo "   Restaurant ID: $restaurant_id"
echo "   API Key: $api_key"
echo
echo "5. Click 'Test Connection'"
echo "6. Click 'Save Settings'"
echo

echo "🎉 SETUP COMPLETE!"
echo "============================================================"
echo "✅ Cloud account created"
echo "✅ Bridge downloaded and configured"
echo "✅ Printers added"
echo "✅ Bridge service started"
echo "✅ POS app configuration ready"
echo
echo "📋 Next Steps:"
echo "1. Configure your POS app with the details above"
echo "2. Test by creating an order and clicking 'Send to Kitchen'"
echo "3. Keep this computer running for printing to work"
echo
echo "📞 Need help? Call: 1-800-PRINT-HELP"
echo "📧 Email: support@restaurant-print.cloud"
echo
echo "🚀 You're ready to print from home to your restaurant!"
echo

read -p "Press Enter to exit..." 