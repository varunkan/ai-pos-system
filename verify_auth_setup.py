#!/usr/bin/env python3
"""
Firebase Authentication Verification Script
Verifies that all authentication data is properly set up
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

def initialize_firebase():
    """Initialize Firebase with default credentials"""
    try:
        # Try to get default app
        firebase_admin.get_app()
        print("✅ Using default Firebase credentials")
    except ValueError:
        # Initialize with default credentials
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {
            'projectId': 'dineai-pos-system'
        })
        print("✅ Initialized Firebase with default credentials")

def verify_firebase_setup():
    """Verify Firebase authentication setup"""
    db = firestore.client()
    
    print("🔍 Verifying Firebase authentication setup...")
    print()
    
    # Check restaurants collection
    restaurants = list(db.collection('restaurants').stream())
    print(f"✅ Restaurant data found: {len(restaurants)} restaurants")
    
    for restaurant in restaurants:
        data = restaurant.to_dict()
        print(f"   Name: {data.get('name')}")
        print(f"   Email: {data.get('email')}")
        print(f"   Admin User: {data.get('adminUserId')}")
    
    print()
    
    # Check global restaurants collection
    global_restaurants = list(db.collection('global_restaurants').stream())
    print(f"✅ Global restaurant registration found: {len(global_restaurants)} restaurants")
    
    # Check tenants collection
    tenants = list(db.collection('tenants').stream())
    print(f"✅ Tenant structures found: {len(tenants)} tenants")
    
    total_users = 0
    total_categories = 0
    total_menu_items = 0
    total_orders = 0
    
    if tenants:
        for tenant in tenants:
            tenant_id = tenant.id
            print(f"   Tenant: {tenant_id}")
            
            # Check users in this tenant
            users = list(tenant.reference.collection('users').stream())
            total_users += len(users)
            print(f"     Users: {len(users)}")
            for user in users:
                user_data = user.to_dict()
                print(f"       - {user_data.get('name')} ({user_data.get('role')}) - ID: {user_data.get('id')}")
            
            # Check categories in this tenant
            categories = list(tenant.reference.collection('categories').stream())
            total_categories += len(categories)
            print(f"     Categories: {len(categories)}")
            
            # Check menu items in this tenant
            menu_items = list(tenant.reference.collection('menu_items').stream())
            total_menu_items += len(menu_items)
            print(f"     Menu Items: {len(menu_items)}")
            
            # Check orders in this tenant
            orders = list(tenant.reference.collection('orders').stream())
            total_orders += len(orders)
            print(f"     Orders: {len(orders)}")
            print()
    else:
        print("   ⚠️  No tenant structures found - this may indicate an issue with the setup")
        print()
    
    print("🎯 Authentication Setup Summary:")
    print("================================")
    print(f"✅ Restaurant data created: {len(restaurants)} restaurants")
    print(f"✅ Global restaurant registration created: {len(global_restaurants)} restaurants")
    print(f"✅ Tenant users created: {total_users} total users")
    print(f"✅ Sample data available: {total_categories} categories, {total_menu_items} menu items, {total_orders} orders")
    
    print()
    print("📱 Ready for POS app login!")
    print("Use these credentials:")
    print("   Restaurant Email: demo@restaurant.com")
    print("   User ID: admin")
    print("   Password: admin123")
    print("   PIN: 1234")
    
    # Check for specific restaurants
    print()
    print("🔍 Available Restaurants for Testing:")
    print("=====================================")
    
    test_restaurants = [
        {'email': 'demo@restaurant.com', 'admin': 'admin', 'password': 'admin123'},
        {'email': 'test1@restaurant.com', 'admin': 'admin1', 'password': 'admin123'},
        {'email': 'test2@restaurant.com', 'admin': 'admin2', 'password': 'admin123'},
        {'email': 'pizza@restaurant.com', 'admin': 'pizza_admin', 'password': 'pizza123'},
        {'email': 'sushi@restaurant.com', 'admin': 'sushi_admin', 'password': 'sushi123'},
    ]
    
    for restaurant in test_restaurants:
        found = any(r.to_dict().get('email') == restaurant['email'] for r in restaurants)
        status = "✅" if found else "❌"
        print(f"{status} {restaurant['email']} - Admin: {restaurant['admin']}")

def main():
    """Main function"""
    try:
        initialize_firebase()
        verify_firebase_setup()
    except Exception as e:
        print(f"❌ Error verifying Firebase setup: {e}")
        raise

if __name__ == "__main__":
    main() 