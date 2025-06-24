# App Store Screenshots Guide

## 📱 Required Screenshot Sizes

### iPhone Screenshots (Required)
1. **iPhone 6.7"** (1290 x 2796 pixels) - iPhone 14 Pro Max
2. **iPhone 6.5"** (1242 x 2688 pixels) - iPhone 11 Pro Max  
3. **iPhone 5.5"** (1242 x 2208 pixels) - iPhone 8 Plus

## 🎯 Screenshots to Take

### Screenshot 1: Main Dashboard
**Show:** Clean, professional main interface with order management
**Features to highlight:**
- Order creation buttons
- Professional layout
- Clear navigation

### Screenshot 2: Order Management  
**Show:** The unified order creation/edit screen
**Features to highlight:**
- Side-by-side layout (order panel + menu)
- Item selection and quantity controls
- Professional action buttons

### Screenshot 3: Menu Management
**Show:** Category and menu item management
**Features to highlight:**
- Category organization
- Menu item details
- Easy editing interface

### Screenshot 4: Kitchen View
**Show:** Kitchen screen with order tracking
**Features to highlight:**
- Order status tracking
- Clear order details
- Professional kitchen interface

### Screenshot 5: Receipt Preview
**Show:** Professional receipt generation
**Features to highlight:**
- Clean receipt format
- Order details
- Professional branding

## 📷 How to Take Screenshots

### Method 1: Using iOS Simulator (Recommended)
1. Open Xcode
2. Go to Window → Devices and Simulators
3. Select iOS Simulators tab
4. Choose device size (iPhone 14 Pro Max for 6.7")
5. Click "Open Simulator"
6. Run your app: `flutter run -d [simulator_id]`
7. Navigate to each screen and take screenshots

### Method 2: Using Physical Device
1. Connect iPhone to Mac
2. Run app on device: `flutter run -d [device_id]`
3. Take screenshots on device
4. Transfer to Mac via AirDrop or Photos

## 🎨 Screenshot Tips

### Content Guidelines
- ✅ Use real, professional-looking data
- ✅ Show the app in use with realistic content
- ✅ Ensure text is readable
- ✅ Show key features clearly
- ❌ No placeholder text like "Lorem ipsum"
- ❌ No debug information visible
- ❌ No personal information

### Visual Guidelines
- Use consistent lighting and contrast
- Ensure UI elements are clearly visible
- Show the app's value proposition
- Make screenshots look professional
- Use the same device orientation consistently

## 📂 Screenshot Organization

Save screenshots with clear names:
- `01_main_dashboard_6.7.png`
- `02_order_management_6.7.png`
- `03_menu_management_6.7.png`
- `04_kitchen_view_6.7.png`
- `05_receipt_preview_6.7.png`

Repeat for each required size (6.7", 6.5", 5.5")

## 🚀 Quick Screenshot Commands

```bash
# List available simulators
flutter devices

# Run on specific simulator
flutter run -d "iPhone 14 Pro Max"

# Run on physical device
flutter run -d [your_device_id]
``` 