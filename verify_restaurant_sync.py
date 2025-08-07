#!/usr/bin/env python3
"""
Restaurant Sync Verification Script
Verifies restaurant data in Firebase and helps debug cross-device sync issues.
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

def initialize_firebase():
    """Initialize Firebase with default credentials."""
    try:
        # Use default credentials
        firebase_admin.initialize_app()
        print("✅ Using default Firebase credentials")
        return firestore.client()
    except Exception as e:
        print(f"❌ Error initializing Firebase: {e}")
        return None

def check_restaurant_collections(db):
    """Check restaurant data in both collections."""
    print("\n🔍 Checking Restaurant Collections")
    print("==================================")
    
    # Check restaurants collection
    restaurants = list(db.collection('restaurants').stream())
    print(f"📊 Restaurants collection: {len(restaurants)} documents")
    
    for doc in restaurants:
        data = doc.to_dict()
        print(f"   • {data.get('name', 'Unknown')} - {data.get('email', 'No email')}")
    
    # Check global_restaurants collection
    global_restaurants = list(db.collection('global_restaurants').stream())
    print(f"📊 Global restaurants collection: {len(global_restaurants)} documents")
    
    for doc in global_restaurants:
        data = doc.to_dict()
        print(f"   • {data.get('name', 'Unknown')} - {data.get('email', 'No email')}")
    
    return restaurants, global_restaurants

def check_tenant_structure(db, restaurant_id):
    """Check tenant structure for a specific restaurant."""
    print(f"\n🏗️ Checking Tenant Structure for {restaurant_id}")
    print("=" * 50)
    
    tenant_ref = db.collection('tenants').document(restaurant_id)
    
    # Check users
    users = list(tenant_ref.collection('users').stream())
    print(f"👥 Users: {len(users)}")
    for user in users:
        data = user.to_dict()
        print(f"   • {data.get('name', 'Unknown')} ({data.get('role', 'Unknown role')})")
    
    # Check categories
    categories = list(tenant_ref.collection('categories').stream())
    print(f"📂 Categories: {len(categories)}")
    for category in categories:
        data = category.to_dict()
        print(f"   • {data.get('name', 'Unknown')}")
    
    # Check menu items
    menu_items = list(tenant_ref.collection('menu_items').stream())
    print(f"🍽️ Menu Items: {len(menu_items)}")
    for item in menu_items:
        data = item.to_dict()
        print(f"   • {data.get('name', 'Unknown')} - ${data.get('price', 0)}")
    
    return users, categories, menu_items

def search_restaurant_by_email(db, email):
    """Search for restaurant by email in both collections."""
    print(f"\n🔍 Searching for Restaurant: {email}")
    print("=" * 40)
    
    # Search in restaurants collection
    restaurant_query = db.collection('restaurants').where('email', '==', email.lower()).limit(1)
    restaurant_docs = list(restaurant_query.stream())
    
    if restaurant_docs:
        doc = restaurant_docs[0]
        data = doc.to_dict()
        print(f"✅ Found in restaurants collection:")
        print(f"   • ID: {doc.id}")
        print(f"   • Name: {data.get('name', 'Unknown')}")
        print(f"   • Email: {data.get('email', 'Unknown')}")
        print(f"   • Admin User: {data.get('adminUserId', 'Unknown')}")
        return doc.id, data
    else:
        print("❌ Not found in restaurants collection")
    
    # Search in global_restaurants collection
    global_query = db.collection('global_restaurants').where('email', '==', email.lower()).limit(1)
    global_docs = list(global_query.stream())
    
    if global_docs:
        doc = global_docs[0]
        data = doc.to_dict()
        print(f"✅ Found in global_restaurants collection:")
        print(f"   • ID: {doc.id}")
        print(f"   • Name: {data.get('name', 'Unknown')}")
        print(f"   • Email: {data.get('email', 'Unknown')}")
        print(f"   • Admin User: {data.get('adminUserId', 'Unknown')}")
        return doc.id, data
    else:
        print("❌ Not found in global_restaurants collection")
    
    return None, None

def create_test_restaurant(db, email, name, admin_user, admin_password):
    """Create a test restaurant for debugging."""
    print(f"\n🏪 Creating Test Restaurant: {name}")
    print("=" * 40)
    
    import uuid
    from datetime import datetime
    
    restaurant_id = str(uuid.uuid4())
    now = datetime.now().isoformat()
    
    restaurant_data = {
        'id': restaurant_id,
        'name': name,
        'businessType': 'Restaurant',
        'address': '123 Test Street',
        'phone': '+1-555-0123',
        'email': email.lower(),
        'adminUserId': admin_user,
        'adminPassword': admin_password,  # In production, this should be hashed
        'createdAt': now,
        'updatedAt': now,
        'databaseName': f'restaurant_{restaurant_id.replace("-", "_").lower()}',
    }
    
    try:
        # Save to restaurants collection
        db.collection('restaurants').document(restaurant_id).set(restaurant_data)
        print(f"✅ Saved to restaurants collection")
        
        # Save to global_restaurants collection
        db.collection('global_restaurants').document(restaurant_id).set(restaurant_data)
        print(f"✅ Saved to global_restaurants collection")
        
        # Create tenant structure
        tenant_ref = db.collection('tenants').document(restaurant_id)
        
        # Create admin user
        admin_user_data = {
            'id': admin_user,
            'name': 'Admin',
            'pin': admin_password,
            'role': 'admin',
            'is_active': True,
            'created_at': now,
            'updated_at': now,
            'restaurant_id': restaurant_id,
        }
        tenant_ref.collection('users').document(admin_user).set(admin_user_data)
        print(f"✅ Created admin user in tenant")
        
        print(f"🎉 Test restaurant created successfully!")
        print(f"   • ID: {restaurant_id}")
        print(f"   • Email: {email}")
        print(f"   • Admin User: {admin_user}")
        
        return restaurant_id
        
    except Exception as e:
        print(f"❌ Error creating test restaurant: {e}")
        return None

def main():
    """Main function to run restaurant sync verification."""
    print("🔍 Restaurant Sync Verification")
    print("===============================")
    
    # Initialize Firebase
    db = initialize_firebase()
    if not db:
        print("❌ Failed to initialize Firebase")
        return
    
    # Check restaurant collections
    restaurants, global_restaurants = check_restaurant_collections(db)
    
    # Interactive menu
    while True:
        print("\n📋 Available Actions:")
        print("1. Search restaurant by email")
        print("2. Check tenant structure")
        print("3. Create test restaurant")
        print("4. Show all restaurants")
        print("5. Exit")
        
        choice = input("\nEnter your choice (1-5): ").strip()
        
        if choice == '1':
            email = input("Enter restaurant email: ").strip()
            if email:
                restaurant_id, data = search_restaurant_by_email(db, email)
                if restaurant_id:
                    check_tenant_structure(db, restaurant_id)
        
        elif choice == '2':
            restaurant_id = input("Enter restaurant ID: ").strip()
            if restaurant_id:
                check_tenant_structure(db, restaurant_id)
        
        elif choice == '3':
            email = input("Enter restaurant email: ").strip()
            name = input("Enter restaurant name: ").strip()
            admin_user = input("Enter admin user ID: ").strip()
            admin_password = input("Enter admin password: ").strip()
            
            if email and name and admin_user and admin_password:
                create_test_restaurant(db, email, name, admin_user, admin_password)
        
        elif choice == '4':
            check_restaurant_collections(db)
        
        elif choice == '5':
            print("👋 Goodbye!")
            break
        
        else:
            print("❌ Invalid choice. Please try again.")

if __name__ == "__main__":
    main() 