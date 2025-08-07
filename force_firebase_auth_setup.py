#!/usr/bin/env python3
"""
Firebase Authentication Setup Script
Creates multiple restaurants with proper credentials for multi-tenant testing
"""

import firebase_admin
from firebase_admin import credentials, firestore
import uuid
from datetime import datetime
import os

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

def create_restaurant_data():
    """Create comprehensive restaurant data with proper credentials"""
    
    # Multiple restaurants for testing
    restaurants = [
        {
            'id': 'demo-restaurant',
            'name': 'Demo Restaurant',
            'email': 'demo@restaurant.com',
            'adminUserId': 'admin',
            'adminPassword': 'admin123',
            'businessType': 'Restaurant',
            'address': '123 Demo Street, Toronto, ON',
            'phone': '+1-416-555-0123'
        },
        {
            'id': 'test-restaurant-1',
            'name': 'Test Restaurant One',
            'email': 'test1@restaurant.com',
            'adminUserId': 'admin1',
            'adminPassword': 'admin123',
            'businessType': 'Restaurant',
            'address': '456 Test Avenue, Toronto, ON',
            'phone': '+1-416-555-0456'
        },
        {
            'id': 'test-restaurant-2',
            'name': 'Test Restaurant Two',
            'email': 'test2@restaurant.com',
            'adminUserId': 'admin2',
            'adminPassword': 'admin123',
            'businessType': 'Restaurant',
            'address': '789 Test Boulevard, Toronto, ON',
            'phone': '+1-416-555-0789'
        },
        {
            'id': 'pizza-palace',
            'name': 'Pizza Palace',
            'email': 'pizza@restaurant.com',
            'adminUserId': 'pizza_admin',
            'adminPassword': 'pizza123',
            'businessType': 'Pizzeria',
            'address': '321 Pizza Street, Toronto, ON',
            'phone': '+1-416-555-0321'
        },
        {
            'id': 'sushi-bar',
            'name': 'Sushi Bar',
            'email': 'sushi@restaurant.com',
            'adminUserId': 'sushi_admin',
            'adminPassword': 'sushi123',
            'businessType': 'Sushi Restaurant',
            'address': '654 Sushi Avenue, Toronto, ON',
            'phone': '+1-416-555-0654'
        }
    ]
    
    return restaurants

def create_user_data():
    """Create user data for each restaurant"""
    users = [
        # Demo Restaurant Users
        {
            'restaurantId': 'demo-restaurant',
            'users': [
                {'id': 'admin', 'name': 'Admin User', 'role': 'admin', 'pin': '1234', 'is_active': True},
                {'id': 'cashier1', 'name': 'Cashier One', 'role': 'cashier', 'pin': '1111', 'is_active': True},
                {'id': 'manager1', 'name': 'Manager One', 'role': 'manager', 'pin': '2222', 'is_active': True},
                {'id': 'waiter1', 'name': 'Waiter One', 'role': 'waiter', 'pin': '3333', 'is_active': True}
            ]
        },
        # Test Restaurant 1 Users
        {
            'restaurantId': 'test-restaurant-1',
            'users': [
                {'id': 'admin1', 'name': 'Admin User', 'role': 'admin', 'pin': '1234', 'is_active': True},
                {'id': 'cashier1', 'name': 'Cashier One', 'role': 'cashier', 'pin': '1111', 'is_active': True},
                {'id': 'manager1', 'name': 'Manager One', 'role': 'manager', 'pin': '2222', 'is_active': True}
            ]
        },
        # Test Restaurant 2 Users
        {
            'restaurantId': 'test-restaurant-2',
            'users': [
                {'id': 'admin2', 'name': 'Admin User', 'role': 'admin', 'pin': '1234', 'is_active': True},
                {'id': 'cashier1', 'name': 'Cashier One', 'role': 'cashier', 'pin': '1111', 'is_active': True},
                {'id': 'manager1', 'name': 'Manager One', 'role': 'manager', 'pin': '2222', 'is_active': True}
            ]
        },
        # Pizza Palace Users
        {
            'restaurantId': 'pizza-palace',
            'users': [
                {'id': 'pizza_admin', 'name': 'Pizza Admin', 'role': 'admin', 'pin': '1234', 'is_active': True},
                {'id': 'pizza_cashier', 'name': 'Pizza Cashier', 'role': 'cashier', 'pin': '1111', 'is_active': True},
                {'id': 'pizza_chef', 'name': 'Pizza Chef', 'role': 'chef', 'pin': '4444', 'is_active': True}
            ]
        },
        # Sushi Bar Users
        {
            'restaurantId': 'sushi-bar',
            'users': [
                {'id': 'sushi_admin', 'name': 'Sushi Admin', 'role': 'admin', 'pin': '1234', 'is_active': True},
                {'id': 'sushi_cashier', 'name': 'Sushi Cashier', 'role': 'cashier', 'pin': '1111', 'is_active': True},
                {'id': 'sushi_chef', 'name': 'Sushi Chef', 'role': 'chef', 'pin': '5555', 'is_active': True}
            ]
        }
    ]
    
    return users

