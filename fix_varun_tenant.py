#!/usr/bin/env python3
"""
Fix Tenant Structure for varun.kan@gmail.com
Creates the missing tenant structure document and ensures all data is properly set up
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

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

def fix_varun_tenant():
    """Fix the tenant structure for varun.kan@gmail.com"""
    print("🔧 Fixing Tenant Structure for varun.kan@gmail.com")
    print("=" * 55)
    
    db = firestore.client()
    tenant_id = '98213ca9-90b3-4f77-8aa1-488c0cbbd9b6'
    
    # Create tenant structure document
    tenant_data = {
        'id': tenant_id,
        'name': 'Test Restaurant',
        'email': 'varun.kan@gmail.com',
        'created_at': datetime.now().isoformat(),
        'updated_at': datetime.now().isoformat(),
        'is_active': True,
        'settings': {
            'timezone': 'UTC',
            'currency': 'USD',
            'tax_rate': 0.08,
            'auto_logout_minutes': 30
        }
    }
    
    # Create the tenant document
    db.collection('tenants').document(tenant_id).set(tenant_data)
    print("✅ Created tenant structure document")
    
    # Verify the tenant structure now exists
    tenant_doc = db.collection('tenants').document(tenant_id).get()
    if tenant_doc.exists:
        print("✅ Tenant structure verified")
    else:
        print("❌ Tenant structure still missing")
        return False
    
    # Check all data is present
    users = list(db.collection('tenants').document(tenant_id).collection('users').stream())
    categories = list(db.collection('tenants').document(tenant_id).collection('categories').stream())
    menu_items = list(db.collection('tenants').document(tenant_id).collection('menu_items').stream())
    
    print(f"👥 Users: {len(users)}")
    print(f"📂 Categories: {len(categories)}")
    print(f"🍽️ Menu Items: {len(menu_items)}")
    
    print("\n📋 FINAL LOGIN CREDENTIALS:")
    print("=" * 35)
    print("Restaurant Email: varun.kan@gmail.com")
    print("User ID: admin")
    print("Password: admin123")
    print("PIN: 1234")
    
    print("\n✅ Tenant structure fixed successfully!")
    return True

def main():
    """Main function"""
    try:
        initialize_firebase()
        fix_varun_tenant()
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    main() 