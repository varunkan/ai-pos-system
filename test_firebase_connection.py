#!/usr/bin/env python3
"""
Test Firebase Connection and Permissions
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os
import sys

def test_firebase_connection():
    """Test Firebase connection and permissions"""
    
    try:
        # Initialize Firebase
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        print("✅ Using default Firebase credentials")
        
        # Test basic connection
        print("🔍 Testing Firebase connection...")
        
        # Test read access
        print("📖 Testing read access...")
        restaurants = list(db.collection('restaurants').limit(1).stream())
        print(f"✅ Successfully read {len(restaurants)} restaurant documents")
        
        # Test write access
        print("📝 Testing write access...")
        test_doc = db.collection('test_permissions').document('test')
        test_doc.set({
            'test': True,
            'timestamp': firestore.SERVER_TIMESTAMP
        })
        print("✅ Successfully wrote to test document")
        
        # Clean up
        test_doc.delete()
        print("✅ Test document cleaned up")
        
        print("🎉 Firebase connection test PASSED!")
        return True
        
    except Exception as e:
        print(f"❌ Firebase connection test failed: {e}")
        return False

if __name__ == "__main__":
    test_firebase_connection() 