def create_sample_data():
    """Create sample menu items and categories"""
    categories = [
        {'id': 'appetizers', 'name': 'Appetizers', 'description': 'Starters and small plates'},
        {'id': 'main-course', 'name': 'Main Course', 'description': 'Main dishes'},
        {'id': 'desserts', 'name': 'Desserts', 'description': 'Sweet treats'},
        {'id': 'beverages', 'name': 'Beverages', 'description': 'Drinks and refreshments'},
        {'id': 'pizza', 'name': 'Pizza', 'description': 'Fresh baked pizzas'},
        {'id': 'sushi', 'name': 'Sushi', 'description': 'Fresh sushi and sashimi'}
    ]
    
    menu_items = [
        # General items
        {'id': 'bruschetta', 'name': 'Bruschetta', 'category': 'appetizers', 'price': 8.99, 'description': 'Toasted bread with tomatoes and herbs'},
        {'id': 'margherita-pizza', 'name': 'Margherita Pizza', 'category': 'main-course', 'price': 16.99, 'description': 'Classic tomato and mozzarella pizza'},
        {'id': 'chicken-alfredo', 'name': 'Chicken Alfredo', 'category': 'main-course', 'price': 18.99, 'description': 'Creamy pasta with grilled chicken'},
        {'id': 'tiramisu', 'name': 'Tiramisu', 'category': 'desserts', 'price': 9.99, 'description': 'Classic Italian dessert'},
        {'id': 'iced-latte', 'name': 'Iced Latte', 'category': 'beverages', 'price': 4.99, 'description': 'Cold coffee with milk'},
        
        # Pizza Palace items
        {'id': 'pepperoni-pizza', 'name': 'Pepperoni Pizza', 'category': 'pizza', 'price': 19.99, 'description': 'Spicy pepperoni pizza'},
        {'id': 'veggie-pizza', 'name': 'Veggie Pizza', 'category': 'pizza', 'price': 17.99, 'description': 'Fresh vegetable pizza'},
        {'id': 'hawaiian-pizza', 'name': 'Hawaiian Pizza', 'category': 'pizza', 'price': 18.99, 'description': 'Ham and pineapple pizza'},
        
        # Sushi Bar items
        {'id': 'california-roll', 'name': 'California Roll', 'category': 'sushi', 'price': 12.99, 'description': 'Crab, avocado, and cucumber roll'},
        {'id': 'salmon-nigiri', 'name': 'Salmon Nigiri', 'category': 'sushi', 'price': 8.99, 'description': 'Fresh salmon over rice'},
        {'id': 'dragon-roll', 'name': 'Dragon Roll', 'category': 'sushi', 'price': 16.99, 'description': 'Eel and avocado roll'}
    ]
    
    return categories, menu_items

