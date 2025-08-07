import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/restaurant.dart';
import '../models/user.dart' as pos_user;
import '../models/order.dart' as pos_order;
import '../models/menu_item.dart';
import '../models/category.dart' as pos_category;
import '../models/inventory_item.dart';
import 'multi_tenant_auth_service.dart';
import '../config/firebase_config.dart';
import 'multidevice_sync_manager.dart';

/// Enhanced Firebase-based real-time synchronization service for multi-tenant POS system
/// Handles real-time data sync across multiple devices for each restaurant
/// Integrates with MultideviceSyncManager for comprehensive sync capabilities
class FirebaseRealtimeSyncService extends ChangeNotifier {
  static FirebaseRealtimeSyncService? _instance;
  static final _uuid = const Uuid();
  
  // Firebase instances
  late FirebaseFirestore _firestore;
  late firebase_auth.FirebaseAuth _auth;
  
  // Current restaurant and session
  Restaurant? _currentRestaurant;
  RestaurantSession? _currentSession;
  
  // Multidevice sync manager integration
  late MultideviceSyncManager _syncManager;
  
  // Real-time listeners
  StreamSubscription<DocumentSnapshot>? _restaurantListener;
  StreamSubscription<QuerySnapshot>? _ordersListener;
  StreamSubscription<QuerySnapshot>? _inventoryListener;
  StreamSubscription<QuerySnapshot>? _usersListener;
  StreamSubscription<QuerySnapshot>? _menuItemsListener;
  StreamSubscription<QuerySnapshot>? _categoriesListener;
  StreamSubscription<QuerySnapshot>? _activeSessionsListener;
  StreamSubscription<QuerySnapshot>? _kitchenOrdersListener;
  StreamSubscription<QuerySnapshot>? _tableStatusListener;
  
  // Data caches
  final Map<String, dynamic> _dataCache = {};
  final Set<String> _activeDevices = {};
  
  // Sync state
  bool _isConnected = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  
  // Callbacks for UI updates
  Function()? _onOrdersUpdated;
  Function()? _onInventoryUpdated;
  Function()? _onUsersUpdated;
  Function()? _onMenuItemsUpdated;
  Function()? _onCategoriesUpdated;
  Function()? _onSessionsUpdated;
  Function()? _onKitchenOrdersUpdated;
  Function()? _onTableStatusUpdated;
  
  // Enhanced sync features
  bool _enableKitchenSync = true;
  bool _enableTableSync = true;
  bool _enableInventorySync = true;
  bool _enableMenuSync = true;
  
  factory FirebaseRealtimeSyncService() {
    _instance ??= FirebaseRealtimeSyncService._internal();
    return _instance!;
  }
  
  FirebaseRealtimeSyncService._internal();
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  DateTime? get lastSyncTime => _lastSyncTime;
  Set<String> get activeDevices => Set.unmodifiable(_activeDevices);
  MultideviceSyncManager get syncManager => _syncManager;
  
  /// Initialize Firebase services with enhanced capabilities
  Future<void> initialize() async {
    try {
      debugPrint('🔥 Initializing Enhanced Firebase Realtime Sync Service...');
      
      // Check if Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized - sync service will be limited');
        _isInitialized = true; // Mark as initialized but limited
        return;
      }
      
      _firestore = FirebaseFirestore.instance;
      _auth = firebase_auth.FirebaseAuth.instance;
      
      // Enable offline persistence with enhanced settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        sslEnabled: true,
      );
      
      // Initialize multidevice sync manager
      _syncManager = MultideviceSyncManager();
      await _syncManager.initialize();
      
