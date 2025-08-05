import 'dart:async';
import 'package:flutter/foundation.dart';
import 'cloud_sync_service.dart';
import 'order_service.dart';
import 'menu_service.dart';
import 'inventory_service.dart';
import 'table_service.dart';
import 'user_service.dart';
import 'enhanced_printer_manager.dart';

/// Service that integrates cloud synchronization with existing POS services
/// Automatically broadcasts changes made in the POS system to all connected devices
class CloudSyncIntegrationService extends ChangeNotifier {
  static CloudSyncIntegrationService? _instance;
  static final _lock = Object();
  
  // Services
  CloudSyncService? _cloudSyncService;
  OrderService? _orderService;
  MenuService? _menuService;
  InventoryService? _inventoryService;
  TableService? _tableService;
  UserService? _userService;
  EnhancedPrinterManager? _printerManager;
  
  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];
  
  // Configuration
  bool _isInitialized = false;
  bool _isEnabled = true;
  
  factory CloudSyncIntegrationService() {
    synchronized(_lock, () {
      _instance ??= CloudSyncIntegrationService._internal();
    });
    return _instance!;
  }
  
  CloudSyncIntegrationService._internal();
  
  /// Initialize the integration service
  Future<void> initialize({
    required CloudSyncService cloudSyncService,
    OrderService? orderService,
    MenuService? menuService,
    InventoryService? inventoryService,
    TableService? tableService,
    UserService? userService,
    EnhancedPrinterManager? printerManager,
  }) async {
    if (_isInitialized) return;
    
    _cloudSyncService = cloudSyncService;
    _orderService = orderService;
    _menuService = menuService;
    _inventoryService = inventoryService;
    _tableService = tableService;
    _userService = userService;
    _printerManager = printerManager;
    
    debugPrint('🔗 CloudSyncIntegrationService: Initializing...');
    
    // Setup listeners for cloud sync events
    _setupCloudSyncListeners();
    
    // Setup listeners for local service changes
    _setupLocalServiceListeners();
    
    _isInitialized = true;
    debugPrint('🔗 CloudSyncIntegrationService: Initialized successfully');
  }
  
  /// Setup listeners for cloud sync events
  void _setupCloudSyncListeners() {
    if (_cloudSyncService == null) return;
    
    // Listen for order updates from other devices
    _subscriptions.add(_cloudSyncService!.orderUpdates.listen((data) {
      _handleRemoteOrderUpdate(data);
    }));
    
    // Listen for menu updates from other devices
    _subscriptions.add(_cloudSyncService!.menuUpdates.listen((data) {
      _handleRemoteMenuUpdate(data);
    }));
    
    // Listen for inventory updates from other devices
    _subscriptions.add(_cloudSyncService!.inventoryUpdates.listen((data) {
      _handleRemoteInventoryUpdate(data);
    }));
    
    // Listen for table updates from other devices
    _subscriptions.add(_cloudSyncService!.tableUpdates.listen((data) {
      _handleRemoteTableUpdate(data);
    }));
    
    // Listen for user updates from other devices
    _subscriptions.add(_cloudSyncService!.userUpdates.listen((data) {
      _handleRemoteUserUpdate(data);
    }));
    
    // Listen for printer updates from other devices
    _subscriptions.add(_cloudSyncService!.printerUpdates.listen((data) {
      _handleRemotePrinterUpdate(data);
    }));
  }
  
  /// Setup listeners for local service changes
  void _setupLocalServiceListeners() {
    // Order service listeners
    if (_orderService != null) {
      _subscriptions.add(_orderService!.orderStream.listen((order) {
        if (_isEnabled && _cloudSyncService != null) {
          _cloudSyncService!.broadcastOrderUpdate(
            order.id,
            'updated',
            {
              'order_number': order.orderNumber,
              'status': order.status.toString(),
              'type': order.type.toString(),
              'total_amount': order.totalAmount,
              'items_count': order.items.length,
              'updated_at': order.updatedAt?.toIso8601String(),
            },
          );
        }
      }));
    }
    
    // Menu service listeners
    if (_menuService != null) {
      _subscriptions.add(_menuService!.menuItemStream.listen((item) {
        if (_isEnabled && _cloudSyncService != null) {
          _cloudSyncService!.broadcastMenuUpdate(
            item.id,
            'updated',
            {
              'name': item.name,
              'price': item.price,
              'category_id': item.categoryId,
              'is_available': item.isAvailable,
              'updated_at': item.updatedAt?.toIso8601String(),
            },
          );
        }
      }));
    }
    
    // Inventory service listeners
    if (_inventoryService != null) {
      _subscriptions.add(_inventoryService!.inventoryStream.listen((item) {
        if (_isEnabled && _cloudSyncService != null) {
          _cloudSyncService!.broadcastInventoryUpdate(
            item.id,
            'stock_changed',
            {
              'name': item.name,
              'current_stock': item.currentStock,
              'min_stock': item.minStock,
              'category': item.category.toString(),
              'updated_at': item.updatedAt?.toIso8601String(),
            },
          );
        }
      }));
    }
  }
  
  /// Handle remote order updates
  void _handleRemoteOrderUpdate(Map<String, dynamic> data) {
    try {
      final orderId = data['order_id'] as String?;
      final action = data['action'] as String?;
      final orderData = data['data'] as Map<String, dynamic>?;
      final deviceId = data['device_id'] as String?;
      
      if (orderId == null || action == null || orderData == null) return;
      
      // Skip if this update came from our own device
      if (deviceId == _cloudSyncService?._deviceId) return;
      
      debugPrint('🔗 CloudSyncIntegrationService: Received remote order update: $action for $orderId');
      
      // Update local order service
      if (_orderService != null) {
        switch (action) {
          case 'created':
            // Handle new order creation
            break;
          case 'updated':
            // Handle order update
            break;
          case 'status_changed':
            // Handle status change
            break;
          case 'completed':
            // Handle order completion
            break;
        }
      }
      
    } catch (e) {
      debugPrint('⚠️ CloudSyncIntegrationService: Error handling remote order update: $e');
    }
  }
  
  /// Handle remote menu updates
  void _handleRemoteMenuUpdate(Map<String, dynamic> data) {
    try {
      final itemId = data['item_id'] as String?;
      final action = data['action'] as String?;
      final itemData = data['data'] as Map<String, dynamic>?;
      final deviceId = data['device_id'] as String?;
      
      if (itemId == null || action == null || itemData == null) return;
      
      // Skip if this update came from our own device
      if (deviceId == _cloudSyncService?._deviceId) return;
      
      debugPrint('🔗 CloudSyncIntegrationService: Received remote menu update: $action for $itemId');
      
      // Update local menu service
      if (_menuService != null) {
        switch (action) {
          case 'created':
            // Handle new menu item creation
            break;
          case 'updated':
            // Handle menu item update
            break;
          case 'deleted':
            // Handle menu item deletion
            break;
          case 'availability_changed':
            // Handle availability change
            break;
        }
      }
      
    } catch (e) {
      debugPrint('⚠️ CloudSyncIntegrationService: Error handling remote menu update: $e');
    }
  }
  
  /// Handle remote inventory updates
  void _handleRemoteInventoryUpdate(Map<String, dynamic> data) {
    try {
      final itemId = data['item_id'] as String?;
      final action = data['action'] as String?;
      final itemData = data['data'] as Map<String, dynamic>?;
      final deviceId = data['device_id'] as String?;
      
      if (itemId == null || action == null || itemData == null) return;
      
      // Skip if this update came from our own device
      if (deviceId == _cloudSyncService?._deviceId) return;
      
      debugPrint('🔗 CloudSyncIntegrationService: Received remote inventory update: $action for $itemId');
      
      // Update local inventory service
      if (_inventoryService != null) {
        switch (action) {
          case 'stock_changed':
            // Handle stock change
            break;
          case 'item_added':
            // Handle new item addition
            break;
          case 'item_removed':
            // Handle item removal
            break;
          case 'low_stock_alert':
            // Handle low stock alert
            break;
        }
      }
      
    } catch (e) {
      debugPrint('⚠️ CloudSyncIntegrationService: Error handling remote inventory update: $e');
    }
  }
  
  /// Handle remote table updates
  void _handleRemoteTableUpdate(Map<String, dynamic> data) {
    try {
      final tableId = data['table_id'] as String?;
      final action = data['action'] as String?;
      final tableData = data['data'] as Map<String, dynamic>?;
      final deviceId = data['device_id'] as String?;
      
      if (tableId == null || action == null || tableData == null) return;
      
      // Skip if this update came from our own device
      if (deviceId == _cloudSyncService?._deviceId) return;
      
      debugPrint('🔗 CloudSyncIntegrationService: Received remote table update: $action for $tableId');
      
      // Update local table service
      if (_tableService != null) {
        switch (action) {
          case 'occupied':
            // Handle table occupation
            break;
          case 'available':
            // Handle table availability
            break;
          case 'reserved':
            // Handle table reservation
            break;
          case 'cleaning':
            // Handle table cleaning
            break;
        }
      }
      
    } catch (e) {
      debugPrint('⚠️ CloudSyncIntegrationService: Error handling remote table update: $e');
    }
  }
  
  /// Handle remote user updates
  void _handleRemoteUserUpdate(Map<String, dynamic> data) {
    try {
      final userId = data['user_id'] as String?;
      final action = data['action'] as String?;
      final userData = data['data'] as Map<String, dynamic>?;
      final deviceId = data['device_id'] as String?;
      
      if (userId == null || action == null || userData == null) return;
      
      // Skip if this update came from our own device
      if (deviceId == _cloudSyncService?._deviceId) return;
      
      debugPrint('🔗 CloudSyncIntegrationService: Received remote user update: $action for $userId');
      
      // Update local user service
      if (_userService != null) {
        switch (action) {
          case 'created':
            // Handle new user creation
            break;
          case 'updated':
            // Handle user update
            break;
          case 'deleted':
            // Handle user deletion
            break;
          case 'role_changed':
            // Handle role change
            break;
        }
      }
      
    } catch (e) {
      debugPrint('⚠️ CloudSyncIntegrationService: Error handling remote user update: $e');
    }
  }
  
  /// Handle remote printer updates
  void _handleRemotePrinterUpdate(Map<String, dynamic> data) {
    try {
      final printerId = data['printer_id'] as String?;
      final action = data['action'] as String?;
      final printerData = data['data'] as Map<String, dynamic>?;
      final deviceId = data['device_id'] as String?;
      
      if (printerId == null || action == null || printerData == null) return;
      
      // Skip if this update came from our own device
      if (deviceId == _cloudSyncService?._deviceId) return;
      
      debugPrint('🔗 CloudSyncIntegrationService: Received remote printer update: $action for $printerId');
      
      // Update local printer manager
      if (_printerManager != null) {
        switch (action) {
          case 'added':
            // Handle new printer addition
            break;
          case 'removed':
            // Handle printer removal
            break;
          case 'configured':
            // Handle printer configuration
            break;
          case 'assignment_changed':
            // Handle assignment change
            break;
        }
      }
      
    } catch (e) {
      debugPrint('⚠️ CloudSyncIntegrationService: Error handling remote printer update: $e');
    }
  }
  
  /// Manually broadcast an order update
  void broadcastOrderUpdate(String orderId, String action, Map<String, dynamic> data) {
    if (_isEnabled && _cloudSyncService != null) {
      _cloudSyncService!.broadcastOrderUpdate(orderId, action, data);
    }
  }
  
  /// Manually broadcast a menu update
  void broadcastMenuUpdate(String itemId, String action, Map<String, dynamic> data) {
    if (_isEnabled && _cloudSyncService != null) {
      _cloudSyncService!.broadcastMenuUpdate(itemId, action, data);
    }
  }
  
  /// Manually broadcast an inventory update
  void broadcastInventoryUpdate(String itemId, String action, Map<String, dynamic> data) {
    if (_isEnabled && _cloudSyncService != null) {
      _cloudSyncService!.broadcastInventoryUpdate(itemId, action, data);
    }
  }
  
  /// Manually broadcast a table update
  void broadcastTableUpdate(String tableId, String action, Map<String, dynamic> data) {
    if (_isEnabled && _cloudSyncService != null) {
      _cloudSyncService!.broadcastTableUpdate(tableId, action, data);
    }
  }
  
  /// Manually broadcast a user update
  void broadcastUserUpdate(String userId, String action, Map<String, dynamic> data) {
    if (_isEnabled && _cloudSyncService != null) {
      _cloudSyncService!.broadcastUserUpdate(userId, action, data);
    }
  }
  
  /// Manually broadcast a printer update
  void broadcastPrinterUpdate(String printerId, String action, Map<String, dynamic> data) {
    if (_isEnabled && _cloudSyncService != null) {
      _cloudSyncService!.broadcastPrinterUpdate(printerId, action, data);
    }
  }
  
  /// Enable or disable cloud sync
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    debugPrint('🔗 CloudSyncIntegrationService: ${enabled ? 'Enabled' : 'Disabled'}');
    notifyListeners();
  }
  
  /// Get connection status
  bool get isConnected => _cloudSyncService?.isConnected ?? false;
  bool get isOnline => _cloudSyncService?.isOnline ?? false;
  bool get isEnabled => _isEnabled;
  
  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}

/// Singleton instance for global access
class CloudSyncIntegrationManager {
  static CloudSyncIntegrationService? _instance;
  
  static CloudSyncIntegrationService get instance {
    _instance ??= CloudSyncIntegrationService();
    return _instance!;
  }
  
  static Future<void> initialize({
    required CloudSyncService cloudSyncService,
    OrderService? orderService,
    MenuService? menuService,
    InventoryService? inventoryService,
    TableService? tableService,
    UserService? userService,
    EnhancedPrinterManager? printerManager,
  }) async {
    _instance = CloudSyncIntegrationService();
    await _instance!.initialize(
      cloudSyncService: cloudSyncService,
      orderService: orderService,
      menuService: menuService,
      inventoryService: inventoryService,
      tableService: tableService,
      userService: userService,
      printerManager: printerManager,
    );
  }
} 