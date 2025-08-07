import 'dart:async';

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

import '../services/database_service.dart';
import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../services/order_log_service.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';
import '../services/table_service.dart';
import '../config/firebase_config.dart';

/// Multi-Device Sync Manager for Real-Time Synchronization
/// Handles real-time data sync across multiple devices for each restaurant tenant
/// Integrates with existing multitenant architecture
class MultideviceSyncManager extends ChangeNotifier {
  static MultideviceSyncManager? _instance;
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
  StreamSubscription<QuerySnapshot>? _activeSessionsListener;
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
  
  // Sync configuration
  static const Duration _backgroundSyncInterval = Duration(minutes: 2);
  static const Duration _heartbeatInterval = Duration(minutes: 1);
  static const Duration _cleanupInterval = Duration(minutes: 10);
  static const Duration _offlineTimeout = Duration(minutes: 5);
  
  factory MultideviceSyncManager() {
    _instance ??= MultideviceSyncManager._internal();
    return _instance!;
  }
  
  MultideviceSyncManager._internal();
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSyncTime => _lastSyncTime;
  DateTime? get lastFullSyncTime => _lastFullSyncTime;
  Set<String> get activeDevices => Set.unmodifiable(_activeDevices);
  String? get deviceId => _deviceId;
  String? get currentTenantId => _currentRestaurant?.id;
  
  /// Initialize the sync manager
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing Multi-Device Sync Manager...');
      
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
      debugPrint('✅ Multi-Device Sync Manager initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize Multi-Device Sync Manager: $e');
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
  
  /// Connect to a restaurant for multi-device sync
  Future<void> connectToRestaurant(Restaurant restaurant, RestaurantSession session) async {
    try {
      debugPrint('🔗 Connecting to restaurant for multi-device sync: ${restaurant.name}');
      
      _currentRestaurant = restaurant;
      _currentSession = session;
      
      // Initialize tenant database
      await _initializeTenantDatabase(restaurant);
      
      // Initialize service instances
      await _initializeServices();
      
      // Register this device as active
      await _registerActiveDevice();
      
      // Perform initial data synchronization
      await _performInitialSync();
      
      // Start real-time listeners
      await _startRealtimeListeners();
      
      _isConnected = true;
      _lastSyncTime = DateTime.now();
      
      debugPrint('✅ Connected to restaurant for multi-device sync: ${restaurant.name}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to connect to restaurant: $e');
      _onSyncError?.call('Failed to connect: $e');
      rethrow;
    }
  }
  
  /// Initialize tenant database
  Future<void> _initializeTenantDatabase(Restaurant restaurant) async {
    try {
      debugPrint('🗄️ Initializing tenant database for sync...');
      
      _tenantDb = DatabaseService();
      await _tenantDb!.initializeWithCustomName(restaurant.databaseName);
      
      debugPrint('✅ Tenant database initialized: ${restaurant.databaseName}');
    } catch (e) {
      debugPrint('❌ Failed to initialize tenant database: $e');
      rethrow;
    }
  }
  
  /// Initialize service instances
  Future<void> _initializeServices() async {
    try {
      debugPrint('🔧 Initializing service instances for sync...');
      
      // Initialize services with required dependencies
      _menuService = MenuService(_tenantDb!);
      _orderService = OrderService(_tenantDb!, OrderLogService(_tenantDb!), InventoryService());
      _inventoryService = InventoryService();
      _userService = UserService(await SharedPreferences.getInstance(), _tenantDb!);
      _tableService = TableService(await SharedPreferences.getInstance());
      
      debugPrint('✅ Service instances initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize service instances: $e');
      rethrow;
    }
  }
  
  /// Register this device as active for the restaurant
  Future<void> _registerActiveDevice() async {
    if (_currentRestaurant == null || _currentSession == null || _deviceId == null) return;
    
    try {
      final deviceData = {
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'deviceType': _deviceType,
        'userId': _currentSession!.userId,
        'userName': _currentSession!.userName,
        'userRole': _currentSession!.userRole.toString(),
        'loginTime': _currentSession!.loginTime.toIso8601String(),
        'lastActivity': DateTime.now().toIso8601String(),
        'isActive': true,
        'version': '1.0.0', // App version
        'platform': 'android', // Platform info
      };
      
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('active_devices')
          .doc(_deviceId)
          .set(deviceData, SetOptions(merge: true));
      
      debugPrint('📱 Registered device: $_deviceId (tenant: $tenantId)');
    } catch (e) {
      debugPrint('❌ Failed to register device: $e');
    }
  }
  
