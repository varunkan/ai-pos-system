import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/restaurant.dart';
import '../models/user.dart' as pos_user;
import '../models/order.dart' as pos_order;
import '../models/menu_item.dart';
import '../models/category.dart' as pos_category;
import '../models/inventory_item.dart';
import '../models/table.dart' as pos_table;
import '../models/activity_log.dart' as pos_activity_log;

import '../services/database_service.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../services/order_log_service.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';
import '../services/table_service.dart';
import '../config/firebase_config.dart';

/// UNIFIED FIREBASE SYNC SERVICE
/// Single source of truth for all Firebase synchronization operations
/// Ensures consistent schema and principles across all sync operations
class UnifiedFirebaseSyncService extends ChangeNotifier {
  static UnifiedFirebaseSyncService? _instance;
  static final _uuid = const Uuid();
  
  // Firebase instances
  late FirebaseFirestore _firestore;
  late firebase_auth.FirebaseAuth _auth;
  
  // Current restaurant and session
  Restaurant? _currentRestaurant;
  RestaurantSession? _currentSession;
  
  // Service instances
  DatabaseService? _tenantDb;
  MenuService? _menuService;
  OrderService? _orderService;
  InventoryService? _inventoryService;
  UserService? _userService;
  TableService? _tableService;
  
  // Real-time listeners
  StreamSubscription<DocumentSnapshot>? _restaurantListener;
  StreamSubscription<QuerySnapshot>? _ordersListener;
  StreamSubscription<QuerySnapshot>? _inventoryListener;
  StreamSubscription<QuerySnapshot>? _usersListener;
  StreamSubscription<QuerySnapshot>? _menuItemsListener;
  StreamSubscription<QuerySnapshot>? _categoriesListener;
  StreamSubscription<QuerySnapshot>? _tablesListener;
  StreamSubscription<QuerySnapshot>? _activeDevicesListener;
  StreamSubscription<QuerySnapshot>? _syncEventsListener;
  
  // Device management
  String? _deviceId;
  String? _deviceName;
  String? _deviceType;
  DateTime? _lastActivity;
  
  // Sync state
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  DateTime? _lastFullSyncTime;
  
  // Data caches for offline support
  final Map<String, dynamic> _dataCache = {};
  final Set<String> _activeDevices = {};
  final List<Map<String, dynamic>> _pendingChanges = [];
  
  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  
  // Background sync
  Timer? _backgroundSyncTimer;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  
  // Callbacks for UI updates
  Function()? _onOrdersUpdated;
  Function()? _onInventoryUpdated;
  Function()? _onUsersUpdated;
  Function()? _onMenuItemsUpdated;
  Function()? _onCategoriesUpdated;
  Function()? _onTablesUpdated;
  Function()? _onSessionsUpdated;
  Function(String)? _onSyncProgress;
  Function(String)? _onSyncError;
  
  // Debounce mechanism to prevent infinite loops
  Timer? _sessionsUpdateDebounceTimer;
  Set<String> _lastActiveDevices = {};
  
  factory UnifiedFirebaseSyncService() {
    _instance ??= UnifiedFirebaseSyncService._internal();
    return _instance!;
  }
  
  UnifiedFirebaseSyncService._internal();
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  DateTime? get lastFullSyncTime => _lastFullSyncTime;
  Set<String> get activeDevices => Set.unmodifiable(_activeDevices);
  bool get isOnline => _isOnline;
  
  /// Initialize the unified sync service
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing Unified Firebase Sync Service...');
      
