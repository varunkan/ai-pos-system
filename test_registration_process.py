#!/usr/bin/env python3
"""
Test Restaurant Registration Process
Monitors the registration process and identifies issues
"""

import firebase_admin
from firebase_admin import credentials, firestore
import time
import os
import sys

def monitor_firebase_state():
    """Monitor current Firebase state"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        print("📊 Current Firebase State:")
        print("=" * 40)
        
        # Check collections
        collections = ['restaurants', 'global_restaurants', 'tenants', 'devices']
        
        for collection_name in collections:
            try:
                docs = list(db.collection(collection_name).stream())
                print(f"   {collection_name}: {len(docs)} documents")
                
                # Show first few documents
                for i, doc in enumerate(docs[:3]):
                    data = doc.to_dict()
                    print(f"     {i+1}. {doc.id}: {list(data.keys())}")
                    
            except Exception as e:
                print(f"   {collection_name}: Error - {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error monitoring Firebase: {e}")
        return False

def test_restaurant_creation():
    """Test creating a restaurant manually"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        print("\n🧪 Testing Restaurant Creation:")
        print("=" * 40)
        
        # Test restaurant data
        restaurant_data = {
            'name': 'Test Restaurant',
            'email': 'test@restaurant.com',
            'phone': '+1234567890',
            'address': '123 Test Street',
            'created_at': firestore.SERVER_TIMESTAMP,
            'status': 'active'
        }
        
        # Create restaurant
        print("📝 Creating test restaurant...")
        restaurant_ref = db.collection('restaurants').document('test-restaurant-123')
        restaurant_ref.set(restaurant_data)
        print("✅ Restaurant created in 'restaurants' collection")
        
        # Create global restaurant
        print("📝 Creating global restaurant record...")
        global_restaurant_data = {
            'restaurant_id': 'test-restaurant-123',
            'name': 'Test Restaurant',
            'email': 'test@restaurant.com',
            'created_at': firestore.SERVER_TIMESTAMP,
            'status': 'active'
        }
        global_ref = db.collection('global_restaurants').document('test-restaurant-123')
        global_ref.set(global_restaurant_data)
        print("✅ Global restaurant record created")
        
        # Create tenant structure
        print("📝 Creating tenant structure...")
        tenant_ref = db.collection('tenants').document('test-restaurant-123')
        tenant_ref.set({
            'restaurant_id': 'test-restaurant-123',
            'name': 'Test Restaurant',
            'created_at': firestore.SERVER_TIMESTAMP,
            'status': 'active'
        })
        
        # Create admin user
        admin_user_data = {
            'id': 'admin',
            'name': 'Admin User',
            'email': 'admin@test.com',
            'role': 'admin',
            'pin': '1234',
            'password_hash': 'test_hash',
            'created_at': firestore.SERVER_TIMESTAMP,
            'status': 'active'
        }
        
        user_ref = tenant_ref.collection('users').document('admin')
        user_ref.set(admin_user_data)
        print("✅ Admin user created in tenant")
        
        # Create sample categories
        categories = ['Appetizers', 'Main Course', 'Desserts', 'Beverages']
        for i, category_name in enumerate(categories):
            category_data = {
                'id': f'cat_{i+1}',
                'name': category_name,
                'created_at': firestore.SERVER_TIMESTAMP,
                'status': 'active'
            }
            cat_ref = tenant_ref.collection('categories').document(f'cat_{i+1}')
            cat_ref.set(category_data)
        
        print("✅ Sample categories created")
        
        # Create sample menu items
        menu_items = [
            {'name': 'Bruschetta', 'price': 8.99, 'category_id': 'cat_1'},
            {'name': 'Margherita Pizza', 'price': 16.99, 'category_id': 'cat_2'},
            {'name': 'Tiramisu', 'price': 9.99, 'category_id': 'cat_3'},
            {'name': 'Iced Latte', 'price': 4.99, 'category_id': 'cat_4'}
        ]
        
        for i, item in enumerate(menu_items):
            item_data = {
                'id': f'item_{i+1}',
                'name': item['name'],
                'price': item['price'],
                'category_id': item['category_id'],
                'created_at': firestore.SERVER_TIMESTAMP,
                'status': 'active'
            }
            item_ref = tenant_ref.collection('menu_items').document(f'item_{i+1}')
            item_ref.set(item_data)
        
        print("✅ Sample menu items created")
        
        print("\n🎉 Test restaurant creation completed!")
        print("📱 You can now test login with:")
        print("   Restaurant Email: test@restaurant.com")
        print("   User ID: admin")
        print("   PIN: 1234")
        
        return True
        
    except Exception as e:
        print(f"❌ Error testing restaurant creation: {e}")
        return False

def cleanup_test_data():
    """Clean up test data"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        print("\n🧹 Cleaning up test data...")
        
        # Delete test restaurant
        test_id = 'test-restaurant-123'
        
        # Delete from tenants collection
        tenant_ref = db.collection('tenants').document(test_id)
        if tenant_ref.get().exists:
            # Delete subcollections first
            for subcollection in ['users', 'categories', 'menu_items', 'orders']:
                subcoll_ref = tenant_ref.collection(subcollection)
                for doc in subcoll_ref.stream():
                    doc.reference.delete()
            tenant_ref.delete()
            print("✅ Test tenant deleted")
        
        # Delete from restaurants collection
        restaurant_ref = db.collection('restaurants').document(test_id)
        if restaurant_ref.get().exists:
            restaurant_ref.delete()
            print("✅ Test restaurant deleted")
        
        # Delete from global_restaurants collection
        global_ref = db.collection('global_restaurants').document(test_id)
        if global_ref.get().exists:
            global_ref.delete()
            print("✅ Test global restaurant deleted")
        
        print("✅ Test data cleanup completed")
        return True
        
    except Exception as e:
        print(f"❌ Error cleaning up test data: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Restaurant Registration Test Tool")
    print("=" * 50)
    
    # Monitor current state
    monitor_firebase_state()
    
    # Ask user what to do
    print("\nWhat would you like to do?")
    print("1. Monitor Firebase state")
    print("2. Create test restaurant")
    print("3. Clean up test data")
    print("4. All of the above")
    
    choice = input("\nEnter your choice (1-4): ").strip()
    
    if choice == "1":
        monitor_firebase_state()
    elif choice == "2":
        test_restaurant_creation()
    elif choice == "3":
        cleanup_test_data()
    elif choice == "4":
        monitor_firebase_state()
        test_restaurant_creation()
        print("\n" + "="*50)
        monitor_firebase_state()
    else:
        print("Invalid choice")
        sys.exit(1) 