#!/usr/bin/env python3
"""
Test Login Flow
==============
Test the login process to identify why restaurant is not found
"""

import firebase_admin
from firebase_admin import credentials, firestore
import hashlib

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def main():
    print("🔍 Testing Login Flow")
    print("=" * 30)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Test credentials that should work
    test_credentials = [
        {
            "email": "demo@restaurant.com",
            "user_id": "admin",
            "password": "admin123",
            "pin": "1234"
        },
        {
            "email": "schema@restaurant.com", 
            "user_id": "admin",
            "password": "admin123",
            "pin": "1234"
        },
        {
            "email": "test@restaurant.com",
            "user_id": "admin", 
            "password": "admin123",
            "pin": "1234"
        }
    ]
    
    for cred in test_credentials:
        print(f"\n🔐 Testing: {cred['email']}")
        print("-" * 30)
        
        # Step 1: Find restaurant by email
        restaurants = list(db.collection('restaurants').where('email', '==', cred['email']).stream())
        if restaurants:
            restaurant = restaurants[0]
            restaurant_data = restaurant.to_dict()
            print(f"✅ Restaurant found: {restaurant_data.get('name')}")
            print(f"   ID: {restaurant.id}")
            print(f"   Admin User: {restaurant_data.get('admin_user_id')}")
            
            # Step 2: Check if admin user exists in tenant
            tenant_ref = db.collection('tenants').document(restaurant.id)
            admin_user = tenant_ref.collection('users').document(cred['user_id']).get()
            
            if admin_user.exists:
                user_data = admin_user.to_dict()
                print(f"✅ Admin user found: {user_data.get('name')}")
                print(f"   Role: {user_data.get('role')}")
                print(f"   PIN: {user_data.get('pin')}")
                
                # Step 3: Verify password/PIN
                stored_pin = user_data.get('pin', '')
                hashed_input_pin = hash_password(cred['pin'])
                
                if stored_pin == hashed_input_pin:
                    print("✅ PIN verification successful")
                elif stored_pin == cred['pin']:
                    print("✅ PIN verification successful (plain text)")
                else:
                    print(f"❌ PIN verification failed")
                    print(f"   Input PIN (hashed): {hashed_input_pin}")
                    print(f"   Stored PIN: {stored_pin}")
                
                # Step 4: Check if restaurant is active
                if restaurant_data.get('is_active', True):
                    print("✅ Restaurant is active")
                else:
                    print("❌ Restaurant is inactive")
                    
            else:
                print(f"❌ Admin user not found: {cred['user_id']}")
                
        else:
            print(f"❌ Restaurant not found with email: {cred['email']}")
    
    print("\n📋 Available Restaurants for Testing:")
    print("=" * 40)
    restaurants = list(db.collection('restaurants').stream())
    for restaurant in restaurants:
        data = restaurant.to_dict()
        print(f"  - {data.get('name', 'Unknown')}")
        print(f"    Email: {data.get('email')}")
        print(f"    ID: {restaurant.id}")
        print(f"    Active: {data.get('is_active', True)}")
        print()

if __name__ == "__main__":
    main() 