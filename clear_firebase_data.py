#!/usr/bin/env python3
"""
Clear all Firebase data for fresh start
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

def clear_firebase_data():
    """Clear all data from Firebase collections"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        print("✅ Using default Firebase credentials")
        
        # Collections to clear
        collections_to_clear = [
            'restaurants',
            'global_restaurants', 
            'tenants',
            'devices',
            'orders',
            'menu_items',
            'categories',
            'users'
        ]
        
        print("🧹 Clearing all Firebase data...")
        
        for collection_name in collections_to_clear:
            try:
                print(f"   Clearing {collection_name}...")
                collection_ref = db.collection(collection_name)
                docs = collection_ref.stream()
                
                # Delete all documents in collection
                deleted_count = 0
                for doc in docs:
                    # For subcollections, delete them first
                    subcollections = doc.reference.collections()
                    for subcollection in subcollections:
                        subdocs = subcollection.stream()
                        for subdoc in subdocs:
                            subdoc.reference.delete()
                            deleted_count += 1
                    
                    # Delete the main document
                    doc.reference.delete()
                    deleted_count += 1
                
                print(f"   ✅ Deleted {deleted_count} documents from {collection_name}")
                
            except Exception as e:
                print(f"   ⚠️ Error clearing {collection_name}: {e}")
        
        print("🎉 Firebase data cleared successfully!")
        print("📱 You can now register a new restaurant and test the process")
        
    except Exception as e:
        print(f"❌ Error clearing Firebase data: {e}")
        return False
    
    return True

if __name__ == "__main__":
    print("🔥 Firebase Data Clear Tool")
    print("=" * 40)
    
    success = clear_firebase_data()
    
    if success:
        print("\n✅ Firebase data cleared successfully!")
        print("📱 Ready for fresh restaurant registration testing")
    else:
        print("\n❌ Failed to clear Firebase data")
        sys.exit(1) 