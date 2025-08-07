#!/usr/bin/env python3
"""
Fix Login Credentials
=====================
Fix the login credentials to ensure they work properly
"""

import firebase_admin
from firebase_admin import credentials, firestore
import hashlib

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def main():
    print("🔧 Fixing Login Credentials")
    print("=" * 40)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Fix credentials for demo restaurant
    demo_restaurant_email = 'demo@restaurant.com'
    
    # Find demo restaurant
    restaurants = db.collection('restaurants').where('email', '==', demo_restaurant_email).stream()
    restaurant_docs = list(restaurants)
    
    if not restaurant_docs:
        print(f"❌ Restaurant not found: {demo_restaurant_email}")
        return
    
    restaurant_doc = restaurant_docs[0]
    restaurant_data = restaurant_doc.to_dict()
    restaurant_id = restaurant_doc.id
    
    print(f"✅ Found restaurant: {restaurant_data.get('name', 'Unknown')}")
    
    # Fix restaurant admin password (keep as plain text)
    restaurant_data['adminPassword'] = 'admin123'
    restaurant_data['adminUserId'] = 'admin'
    
    # Update restaurant
    db.collection('restaurants').document(restaurant_id).set(restaurant_data)
    print("✅ Updated restaurant admin credentials")
    
    # Fix tenant users
    tenant_id = restaurant_id
    users_ref = db.collection('tenants').document(tenant_id).collection('users')
    user_docs = list(users_ref.stream())
    
    for user_doc in user_docs:
        user_data = user_doc.to_dict()
        user_id = user_data.get('id', '')
        
        if user_id == 'admin':
            # Fix admin user PIN (keep as plain text)
            user_data['pin'] = '1234'
            users_ref.document(user_doc.id).set(user_data)
            print(f"✅ Fixed admin user PIN: {user_id}")
        elif user_id == 'cashier1':
            # Fix cashier PIN
            user_data['pin'] = '1111'
            users_ref.document(user_doc.id).set(user_data)
            print(f"✅ Fixed cashier PIN: {user_id}")
        elif user_id == 'manager1':
            # Fix manager PIN
            user_data['pin'] = '2222'
            users_ref.document(user_doc.id).set(user_data)
            print(f"✅ Fixed manager PIN: {user_id}")
    
    print(f"\n🎯 Fixed Credentials:")
    print("=" * 40)
    print("📱 Use these credentials in the app:")
    print("   Restaurant Email: demo@restaurant.com")
    print("   User ID: admin")
    print("   Password: admin123")
    print("   PIN: 1234")
    print("\n   Additional users:")
    print("   - Cashier: cashier1, PIN: 1111")
    print("   - Manager: manager1, PIN: 2222")

if __name__ == "__main__":
    main() 