      _isInitialized = true;
      debugPrint('✅ Enhanced Firebase Realtime Sync Service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Enhanced Firebase Realtime Sync Service: $e');
      _isInitialized = true; // Mark as initialized but limited
      // Don't rethrow - allow app to continue in offline mode
    }
  }
  
  /// Connect to a restaurant's real-time data with enhanced sync
  Future<void> connectToRestaurant(Restaurant restaurant, RestaurantSession session) async {
    try {
      debugPrint('🔗 Connecting to restaurant with enhanced sync: ${restaurant.name}');
      
      _currentRestaurant = restaurant;
      _currentSession = session;
      
      // Connect multidevice sync manager
      await _syncManager.connectToRestaurant(restaurant, session);
      
      // Set up callbacks for sync manager
      _syncManager.setCallbacks(
        onOrdersUpdated: _onOrdersUpdated,
        onInventoryUpdated: _onInventoryUpdated,
        onUsersUpdated: _onUsersUpdated,
        onMenuItemsUpdated: _onMenuItemsUpdated,
        onCategoriesUpdated: _onCategoriesUpdated,
        onSessionsUpdated: _onSessionsUpdated,
        onSyncProgress: (message) => debugPrint('🔄 Sync: $message'),
        onSyncError: (error) => debugPrint('❌ Sync Error: $error'),
      );
      
      // Start enhanced real-time listeners
      await _startEnhancedRealtimeListeners();
      
      _isConnected = true;
      _lastSyncTime = DateTime.now();
      
      debugPrint('✅ Connected to restaurant with enhanced sync: ${restaurant.name}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to connect to restaurant: $e');
      rethrow;
    }
  }
  
  /// Start enhanced real-time listeners
  Future<void> _startEnhancedRealtimeListeners() async {
    try {
      debugPrint('👂 Starting enhanced real-time listeners...');
      
      final tenantId = _currentRestaurant!.id;
      final tenantRef = _firestore.collection('tenants').doc(tenantId);
      
      // Enhanced active devices listener
      _activeSessionsListener = tenantRef
          .collection('active_devices')
          .snapshots()
          .listen(_handleEnhancedActiveDevicesUpdate);
      
      // Kitchen orders listener (for real-time kitchen updates)
      if (_enableKitchenSync) {
        _kitchenOrdersListener = tenantRef
            .collection('orders')
            .where('status', whereIn: ['preparing', 'ready', 'served'])
            .snapshots()
            .listen(_handleKitchenOrdersUpdate);
      }
      
      // Table status listener (for real-time table management)
      if (_enableTableSync) {
        _tableStatusListener = tenantRef
            .collection('tables')
            .snapshots()
            .listen(_handleTableStatusUpdate);
      }
      
      // Enhanced data listeners
      _setupEnhancedDataListeners(tenantRef);
      
      debugPrint('✅ Enhanced real-time listeners started');
    } catch (e) {
      debugPrint('❌ Failed to start enhanced real-time listeners: $e');
    }
  }
  
  /// Set up enhanced data listeners
  void _setupEnhancedDataListeners(DocumentReference tenantRef) {
    // Enhanced orders listener with real-time status updates
    _ordersListener = tenantRef
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final orderData = change.doc.data() as Map<String, dynamic>;
        final orderId = change.doc.id;
        
        switch (change.type) {
          case DocumentChangeType.added:
            debugPrint('🆕 New order created: $orderId');
            _onOrdersUpdated?.call();
            break;
          case DocumentChangeType.modified:
            debugPrint('🔄 Order updated: $orderId - Status: ${orderData['status']}');
            _onOrdersUpdated?.call();
            break;
          case DocumentChangeType.removed:
            debugPrint('🗑️ Order removed: $orderId');
            _onOrdersUpdated?.call();
            break;
        }
      }
    });
    
    // Enhanced inventory listener with low stock alerts
    if (_enableInventorySync) {
      _inventoryListener = tenantRef
          .collection('inventory')
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          final inventoryData = change.doc.data() as Map<String, dynamic>;
          final itemId = change.doc.id;
          final currentStock = inventoryData['currentStock'] as int? ?? 0;
          final minStock = inventoryData['minStock'] as int? ?? 0;
          
          if (currentStock <= minStock) {
            debugPrint('⚠️ Low stock alert: $itemId (${currentStock}/${minStock})');
          }
          
          _onInventoryUpdated?.call();
        }
      });
    }
    
    // Enhanced menu items listener with availability updates
    if (_enableMenuSync) {
      _menuItemsListener = tenantRef
          .collection('menu_items')
          .snapshots()
          .listen((snapshot) {
        for (final change in snapshot.docChanges) {
          final menuData = change.doc.data() as Map<String, dynamic>;
          final itemId = change.doc.id;
          final isAvailable = menuData['isAvailable'] as bool? ?? true;
          
          if (!isAvailable) {
            debugPrint('🚫 Menu item unavailable: $itemId');
          }
          
          _onMenuItemsUpdated?.call();
        }
      });
    }
    
    // Enhanced categories listener
    _categoriesListener = tenantRef
        .collection('categories')
        .snapshots()
        .listen((snapshot) => _onCategoriesUpdated?.call());
    
    // Enhanced users listener
    _usersListener = tenantRef
        .collection('users')
        .snapshots()
        .listen((snapshot) => _onUsersUpdated?.call());
  }
  
  /// Handle enhanced active devices update
  void _handleEnhancedActiveDevicesUpdate(QuerySnapshot snapshot) {
    final devices = <String>{};
    final deviceDetails = <String, Map<String, dynamic>>{};
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isActive'] == true) {
        final deviceId = doc.id;
        devices.add(deviceId);
        deviceDetails[deviceId] = data;
        
        // Log device activity
        final lastActivity = data['lastActivity'] as String?;
        final userName = data['userName'] as String?;
        final deviceName = data['deviceName'] as String?;
        
        if (lastActivity != null) {
          final activityTime = DateTime.tryParse(lastActivity);
          if (activityTime != null) {
            final timeDiff = DateTime.now().difference(activityTime);
            if (timeDiff.inMinutes < 1) {
              debugPrint('📱 Active device: $deviceName ($userName) - $deviceId');
            }
          }
        }
      }
    }
    
    _activeDevices.clear();
    _activeDevices.addAll(devices);
    
    debugPrint('📱 Enhanced active devices update: ${_activeDevices.length} devices');
    _onSessionsUpdated?.call();
    notifyListeners();
  }
  
  /// Handle kitchen orders update
  void _handleKitchenOrdersUpdate(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      final orderData = change.doc.data() as Map<String, dynamic>;
      final orderId = change.doc.id;
      final status = orderData['status'] as String?;
      final orderNumber = orderData['orderNumber'] as String?;
      
      switch (change.type) {
        case DocumentChangeType.added:
          debugPrint('👨‍🍳 New kitchen order: $orderNumber ($status)');
          break;
        case DocumentChangeType.modified:
          debugPrint('👨‍🍳 Kitchen order status changed: $orderNumber -> $status');
          break;
        case DocumentChangeType.removed:
          debugPrint('👨‍🍳 Kitchen order completed: $orderNumber');
          break;
      }
      
      _onKitchenOrdersUpdated?.call();
    }
  }
  
  /// Handle table status update
  void _handleTableStatusUpdate(QuerySnapshot snapshot) {
    for (final change in snapshot.docChanges) {
      final tableData = change.doc.data() as Map<String, dynamic>;
      final tableId = change.doc.id;
      final tableName = tableData['name'] as String?;
      final status = tableData['status'] as String?;
      
      switch (change.type) {
        case DocumentChangeType.added:
          debugPrint('🪑 New table: $tableName ($status)');
          break;
        case DocumentChangeType.modified:
          debugPrint('🪑 Table status changed: $tableName -> $status');
          break;
        case DocumentChangeType.removed:
          debugPrint('🪑 Table removed: $tableName');
          break;
      }
      
      _onTableStatusUpdated?.call();
    }
  }
  
  /// Broadcast order update to all devices
  Future<void> broadcastOrderUpdate(pos_order.Order order, String action) async {
    try {
      final tenantId = _currentRestaurant!.id;
      final orderData = order.toJson();
      
      // Update order in Firestore
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(order.id)
          .set(orderData, SetOptions(merge: true));
      
      // Create sync event for other devices
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sync_events')
          .add({
        'type': 'order_$action',
        'collection': 'orders',
        'action': action,
        'recordId': order.id,
        'sourceDevice': await _getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'orderNumber': order.orderNumber,
        'status': order.status.toString(),
      });
      
      debugPrint('📡 Broadcasted order update: ${order.orderNumber} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to broadcast order update: $e');
    }
  }
  
  /// Broadcast inventory update to all devices
  Future<void> broadcastInventoryUpdate(InventoryItem item, String action) async {
    try {
      final tenantId = _currentRestaurant!.id;
      final itemData = item.toJson();
      
      // Update inventory in Firestore
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .doc(item.id)
          .set(itemData, SetOptions(merge: true));
      
      // Create sync event for other devices
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sync_events')
          .add({
        'type': 'inventory_$action',
        'collection': 'inventory',
        'action': action,
        'recordId': item.id,
        'sourceDevice': await _getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'itemName': item.name,
        'currentStock': item.currentStock,
      });
      
      debugPrint('📡 Broadcasted inventory update: ${item.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to broadcast inventory update: $e');
    }
  }
  
  /// Broadcast menu update to all devices
  Future<void> broadcastMenuUpdate(MenuItem item, String action) async {
    try {
      final tenantId = _currentRestaurant!.id;
      final itemData = item.toJson();
      
      // Update menu item in Firestore
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .doc(item.id)
          .set(itemData, SetOptions(merge: true));
      
      // Create sync event for other devices
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sync_events')
          .add({
        'type': 'menu_$action',
        'collection': 'menu_items',
        'action': action,
        'recordId': item.id,
        'sourceDevice': await _getDeviceId(),
        'timestamp': DateTime.now().toIso8601String(),
        'itemName': item.name,
        'isAvailable': item.isAvailable,
      });
      
      debugPrint('📡 Broadcasted menu update: ${item.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to broadcast menu update: $e');
    }
  }
  
  /// Get unique device ID
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }
  
  /// Disconnect from current restaurant
  Future<void> disconnect() async {
    try {
      debugPrint('🔌 Disconnecting from restaurant...');
      
      // Disconnect multidevice sync manager
      await _syncManager.disconnect();
      
      // Stop all listeners
      await _stopAllListeners();
      
      _currentRestaurant = null;
      _currentSession = null;
      _isConnected = false;
      _activeDevices.clear();
      _dataCache.clear();
      
      debugPrint('✅ Disconnected from restaurant');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error disconnecting: $e');
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
      _activeSessionsListener?.cancel() ?? Future.value(),
      _kitchenOrdersListener?.cancel() ?? Future.value(),
      _tableStatusListener?.cancel() ?? Future.value(),
    ]);
  }
  
  /// Set callbacks
  void setCallbacks({
    Function()? onOrdersUpdated,
    Function()? onInventoryUpdated,
    Function()? onUsersUpdated,
    Function()? onMenuItemsUpdated,
    Function()? onCategoriesUpdated,
    Function()? onSessionsUpdated,
    Function()? onKitchenOrdersUpdated,
    Function()? onTableStatusUpdated,
  }) {
    _onOrdersUpdated = onOrdersUpdated;
    _onInventoryUpdated = onInventoryUpdated;
    _onUsersUpdated = onUsersUpdated;
    _onMenuItemsUpdated = onMenuItemsUpdated;
    _onCategoriesUpdated = onCategoriesUpdated;
    _onSessionsUpdated = onSessionsUpdated;
    _onKitchenOrdersUpdated = onKitchenOrdersUpdated;
    _onTableStatusUpdated = onTableStatusUpdated;
  }
  
  /// Enable/disable specific sync features
  void configureSyncFeatures({
    bool? enableKitchenSync,
    bool? enableTableSync,
    bool? enableInventorySync,
    bool? enableMenuSync,
  }) {
    if (enableKitchenSync != null) _enableKitchenSync = enableKitchenSync;
    if (enableTableSync != null) _enableTableSync = enableTableSync;
    if (enableInventorySync != null) _enableInventorySync = enableInventorySync;
    if (enableMenuSync != null) _enableMenuSync = enableMenuSync;
    
    debugPrint('⚙️ Sync features configured: Kitchen=$_enableKitchenSync, Table=$_enableTableSync, Inventory=$_enableInventorySync, Menu=$_enableMenuSync');
  }
  
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
} 