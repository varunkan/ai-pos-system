import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../firebase_options.dart';

class FirebaseConfig {
  static FirebaseFirestore? _firestore;
  static FirebaseAuth? _auth;
  static FirebaseStorage? _storage;
  static String? _currentTenantId;
  static bool _isInitialized = false;
  static String? _lastError;
  
  // Initialize Firebase with bulletproof error handling
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Firebase already initialized');
      return;
    }
    
    try {
      print('🔥 Starting bulletproof Firebase initialization...');
      
      // Check if Firebase is already initialized
      if (Firebase.apps.isNotEmpty) {
        print('✅ Firebase already initialized by main.dart');
        _isInitialized = true;
        _initializeServices();
        return;
      }
      
      print('🔧 Initializing Firebase with default options...');
      
      // Initialize Firebase with default options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      print('✅ Firebase core initialized successfully');
      
      // Initialize services
      _initializeServices();
      
      _isInitialized = true;
      _lastError = null;
      print('✅ Firebase initialization completed successfully');
      
    } catch (e) {
      _lastError = e.toString();
      print('❌ Firebase initialization failed: $e');
      print('📱 App will continue in offline mode');
      
      // Don't rethrow - allow app to continue in offline mode
      _isInitialized = false;
    }
  }
  
  static void _initializeServices() {
    try {
      print('🔧 Initializing Firebase services...');
      
      // Initialize Firestore
      _firestore = FirebaseFirestore.instance;
      print('✅ Firestore initialized');
      
      // Enable offline persistence
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('✅ Firestore settings configured');
      
      // Initialize Auth
      _auth = FirebaseAuth.instance;
      print('✅ Firebase Auth initialized');
      
      // Initialize Storage
      _storage = FirebaseStorage.instance;
      print('✅ Firebase Storage initialized');
      
    } catch (e) {
      print('❌ Error initializing Firebase services: $e');
      _lastError = e.toString();
    }
  }
  
  // Getters
  static bool get isInitialized => _isInitialized;
  static FirebaseFirestore? get firestore => _firestore;
  static FirebaseAuth? get auth => _auth;
  static FirebaseStorage? get storage => _storage;
  static String? get currentTenantId => _currentTenantId;
  
  static Future<void> setCurrentTenantId(String? tenantId) async {
    _currentTenantId = tenantId;
    print('🏢 Current tenant ID set to: $tenantId');
  }
  static String? get lastError => _lastError;

  // Methods for tenant management
  static void setCurrentTenant(String tenantId) {
    _currentTenantId = tenantId;
    print('🏢 Tenant ID set to: $_currentTenantId');
  }

  static String? getCurrentTenantId() {
    return _currentTenantId;
  }

  // Collection references for the current tenant
  static CollectionReference<Map<String, dynamic>>? get usersCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Users collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('users');
  }

  static CollectionReference<Map<String, dynamic>>? get categoriesCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Categories collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('categories');
  }

  static CollectionReference<Map<String, dynamic>>? get menuItemsCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Menu items collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('menu_items');
  }

  static CollectionReference<Map<String, dynamic>>? get ordersCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Orders collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('orders');
  }

  static CollectionReference<Map<String, dynamic>>? get tablesCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Tables collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('tables');
  }

  static CollectionReference<Map<String, dynamic>>? get inventoryCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Inventory collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('inventory');
  }

  static CollectionReference<Map<String, dynamic>>? get activityLogCollection {
    if (_firestore == null || _currentTenantId == null) {
      print('⚠️ Activity log collection not available - Firebase: ${_firestore != null}, Tenant: $_currentTenantId');
      return null;
    }
    return _firestore!.collection('tenants').doc(_currentTenantId!).collection('activity_log');
  }

  // Global collections
  static CollectionReference<Map<String, dynamic>>? get restaurantsCollection {
    if (_firestore == null) {
      print('⚠️ Restaurants collection not available - Firebase not initialized');
      return null;
    }
    return _firestore!.collection('restaurants');
  }

  static CollectionReference<Map<String, dynamic>>? get globalRestaurantsCollection {
    if (_firestore == null) {
      print('⚠️ Global restaurants collection not available - Firebase not initialized');
      return null;
    }
    return _firestore!.collection('global_restaurants');
  }

  static CollectionReference<Map<String, dynamic>>? get devicesCollection {
    if (_firestore == null) {
      print('⚠️ Devices collection not available - Firebase not initialized');
      return null;
    }
    return _firestore!.collection('devices');
  }

  static CollectionReference<Map<String, dynamic>>? get globalUsersCollection {
    if (_firestore == null) {
      print('⚠️ Global users collection not available - Firebase not initialized');
      return null;
    }
    return _firestore!.collection('global_users');
  }

  static CollectionReference<Map<String, dynamic>>? get tenantsCollection {
    if (_firestore == null) {
      print('⚠️ Tenants collection not available - Firebase not initialized');
      return null;
    }
    return _firestore!.collection('tenants');
  }
  
  // Health check method
  static Future<bool> healthCheck() async {
    try {
      if (!_isInitialized) {
        print('❌ Firebase not initialized');
        return false;
      }
      
      if (_firestore == null) {
        print('❌ Firestore not available');
        return false;
      }
      
      // Test a simple read operation
      await _firestore!.collection('restaurants').limit(1).get();
      print('✅ Firebase health check passed');
      return true;
      
    } catch (e) {
      print('❌ Firebase health check failed: $e');
      return false;
    }
  }
  
  // Force reinitialize Firebase (for testing/debugging)
  static Future<void> forceReinitialize() async {
    print('🔄 Force reinitializing Firebase...');
    _isInitialized = false;
    _firestore = null;
    _auth = null;
    _storage = null;
    _currentTenantId = null;
    _lastError = null;
    await initialize();
  }
} 