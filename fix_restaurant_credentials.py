#!/usr/bin/env python3
"""
Fix Restaurant Credentials and Tenant Structures
===============================================

This script fixes the existing restaurant data to ensure:
1. All restaurants have proper tenant structures
2. Admin users are created with correct credentials
3. Sample data is available for all restaurants
4. Login credentials work consistently
"""

import firebase_admin
from firebase_admin import credentials, firestore
import hashlib
import os
import sys

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def main():
    print("🔧 Fixing Restaurant Credentials and Tenant Structures")
    print("=" * 60)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Get all restaurants
    restaurants = list(db.collection('restaurants').stream())
    print(f"📊 Found {len(restaurants)} restaurants")
    
    fixed_count = 0
    
    for doc in restaurants:
        restaurant_data = doc.to_dict()
        restaurant_id = doc.id
        restaurant_name = restaurant_data.get('name', 'Unknown')
        restaurant_email = restaurant_data.get('email', '')
        
        print(f"\n🏪 Processing: {restaurant_name} ({restaurant_email})")
        
        # Check if tenant exists
        tenant_doc = db.collection('tenants').document(restaurant_id).get()
        
        if not tenant_doc.exists:
            print(f"  ⚠️  Creating missing tenant structure...")
            
            # Create tenant document
            db.collection('tenants').document(restaurant_id).set({
                'id': restaurant_id,
                'restaurantId': restaurant_id,
                'createdAt': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP,
            })
            
            # Create admin user
            admin_user_id = restaurant_data.get('adminUserId', 'admin')
            admin_password = restaurant_data.get('adminPassword', 'admin123')
            
            # Create admin user with hashed PIN
            admin_user = {
                'id': admin_user_id,
                'name': 'Admin',
                'role': 'admin',
                'pin': hash_password(admin_password),  # Hash the password as PIN
                'isActive': True,
                'adminPanelAccess': True,
                'createdAt': firestore.SERVER_TIMESTAMP,
                'lastLogin': None,
            }
            
            db.collection('tenants').document(restaurant_id).collection('users').document(admin_user_id).set(admin_user)
            
            # Create sample categories
            categories = [
                {'name': 'Appetizers', 'description': 'Starters and appetizers', 'isActive': True, 'sortOrder': 1},
                {'name': 'Main Course', 'description': 'Main dishes', 'isActive': True, 'sortOrder': 2},
                {'name': 'Desserts', 'description': 'Sweet treats', 'isActive': True, 'sortOrder': 3},
                {'name': 'Beverages', 'description': 'Drinks and beverages', 'isActive': True, 'sortOrder': 4},
            ]
            
            for i, category_data in enumerate(categories):
                category_id = f"cat_{i+1}"
                category_data['id'] = category_id
                db.collection('tenants').document(restaurant_id).collection('categories').document(category_id).set(category_data)
            
            # Create sample menu items
            menu_items = [
                {'name': 'Bruschetta', 'description': 'Fresh tomato and basil on toasted bread', 'price': 8.99, 'categoryId': 'cat_1', 'isAvailable': True},
                {'name': 'Margherita Pizza', 'description': 'Classic tomato and mozzarella pizza', 'price': 16.99, 'categoryId': 'cat_2', 'isAvailable': True},
                {'name': 'Chicken Alfredo', 'description': 'Creamy pasta with grilled chicken', 'price': 18.99, 'categoryId': 'cat_2', 'isAvailable': True},
                {'name': 'Tiramisu', 'description': 'Classic Italian dessert', 'price': 9.99, 'categoryId': 'cat_3', 'isAvailable': True},
                {'name': 'Iced Latte', 'description': 'Refreshing coffee drink', 'price': 4.99, 'categoryId': 'cat_4', 'isAvailable': True},
            ]
            
            for i, item_data in enumerate(menu_items):
                item_id = f"item_{i+1}"
                item_data['id'] = item_id
                db.collection('tenants').document(restaurant_id).collection('menu_items').document(item_id).set(item_data)
            
            print(f"  ✅ Created tenant structure with admin user and sample data")
            print(f"  📋 Login credentials:")
            print(f"     Restaurant Email: {restaurant_email}")
            print(f"     User ID: {admin_user_id}")
            print(f"     Password: {admin_password}")
            print(f"     PIN: {admin_password}")
            
            fixed_count += 1
        else:
            print(f"  ✅ Tenant structure already exists")
            
            # Check if admin user exists
            admin_user_id = restaurant_data.get('adminUserId', 'admin')
            admin_user_doc = db.collection('tenants').document(restaurant_id).collection('users').document(admin_user_id).get()
            
            if not admin_user_doc.exists:
                print(f"  ⚠️  Creating missing admin user...")
                admin_password = restaurant_data.get('adminPassword', 'admin123')
                
                admin_user = {
                    'id': admin_user_id,
                    'name': 'Admin',
                    'role': 'admin',
                    'pin': hash_password(admin_password),
                    'isActive': True,
                    'adminPanelAccess': True,
                    'createdAt': firestore.SERVER_TIMESTAMP,
                    'lastLogin': None,
                }
                
                db.collection('tenants').document(restaurant_id).collection('users').document(admin_user_id).set(admin_user)
                print(f"  ✅ Created admin user")
                fixed_count += 1
            else:
                print(f"  ✅ Admin user already exists")
    
    print(f"\n🎉 Fix Complete!")
    print(f"✅ Fixed {fixed_count} restaurants")
    print(f"\n📱 Login Instructions:")
    print(f"1. Use the restaurant email and admin credentials shown above")
    print(f"2. You can use either password or PIN (they're the same)")
    print(f"3. The app will now properly validate credentials")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1) 