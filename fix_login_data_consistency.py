#!/usr/bin/env python3
"""
Fix Login Data Consistency
==========================

This script fixes the existing Firebase data to ensure:
1. All restaurant admin passwords are consistent (plain text)
2. All user PINs are properly hashed
3. User IDs are properly set
4. Data structure is consistent across all restaurants
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
    print("🔧 Fixing Login Data Consistency")
    print("=" * 50)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Fix restaurants collection
    print("\n📋 Fixing restaurants collection...")
    restaurants = list(db.collection('restaurants').stream())
    
    for doc in restaurants:
        data = doc.to_dict()
        restaurant_id = doc.id
        
        # Fix admin password - ensure it's plain text
        admin_password = data.get('adminPassword', '')
        if admin_password.startswith('hashed_'):
            # Remove 'hashed_' prefix and use the actual password
            actual_password = admin_password.replace('hashed_', '')
            print(f"  Fixing {data.get('name', 'Unknown')}: {admin_password} -> {actual_password}")
            
            # Update the document
            db.collection('restaurants').document(restaurant_id).update({
                'adminPassword': actual_password
            })
        elif not admin_password:
            # Set default admin password
            default_password = 'admin123'
            print(f"  Setting default password for {data.get('name', 'Unknown')}: {default_password}")
            
            db.collection('restaurants').document(restaurant_id).update({
                'adminPassword': default_password
            })
    
    # Fix tenant users
    print("\n👥 Fixing tenant users...")
    tenants = list(db.collection('tenants').stream())
    
    for tenant_doc in tenants:
        tenant_id = tenant_doc.id
        users_ref = db.collection('tenants').document(tenant_id).collection('users')
        users = list(users_ref.stream())
        
        print(f"  Processing tenant: {tenant_id}")
        
        for user_doc in users:
            user_data = user_doc.to_dict()
            user_id = user_doc.id
            
            # Fix user ID field
            if 'userId' not in user_data:
                user_data['userId'] = user_id
                print(f"    Adding userId field for user {user_id}")
            
            # Fix PIN - ensure it's properly hashed
            pin = user_data.get('pin', '')
            if pin and not pin.startswith('hashed_') and len(pin) < 64:
                # This looks like a plain text PIN, hash it
                hashed_pin = hash_password(pin)
                user_data['pin'] = hashed_pin
                print(f"    Hashing PIN for user {user_id}: {pin} -> {hashed_pin[:8]}...")
            
            # Update user document
            users_ref.document(user_id).set(user_data, merge=True)
    
    # Create test credentials for demo restaurant
    print("\n🎯 Creating test credentials for demo restaurant...")
    demo_restaurant_id = 'default-restaurant'
    
    # Ensure demo restaurant exists with proper credentials
    demo_restaurant_data = {
        'name': 'Demo Restaurant',
        'email': 'demo@restaurant.com',
        'adminUserId': 'admin',
        'adminPassword': 'admin123',  # Plain text
        'isActive': True
    }
    
    db.collection('restaurants').document(demo_restaurant_id).set(demo_restaurant_data, merge=True)
    db.collection('global_restaurants').document(demo_restaurant_id).set(demo_restaurant_data, merge=True)
    
    # Create demo tenant structure
    demo_tenant_data = {
        'id': demo_restaurant_id,
        'restaurantId': demo_restaurant_id,
        'createdAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP
    }
    
    db.collection('tenants').document(demo_restaurant_id).set(demo_tenant_data, merge=True)
    
    # Create demo users
    demo_users = [
        {
            'id': 'admin',
            'userId': 'admin',
            'name': 'Admin User',
            'role': 'admin',
            'pin': hash_password('1234'),  # Hashed PIN
            'isActive': True,
            'adminPanelAccess': True
        },
        {
            'id': 'cashier1',
            'userId': 'cashier1',
            'name': 'Cashier One',
            'role': 'cashier',
            'pin': hash_password('1111'),  # Hashed PIN
            'isActive': True,
            'adminPanelAccess': False
        },
        {
            'id': 'manager1',
            'userId': 'manager1',
            'name': 'Manager One',
            'role': 'manager',
            'pin': hash_password('2222'),  # Hashed PIN
            'isActive': True,
            'adminPanelAccess': True
        }
    ]
    
    users_ref = db.collection('tenants').document(demo_restaurant_id).collection('users')
    for user_data in demo_users:
        users_ref.document(user_data['id']).set(user_data, merge=True)
        print(f"    Created user: {user_data['name']} ({user_data['role']})")
    
    print("\n✅ Login data consistency fix complete!")
    print("\n📋 Test Credentials for Demo Restaurant:")
    print("   Restaurant Email: demo@restaurant.com")
    print("   Admin User ID: admin")
    print("   Admin Password: admin123")
    print("   Admin PIN: 1234")
    print("   Cashier PIN: 1111")
    print("   Manager PIN: 2222")

if __name__ == "__main__":
    main() 