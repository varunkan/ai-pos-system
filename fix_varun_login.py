#!/usr/bin/env python3
"""
Fix Login Credentials for varun.kan@gmail.com
Sets up proper user credentials that will work with the app
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import hashlib

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

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def fix_varun_login():
    """Fix login credentials for varun.kan@gmail.com"""
    try:
        initialize_firebase()
        db = firestore.client()
        
        # Restaurant details
        restaurant_email = "varun.kan@gmail.com"
        tenant_id = "98213ca9-90b3-4f77-8aa1-488c0cbbd9b6"
        
        print(f"🔧 Fixing login credentials for {restaurant_email}")
        print(f"📋 Tenant ID: {tenant_id}")
        
        # Create proper user credentials
        user_data = {
            'id': 'admin',
            'name': 'Admin User',
            'email': 'admin@varun.restaurant',
            'role': 'admin',
            'pin': hash_password('1234'),  # PIN: 1234
            'password': hash_password('admin123'),  # Password: admin123
            'restaurant_id': tenant_id,
            'is_active': True,
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
        }
        
        # Update user in tenant database
        db.collection('tenants').document(tenant_id).collection('users').document('admin').set(user_data)
        print("✅ Updated admin user credentials")
        
        # Create additional test users
        test_users = [
            {
                'id': 'cashier1',
                'name': 'Cashier One',
                'email': 'cashier@varun.restaurant',
                'role': 'cashier',
                'pin': hash_password('1111'),  # PIN: 1111
                'password': hash_password('cashier123'),  # Password: cashier123
                'restaurant_id': tenant_id,
                'is_active': True,
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat(),
            },
            {
                'id': 'manager1',
                'name': 'Manager One',
                'email': 'manager@varun.restaurant',
                'role': 'manager',
                'pin': hash_password('2222'),  # PIN: 2222
                'password': hash_password('manager123'),  # Password: manager123
                'restaurant_id': tenant_id,
                'is_active': True,
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat(),
            }
        ]
        
        for user in test_users:
            db.collection('tenants').document(tenant_id).collection('users').document(user['id']).set(user)
            print(f"✅ Created user: {user['name']} ({user['id']})")
        
        # Verify the setup
        users = list(db.collection('tenants').document(tenant_id).collection('users').stream())
        print(f"\n📊 Verification:")
        print(f"   Total users: {len(users)}")
        for user in users:
            user_data = user.to_dict()
            print(f"   - {user_data['name']} ({user_data['id']}) - Role: {user_data['role']}")
        
        print(f"\n🎉 Login credentials fixed for {restaurant_email}!")
        print(f"\n📱 Login Information:")
        print(f"   Restaurant Email: {restaurant_email}")
        print(f"   Admin User ID: admin")
        print(f"   Admin Password: admin123")
        print(f"   Admin PIN: 1234")
        print(f"   Cashier User ID: cashier1")
        print(f"   Cashier PIN: 1111")
        print(f"   Manager User ID: manager1")
        print(f"   Manager PIN: 2222")
        
    except Exception as e:
        print(f"❌ Error fixing login credentials: {e}")

if __name__ == "__main__":
    fix_varun_login() 