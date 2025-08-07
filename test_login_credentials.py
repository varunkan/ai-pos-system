#!/usr/bin/env python3
"""
Test Login Credentials
======================
Simple script to verify login credentials work
"""

import firebase_admin
from firebase_admin import credentials, firestore
import hashlib

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def main():
    print("🧪 Testing Login Credentials")
    print("=" * 40)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Test credentials
    test_credentials = [
        {
            'email': 'demo@restaurant.com',
            'user_id': 'admin',
            'password': 'admin123',
            'pin': '1234'
        },
        {
            'email': 'varun.kan@gmail.com',
            'user_id': 'admin',
            'password': 'admin123',
            'pin': '1234'
        }
    ]
    
    for cred in test_credentials:
        print(f"\n🔍 Testing: {cred['email']}")
        print("-" * 30)
        
        # Find restaurant
        restaurants = db.collection('restaurants').where('email', '==', cred['email']).stream()
        restaurant_docs = list(restaurants)
        
        if not restaurant_docs:
            print(f"❌ Restaurant not found: {cred['email']}")
            continue
            
        restaurant = restaurant_docs[0].to_dict()
        print(f"✅ Restaurant found: {restaurant.get('name', 'Unknown')}")
        
        # Check admin password
        stored_password = restaurant.get('adminPassword', '')
        if cred['password'] == stored_password:
            print(f"✅ Admin password matches: {cred['password']}")
        else:
            print(f"❌ Admin password mismatch. Expected: {stored_password}, Got: {cred['password']}")
        
        # Check admin user ID
        admin_user_id = restaurant.get('adminUserId', '')
        if cred['user_id'] == admin_user_id:
            print(f"✅ Admin user ID matches: {cred['user_id']}")
        else:
            print(f"❌ Admin user ID mismatch. Expected: {admin_user_id}, Got: {cred['user_id']}")
        
        # Check tenant users
        tenant_id = restaurant.get('id', '')
        if tenant_id:
            users_ref = db.collection('tenants').document(tenant_id).collection('users')
            user_docs = list(users_ref.stream())
            
            if user_docs:
                print(f"✅ Found {len(user_docs)} users in tenant")
                for user_doc in user_docs:
                    user_data = user_doc.to_dict()
                    user_id = user_data.get('id', '')
                    user_pin = user_data.get('pin', '')
                    
                    if user_id == cred['user_id']:
                        print(f"✅ Found admin user: {user_id}")
                        if cred['pin'] == user_pin:
                            print(f"✅ Admin PIN matches: {cred['pin']}")
                        else:
                            print(f"❌ Admin PIN mismatch. Expected: {user_pin}, Got: {cred['pin']}")
            else:
                print(f"⚠️ No users found in tenant: {tenant_id}")
        else:
            print(f"❌ No tenant ID found for restaurant")
    
    print(f"\n🎯 Login Test Summary:")
    print("=" * 40)
    print("📱 Test these credentials in the app:")
    print("   Restaurant Email: demo@restaurant.com")
    print("   User ID: admin")
    print("   Password: admin123")
    print("   PIN: 1234")
    print("\n   OR")
    print("   Restaurant Email: varun.kan@gmail.com")
    print("   User ID: admin")
    print("   Password: admin123")
    print("   PIN: 1234")

if __name__ == "__main__":
    main() 