      // Check if Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized - sync will be limited');
        _isInitialized = true; // Mark as initialized but limited
        return;
      }
      
      _firestore = FirebaseFirestore.instance;
      _auth = firebase_auth.FirebaseAuth.instance;
      
      // Enable offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Initialize device information
      await _initializeDeviceInfo();
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      // Start background processes
      _startBackgroundProcesses();
      
      _isInitialized = true;
      debugPrint('✅ Unified Firebase Sync Service initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize Unified Firebase Sync Service: $e');
      _onSyncError?.call('Failed to initialize: $e');
      _isInitialized = true; // Mark as initialized but limited
    }
  }
  
  /// Initialize device information
  Future<void> _initializeDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get or generate device ID
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      _deviceId = _uuid.v4();
      await prefs.setString('device_id', _deviceId!);
    }
    
    // Get device name and type
    _deviceName = prefs.getString('device_name') ?? 'Unknown Device';
    _deviceType = prefs.getString('device_type') ?? 'mobile';
    
    debugPrint('📱 Device initialized: $_deviceName ($_deviceType) - $_deviceId');
  }
  
  /// Connect to restaurant for sync operations
  Future<void> connectToRestaurant(Restaurant restaurant, RestaurantSession currentUserSession) async {
    try {
      debugPrint('🔄 Connecting to restaurant for sync: ${restaurant.name}');
      
      // Set current tenant ID for Firebase operations
      FirebaseConfig.setCurrentTenantId(restaurant.email);
      
      _currentRestaurant = restaurant;
      _currentSession = currentUserSession;
      
      // Initialize Firebase sync
      await _initializeFirebaseSync();
      
      debugPrint('✅ Connected to restaurant: ${restaurant.name}');
    } catch (e) {
      debugPrint('❌ Failed to connect to restaurant: $e');
      throw Exception('Failed to connect to restaurant: $e');
    }
  }
  
  /// Initialize Firebase sync
  Future<void> _initializeFirebaseSync() async {
    try {
      debugPrint('🔄 Initializing Firebase sync...');
      
      // Register active device
      await _registerActiveDevice();
      
      // Perform initial data synchronization
      await _performInitialSync();
      
      // Start real-time listeners
      await _startRealtimeListeners();
      
      _isConnected = true;
      _lastSyncTime = DateTime.now();
      
      debugPrint('✅ Firebase sync initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase sync: $e');
      throw e;
    }
  }
  
  /// Disconnect from current restaurant
  Future<void> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting from restaurant...');
      
      // Stop all listeners
      await _stopAllListeners();
      
      // Unregister active device
      await _unregisterActiveDevice();
      
      // Clear current session
      _currentRestaurant = null;
      _currentSession = null;
      _isConnected = false;
      
      debugPrint('✅ Disconnected from restaurant');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error during disconnect: $e');
    }
  }
  
  /// Register active device with error handling
  Future<void> _registerActiveDevice() async {
    if (_currentRestaurant == null || _deviceId == null) return;
    
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Check if tenant document exists first
      final tenantDoc = await _firestore.collection('tenants').doc(tenantId).get();
      if (!tenantDoc.exists) {
        debugPrint('⚠️ Tenant document does not exist, creating it...');
        await _firestore.collection('tenants').doc(tenantId).set({
          'tenantId': tenantId,
          'restaurantId': _currentRestaurant!.id,
          'restaurantName': _currentRestaurant!.name,
          'restaurantEmail': _currentRestaurant!.email,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'isActive': true,
        });
      }
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('active_devices')
          .doc(_deviceId)
          .set({
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'deviceType': _deviceType,
        'isActive': true,
        'lastActivity': DateTime.now().toIso8601String(),
        'userId': _currentSession?.userId,
        'userName': _currentSession?.userName,
      });
      
      debugPrint('📱 Registered device: $_deviceId (tenant: $tenantId)');
    } catch (e) {
      debugPrint('❌ Failed to register device: $e');
    }
  }
  
  /// Unregister active device
  Future<void> _unregisterActiveDevice() async {
    if (_currentRestaurant == null || _deviceId == null) return;
    
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('active_devices')
          .doc(_deviceId)
          .delete();
      
      debugPrint('📱 Unregistered device: $_deviceId (tenant: $tenantId)');
    } catch (e) {
      debugPrint('❌ Failed to unregister device: $e');
    }
  }
  
  /// Perform initial data synchronization
  Future<void> _performInitialSync() async {
    if (_isSyncing) return;
    
    try {
      _isSyncing = true;
      _onSyncProgress?.call('🔄 Performing initial data synchronization...');
      
      // Sync all data types
      await Future.wait([
        _syncCategories(),
        _syncMenuItems(),
        _syncUsers(),
        _syncTables(),
        _syncInventory(),
        _syncOrders(),
      ]);
      
      _lastFullSyncTime = DateTime.now();
      _onSyncProgress?.call('✅ Initial synchronization completed');
      
    } catch (e) {
      debugPrint('❌ Initial sync failed: $e');
      _onSyncError?.call('Initial sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Perform full synchronization
  Future<void> performFullSync() async {
    if (_isSyncing) return;
    
    try {
      _isSyncing = true;
      _onSyncProgress?.call('🔄 Performing full data synchronization...');
      
      // Sync all data types
      await Future.wait([
        _syncCategories(),
        _syncMenuItems(),
        _syncUsers(),
        _syncTables(),
        _syncInventory(),
        _syncOrders(),
      ]);
      
      _lastFullSyncTime = DateTime.now();
      _onSyncProgress?.call('✅ Full synchronization completed');
      
    } catch (e) {
      debugPrint('❌ Full sync failed: $e');
      _onSyncError?.call('Full sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Set callbacks for UI updates
  void setCallbacks({
    Function()? onOrdersUpdated,
    Function()? onInventoryUpdated,
    Function()? onUsersUpdated,
    Function()? onMenuItemsUpdated,
    Function()? onCategoriesUpdated,
    Function()? onTablesUpdated,
    Function()? onSessionsUpdated,
    Function(String)? onSyncProgress,
    Function(String)? onSyncError,
  }) {
    _onOrdersUpdated = onOrdersUpdated;
    _onInventoryUpdated = onInventoryUpdated;
    _onUsersUpdated = onUsersUpdated;
    _onMenuItemsUpdated = onMenuItemsUpdated;
    _onCategoriesUpdated = onCategoriesUpdated;
    _onTablesUpdated = onTablesUpdated;
    _onSessionsUpdated = onSessionsUpdated;
    _onSyncProgress = onSyncProgress;
    _onSyncError = onSyncError;
  }
  
  /// Start real-time listeners for all data types
  Future<void> _startRealtimeListeners() async {
    try {
      debugPrint('👂 Starting real-time listeners...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final tenantRef = _firestore.collection('tenants').doc(tenantId);
      
      // Listen for active devices
      _activeDevicesListener = tenantRef
          .collection('active_devices')
          .snapshots()
          .listen(_handleActiveDevicesUpdate);
      
      // Listen for sync events
      _syncEventsListener = tenantRef
          .collection('sync_events')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen(_handleSyncEvents);
      
      // Listen for data changes
      _setupDataListeners(tenantRef);
      
      debugPrint('✅ Real-time listeners started');
    } catch (e) {
      debugPrint('❌ Failed to start real-time listeners: $e');
    }
  }
  
  /// Set up data listeners for all collections
  void _setupDataListeners(DocumentReference tenantRef) {
    // Categories listener
    _categoriesListener = tenantRef
        .collection('categories')
        .snapshots()
        .listen((snapshot) => _handleCategoriesUpdate(snapshot));
    
    // Menu items listener
    _menuItemsListener = tenantRef
        .collection('menu_items')
        .snapshots()
        .listen((snapshot) => _handleMenuItemsUpdate(snapshot));
    
    // Orders listener
    _ordersListener = tenantRef
        .collection('orders')
        .where('status', whereIn: ['pending', 'preparing', 'ready'])
        .snapshots()
        .listen((snapshot) => _handleOrdersUpdate(snapshot));
    
    // Inventory listener
    _inventoryListener = tenantRef
        .collection('inventory')
        .snapshots()
        .listen((snapshot) => _handleInventoryUpdate(snapshot));
    
    // Users listener
    _usersListener = tenantRef
        .collection('users')
        .snapshots()
        .listen((snapshot) => _handleUsersUpdate(snapshot));
    
    // Tables listener
    _tablesListener = tenantRef
        .collection('tables')
        .snapshots()
        .listen((snapshot) => _handleTablesUpdate(snapshot));
  }
  
  /// Handle active devices updates
  void _handleActiveDevicesUpdate(QuerySnapshot snapshot) {
    final devices = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] == true) {
        devices.add(doc.id);
      }
    }
    
    // Check if the devices list has actually changed
    if (devices.length == _lastActiveDevices.length && 
        devices.every((device) => _lastActiveDevices.contains(device))) {
      // No change detected - skip update to prevent infinite loop
      debugPrint('📱 Active devices unchanged: ${devices.length} devices (skipping update)');
      return;
    }
    
    _activeDevices.clear();
    _activeDevices.addAll(devices);
    
    // Update last known devices
    _lastActiveDevices.clear();
    _lastActiveDevices.addAll(devices);
    
    debugPrint('📱 Active devices updated: ${_activeDevices.length} devices');
    
    // Debounce the sessions update to prevent rapid successive calls
    _sessionsUpdateDebounceTimer?.cancel();
    _sessionsUpdateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _onSessionsUpdated?.call();
      notifyListeners();
    });
  }
  
  /// Handle sync events
  void _handleSyncEvents(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final event = change.doc.data() as Map<String, dynamic>;
        _processSyncEvent(event);
      }
    }
  }
  
  /// Process sync events
  void _processSyncEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String?;
    final sourceDevice = event['sourceDevice'] as String?;
    
    // Ignore events from this device
    if (sourceDevice == _deviceId) return;
    
    debugPrint('🔄 Processing sync event: $eventType from $sourceDevice');
    
    switch (eventType) {
      case 'order_created':
      case 'order_updated':
        _onOrdersUpdated?.call();
        break;
      case 'inventory_updated':
        _onInventoryUpdated?.call();
        break;
      case 'menu_updated':
        _onMenuItemsUpdated?.call();
        break;
      case 'user_updated':
        _onUsersUpdated?.call();
        break;
      case 'table_updated':
        _onTablesUpdated?.call();
        break;
    }
  }
  
  /// Handle categories update
  void _handleCategoriesUpdate(QuerySnapshot snapshot) {
    debugPrint('🔄 Categories updated from cloud');
    _onCategoriesUpdated?.call();
  }
  
  /// Handle menu items update
  void _handleMenuItemsUpdate(QuerySnapshot snapshot) {
    debugPrint('🔄 Menu items updated from cloud');
    _onMenuItemsUpdated?.call();
  }
  
  /// Handle orders update
  void _handleOrdersUpdate(QuerySnapshot snapshot) {
    debugPrint('🔄 Orders updated from cloud');
    _onOrdersUpdated?.call();
  }
  
  /// Handle inventory update
  void _handleInventoryUpdate(QuerySnapshot snapshot) {
    debugPrint('🔄 Inventory updated from cloud');
    _onInventoryUpdated?.call();
  }
  
  /// Handle users update
  void _handleUsersUpdate(QuerySnapshot snapshot) {
    debugPrint('🔄 Users updated from cloud');
    _onUsersUpdated?.call();
  }
  
  /// Handle tables update
  void _handleTablesUpdate(QuerySnapshot snapshot) {
    debugPrint('🔄 Tables updated from cloud');
    _onTablesUpdated?.call();
  }
  
  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (wasOnline != _isOnline) {
        debugPrint('🌐 Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
        
        if (_isOnline) {
          _syncPendingChanges();
        }
        
        notifyListeners();
      }
    });
  }
  
  /// Start background processes
  void _startBackgroundProcesses() {
    // Background sync every 5 minutes
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _isConnected) {
        _syncPendingChanges();
      }
    });
    
    // Heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        _updateHeartbeat();
      }
    });
    
    // Cleanup every hour
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupOldData();
    });
  }
  
  /// Update device heartbeat
  Future<void> _updateHeartbeat() async {
    if (!_isConnected || _currentRestaurant == null || _deviceId == null) return;
    
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final deviceDoc = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('active_devices')
          .doc(_deviceId);
      
      await deviceDoc.set({
        'lastActivity': DateTime.now().toIso8601String(),
        'isActive': true,
      }, SetOptions(merge: true));
      
    } catch (e) {
      // Don't log every heartbeat failure to avoid spam
      if (e.toString().contains('permission-denied')) {
        debugPrint('⚠️ Firebase permission denied for heartbeat - continuing in offline mode');
        _isConnected = false;
        notifyListeners();
      } else {
        debugPrint('❌ Failed to update heartbeat: $e');
      }
    }
  }
  
  /// Cleanup old data
  void _cleanupOldData() {
    // Remove old sync events (older than 24 hours)
    // This is handled by Firebase TTL if configured
    debugPrint('🧹 Cleanup completed');
  }
  
  /// Stop all listeners
  Future<void> _stopAllListeners() async {
    await _restaurantListener?.cancel();
    await _ordersListener?.cancel();
    await _inventoryListener?.cancel();
    await _usersListener?.cancel();
    await _menuItemsListener?.cancel();
    await _categoriesListener?.cancel();
    await _tablesListener?.cancel();
    await _activeDevicesListener?.cancel();
    await _syncEventsListener?.cancel();
    
    _restaurantListener = null;
    _ordersListener = null;
    _inventoryListener = null;
    _usersListener = null;
    _menuItemsListener = null;
    _categoriesListener = null;
    _tablesListener = null;
    _activeDevicesListener = null;
    _syncEventsListener = null;
  }
  
  /// Sync pending changes
  Future<void> _syncPendingChanges() async {
    if (_pendingChanges.isEmpty) return;
    
    try {
      final changes = List<Map<String, dynamic>>.from(_pendingChanges);
      _pendingChanges.clear();
      
      for (final change in changes) {
        await _syncChange(change);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync pending changes: $e');
    }
  }
  
  /// Add a pending sync change
  void addPendingSyncChange(String collection, String action, String id, Map<String, dynamic> data) {
    _pendingChanges.add({
      'collection': collection,
      'action': action,
      'id': id,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('📝 Added pending sync change: $collection $action $id');
  }

  /// Sync a single change
  Future<void> _syncChange(Map<String, dynamic> change) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final collection = change['collection'] as String;
      final action = change['action'] as String;
      final data = change['data'] as Map<String, dynamic>;
      final id = change['id'] as String;
      
      final collectionRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection(collection);
      
      switch (action) {
        case 'create':
          await collectionRef.doc(id).set(data);
          break;
        case 'update':
          await collectionRef.doc(id).update(data);
          break;
        case 'delete':
          await collectionRef.doc(id).delete();
          break;
      }
      
      // Create sync event
      await _createSyncEvent(collection, action, id);
      
    } catch (e) {
      debugPrint('❌ Failed to sync change: $e');
      // Re-add to pending changes
      _pendingChanges.add(change);
    }
  }
  
  /// Create sync event
  Future<void> _createSyncEvent(String collection, String action, String recordId) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sync_events')
          .add({
        'type': '${collection}_$action',
        'collection': collection,
        'action': action,
        'recordId': recordId,
        'sourceDevice': _deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create sync event: $e');
    }
  }
  
  // Data sync methods
  Future<void> _syncCategories() async {
    try {
      debugPrint('🔄 Syncing categories...');
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Get categories from Firebase
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .get();
      
      // Update local cache
      _dataCache['categories'] = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint('✅ Synced ${snapshot.docs.length} categories from Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync categories: $e');
    }
  }
  
  Future<void> _syncMenuItems() async {
    try {
      debugPrint('🔄 Syncing menu items...');
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Get menu items from Firebase
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .get();
      
      // Update local cache
      _dataCache['menu_items'] = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint('✅ Synced ${snapshot.docs.length} menu items from Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync menu items: $e');
    }
  }
  
  Future<void> _syncUsers() async {
    try {
      debugPrint('🔄 Syncing users...');
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Get users from Firebase
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .get();
      
      // Update local cache
      _dataCache['users'] = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint('✅ Synced ${snapshot.docs.length} users from Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync users: $e');
    }
  }
  
  Future<void> _syncTables() async {
    try {
      debugPrint('🔄 Syncing tables...');
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Get tables from Firebase
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .get();
      
      // Update local cache
      _dataCache['tables'] = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint('✅ Synced ${snapshot.docs.length} tables from Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync tables: $e');
    }
  }
  
  Future<void> _syncInventory() async {
    try {
      debugPrint('🔄 Syncing inventory...');
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Get inventory from Firebase
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .get();
      
      // Update local cache
      _dataCache['inventory'] = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint('✅ Synced ${snapshot.docs.length} inventory items from Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory: $e');
    }
  }
  
  Future<void> _syncOrders() async {
    try {
      debugPrint('🔄 Syncing orders...');
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      // Get active orders from Firebase
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .where('status', whereIn: ['pending', 'preparing', 'ready'])
          .get();
      
      // Update local cache
      _dataCache['orders'] = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint('✅ Synced ${snapshot.docs.length} orders from Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync orders: $e');
    }
  }
  
  /// Create or update order in Firebase
  Future<void> createOrUpdateOrder(pos_order.Order order) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final orderData = order.toJson();
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(order.id)
          .set(orderData, SetOptions(merge: true));
      
      // Create sync event
      await _createSyncEvent('orders', 'updated', order.id);
      
      debugPrint('✅ Order synced to Firebase: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to sync order: $e');
      _onSyncError?.call('Failed to sync order: $e');
    }
  }
  
  /// Create or update menu item in Firebase
  Future<void> createOrUpdateMenuItem(MenuItem menuItem) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final menuItemData = menuItem.toJson();
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .doc(menuItem.id)
          .set(menuItemData, SetOptions(merge: true));
      
      // Create sync event
      await _createSyncEvent('menu_items', 'updated', menuItem.id);
      
      debugPrint('✅ Menu item synced to Firebase: ${menuItem.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync menu item: $e');
      _onSyncError?.call('Failed to sync menu item: $e');
    }
  }
  
  /// Create or update category in Firebase
  Future<void> createOrUpdateCategory(pos_category.Category category) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final categoryData = category.toJson();
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .doc(category.id)
          .set(categoryData, SetOptions(merge: true));
      
      // Create sync event
      await _createSyncEvent('categories', 'updated', category.id);
      
      debugPrint('✅ Category synced to Firebase: ${category.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync category: $e');
      _onSyncError?.call('Failed to sync category: $e');
    }
  }
  
  /// Create or update user in Firebase
  Future<void> createOrUpdateUser(pos_user.User user) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final userData = user.toJson();
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(user.id)
          .set(userData, SetOptions(merge: true));
      
      // Create sync event
      await _createSyncEvent('users', 'updated', user.id);
      
      debugPrint('✅ User synced to Firebase: ${user.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync user: $e');
      _onSyncError?.call('Failed to sync user: $e');
    }
  }
  
  /// Create or update inventory item in Firebase
  Future<void> createOrUpdateInventoryItem(InventoryItem item) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      final itemData = item.toJson();
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .doc(item.id)
          .set(itemData, SetOptions(merge: true));
      
      // Create sync event
      await _createSyncEvent('inventory', 'updated', item.id);
      
      debugPrint('✅ Inventory item synced to Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory item: $e');
      _onSyncError?.call('Failed to sync inventory item: $e');
    }
  }
  
  /// Delete item from Firebase
  Future<void> deleteItem(String collection, String id) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId() ?? 'default-tenant';
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection(collection)
          .doc(id)
          .delete();
      
      // Create sync event
      await _createSyncEvent(collection, 'deleted', id);
      
      debugPrint('✅ Item deleted from Firebase: $collection/$id');
    } catch (e) {
      debugPrint('❌ Failed to delete item: $e');
      _onSyncError?.call('Failed to delete item: $e');
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _backgroundSyncTimer?.cancel();
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    _sessionsUpdateDebounceTimer?.cancel();
    _stopAllListeners();
    super.dispose();
  }
} 