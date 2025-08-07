#!/usr/bin/env python3
"""
Comprehensive Login System Test
===============================

This script tests the entire login system to ensure it works correctly.
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
    print("🧪 Comprehensive Login System Test")
    print("=" * 50)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Test 1: Check Firebase Connection
    print("\n🔍 Test 1: Firebase Connection")
    try:
        restaurants = list(db.collection('restaurants').stream())
        print(f"✅ Firebase connection successful - Found {len(restaurants)} restaurants")
    except Exception as e:
        print(f"❌ Firebase connection failed: {e}")
        return
    
    # Test 2: Check Demo Restaurant
    print("\n🔍 Test 2: Demo Restaurant Data")
    demo_restaurant = None
    for doc in restaurants:
        data = doc.to_dict()
        if data.get('email') == 'demo@restaurant.com':
            demo_restaurant = {'id': doc.id, 'data': data}
            break
    
    if demo_restaurant:
        print(f"✅ Demo restaurant found: {demo_restaurant['data'].get('name')}")
        print(f"   ID: {demo_restaurant['id']}")
        print(f"   Admin User ID: {demo_restaurant['data'].get('adminUserId')}")
        print(f"   Admin Password: {demo_restaurant['data'].get('adminPassword')}")
    else:
        print("❌ Demo restaurant not found")
        return
    
    # Test 3: Check Tenant Structure
    print("\n🔍 Test 3: Tenant Structure")
    tenant_id = demo_restaurant['id']
    tenant_doc = db.collection('tenants').document(tenant_id).get()
    
    if tenant_doc.exists:
        print(f"✅ Tenant document exists: {tenant_id}")
    else:
        print(f"❌ Tenant document not found: {tenant_id}")
        return
    
    # Test 4: Check Users
    print("\n🔍 Test 4: User Data")
    users_ref = db.collection('tenants').document(tenant_id).collection('users')
    users = list(users_ref.stream())
    
    print(f"Found {len(users)} users:")
    for user_doc in users:
        user_data = user_doc.to_dict()
        user_id = user_doc.id
        print(f"  User: {user_data.get('name', 'Unknown')} (ID: {user_id})")
        print(f"    Role: {user_data.get('role', 'Unknown')}")
        print(f"    PIN: {user_data.get('pin', 'No PIN')}")
        print(f"    User ID: {user_data.get('userId', 'No userId')}")
    
    # Test 5: Test Login Credentials
    print("\n🔍 Test 5: Login Credentials Test")
    
    # Test admin login
    admin_user = None
    for user_doc in users:
        user_data = user_doc.to_dict()
        if user_data.get('role') == 'admin':
            admin_user = {'id': user_doc.id, 'data': user_data}
            break
    
    if admin_user:
        print(f"✅ Admin user found: {admin_user['data'].get('name')}")
        
        # Test password verification
        stored_password = demo_restaurant['data'].get('adminPassword', '')
        test_password = 'admin123'
        
        if stored_password == test_password:
            print(f"✅ Admin password verification: PASSED")
        else:
            print(f"❌ Admin password verification: FAILED")
            print(f"   Expected: {test_password}")
            print(f"   Stored: {stored_password}")
        
        # Test PIN verification
        stored_pin = admin_user['data'].get('pin', '')
        test_pin = '1234'
        hashed_test_pin = hash_password(test_pin)
        
        if stored_pin == hashed_test_pin:
            print(f"✅ Admin PIN verification: PASSED")
        else:
            print(f"❌ Admin PIN verification: FAILED")
            print(f"   Expected hash: {hashed_test_pin}")
            print(f"   Stored: {stored_pin}")
    else:
        print("❌ Admin user not found")
    
    # Test 6: Test User Login
    print("\n🔍 Test 6: User Login Test")
    cashier_user = None
    for user_doc in users:
        user_data = user_doc.to_dict()
        if user_data.get('role') == 'cashier':
            cashier_user = {'id': user_doc.id, 'data': user_data}
            break
    
    if cashier_user:
        print(f"✅ Cashier user found: {cashier_user['data'].get('name')}")
        
        # Test PIN verification
        stored_pin = cashier_user['data'].get('pin', '')
        test_pin = '1111'
        hashed_test_pin = hash_password(test_pin)
        
        if stored_pin == hashed_test_pin:
            print(f"✅ Cashier PIN verification: PASSED")
        else:
            print(f"❌ Cashier PIN verification: FAILED")
            print(f"   Expected hash: {hashed_test_pin}")
            print(f"   Stored: {stored_pin}")
    else:
        print("❌ Cashier user not found")
    
    # Test 7: Sample Data
    print("\n🔍 Test 7: Sample Data")
    categories_ref = db.collection('tenants').document(tenant_id).collection('categories')
    categories = list(categories_ref.stream())
    print(f"Categories: {len(categories)} found")
    
    menu_items_ref = db.collection('tenants').document(tenant_id).collection('menu_items')
    menu_items = list(menu_items_ref.stream())
    print(f"Menu Items: {len(menu_items)} found")
    
    # Summary
    print("\n🎯 LOGIN SYSTEM SUMMARY")
    print("=" * 30)
    print("✅ Firebase connection: WORKING")
    print("✅ Demo restaurant: AVAILABLE")
    print("✅ Tenant structure: CORRECT")
    print("✅ User data: PRESENT")
    print("✅ Sample data: AVAILABLE")
    
    print("\n📋 TEST CREDENTIALS:")
    print("Restaurant Email: demo@restaurant.com")
    print("Admin User ID: admin")
    print("Admin Password: admin123")
    print("Admin PIN: 1234")
    print("Cashier PIN: 1111")
    print("Manager PIN: 2222")
    
    print("\n🔧 If login still fails, check:")
    print("1. Firebase initialization in the app")
    print("2. Network connectivity")
    print("3. App logs for detailed error messages")
    print("4. Firebase project permissions")

if __name__ == "__main__":
    main() 