def setup_firebase_data():
    """Set up all Firebase data"""
    db = firestore.client()
    
    print("🔐 Setting up Firebase authentication data...")
    
    # Get data
    restaurants = create_restaurant_data()
    users_data = create_user_data()
    categories, menu_items = create_sample_data()
    
    # Create restaurants
    for restaurant in restaurants:
        print(f"📝 Creating restaurant: {restaurant['name']}")
        
        # Save to restaurants collection
        db.collection('restaurants').document(restaurant['id']).set({
            'id': restaurant['id'],
            'name': restaurant['name'],
            'email': restaurant['email'],
            'adminUserId': restaurant['adminUserId'],
            'adminPassword': restaurant['adminPassword'],
            'businessType': restaurant['businessType'],
            'address': restaurant['address'],
            'phone': restaurant['phone'],
            'createdAt': datetime.now().isoformat(),
            'updatedAt': datetime.now().isoformat(),
            'isActive': True,
            'databaseName': f"restaurant_{restaurant['id']}"
        })
        print(f"   ✅ Saved to restaurants collection")
        
        # Save to global_restaurants collection
        db.collection('global_restaurants').document(restaurant['id']).set({
            'id': restaurant['id'],
            'name': restaurant['name'],
            'email': restaurant['email'],
            'adminUserId': restaurant['adminUserId'],
            'adminPassword': restaurant['adminPassword'],
            'businessType': restaurant['businessType'],
            'address': restaurant['address'],
            'phone': restaurant['phone'],
            'createdAt': datetime.now().isoformat(),
            'updatedAt': datetime.now().isoformat(),
            'isActive': True,
            'databaseName': f"restaurant_{restaurant['id']}"
        })
        print(f"   ✅ Saved to global_restaurants collection")
        
        # Create tenant structure
        tenant_ref = db.collection('tenants').document(restaurant['id'])
        
        # Create admin user in tenant database
        admin_user = next((u for u in users_data if u['restaurantId'] == restaurant['id']), None)
        if admin_user:
            admin_data = next((u for u in admin_user['users'] if u['role'] == 'admin'), None)
            if admin_data:
                tenant_ref.collection('users').document(admin_data['id']).set({
                    'id': admin_data['id'],
                    'name': admin_data['name'],
                    'role': admin_data['role'],
                    'pin': admin_data['pin'],
                    'is_active': admin_data['is_active'],
                    'created_at': datetime.now().isoformat(),
                    'updated_at': datetime.now().isoformat()
                })
                print(f"   ✅ Created admin user in tenant database")
        
        # Create all users for this restaurant
        for user in admin_user['users']:
            tenant_ref.collection('users').document(user['id']).set({
                'id': user['id'],
                'name': user['name'],
                'role': user['role'],
                'pin': user['pin'],
                'is_active': user['is_active'],
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            })
        print(f"   ✅ Created {len(admin_user['users'])} users for {restaurant['name']}")
        
        # Create categories
        for category in categories:
            tenant_ref.collection('categories').document(category['id']).set({
                'id': category['id'],
                'name': category['name'],
                'description': category['description'],
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            })
        print(f"   ✅ Created {len(categories)} categories")
        
        # Create menu items
        for item in menu_items:
            tenant_ref.collection('menu_items').document(item['id']).set({
                'id': item['id'],
                'name': item['name'],
                'category_id': item['category'],
                'price': item['price'],
                'description': item['description'],
                'is_active': True,
                'created_at': datetime.now().isoformat(),
                'updated_at': datetime.now().isoformat()
            })
        print(f"   ✅ Created {len(menu_items)} menu items")
        
        # Create sample order
        sample_order = {
            'id': f'ORDER-{restaurant["id"].upper()}-001',
            'customer_name': f'{restaurant["name"]} Test Customer',
            'order_type': 'dine_in',
            'status': 'completed',
            'total_amount': 25.98,
            'items': [
                {
                    'menu_item_id': 'bruschetta',
                    'name': 'Bruschetta',
                    'quantity': 1,
                    'price': 8.99,
                    'total': 8.99
                },
                {
                    'menu_item_id': 'margherita-pizza',
                    'name': 'Margherita Pizza',
                    'quantity': 1,
                    'price': 16.99,
                    'total': 16.99
                }
            ],
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        tenant_ref.collection('orders').document(sample_order['id']).set(sample_order)
        print(f"   ✅ Created sample order")
        
        print(f"   🎉 Restaurant {restaurant['name']} setup complete!")
        print()
    
    print("🎉 Firebase authentication setup complete!")
    print()
    print("📱 Login Credentials for POS App:")
    print("====================================")
    
    for restaurant in restaurants:
        print(f"Restaurant: {restaurant['name']}")
        print(f"Email: {restaurant['email']}")
        print(f"Admin User ID: {restaurant['adminUserId']}")
        print(f"Admin Password: {restaurant['adminPassword']}")
        print(f"Admin PIN: 1234")
        print()
    
    print("🔗 After login, the app should connect to Firebase real-time sync!")

def main():
    """Main function"""
    try:
        initialize_firebase()
        setup_firebase_data()
    except Exception as e:
        print(f"❌ Error setting up Firebase authentication: {e}")
        raise

if __name__ == "__main__":
    main() 