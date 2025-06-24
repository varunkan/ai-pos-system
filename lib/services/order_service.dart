import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/services/database_service.dart';

/// Custom exception for order operations
class OrderServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  OrderServiceException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'OrderServiceException: $message${operation != null ? ' (Operation: $operation)' : ''}';
}

/// Advanced order service with caching and performance optimizations
class OrderService with ChangeNotifier {
  DatabaseService _databaseService;
  
  // Cached data
  List<Order> _activeOrders = [];
  List<Order> _completedOrders = [];
  final Map<String, Order> _orderCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Performance tracking
  bool _isLoading = false;
  Timer? _cacheCleanupTimer;
  Timer? _autoRefreshTimer;
  
  // Cache configuration
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  static const Duration _autoRefreshInterval = Duration(seconds: 30);
  static const int _maxCacheSize = 1000;

  OrderService(this._databaseService) {
    _startCacheCleanup();
    // Disable auto-refresh for now to prevent crashes
    // _startAutoRefresh();
    debugPrint('OrderService initialized with advanced caching');
  }

  @override
  void dispose() {
    _cacheCleanupTimer?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // Getters with lazy loading disabled for stability
  List<Order> get activeOrders {
    // Disable automatic loading to prevent crashes
    // if (_activeOrders.isEmpty && !_isLoading) {
    //   _loadOrdersLazy();
    // }
    return List.unmodifiable(_activeOrders);
  }
  
  List<Order> get completedOrders {
    // Disable automatic loading to prevent crashes
    // if (_completedOrders.isEmpty && !_isLoading) {
    //   _loadOrdersLazy();
    // }
    return List.unmodifiable(_completedOrders);
  }
  
  bool get isLoading => _isLoading;

  /// Manually load orders from database
  /// Use this instead of automatic loading for better control
  Future<void> loadOrders() async {
    if (_isLoading) {
      debugPrint('OrderService: Already loading orders, skipping...');
      return;
    }
    
    debugPrint('OrderService: Starting to load all orders...');
    
    try {
      await _loadOrders();
      debugPrint('OrderService: Successfully loaded ${_activeOrders.length + _completedOrders.length} orders');
    } catch (e) {
      debugPrint('OrderService: Error loading orders: $e');
      // Don't rethrow to prevent crashes, just log the error
    }
  }

  /// Lazy loading with debouncing
  Timer? _loadDebounceTimer;
  void _loadOrdersLazy() {
    _loadDebounceTimer?.cancel();
    _loadDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _loadOrders();
    });
  }

  /// Start automatic cache cleanup
  void _startCacheCleanup() {
    _cacheCleanupTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _cleanupCache();
    });
  }

  /// Start automatic refresh for real-time updates
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!_isLoading) {
        _refreshActiveOrders();
      }
    });
  }

  /// Clean up expired cache entries
  void _cleanupCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheValidDuration)
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _orderCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    // Limit cache size
    if (_orderCache.length > _maxCacheSize) {
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final keysToRemove = sortedEntries
          .take(_orderCache.length - _maxCacheSize)
          .map((e) => e.key);
      
      for (final key in keysToRemove) {
        _orderCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    
    debugPrint('Cache cleanup completed. Cache size: ${_orderCache.length}');
  }

  /// Optimized order loading with caching
  Future<void> _loadOrders() async {
    if (_isLoading) return;
    
    _setLoading(true);
    
    try {
      debugPrint('OrderService: Starting database query...');
      // Use optimized database query
      final ordersData = await _databaseService.getOrdersWithItems(
        orderBy: 'o.created_at DESC',
        limit: 500, // Limit for performance
      );
      
      debugPrint('OrderService: Found ${ordersData.length} order rows in database');
      final ordersMap = <String, Order>{};
      
      // Group data by order ID
      for (final row in ordersData) {
        final orderId = row['id'] as String;
        
        if (!ordersMap.containsKey(orderId)) {
          ordersMap[orderId] = _buildOrderFromOptimizedData(row);
        }
        
        // Add item if exists
        if (row['item_id'] != null) {
          final item = _buildOrderItemFromOptimizedData(row);
          ordersMap[orderId]!.items.add(item);
        }
      }
      
      final allOrders = ordersMap.values.toList();
      
      // Update cache
      for (final order in allOrders) {
        _orderCache[order.id] = order;
        _cacheTimestamps[order.id] = DateTime.now();
      }
      
      _categorizeOrders(allOrders);
      _safeNotifyListeners();
      
    } catch (e) {
      debugPrint('Error loading orders: $e');
      throw OrderServiceException('Failed to load orders', operation: 'load_orders', originalError: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Build order from optimized query data
  Order _buildOrderFromOptimizedData(Map<String, dynamic> row) {
    return Order(
      id: row['id'],
      orderNumber: row['order_number'],
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == row['status'],
        orElse: () => OrderStatus.pending,
      ),
      type: OrderType.values.firstWhere(
        (e) => e.toString().split('.').last == row['type'],
        orElse: () => OrderType.dineIn,
      ),
      tableId: row['table_id'],
      userId: row['user_id'],
      customerName: row['customer_name'],
      customerPhone: row['customer_phone'],
      customerEmail: row['customer_email'],
      customerAddress: row['customer_address'],
      specialInstructions: row['special_instructions'],
      subtotal: (row['subtotal'] ?? 0.0).toDouble(),
      taxAmount: (row['tax_amount'] ?? 0.0).toDouble(),
      tipAmount: (row['tip_amount'] ?? 0.0).toDouble(),
      hstAmount: (row['hst_amount'] ?? 0.0).toDouble(),
      discountAmount: (row['discount_amount'] ?? 0.0).toDouble(),
      gratuityAmount: (row['gratuity_amount'] ?? 0.0).toDouble(),
      totalAmount: (row['total_amount'] ?? 0.0).toDouble(),
      paymentMethod: row['payment_method'],
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (row['payment_status'] ?? 'pending'),
        orElse: () => PaymentStatus.pending,
      ),
      paymentTransactionId: row['payment_transaction_id'],
      orderTime: DateTime.tryParse(row['order_time']) ?? DateTime.now(),
      estimatedReadyTime: row['estimated_ready_time'] != null 
          ? DateTime.tryParse(row['estimated_ready_time']) 
          : null,
      actualReadyTime: row['actual_ready_time'] != null 
          ? DateTime.tryParse(row['actual_ready_time']) 
          : null,
      servedTime: row['served_time'] != null 
          ? DateTime.tryParse(row['served_time']) 
          : null,
      completedTime: row['completed_time'] != null 
          ? DateTime.tryParse(row['completed_time']) 
          : null,
      isUrgent: (row['is_urgent'] ?? 0) == 1,
      priority: row['priority'] ?? 0,
      assignedTo: row['assigned_to'],
      customFields: row['custom_fields'] != null 
          ? jsonDecode(row['custom_fields']) 
          : {},
      metadata: row['metadata'] != null 
          ? jsonDecode(row['metadata']) 
          : {},
      createdAt: DateTime.tryParse(row['created_at']) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']) ?? DateTime.now(),
      items: [], // Items will be added separately
    );
  }

  /// Build order item from optimized query data
  OrderItem _buildOrderItemFromOptimizedData(Map<String, dynamic> row) {
    final menuItem = MenuItem(
      id: row['menu_item_id'],
      name: row['menu_item_name'] ?? 'Unknown Item',
      description: row['menu_item_description'] ?? '',
      price: (row['menu_item_price'] ?? 0.0).toDouble(),
      categoryId: row['menu_item_category_id'] ?? '',
      imageUrl: row['menu_item_image_url'],
      isAvailable: (row['menu_item_available'] ?? 1) == 1,
      preparationTime: row['preparation_time'] ?? 0,
      isVegetarian: (row['is_vegetarian'] ?? 0) == 1,
      isVegan: (row['is_vegan'] ?? 0) == 1,
      isGlutenFree: (row['is_gluten_free'] ?? 0) == 1,
      isSpicy: (row['is_spicy'] ?? 0) == 1,
      spiceLevel: row['spice_level'] ?? 0,
    );

    return OrderItem(
      id: row['item_id'],
      menuItem: menuItem,
      quantity: row['quantity'] ?? 1,
      unitPrice: (row['unit_price'] ?? 0.0).toDouble(),
      selectedVariant: row['selected_variant'],
      selectedModifiers: row['selected_modifiers'] != null 
          ? List<String>.from(jsonDecode(row['selected_modifiers'])) 
          : [],
      specialInstructions: row['special_instructions'],
      notes: row['notes'],
      customProperties: row['custom_properties'] != null 
          ? jsonDecode(row['custom_properties']) 
          : {},
      isAvailable: (row['item_available'] ?? 1) == 1,
      sentToKitchen: (row['sent_to_kitchen'] ?? 0) == 1,
      createdAt: DateTime.tryParse(row['item_created_at']) ?? DateTime.now(),
    );
  }

  /// Fast refresh for active orders only
  Future<void> _refreshActiveOrders() async {
    try {
      final activeOrdersData = await _databaseService.getOrdersWithItems(
        whereClause: "o.status IN ('pending', 'confirmed', 'preparing', 'ready')",
        orderBy: 'o.created_at DESC',
      );
      
      final ordersMap = <String, Order>{};
      
      for (final row in activeOrdersData) {
        final orderId = row['id'] as String;
        
        if (!ordersMap.containsKey(orderId)) {
          ordersMap[orderId] = _buildOrderFromOptimizedData(row);
        }
        
        if (row['item_id'] != null) {
          final item = _buildOrderItemFromOptimizedData(row);
          ordersMap[orderId]!.items.add(item);
        }
      }
      
      final newActiveOrders = ordersMap.values.toList();
      
      // Check if there are actual changes
      if (_hasOrdersChanged(_activeOrders, newActiveOrders)) {
        _activeOrders = newActiveOrders;
        
        // Update cache for active orders
        for (final order in newActiveOrders) {
          _orderCache[order.id] = order;
          _cacheTimestamps[order.id] = DateTime.now();
        }
        
        _safeNotifyListeners();
      }
      
    } catch (e) {
      debugPrint('Error refreshing active orders: $e');
    }
  }

  /// Check if orders list has changed
  bool _hasOrdersChanged(List<Order> oldOrders, List<Order> newOrders) {
    if (oldOrders.length != newOrders.length) return true;
    
    for (int i = 0; i < oldOrders.length; i++) {
      if (oldOrders[i].id != newOrders[i].id || 
          oldOrders[i].status != newOrders[i].status ||
          oldOrders[i].items.length != newOrders[i].items.length) {
        return true;
      }
    }
    
    return false;
  }

  /// Get order from cache or database
  Future<Order?> getOrderById(String orderId) async {
    // Check cache first
    if (_orderCache.containsKey(orderId)) {
      final cacheTime = _cacheTimestamps[orderId];
      if (cacheTime != null && 
          DateTime.now().difference(cacheTime) < _cacheValidDuration) {
        return _orderCache[orderId];
      }
    }
    
    // Load from database
    try {
      final orderData = await _databaseService.getOrdersWithItems(
        whereClause: 'o.id = ?',
        whereArgs: [orderId],
      );
      
      if (orderData.isEmpty) return null;
      
      final order = _buildOrderFromOptimizedData(orderData.first);
      
      // Add items
      for (final row in orderData) {
        if (row['item_id'] != null) {
          final item = _buildOrderItemFromOptimizedData(row);
          order.items.add(item);
        }
      }
      
      // Update cache
      _orderCache[orderId] = order;
      _cacheTimestamps[orderId] = DateTime.now();
      
      return order;
    } catch (e) {
      throw OrderServiceException('Failed to get order by ID', operation: 'get_by_id', originalError: e);
    }
  }

  /// Categorizes orders into active and completed lists.
  /// 
  /// [orders] is the list of all orders to categorize.
  void _categorizeOrders(List<Order> orders) {
    _activeOrders = orders.where((order) => order.isActive).toList();
    _completedOrders = orders.where((order) => order.isCompleted).toList();
    
    // Sort orders by creation time (newest first)
    _activeOrders.sort((a, b) => b.orderTime.compareTo(a.orderTime));
    _completedOrders.sort((a, b) => b.orderTime.compareTo(a.orderTime));
  }

  /// Saves an order to the database and updates local lists.
  /// 
  /// [order] is the order to save.
  /// Throws [OrderServiceException] if saving fails.
  Future<void> saveOrder(Order order) async {
    try {
      // Validate order before saving
      if (order.id.isEmpty || order.orderNumber.isEmpty) {
        throw OrderServiceException('Invalid order data: missing required fields', operation: 'save_order');
      }
      
      final orderData = _orderToMap(order);
      
      // Save order in a transaction with better error handling
      await _databaseService.database.then((db) async {
        await db.transaction((txn) async {
          debugPrint('Starting order save transaction for: ${order.id}');
          // Use INSERT OR REPLACE to handle potential ID conflicts
          await txn.rawInsert('''
            INSERT OR REPLACE INTO orders (
              id, order_number, status, type, table_id, user_id, customer_name,
              customer_phone, customer_email, customer_address, special_instructions,
              subtotal, tax_amount, tip_amount, hst_amount, discount_amount, gratuity_amount, total_amount, payment_method,
              payment_status, payment_transaction_id, order_time, estimated_ready_time,
              actual_ready_time, served_time, completed_time, is_urgent, priority,
              assigned_to, custom_fields, metadata, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            orderData['id'],
            orderData['order_number'],
            orderData['status'],
            orderData['type'],
            orderData['table_id'],
            orderData['user_id'],
            orderData['customer_name'],
            orderData['customer_phone'],
            orderData['customer_email'],
            orderData['customer_address'],
            orderData['special_instructions'],
            orderData['subtotal'],
            orderData['tax_amount'],
            orderData['tip_amount'],
            orderData['hst_amount'],
            orderData['discount_amount'],
            orderData['gratuity_amount'],
            orderData['total_amount'],
            orderData['payment_method'],
            orderData['payment_status'],
            orderData['payment_transaction_id'],
            orderData['order_time'],
            orderData['estimated_ready_time'],
            orderData['actual_ready_time'],
            orderData['served_time'],
            orderData['completed_time'],
            orderData['is_urgent'],
            orderData['priority'],
            orderData['assigned_to'],
            orderData['custom_fields'],
            orderData['metadata'],
            orderData['created_at'],
            orderData['updated_at'],
          ]);
          
          // Delete existing order items first to avoid duplicates
          await txn.delete('order_items', where: 'order_id = ?', whereArgs: [order.id]);
          
          // Save order items
          for (final item in order.items) {
            final itemData = _orderItemToMap(item, order.id);
            await txn.rawInsert('''
              INSERT OR REPLACE INTO order_items (
                id, order_id, menu_item_id, quantity, unit_price, total_price,
                selected_variant, selected_modifiers, special_instructions,
                custom_properties, is_available, sent_to_kitchen, created_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              itemData['id'],
              itemData['order_id'],
              itemData['menu_item_id'],
              itemData['quantity'],
              itemData['unit_price'],
              itemData['total_price'],
              itemData['selected_variant'],
              itemData['selected_modifiers'],
              itemData['special_instructions'],
              itemData['custom_properties'],
              itemData['is_available'],
              itemData['sent_to_kitchen'],
              itemData['created_at'],
            ]);
          }
          
          debugPrint('Order save transaction completed successfully for: ${order.id}');
        });
      });
      
      debugPrint('About to update local lists for order: ${order.id}');
      // Update local lists
      _addOrderToLocalLists(order);
      debugPrint('Local lists updated for order: ${order.id}');
      
      // Simple direct notifyListeners call (without SchedulerBinding)
      debugPrint('About to call notifyListeners directly for order: ${order.id}');
      try {
        notifyListeners();
        debugPrint('notifyListeners completed successfully for order: ${order.id}');
      } catch (e) {
        debugPrint('Error calling notifyListeners: $e');
        // Continue execution even if notification fails
      }
      
      debugPrint('Order saved successfully: ${order.orderNumber}');
    } catch (e) {
      debugPrint('Error saving order: $e');
      throw OrderServiceException('Failed to save order: $e', operation: 'save_order', originalError: e);
    }
  }

  /// Adds an order to the appropriate local list.
  /// 
  /// [order] is the order to add.
  void _addOrderToLocalLists(Order order) {
    debugPrint('Adding order to local lists: ${order.id}, isActive: ${order.isActive}');
    
    // First, remove the order from both lists to avoid duplicates
    _activeOrders.removeWhere((o) => o.id == order.id);
    _completedOrders.removeWhere((o) => o.id == order.id);
    debugPrint('Removed duplicates from lists');
    
    // Then add it to the appropriate list based on its current status
    if (order.isActive) {
      _activeOrders.insert(0, order);
      debugPrint('Added order to active orders list. Total active: ${_activeOrders.length}');
    } else {
      _completedOrders.insert(0, order);
      debugPrint('Added order to completed orders list. Total completed: ${_completedOrders.length}');
      
      // Limit completed orders in memory to prevent memory issues
      const maxCompletedOrders = 100;
      if (_completedOrders.length > maxCompletedOrders) {
        _completedOrders = _completedOrders.take(maxCompletedOrders).toList();
        debugPrint('Trimmed completed orders to max: $maxCompletedOrders');
      }
    }
    
    debugPrint('Order successfully added to local lists: ${order.id}');
  }

  /// Updates the status of an order.
  /// 
  /// [orderId] is the ID of the order to update.
  /// [newStatus] is the new status to set.
  /// Throws [OrderServiceException] if updating fails.
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final orderIndex = _activeOrders.indexWhere((order) => order.id == orderId);
      if (orderIndex == -1) {
        throw OrderServiceException('Order not found: $orderId', operation: 'update_status');
      }
      
      final order = _activeOrders[orderIndex];
      final updatedOrder = order.copyWith(status: newStatus);
      
      // Update in database
      await _databaseService.update(
        'orders',
        {'status': newStatus.toString().split('.').last},
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
      // Update local list
      _activeOrders[orderIndex] = updatedOrder;
      
      // Move to completed if needed
      if (updatedOrder.isCompleted) {
        _activeOrders.removeAt(orderIndex);
        _completedOrders.insert(0, updatedOrder);
      }
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during status update: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during status update: $e');
      }
      
      debugPrint('Order status updated: ${order.orderNumber} -> ${newStatus.toString().split('.').last}');
    } catch (e) {
      throw OrderServiceException('Failed to update order status', operation: 'update_status', originalError: e);
    }
  }

  /// Gets all orders for a specific user.
  /// 
  /// [userId] is the ID of the user.
  /// Returns a list of orders for that user.
  Future<List<Order>> getOrdersByUser(String userId) async {
    try {
      final orderData = await _databaseService.query(
        'orders',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      
      final orders = <Order>[];
      for (final data in orderData) {
        try {
          final order = await _buildOrderFromData(data);
          orders.add(order);
        } catch (e) {
          debugPrint('Error loading order for user: $e');
          // Continue loading other orders
        }
      }
      
      return orders;
    } catch (e) {
      throw OrderServiceException('Failed to get orders by user', operation: 'get_by_user', originalError: e);
    }
  }

  /// Gets all orders for a specific table.
  /// 
  /// [tableId] is the ID of the table.
  /// Returns a list of orders for that table.
  Future<List<Order>> getOrdersByTable(String tableId) async {
    try {
      final orderData = await _databaseService.query(
        'orders',
        where: 'table_id = ?',
        whereArgs: [tableId],
        orderBy: 'created_at DESC',
      );
      
      final orders = <Order>[];
      for (final data in orderData) {
        try {
          final order = await _buildOrderFromData(data);
          orders.add(order);
        } catch (e) {
          debugPrint('Error loading order for table: $e');
          // Continue loading other orders
        }
      }
      
      return orders;
    } catch (e) {
      throw OrderServiceException('Failed to get orders by table', operation: 'get_by_table', originalError: e);
    }
  }

  /// Refreshes the order lists from the database.
  /// 
  /// This method can be called to reload all orders from the database.
  Future<void> refreshOrders() async {
    await _loadOrders();
  }

  /// Sets the loading state and notifies listeners.
  /// 
  /// [loading] is the new loading state.
  void _setLoading(bool loading) {
    _isLoading = loading;
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during loading state change: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during loading state change: $e');
    }
  }

  /// Converts an Order object to a database map.
  /// 
  /// [order] is the order to convert.
  /// Returns a map suitable for database insertion.
  Map<String, dynamic> _orderToMap(Order order) {
    return {
      'id': order.id,
      'order_number': order.orderNumber,
      'status': order.status.toString().split('.').last,
      'type': order.type.toString().split('.').last,
      'table_id': order.tableId,
      'user_id': order.userId,
      'customer_name': order.customerName,
      'customer_phone': order.customerPhone,
      'customer_email': order.customerEmail,
      'customer_address': order.customerAddress,
      'special_instructions': order.specialInstructions,
      'subtotal': order.subtotal,
      'tax_amount': order.taxAmount,
      'tip_amount': order.tipAmount,
      'hst_amount': order.hstAmount,
      'discount_amount': order.discountAmount,
      'gratuity_amount': order.gratuityAmount,
      'total_amount': order.totalAmount,
      'payment_method': order.paymentMethod,
      'payment_status': order.paymentStatus.toString().split('.').last,
      'payment_transaction_id': order.paymentTransactionId,
      'order_time': order.orderTime.toIso8601String(),
      'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
      'actual_ready_time': order.actualReadyTime?.toIso8601String(),
      'served_time': order.servedTime?.toIso8601String(),
      'completed_time': order.completedTime?.toIso8601String(),
      'is_urgent': order.isUrgent ? 1 : 0,
      'priority': order.priority,
      'assigned_to': order.assignedTo,
      'custom_fields': jsonEncode(order.customFields),
      'metadata': jsonEncode(order.metadata),
      'created_at': order.createdAt.toIso8601String(),
      'updated_at': order.updatedAt.toIso8601String(),
    };
  }

  /// Converts an OrderItem object to a database map.
  /// 
  /// [item] is the order item to convert.
  /// [orderId] is the ID of the parent order.
  /// Returns a map suitable for database insertion.
  Map<String, dynamic> _orderItemToMap(OrderItem item, String orderId) {
    return {
      'id': item.id,
      'order_id': orderId,
      'menu_item_id': item.menuItem.id,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'total_price': item.totalPrice,
      'selected_variant': item.selectedVariant,
      'selected_modifiers': jsonEncode(item.selectedModifiers),
      'special_instructions': item.specialInstructions,
      'notes': item.notes, // Include notes field
      'custom_properties': jsonEncode(item.customProperties),
      'is_available': item.isAvailable ? 1 : 0,
      'sent_to_kitchen': item.sentToKitchen ? 1 : 0,
      'kitchen_status': item.sentToKitchen ? 'preparing' : 'pending', // Include kitchen_status
      'created_at': item.createdAt.toIso8601String(),
    };
  }

  /// Gets all orders from the database.
  /// 
  /// Returns a list of all orders sorted by creation time (newest first).
  Future<List<Order>> getAllOrders() async {
    try {
      debugPrint('OrderService: Starting to load all orders...');
      
      final orderData = await _databaseService.query(
        'orders',
        orderBy: 'created_at DESC',
      );
      
      debugPrint('OrderService: Found ${orderData.length} orders in database');
      
      final orders = <Order>[];
      for (int i = 0; i < orderData.length; i++) {
        final data = orderData[i];
        try {
          final order = await _buildOrderFromData(data);
          orders.add(order);
        } catch (e) {
          debugPrint('Error loading order ${i + 1}/${orderData.length} (ID: ${data['id']}): $e');
          // Continue loading other orders
        }
      }
      
      debugPrint('OrderService: Successfully loaded ${orders.length}/${orderData.length} orders');
      return orders;
    } catch (e) {
      debugPrint('OrderService: Failed to get all orders: $e');
      throw OrderServiceException('Failed to get all orders', operation: 'get_all', originalError: e);
    }
  }

  /// Deletes an order from the database.
  /// 
  /// [orderId] is the ID of the order to delete.
  /// Throws [OrderServiceException] if deletion fails.
  Future<void> deleteOrder(String orderId) async {
    try {
      // Delete in a transaction
      await _databaseService.database.then((db) async {
        await db.transaction((txn) async {
          // Delete order items first
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderId],
          );
          
          // Delete the order
          await txn.delete(
            'orders',
            where: 'id = ?',
            whereArgs: [orderId],
          );
        });
      });
      
      // Remove from local lists
      _activeOrders.removeWhere((order) => order.id == orderId);
      _completedOrders.removeWhere((order) => order.id == orderId);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during order deletion: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during order deletion: $e');
      }
      
      debugPrint('Order deleted: $orderId');
    } catch (e) {
      throw OrderServiceException('Failed to delete order', operation: 'delete', originalError: e);
    }
  }

  void updateDatabase(DatabaseService db) {
    _databaseService = db;
    _loadOrders();
  }

  /// Builds an Order object from database row data.
  /// 
  /// This method loads order items separately from the database.
  /// [data] is the database row containing order data.
  /// Returns a complete Order object with its items.
  Future<Order> _buildOrderFromData(Map<String, dynamic> data) async {
    try {
      // Create the order from the main data
      final order = Order(
        id: data['id'],
        orderNumber: data['order_number'],
        status: OrderStatus.values.firstWhere(
          (e) => e.toString().split('.').last == data['status'],
          orElse: () => OrderStatus.pending,
        ),
        type: OrderType.values.firstWhere(
          (e) => e.toString().split('.').last == data['type'],
          orElse: () => OrderType.dineIn,
        ),
        tableId: data['table_id'],
        userId: data['user_id'],
        customerName: data['customer_name'],
        customerPhone: data['customer_phone'],
        customerEmail: data['customer_email'],
        customerAddress: data['customer_address'],
        specialInstructions: data['special_instructions'],
        subtotal: (data['subtotal'] ?? 0.0).toDouble(),
        taxAmount: (data['tax_amount'] ?? 0.0).toDouble(),
        tipAmount: (data['tip_amount'] ?? 0.0).toDouble(),
        hstAmount: (data['hst_amount'] ?? 0.0).toDouble(),
        discountAmount: (data['discount_amount'] ?? 0.0).toDouble(),
        gratuityAmount: (data['gratuity_amount'] ?? 0.0).toDouble(),
        totalAmount: (data['total_amount'] ?? 0.0).toDouble(),
        paymentMethod: data['payment_method'],
        paymentStatus: PaymentStatus.values.firstWhere(
          (e) => e.toString().split('.').last == (data['payment_status'] ?? 'pending'),
          orElse: () => PaymentStatus.pending,
        ),
        paymentTransactionId: data['payment_transaction_id'],
        orderTime: DateTime.tryParse(data['order_time']) ?? DateTime.now(),
        estimatedReadyTime: data['estimated_ready_time'] != null 
            ? DateTime.tryParse(data['estimated_ready_time']) 
            : null,
        actualReadyTime: data['actual_ready_time'] != null 
            ? DateTime.tryParse(data['actual_ready_time']) 
            : null,
        servedTime: data['served_time'] != null 
            ? DateTime.tryParse(data['served_time']) 
            : null,
        completedTime: data['completed_time'] != null 
            ? DateTime.tryParse(data['completed_time']) 
            : null,
        isUrgent: (data['is_urgent'] ?? 0) == 1,
        priority: data['priority'] ?? 0,
        assignedTo: data['assigned_to'],
        customFields: data['custom_fields'] != null 
            ? jsonDecode(data['custom_fields']) 
            : {},
        metadata: data['metadata'] != null 
            ? jsonDecode(data['metadata']) 
            : {},
        createdAt: DateTime.tryParse(data['created_at']) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(data['updated_at']) ?? DateTime.now(),
        items: [], // Will be loaded separately
      );

      // Load order items for this order
      final orderItemsData = await _databaseService.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [order.id],
      );

      // Load each order item with its menu item data
      for (final itemData in orderItemsData) {
        try {
          // Get menu item details
          final menuItemData = await _databaseService.query(
            'menu_items',
            where: 'id = ?',
            whereArgs: [itemData['menu_item_id']],
          );

          if (menuItemData.isNotEmpty) {
            final menuItemRow = menuItemData.first;
            final menuItem = MenuItem(
              id: menuItemRow['id'],
              name: menuItemRow['name'] ?? 'Unknown Item',
              description: menuItemRow['description'] ?? '',
              price: (menuItemRow['price'] ?? 0.0).toDouble(),
              categoryId: menuItemRow['category_id'] ?? '',
              imageUrl: menuItemRow['image_url'],
              isAvailable: (menuItemRow['is_available'] ?? 1) == 1,
              preparationTime: menuItemRow['preparation_time'] ?? 0,
              isVegetarian: (menuItemRow['is_vegetarian'] ?? 0) == 1,
              isVegan: (menuItemRow['is_vegan'] ?? 0) == 1,
              isGlutenFree: (menuItemRow['is_gluten_free'] ?? 0) == 1,
              isSpicy: (menuItemRow['is_spicy'] ?? 0) == 1,
              spiceLevel: menuItemRow['spice_level'] ?? 0,
            );

            final orderItem = OrderItem(
              id: itemData['id'],
              menuItem: menuItem,
              quantity: itemData['quantity'] ?? 1,
              unitPrice: (itemData['unit_price'] ?? 0.0).toDouble(),
              selectedVariant: itemData['selected_variant'],
              selectedModifiers: itemData['selected_modifiers'] != null 
                  ? List<String>.from(jsonDecode(itemData['selected_modifiers'])) 
                  : [],
              specialInstructions: itemData['special_instructions'],
              notes: itemData['notes'],
              customProperties: itemData['custom_properties'] != null 
                  ? jsonDecode(itemData['custom_properties']) 
                  : {},
              isAvailable: (itemData['is_available'] ?? 1) == 1,
              sentToKitchen: (itemData['sent_to_kitchen'] ?? 0) == 1,
              createdAt: DateTime.tryParse(itemData['created_at']) ?? DateTime.now(),
            );

            order.items.add(orderItem);
          }
        } catch (e) {
          debugPrint('Error loading order item: $e');
          // Continue loading other items
        }
      }

      return order;
    } catch (e) {
      debugPrint('Error building order from data: $e');
      rethrow;
    }
  }

  void _safeNotifyListeners() {
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('Error notifying listeners: $e');
    }
  }
} 