  /// Unregister this device
  Future<void> _unregisterActiveDevice() async {
    if (_currentRestaurant == null || _deviceId == null) return;
    
    try {
      final tenantId = _currentRestaurant!.id;
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
  
  /// Start real-time listeners for all data types
  Future<void> _startRealtimeListeners() async {
    try {
      debugPrint('👂 Starting real-time listeners...');
      
      final tenantId = _currentRestaurant!.id;
      final tenantRef = _firestore.collection('tenants').doc(tenantId);
      
      // Listen for active devices
      _activeSessionsListener = tenantRef
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
    
    _activeDevices.clear();
    _activeDevices.addAll(devices);
    
    debugPrint('📱 Active devices updated: ${_activeDevices.length} devices');
    _onSessionsUpdated?.call();
    notifyListeners();
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
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (wasOnline != _isOnline) {
        debugPrint('🌐 Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
        notifyListeners();
        
        if (_isOnline && _isConnected) {
          // Reconnect when coming back online
          _performBackgroundSync();
        }
      }
    });
  }
  
  /// Start background processes
  void _startBackgroundProcesses() {
    // Background sync timer
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (timer) {
      if (_isConnected && _isOnline && !_isSyncing) {
        _performBackgroundSync();
      }
    });
    
    // Heartbeat timer
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        _updateHeartbeat();
      }
    });
    
    // Cleanup timer
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      if (_isConnected) {
        _performCleanup();
      }
    });
  }
  
  /// Perform background sync
  Future<void> _performBackgroundSync() async {
    if (_isSyncing || !_isConnected || !_isOnline) return;
    
    try {
      _isSyncing = true;
      
      // Sync pending changes
      await _syncPendingChanges();
      
      // Update last sync time
      _lastSyncTime = DateTime.now();
      
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Update heartbeat
  Future<void> _updateHeartbeat() async {
    if (_currentRestaurant == null || _deviceId == null) return;
    
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('active_devices')
          .doc(_deviceId)
          .update({
        'lastActivity': DateTime.now().toIso8601String(),
        'isActive': true,
      });
      
      _lastActivity = DateTime.now();
    } catch (e) {
      debugPrint('❌ Failed to update heartbeat: $e');
    }
  }
  
  /// Perform cleanup
  Future<void> _performCleanup() async {
    try {
      // Remove old sync events (older than 24 hours)
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      final tenantId = _currentRestaurant!.id;
      
      final oldEvents = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sync_events')
          .where('timestamp', isLessThan: cutoffTime.toIso8601String())
          .get();
      
      for (final doc in oldEvents.docs) {
        await doc.reference.delete();
      }
      
      // Remove inactive devices (inactive for more than 5 minutes)
      final inactiveCutoff = DateTime.now().subtract(_offlineTimeout);
      final inactiveDevices = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('active_devices')
          .where('lastActivity', isLessThan: inactiveCutoff.toIso8601String())
          .get();
      
      for (final doc in inactiveDevices.docs) {
        await doc.reference.delete();
      }
      
    } catch (e) {
      debugPrint('❌ Cleanup failed: $e');
    }
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
  
  /// Sync a single change
  Future<void> _syncChange(Map<String, dynamic> change) async {
    try {
      final tenantId = _currentRestaurant!.id;
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
  Future<void> _createSyncEvent(String collection, String action, String id) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sync_events')
          .add({
        'type': '${collection}_$action',
        'collection': collection,
        'action': action,
        'recordId': id,
        'sourceDevice': _deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Failed to create sync event: $e');
    }
  }
  
  /// Queue a change for sync
  void queueChange(String collection, String action, String id, Map<String, dynamic> data) {
    _pendingChanges.add({
      'collection': collection,
      'action': action,
      'id': id,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Trigger immediate sync if online
    if (_isOnline && _isConnected) {
      _performBackgroundSync();
    }
  }
  
  /// Sync categories
  Future<void> _syncCategories() async {
    try {
      final categories = await _menuService?.getCategories() ?? [];
      for (final category in categories) {
        await _syncCategory(category);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync categories: $e');
    }
  }
  
  /// Sync a single category
  Future<void> _syncCategory(pos_category.Category category) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .doc(category.id)
          .set(category.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync category: $e');
    }
  }
  
  /// Sync menu items
  Future<void> _syncMenuItems() async {
    try {
      final menuItems = await _menuService?.getMenuItems() ?? [];
      for (final item in menuItems) {
        await _syncMenuItem(item);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync menu items: $e');
    }
  }
  
  /// Sync a single menu item
  Future<void> _syncMenuItem(MenuItem item) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .doc(item.id)
          .set(item.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync menu item: $e');
    }
  }
  
  /// Sync users
  Future<void> _syncUsers() async {
    try {
      final users = await _userService?.getUsers() ?? [];
      for (final user in users) {
        await _syncUser(user);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync users: $e');
    }
  }
  
  /// Sync a single user
  Future<void> _syncUser(pos_user.User user) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(user.id)
          .set(user.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync user: $e');
    }
  }
  
  /// Sync tables
  Future<void> _syncTables() async {
    try {
      final tables = await _tableService?.getTables() ?? [];
      for (final table in tables) {
        await _syncTable(table);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync tables: $e');
    }
  }
  
  /// Sync a single table
  Future<void> _syncTable(pos_table.Table table) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .doc(table.id)
          .set(table.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync table: $e');
    }
  }
  
  /// Sync inventory
  Future<void> _syncInventory() async {
    try {
      final inventory = await _inventoryService?.getAllItems() ?? [];
      for (final item in inventory) {
        await _syncInventoryItem(item);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync inventory: $e');
    }
  }
  
  /// Sync a single inventory item
  Future<void> _syncInventoryItem(InventoryItem item) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .doc(item.id)
          .set(item.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync inventory item: $e');
    }
  }
  
  /// Sync orders
  Future<void> _syncOrders() async {
    try {
      final orders = _orderService?.allOrders ?? [];
      for (final order in orders) {
        await _syncOrder(order);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync orders: $e');
    }
  }
  
  /// Sync a single order
  Future<void> _syncOrder(pos_order.Order order) async {
    try {
      final tenantId = _currentRestaurant!.id;
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(order.id)
          .set(order.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync order: $e');
    }
  }
  
  /// Stop all listeners
  Future<void> _stopAllListeners() async {
    await Future.wait([
      _restaurantListener?.cancel() ?? Future.value(),
      _ordersListener?.cancel() ?? Future.value(),
      _inventoryListener?.cancel() ?? Future.value(),
      _usersListener?.cancel() ?? Future.value(),
      _menuItemsListener?.cancel() ?? Future.value(),
      _categoriesListener?.cancel() ?? Future.value(),
      _tablesListener?.cancel() ?? Future.value(),
      _activeSessionsListener?.cancel() ?? Future.value(),
      _syncEventsListener?.cancel() ?? Future.value(),
    ]);
  }
  
  /// Disconnect from current restaurant
  Future<void> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting from restaurant...');
      
      // Unregister this device
      await _unregisterActiveDevice();
      
      // Stop all listeners
      await _stopAllListeners();
      
      // Stop background processes
      _backgroundSyncTimer?.cancel();
      _heartbeatTimer?.cancel();
      _cleanupTimer?.cancel();
      _connectivitySubscription?.cancel();
      
      _currentRestaurant = null;
      _currentSession = null;
      _isConnected = false;
      _activeDevices.clear();
      _dataCache.clear();
      _pendingChanges.clear();
      
      debugPrint('✅ Disconnected from restaurant');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error disconnecting: $e');
    }
  }
  
  /// Set callbacks
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
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// Singleton instance for global access
class MultideviceSyncManagerInstance {
  static MultideviceSyncManager? _instance;
  
  static MultideviceSyncManager get instance {
    _instance ??= MultideviceSyncManager();
    return _instance!;
  }
  
  static void initialize() {
    _instance = MultideviceSyncManager();
  }
} 