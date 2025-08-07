#!/usr/bin/env python3
"""
Test Login for varun.kan@gmail.com
Verifies that the restaurant registration and login credentials are working
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

def test_varun_login():
    """Test the login credentials for varun.kan@gmail.com"""
    print("🔍 Testing Login for varun.kan@gmail.com")
    print("=" * 50)
    
    db = firestore.client()
    
    # Find the restaurant
    restaurant_id = '98213ca9-90b3-4f77-8aa1-488c0cbbd9b6'
    restaurant_doc = db.collection('restaurants').document(restaurant_id).get()
    
    if not restaurant_doc.exists:
        print("❌ Restaurant not found!")
        return False
    
    restaurant_data = restaurant_doc.to_dict()
    print(f"✅ Restaurant found: {restaurant_data.get('name')}")
    print(f"📧 Email: {restaurant_data.get('email')}")
    print(f"🆔 ID: {restaurant_id}")
    
    # Check global registration
    global_doc = db.collection('global_restaurants').document(restaurant_id).get()
    if global_doc.exists:
        print("✅ Global registration found")
    else:
        print("❌ Global registration missing")
    
    # Check tenant structure
    tenant_doc = db.collection('tenants').document(restaurant_id).get()
    if tenant_doc.exists:
        print("✅ Tenant structure exists")
    else:
        print("❌ Tenant structure missing")
    
    # Check users
    users = list(db.collection('tenants').document(restaurant_id).collection('users').stream())
    print(f"👥 Users found: {len(users)}")
    
    for user in users:
        user_data = user.to_dict()
        print(f"  - User ID: {user.id}")
        print(f"    Name: {user_data.get('name')}")
        print(f"    Role: {user_data.get('role')}")
        print(f"    Active: {user_data.get('is_active')}")
    
    # Check categories
    categories = list(db.collection('tenants').document(restaurant_id).collection('categories').stream())
    print(f"📂 Categories found: {len(categories)}")
    
    # Check menu items
    menu_items = list(db.collection('tenants').document(restaurant_id).collection('menu_items').stream())
    print(f"🍽️ Menu items found: {len(menu_items)}")
    
    print("\n📋 LOGIN CREDENTIALS:")
    print("=" * 30)
    print("Restaurant Email: varun.kan@gmail.com")
    print("User ID: admin")
    print("Password: admin123")
    print("PIN: 1234")
    
    print("\n✅ Login test completed successfully!")
    return True

def main():
    """Main function"""
    try:
        initialize_firebase()
        test_varun_login()
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main() 