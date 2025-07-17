# 🖨️ Printer Assignment System Guide

## Overview

The POS system now includes a comprehensive printer assignment system that allows you to:
- **Assign specific menu items** to specific printers
- **Assign categories** to printers (items inherit from categories)
- **Send orders to multiple printers** automatically based on assignments
- **View real-time printer status** and test connections

## How It Works

### 1. **Printer Discovery & Configuration**
- The system automatically discovers network printers on startup
- Printers are saved to the database with their IP addresses and ports
- You can manually configure additional printers if needed

### 2. **Assignment Priority System**
- **Menu Item Assignments** (Highest Priority): Specific dishes assigned to specific printers
- **Category Assignments** (Lower Priority): All items in a category go to the assigned printer
- **Default Printer** (Fallback): Items with no assignments go to the default printer

### 3. **Order Processing Flow**
When you click "Send to Kitchen":
1. System analyzes each item in the order
2. Checks for specific menu item assignments first
3. Falls back to category assignments if no specific assignment exists
4. Groups items by their assigned printers
5. Sends kitchen tickets to each printer with only their assigned items

## Step-by-Step Usage

### Step 1: Discover Printers
1. Start the POS app
2. Go to **Admin Panel** → **Printer Assignment**
3. The system will automatically discover network printers
4. You should see your printers listed with their IP addresses

### Step 2: Create Assignments
1. In the **Printer Assignment** screen, you'll see two tabs:
   - **Assign Categories**: Assign entire menu categories to printers
   - **Assign Menu Items**: Assign specific dishes to printers

2. **For Categories** (Recommended first step):
   - Click "Assign Categories"
   - Select a category (e.g., "Appetizers")
   - Choose which printer should handle all appetizers
   - Click "Assign"

3. **For Specific Items** (Fine-tuning):
   - Click "Assign Menu Items"
   - Select a specific dish (e.g., "Tandoori Chicken")
   - Choose which printer should handle this specific item
   - Click "Assign"

### Step 3: Test Your Setup
1. Click "Test All Printers" to verify connections
2. Create a test order with items from different categories
3. Click "Send to Kitchen"
4. Verify that items are printed on their assigned printers

## Example Restaurant Setup

### Kitchen Station Layout:
```
🍳 Main Kitchen (192.168.0.141)
├── Appetizers
├── Soups
└── Salads

🔥 Grill Station (192.168.0.147)
├── Tandoori Items
├── Grilled Dishes
└── BBQ Items

🍹 Bar Station (192.168.0.233)
├── Beverages
├── Cocktails
└── Desserts
```

### Assignment Strategy:
1. **Start with Categories**:
   - Assign "Appetizers" category → Main Kitchen printer
   - Assign "Tandoori" category → Grill Station printer  
   - Assign "Beverages" category → Bar Station printer

2. **Fine-tune with Specific Items**:
   - "Tandoori Chicken" → Grill Station (overrides category)
   - "Caesar Salad" → Main Kitchen (overrides category)
   - "Mango Lassi" → Bar Station (overrides category)

## Order Flow Example

**Customer Order**:
- 1x Samosas (Appetizers category)
- 1x Tandoori Chicken (Tandoori category)
- 1x Mango Lassi (Beverages category)

**System Processing**:
1. **Samosas** → Main Kitchen (category assignment)
2. **Tandoori Chicken** → Grill Station (category assignment)
3. **Mango Lassi** → Bar Station (category assignment)

**Result**: 3 separate kitchen tickets printed simultaneously at 3 different stations.

## Key Features

### ✅ **Real-time Status**
- View which printers are online/offline
- See connection status and IP addresses
- Test individual printer connections

### ✅ **Flexible Assignment System**
- Assign by category for broad organization
- Override with specific item assignments
- Multiple items can be assigned to the same printer

### ✅ **Smart Fallbacks**
- Items without assignments go to a default printer
- System continues working even if some printers are offline
- Detailed error reporting for troubleshooting

### ✅ **Multi-language Kitchen Tickets**
- Tickets include order details, table numbers, and timing
- Special instructions are included
- Urgent orders are clearly marked

## Troubleshooting

### Problem: Printers Not Discovered
**Solution**: 
- Ensure printers are on the same network
- Check printer IP addresses are in 192.168.x.x range
- Restart the POS app to trigger new discovery

### Problem: Items Not Printing to Assigned Printer
**Solution**:
- Verify printer assignments in Admin Panel
- Check if printer is online (green status)
- Test printer connection individually
- Check if item has a specific assignment overriding category

### Problem: Kitchen Tickets Not Printing
**Solution**:
- Verify printer is powered on and connected to network
- Check printer has paper loaded
- Test printer connection from assignment screen
- Review printer IP address settings

## Advanced Tips

### 🎯 **Efficient Assignment Strategy**
1. **Start broad**: Assign main categories first
2. **Get specific**: Override individual items as needed
3. **Test frequently**: Use test orders to verify setup
4. **Monitor performance**: Check which printers are busiest

### 🔧 **Performance Optimization**
- Keep printers on a fast, stable network
- Use wired connections when possible
- Regularly test printer connections
- Keep printer firmware updated

### 📊 **Operational Benefits**
- **Faster service**: Kitchen staff get orders immediately
- **Better organization**: Each station gets only relevant items
- **Reduced errors**: Clear separation of responsibilities
- **Improved workflow**: Parallel food preparation

## API Integration

The system provides hooks for integration with external systems:

```dart
// Get assignment for a menu item
final assignment = printerAssignmentService.getAssignmentForMenuItem(
  menuItemId, 
  categoryId
);

// Print order to assigned printers
final results = await printingService.printOrderSegregated(
  order, 
  itemsByPrinter
);
```

## Support

For additional help:
1. Check the **Admin Panel** → **Printer Assignment** screen
2. Use the "Test All Printers" function
3. Review printer connection logs
4. Verify network configuration

---

**🎉 Your restaurant now has professional-grade kitchen ticket routing!**

Each order automatically goes to the right stations, improving efficiency and reducing errors. The system works seamlessly in the background, ensuring your kitchen staff always know what to prepare. 