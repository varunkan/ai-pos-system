#!/usr/bin/env python3
"""
Fix Password Hashing Consistency
================================
Fix all existing passwords in Firebase to use consistent SHA-256 hashing
"""

import firebase_admin
from firebase_admin import credentials, firestore
import hashlib

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def main():
    print("🔧 Fixing Password Hashing Consistency")
    print("=" * 50)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Get all restaurants
    restaurants = list(db.collection('restaurants').stream())
    print(f"Found {len(restaurants)} restaurants to fix")
    
    for restaurant_doc in restaurants:
        restaurant_data = restaurant_doc.to_dict()
        restaurant_id = restaurant_doc.id
        restaurant_email = restaurant_data.get('email', 'Unknown')
        restaurant_name = restaurant_data.get('name', 'Unknown')
        
        print(f"\n🔍 Fixing: {restaurant_name} ({restaurant_email})")
        print("-" * 50)
        
        # Fix restaurant admin password (hash if it's plain text)
        current_password = restaurant_data.get('adminPassword', '')
        if current_password and len(current_password) < 64:  # Likely plain text
            hashed_password = hash_password(current_password)
            restaurant_data['adminPassword'] = hashed_password
            print(f"✅ Hashed admin password: {current_password} -> {hashed_password[:10]}...")
        else:
            print(f"✅ Admin password already hashed: {current_password[:10]}...")
        
        # Update restaurant
        db.collection('restaurants').document(restaurant_id).set(restaurant_data)
        print("✅ Updated restaurant admin password")
        
        # Fix tenant users
        tenant_id = restaurant_id
        users_ref = db.collection('tenants').document(tenant_id).collection('users')
        user_docs = list(users_ref.stream())
        
        for user_doc in user_docs:
            user_data = user_doc.to_dict()
            user_id = user_data.get('id', '')
            current_pin = user_data.get('pin', '')
            
            # Hash PIN if it's plain text
            if current_pin and len(current_pin) < 64:  # Likely plain text
                hashed_pin = hash_password(current_pin)
                user_data['pin'] = hashed_pin
                print(f"✅ Hashed user PIN ({user_id}): {current_pin} -> {hashed_pin[:10]}...")
            else:
                print(f"✅ User PIN already hashed ({user_id}): {current_pin[:10]}...")
            
            users_ref.document(user_doc.id).set(user_data)
    
    print(f"\n🎯 Password Hashing Fixed!")
    print("=" * 50)
    print("📱 All passwords and PINs are now consistently hashed")
    print("🔐 Login will work with the same credentials:")
    print("   Restaurant Email: demo@restaurant.com")
    print("   User ID: admin")
    print("   Password: admin123")
    print("   PIN: 1234")
    print("\n📋 Available restaurants:")
    for restaurant_doc in restaurants:
        restaurant_data = restaurant_doc.to_dict()
        print(f"   - {restaurant_data.get('name', 'Unknown')}: {restaurant_data.get('email', 'No email')}")

if __name__ == "__main__":
    main() 