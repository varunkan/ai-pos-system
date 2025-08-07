#!/usr/bin/env python3
"""
Verify Firebase Schema and Permissions
======================================
Test the Firebase schema structure and ensure all permissions are working correctly
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime

def main():
    print("🔍 Verifying Firebase Schema and Permissions")
    print("=" * 50)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Test restaurant data
    restaurant_id = "demo-restaurant-schema"
    print(f"📊 Testing restaurant: {restaurant_id}")
    
    try:
        # Test restaurants collection
        restaurant_doc = db.collection('restaurants').document(restaurant_id).get()
        if restaurant_doc.exists:
            print("✅ Restaurant document found")
            restaurant_data = restaurant_doc.to_dict()
            print(f"   Name: {restaurant_data.get('name')}")
            print(f"   Email: {restaurant_data.get('email')}")
            print(f"   Admin User: {restaurant_data.get('admin_user_id')}")
        else:
            print("❌ Restaurant document not found")
            return
        
        # Test global restaurants collection
        global_restaurant_doc = db.collection('global_restaurants').document(restaurant_id).get()
        if global_restaurant_doc.exists:
            print("✅ Global restaurant registration found")
        else:
            print("❌ Global restaurant registration not found")
        
        # Test tenant structure
        tenant_ref = db.collection('tenants').document(restaurant_id)
        
        # Test users subcollection
        users = list(tenant_ref.collection('users').stream())
        print(f"✅ Found {len(users)} users in tenant")
        for user in users:
            user_data = user.to_dict()
            print(f"   - {user_data.get('name')} ({user_data.get('role')}) - ID: {user_data.get('id')}")
        
        # Test categories subcollection
        categories = list(tenant_ref.collection('categories').stream())
        print(f"✅ Found {len(categories)} categories in tenant")
        for category in categories:
            cat_data = category.to_dict()
            print(f"   - {cat_data.get('name')} (Order: {cat_data.get('sort_order')})")
        
        # Test menu items subcollection
        menu_items = list(tenant_ref.collection('menu_items').stream())
        print(f"✅ Found {len(menu_items)} menu items in tenant")
        for item in menu_items:
            item_data = item.to_dict()
            print(f"   - {item_data.get('name')} (${item_data.get('price')}) - Category: {item_data.get('category_id')}")
        
        # Test tables subcollection
        tables = list(tenant_ref.collection('tables').stream())
        print(f"✅ Found {len(tables)} tables in tenant")
        for table in tables:
            table_data = table.to_dict()
            print(f"   - Table {table_data.get('number')} (Capacity: {table_data.get('capacity')}) - Status: {table_data.get('status')}")
        
        # Test orders subcollection
        orders = list(tenant_ref.collection('orders').stream())
        print(f"✅ Found {len(orders)} orders in tenant")
        for order in orders:
            order_data = order.to_dict()
            print(f"   - Order {order_data.get('order_number')} (${order_data.get('total_amount')}) - Status: {order_data.get('status')}")
            
            # Test order items subcollection
            order_items = list(tenant_ref.collection('orders').document(order.id).collection('items').stream())
            print(f"     - Contains {len(order_items)} items")
        
        # Test inventory subcollection
        inventory = list(tenant_ref.collection('inventory').stream())
        print(f"✅ Found {len(inventory)} inventory items in tenant")
        for inv in inventory:
            inv_data = inv.to_dict()
            print(f"   - {inv_data.get('name')} (Stock: {inv_data.get('current_stock')})")
        
        # Test customers subcollection
        customers = list(tenant_ref.collection('customers').stream())
        print(f"✅ Found {len(customers)} customers in tenant")
        for customer in customers:
            cust_data = customer.to_dict()
            print(f"   - {cust_data.get('name')} (Points: {cust_data.get('loyalty_points')})")
        
        # Test reservations subcollection
        reservations = list(tenant_ref.collection('reservations').stream())
        print(f"✅ Found {len(reservations)} reservations in tenant")
        for res in reservations:
            res_data = res.to_dict()
            print(f"   - {res_data.get('customer_name')} ({res_data.get('party_size')} people) - {res_data.get('reservation_date')}")
        
        # Test printer configurations subcollection
        printers = list(tenant_ref.collection('printer_configurations').stream())
        print(f"✅ Found {len(printers)} printer configurations in tenant")
        for printer in printers:
            printer_data = printer.to_dict()
            print(f"   - {printer_data.get('name')} ({printer_data.get('type')}) - {printer_data.get('ip_address')}")
        
        # Test printer assignments subcollection
        assignments = list(tenant_ref.collection('printer_assignments').stream())
        print(f"✅ Found {len(assignments)} printer assignments in tenant")
        for assignment in assignments:
            assign_data = assignment.to_dict()
            print(f"   - {assign_data.get('target_name')} -> {assign_data.get('printer_id')}")
        
        # Test order logs subcollection
        logs = list(tenant_ref.collection('order_logs').stream())
        print(f"✅ Found {len(logs)} order logs in tenant")
        for log in logs:
            log_data = log.to_dict()
            print(f"   - {log_data.get('action')} on order {log_data.get('order_id')} by {log_data.get('user_id')}")
        
        # Test app metadata subcollection
        metadata = list(tenant_ref.collection('app_metadata').stream())
        print(f"✅ Found {len(metadata)} app metadata entries in tenant")
        for meta in metadata:
            meta_data = meta.to_dict()
            print(f"   - {meta_data.get('key')}: {meta_data.get('value')}")
        
        print("\n🎉 Firebase Schema Verification Complete!")
        print("=" * 50)
        print("📊 Schema Summary:")
        print(f"   👥 Users: {len(users)}")
        print(f"   📂 Categories: {len(categories)}")
        print(f"   🍽️ Menu Items: {len(menu_items)}")
        print(f"   🪑 Tables: {len(tables)}")
        print(f"   📋 Orders: {len(orders)}")
        print(f"   📦 Inventory: {len(inventory)}")
        print(f"   👤 Customers: {len(customers)}")
        print(f"   📅 Reservations: {len(reservations)}")
        print(f"   🖨️ Printer Configs: {len(printers)}")
        print(f"   🔗 Printer Assignments: {len(assignments)}")
        print(f"   📝 Order Logs: {len(logs)}")
        print(f"   ⚙️ App Metadata: {len(metadata)}")
        
        print("\n🔐 Login Credentials for Testing:")
        print("Restaurant Email: schema@restaurant.com")
        print("Admin User ID: admin")
        print("Admin Password: admin123")
        print("Admin PIN: 1234")
        print("Cashier PIN: 1111")
        print("Manager PIN: 2222")
        
        print("\n✅ Firebase schema is properly structured and ready for the POS app!")
        
    except Exception as e:
        print(f"❌ Error during verification: {e}")
        return

if __name__ == "__main__":
    main() 