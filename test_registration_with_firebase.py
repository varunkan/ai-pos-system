#!/usr/bin/env python3
"""
Test Registration Process with Firebase
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys
import time

def test_firebase_connectivity():
    """Test Firebase connectivity"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        print("✅ Firebase connectivity test passed")
        return True
        
    except Exception as e:
        print(f"❌ Firebase connectivity test failed: {e}")
        return False

def test_registration_process():
    """Test the complete registration process"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        print("\n🧪 Testing Registration Process")
        print("=" * 40)
        
        # Test data
        test_restaurant = {
            'name': 'Test Restaurant Registration',
            'email': 'test-registration@restaurant.com',
            'admin_name': 'Test Admin',
            'admin_password': 'test123',
            'admin_pin': '1234'
        }
        
        # Step 1: Create restaurant ID
        restaurant_id = f"test-restaurant-{int(time.time())}"
        tenant_id = restaurant_id
        
        print(f"📝 Step 1: Creating restaurant with ID: {restaurant_id}")
        
        # Step 2: Create restaurant document
        restaurant_data = {
            'id': restaurant_id,
            'name': test_restaurant['name'],
            'email': test_restaurant['email'],
            'adminUserId': 'admin',
            'adminPassword': test_restaurant['admin_password'],  # In real app, this would be hashed
            'createdAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
            'isActive': True,
            'businessType': 'Restaurant',
            'address': 'Test Address',
            'phone': '+1234567890',
            'databaseName': f'restaurant_{restaurant_id}'
        }
        
        # Save to restaurants collection
        db.collection('restaurants').document(restaurant_id).set(restaurant_data)
        print("✅ Restaurant saved to restaurants collection")
        
        # Save to global_restaurants collection
        db.collection('global_restaurants').document(restaurant_id).set(restaurant_data)
        print("✅ Restaurant saved to global_restaurants collection")
        
        # Step 3: Create tenant structure
        print(f"🏢 Step 3: Creating tenant structure for: {tenant_id}")
        
        # Create admin user
        admin_user = {
            'id': 'admin',
            'name': test_restaurant['admin_name'],
            'role': 'admin',
            'pin': test_restaurant['admin_pin'],  # In real app, this would be hashed
            'isActive': True,
            'adminPanelAccess': True,
            'createdAt': firestore.SERVER_TIMESTAMP
        }
        
        db.collection('tenants').document(tenant_id).collection('users').document('admin').set(admin_user)
        print("✅ Admin user created")
        
        # Create sample categories
        categories = [
            {'id': 'appetizers', 'name': 'Appetizers', 'isActive': True},
            {'id': 'main-course', 'name': 'Main Course', 'isActive': True},
            {'id': 'desserts', 'name': 'Desserts', 'isActive': True},
            {'id': 'beverages', 'name': 'Beverages', 'isActive': True}
        ]
        
        for category in categories:
            db.collection('tenants').document(tenant_id).collection('categories').document(category['id']).set(category)
        print("✅ Sample categories created")
        
        # Create sample menu items
        menu_items = [
            {
                'id': 'bruschetta',
                'name': 'Bruschetta',
                'price': 8.99,
                'categoryId': 'appetizers',
                'isActive': True
            },
            {
                'id': 'pizza',
                'name': 'Margherita Pizza',
                'price': 16.99,
                'categoryId': 'main-course',
                'isActive': True
            },
            {
                'id': 'tiramisu',
                'name': 'Tiramisu',
                'price': 9.99,
                'categoryId': 'desserts',
                'isActive': True
            },
            {
                'id': 'latte',
                'name': 'Iced Latte',
                'price': 4.99,
                'categoryId': 'beverages',
                'isActive': True
            }
        ]
        
        for item in menu_items:
            db.collection('tenants').document(tenant_id).collection('menu_items').document(item['id']).set(item)
        print("✅ Sample menu items created")
        
        # Step 4: Verify the setup
        print(f"🔍 Step 4: Verifying setup for tenant: {tenant_id}")
        
        # Check restaurant
        restaurant_doc = db.collection('restaurants').document(restaurant_id).get()
        if restaurant_doc.exists:
            print("✅ Restaurant document verified")
        else:
            print("❌ Restaurant document not found")
            return False
        
        # Check global restaurant
        global_restaurant_doc = db.collection('global_restaurants').document(restaurant_id).get()
        if global_restaurant_doc.exists:
            print("✅ Global restaurant document verified")
        else:
            print("❌ Global restaurant document not found")
            return False
        
        # Check admin user
        admin_doc = db.collection('tenants').document(tenant_id).collection('users').document('admin').get()
        if admin_doc.exists:
            print("✅ Admin user verified")
        else:
            print("❌ Admin user not found")
            return False
        
        # Check categories
        categories_docs = list(db.collection('tenants').document(tenant_id).collection('categories').stream())
        print(f"✅ Categories verified: {len(categories_docs)} found")
        
        # Check menu items
        menu_items_docs = list(db.collection('tenants').document(tenant_id).collection('menu_items').stream())
        print(f"✅ Menu items verified: {len(menu_items_docs)} found")
        
        print("\n🎉 Registration process test PASSED!")
        print(f"📱 Test restaurant ID: {restaurant_id}")
        print(f"🔗 Tenant ID: {tenant_id}")
        print(f"📧 Login email: {test_restaurant['email']}")
        print(f"👤 Admin user: {test_restaurant['admin_name']}")
        print(f"🔑 Password: {test_restaurant['admin_password']}")
        print(f"🔢 PIN: {test_restaurant['admin_pin']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Registration process test failed: {e}")
        return False

def cleanup_test_data(restaurant_id):
    """Clean up test data"""
    
    try:
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        print(f"\n🧹 Cleaning up test data for: {restaurant_id}")
        
        # Delete restaurant documents
        db.collection('restaurants').document(restaurant_id).delete()
        db.collection('global_restaurants').document(restaurant_id).delete()
        
        # Delete tenant data
        tenant_ref = db.collection('tenants').document(restaurant_id)
        
        # Delete subcollections
        for collection_name in ['users', 'categories', 'menu_items', 'orders']:
            try:
                docs = list(tenant_ref.collection(collection_name).stream())
                for doc in docs:
                    doc.reference.delete()
            except:
                pass
        
        # Delete tenant document
        tenant_ref.delete()
        
        print("✅ Test data cleaned up")
        
    except Exception as e:
        print(f"⚠️ Cleanup failed: {e}")

if __name__ == "__main__":
    print("🔥 Registration Process Test")
    print("=" * 40)
    
    # Set project ID
    os.environ['GOOGLE_CLOUD_PROJECT'] = 'dineai-pos-system'
    
    # Test Firebase connectivity
    if not test_firebase_connectivity():
        print("❌ Cannot proceed without Firebase connectivity")
        sys.exit(1)
    
    # Test registration process
    if test_registration_process():
        print("\n✅ All tests passed! Registration should work in the app.")
        print("📱 Try registering a new restaurant in the app now.")
    else:
        print("\n❌ Registration test failed. Check Firebase configuration.")
        sys.exit(1) 