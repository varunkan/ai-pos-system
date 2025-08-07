#!/usr/bin/env python3
"""
Create Firebase Schema Mirror
=============================
Mirror the local database schema in Firebase with proper permissions and structure
"""

import firebase_admin
from firebase_admin import credentials, firestore
import json
from datetime import datetime
import hashlib

def hash_password(password):
    """Hash password using SHA-256"""
    return hashlib.sha256(password.encode()).hexdigest()

def main():
    print("🔧 Creating Firebase Schema Mirror")
    print("=" * 50)
    
    # Initialize Firebase
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)
    
    db = firestore.client()
    
    # Create comprehensive schema structure
    print("📊 Creating Firebase collections and documents...")
    
    # 1. Create sample restaurant with proper structure
    restaurant_id = "demo-restaurant-schema"
    restaurant_data = {
        "id": restaurant_id,
        "name": "Demo Restaurant Schema",
        "business_type": "Restaurant",
        "address": "123 Schema Street, Test City",
        "phone": "+1234567890",
        "email": "schema@restaurant.com",
        "admin_user_id": "admin",
        "admin_password": hash_password("admin123"),
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
        "is_active": True,
        "database_name": f"restaurant_{restaurant_id}",
        "settings": json.dumps({
            "tax_rate": 0.13,
            "currency": "USD",
            "timezone": "America/New_York",
            "auto_sync": True,
            "printer_enabled": True
        })
    }
    
    # Save to restaurants collection
    db.collection('restaurants').document(restaurant_id).set(restaurant_data)
    print(f"✅ Created restaurant: {restaurant_id}")
    
    # 2. Create global restaurant registration
    global_restaurant_data = {
        "restaurant_id": restaurant_id,
        "email": "schema@restaurant.com",
        "name": "Demo Restaurant Schema",
        "status": "active",
        "created_at": datetime.now().isoformat(),
        "last_login": datetime.now().isoformat(),
        "device_count": 0,
        "subscription_tier": "basic"
    }
    
    db.collection('global_restaurants').document(restaurant_id).set(global_restaurant_data)
    print(f"✅ Created global restaurant registration: {restaurant_id}")
    
    # 3. Create tenant structure with all collections
    tenant_ref = db.collection('tenants').document(restaurant_id)
    
    # Users subcollection
    users_data = {
        "admin": {
            "id": "admin",
            "name": "Admin User",
            "role": "admin",
            "pin": hash_password("1234"),
            "is_active": True,
            "admin_panel_access": True,
            "created_at": datetime.now().isoformat(),
            "last_login": datetime.now().isoformat()
        },
        "cashier1": {
            "id": "cashier1",
            "name": "Cashier One",
            "role": "cashier",
            "pin": hash_password("1111"),
            "is_active": True,
            "admin_panel_access": False,
            "created_at": datetime.now().isoformat(),
            "last_login": None
        },
        "manager1": {
            "id": "manager1",
            "name": "Manager One",
            "role": "manager",
            "pin": hash_password("2222"),
            "is_active": True,
            "admin_panel_access": True,
            "created_at": datetime.now().isoformat(),
            "last_login": None
        }
    }
    
    for user_id, user_data in users_data.items():
        tenant_ref.collection('users').document(user_id).set(user_data)
    print(f"✅ Created {len(users_data)} users in tenant")
    
    # Categories subcollection
    categories_data = {
        "cat-appetizers": {
            "id": "cat-appetizers",
            "name": "Appetizers",
            "description": "Starters and small plates",
            "image_url": "",
            "is_active": True,
            "sort_order": 1,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "cat-main-course": {
            "id": "cat-main-course",
            "name": "Main Course",
            "description": "Main dishes",
            "image_url": "",
            "is_active": True,
            "sort_order": 2,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "cat-desserts": {
            "id": "cat-desserts",
            "name": "Desserts",
            "description": "Sweet treats",
            "image_url": "",
            "is_active": True,
            "sort_order": 3,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "cat-beverages": {
            "id": "cat-beverages",
            "name": "Beverages",
            "description": "Drinks and refreshments",
            "image_url": "",
            "is_active": True,
            "sort_order": 4,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for cat_id, cat_data in categories_data.items():
        tenant_ref.collection('categories').document(cat_id).set(cat_data)
    print(f"✅ Created {len(categories_data)} categories in tenant")
    
    # Menu Items subcollection
    menu_items_data = {
        "item-bruschetta": {
            "id": "item-bruschetta",
            "name": "Bruschetta",
            "description": "Toasted bread with tomatoes and herbs",
            "price": 8.99,
            "category_id": "cat-appetizers",
            "image_url": "",
            "is_available": True,
            "tags": json.dumps(["vegetarian", "gluten-free"]),
            "custom_properties": json.dumps({}),
            "variants": json.dumps([]),
            "modifiers": json.dumps([]),
            "nutritional_info": json.dumps({}),
            "allergens": json.dumps([]),
            "preparation_time": 5,
            "is_vegetarian": True,
            "is_vegan": False,
            "is_gluten_free": True,
            "is_spicy": False,
            "spice_level": 0,
            "stock_quantity": 50,
            "low_stock_threshold": 5,
            "popularity_score": 0.0,
            "last_ordered": None,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "item-pizza": {
            "id": "item-pizza",
            "name": "Margherita Pizza",
            "description": "Classic pizza with tomato and mozzarella",
            "price": 16.99,
            "category_id": "cat-main-course",
            "image_url": "",
            "is_available": True,
            "tags": json.dumps(["vegetarian"]),
            "custom_properties": json.dumps({}),
            "variants": json.dumps([]),
            "modifiers": json.dumps([]),
            "nutritional_info": json.dumps({}),
            "allergens": json.dumps(["dairy"]),
            "preparation_time": 15,
            "is_vegetarian": True,
            "is_vegan": False,
            "is_gluten_free": False,
            "is_spicy": False,
            "spice_level": 0,
            "stock_quantity": 30,
            "low_stock_threshold": 5,
            "popularity_score": 0.0,
            "last_ordered": None,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "item-pasta": {
            "id": "item-pasta",
            "name": "Chicken Alfredo",
            "description": "Creamy pasta with grilled chicken",
            "price": 18.99,
            "category_id": "cat-main-course",
            "image_url": "",
            "is_available": True,
            "tags": json.dumps([]),
            "custom_properties": json.dumps({}),
            "variants": json.dumps([]),
            "modifiers": json.dumps([]),
            "nutritional_info": json.dumps({}),
            "allergens": json.dumps(["dairy", "gluten"]),
            "preparation_time": 12,
            "is_vegetarian": False,
            "is_vegan": False,
            "is_gluten_free": False,
            "is_spicy": False,
            "spice_level": 0,
            "stock_quantity": 25,
            "low_stock_threshold": 5,
            "popularity_score": 0.0,
            "last_ordered": None,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "item-tiramisu": {
            "id": "item-tiramisu",
            "name": "Tiramisu",
            "description": "Classic Italian dessert",
            "price": 9.99,
            "category_id": "cat-desserts",
            "image_url": "",
            "is_available": True,
            "tags": json.dumps([]),
            "custom_properties": json.dumps({}),
            "variants": json.dumps([]),
            "modifiers": json.dumps([]),
            "nutritional_info": json.dumps({}),
            "allergens": json.dumps(["dairy", "eggs"]),
            "preparation_time": 0,
            "is_vegetarian": True,
            "is_vegan": False,
            "is_gluten_free": False,
            "is_spicy": False,
            "spice_level": 0,
            "stock_quantity": 20,
            "low_stock_threshold": 3,
            "popularity_score": 0.0,
            "last_ordered": None,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "item-latte": {
            "id": "item-latte",
            "name": "Iced Latte",
            "description": "Refreshing iced coffee drink",
            "price": 4.99,
            "category_id": "cat-beverages",
            "image_url": "",
            "is_available": True,
            "tags": json.dumps(["cold", "caffeinated"]),
            "custom_properties": json.dumps({}),
            "variants": json.dumps([]),
            "modifiers": json.dumps([]),
            "nutritional_info": json.dumps({}),
            "allergens": json.dumps(["dairy"]),
            "preparation_time": 3,
            "is_vegetarian": True,
            "is_vegan": False,
            "is_gluten_free": True,
            "is_spicy": False,
            "spice_level": 0,
            "stock_quantity": 100,
            "low_stock_threshold": 10,
            "popularity_score": 0.0,
            "last_ordered": None,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for item_id, item_data in menu_items_data.items():
        tenant_ref.collection('menu_items').document(item_id).set(item_data)
    print(f"✅ Created {len(menu_items_data)} menu items in tenant")
    
    # Tables subcollection
    tables_data = {
        "table-1": {
            "id": "table-1",
            "number": 1,
            "capacity": 4,
            "status": "available",
            "user_id": None,
            "customer_name": None,
            "customer_phone": None,
            "customer_email": None,
            "metadata": json.dumps({}),
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "table-2": {
            "id": "table-2",
            "number": 2,
            "capacity": 6,
            "status": "available",
            "user_id": None,
            "customer_name": None,
            "customer_phone": None,
            "customer_email": None,
            "metadata": json.dumps({}),
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        },
        "table-3": {
            "id": "table-3",
            "number": 3,
            "capacity": 2,
            "status": "available",
            "user_id": None,
            "customer_name": None,
            "customer_phone": None,
            "customer_email": None,
            "metadata": json.dumps({}),
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for table_id, table_data in tables_data.items():
        tenant_ref.collection('tables').document(table_id).set(table_data)
    print(f"✅ Created {len(tables_data)} tables in tenant")
    
    # Sample order
    order_id = "order-schema-test"
    order_data = {
        "id": order_id,
        "order_number": "SCHEMA-001",
        "status": "pending",
        "type": "dine_in",
        "table_id": "table-1",
        "user_id": "cashier1",
        "customer_name": "Schema Test Customer",
        "customer_phone": "+1234567890",
        "customer_email": "test@schema.com",
        "customer_address": "",
        "special_instructions": "Test order for schema validation",
        "subtotal": 25.98,
        "tax_amount": 3.38,
        "tip_amount": 5.20,
        "hst_amount": 0.0,
        "discount_amount": 0.0,
        "gratuity_amount": 0.0,
        "total_amount": 34.56,
        "payment_method": "cash",
        "payment_status": "pending",
        "payment_transaction_id": None,
        "order_time": datetime.now().isoformat(),
        "estimated_ready_time": None,
        "actual_ready_time": None,
        "served_time": None,
        "completed_time": None,
        "is_urgent": False,
        "priority": 0,
        "assigned_to": None,
        "custom_fields": json.dumps({}),
        "metadata": json.dumps({}),
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat()
    }
    
    tenant_ref.collection('orders').document(order_id).set(order_data)
    print(f"✅ Created sample order: {order_id}")
    
    # Order items
    order_items_data = {
        "item-1": {
            "id": "item-1",
            "order_id": order_id,
            "menu_item_id": "item-bruschetta",
            "name": "Bruschetta",
            "quantity": 2,
            "unit_price": 8.99,
            "total_price": 17.98,
            "notes": "",
            "modifiers": json.dumps([]),
            "created_at": datetime.now().isoformat()
        },
        "item-2": {
            "id": "item-2",
            "order_id": order_id,
            "menu_item_id": "item-latte",
            "name": "Iced Latte",
            "quantity": 1,
            "unit_price": 4.99,
            "total_price": 4.99,
            "notes": "Extra ice",
            "modifiers": json.dumps([]),
            "created_at": datetime.now().isoformat()
        }
    }
    
    for item_id, item_data in order_items_data.items():
        tenant_ref.collection('orders').document(order_id).collection('items').document(item_id).set(item_data)
    print(f"✅ Created {len(order_items_data)} order items")
    
    # Inventory subcollection
    inventory_data = {
        "inv-tomatoes": {
            "id": "inv-tomatoes",
            "name": "Fresh Tomatoes",
            "description": "Ripe tomatoes for bruschetta",
            "current_stock": 50,
            "min_stock": 10,
            "max_stock": 100,
            "cost_price": 2.50,
            "selling_price": None,
            "unit": "kg",
            "supplier_id": "supplier-1",
            "category": "produce",
            "is_active": True,
            "last_updated": datetime.now().isoformat(),
            "created_at": datetime.now().isoformat()
        },
        "inv-bread": {
            "id": "inv-bread",
            "name": "Artisan Bread",
            "description": "Fresh baked bread for bruschetta",
            "current_stock": 20,
            "min_stock": 5,
            "max_stock": 50,
            "cost_price": 3.00,
            "selling_price": None,
            "unit": "loaves",
            "supplier_id": "supplier-2",
            "category": "bakery",
            "is_active": True,
            "last_updated": datetime.now().isoformat(),
            "created_at": datetime.now().isoformat()
        }
    }
    
    for inv_id, inv_data in inventory_data.items():
        tenant_ref.collection('inventory').document(inv_id).set(inv_data)
    print(f"✅ Created {len(inventory_data)} inventory items")
    
    # Customers subcollection
    customers_data = {
        "cust-1": {
            "id": "cust-1",
            "name": "John Doe",
            "email": "john@example.com",
            "phone": "+1234567890",
            "address": "123 Main St, City",
            "loyalty_points": 150,
            "join_date": datetime.now().isoformat(),
            "preferences": json.dumps({"dietary_restrictions": ["vegetarian"]}),
            "is_active": True,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for cust_id, cust_data in customers_data.items():
        tenant_ref.collection('customers').document(cust_id).set(cust_data)
    print(f"✅ Created {len(customers_data)} customers")
    
    # Reservations subcollection
    reservations_data = {
        "res-1": {
            "id": "res-1",
            "customer_name": "Jane Smith",
            "customer_phone": "+1234567891",
            "customer_email": "jane@example.com",
            "party_size": 4,
            "reservation_date": "2024-01-15",
            "reservation_time": "19:00",
            "table_id": "table-2",
            "status": "confirmed",
            "special_requests": "Window seat preferred",
            "notes": "",
            "created_by": "admin",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for res_id, res_data in reservations_data.items():
        tenant_ref.collection('reservations').document(res_id).set(res_data)
    print(f"✅ Created {len(reservations_data)} reservations")
    
    # Printer configurations subcollection
    printer_configs_data = {
        "printer-kitchen": {
            "id": "printer-kitchen",
            "name": "Kitchen Printer",
            "description": "Main kitchen printer",
            "type": "wifi",
            "model": "epsonTMGeneric",
            "ip_address": "192.168.1.100",
            "port": 9100,
            "bluetooth_address": None,
            "is_active": True,
            "connection_status": "connected",
            "last_connected": datetime.now().isoformat(),
            "last_health_check": datetime.now().isoformat(),
            "print_quality": 3,
            "paper_width": 80,
            "station_type": "kitchen",
            "cloud_id": None,
            "global_access": True,
            "font_size_multiplier": 3,
            "enhanced_formatting": True,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for printer_id, printer_data in printer_configs_data.items():
        tenant_ref.collection('printer_configurations').document(printer_id).set(printer_data)
    print(f"✅ Created {len(printer_configs_data)} printer configurations")
    
    # Printer assignments subcollection
    printer_assignments_data = {
        "assign-1": {
            "id": "assign-1",
            "printer_id": "printer-kitchen",
            "assignment_type": "category",
            "target_id": "cat-main-course",
            "target_name": "Main Course",
            "priority": 1,
            "is_active": True,
            "cloud_id": None,
            "global_sync": True,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for assign_id, assign_data in printer_assignments_data.items():
        tenant_ref.collection('printer_assignments').document(assign_id).set(assign_data)
    print(f"✅ Created {len(printer_assignments_data)} printer assignments")
    
    # Order logs subcollection
    order_logs_data = {
        "log-1": {
            "id": "log-1",
            "order_id": order_id,
            "action": "created",
            "user_id": "cashier1",
            "timestamp": datetime.now().isoformat(),
            "details": json.dumps({"status": "pending", "total_amount": 34.56}),
            "device_id": "device-schema-test",
            "ip_address": "192.168.1.100"
        }
    }
    
    for log_id, log_data in order_logs_data.items():
        tenant_ref.collection('order_logs').document(log_id).set(log_data)
    print(f"✅ Created {len(order_logs_data)} order logs")
    
    # App metadata subcollection
    app_metadata_data = {
        "database_version": {
            "key": "database_version",
            "value": "1.0.0",
            "type": "string",
            "description": "Current database schema version",
            "is_system": True,
            "updated_at": datetime.now().isoformat()
        },
        "last_migration": {
            "key": "last_migration",
            "value": datetime.now().isoformat(),
            "type": "string",
            "description": "Last migration timestamp",
            "is_system": True,
            "updated_at": datetime.now().isoformat()
        }
    }
    
    for meta_id, meta_data in app_metadata_data.items():
        tenant_ref.collection('app_metadata').document(meta_id).set(meta_data)
    print(f"✅ Created {len(app_metadata_data)} app metadata entries")
    
    print("\n🎉 Firebase Schema Creation Complete!")
    print("=" * 50)
    print(f"📊 Created comprehensive schema for restaurant: {restaurant_id}")
    print(f"👥 Users: {len(users_data)}")
    print(f"📂 Categories: {len(categories_data)}")
    print(f"🍽️ Menu Items: {len(menu_items_data)}")
    print(f"🪑 Tables: {len(tables_data)}")
    print(f"📋 Orders: 1 (with items)")
    print(f"📦 Inventory: {len(inventory_data)}")
    print(f"👤 Customers: {len(customers_data)}")
    print(f"📅 Reservations: {len(reservations_data)}")
    print(f"🖨️ Printer Configs: {len(printer_configs_data)}")
    print(f"🔗 Printer Assignments: {len(printer_assignments_data)}")
    print(f"📝 Order Logs: {len(order_logs_data)}")
    print(f"⚙️ App Metadata: {len(app_metadata_data)}")
    
    print("\n🔐 Login Credentials:")
    print("Restaurant Email: schema@restaurant.com")
    print("Admin User ID: admin")
    print("Admin Password: admin123")
    print("Admin PIN: 1234")
    print("Cashier PIN: 1111")
    print("Manager PIN: 2222")
    
    print("\n✅ Firebase schema is now ready for the POS app!")

if __name__ == "__main__":
    main() 