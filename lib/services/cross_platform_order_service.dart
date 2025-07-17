import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/order_log.dart';
import 'cross_platform_database_service.dart';
import 'order_log_service.dart';

/// Cross-platform order service that provides seamless order management
/// across Android, iOS, and web platforms with automatic synchronization.
class CrossPlatformOrderService extends ChangeNotifier {
  static CrossPlatformOrderService? _instance;
  static final _uuid = const Uuid();
  
  final CrossPlatformDatabaseService _db = CrossPlatformDatabaseService();
  late StreamSubscription _dataChangeSubscription;
  OrderLogService? _orderLogService;
  
  // Cache for performance
  final Map<String, Order> _orderCache = {};
  final List<Order> _activeOrders = [];
  final List<Order> _completedOrders = [];
  
  // State management
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _lastError;
  
  // Current user context for logging
  String? _currentUserId;
  String? _currentUserName;
  
  factory CrossPlatformOrderService() {
    _instance ??= CrossPlatformOrderService._internal();
    return _instance!;
  }
  
  CrossPlatformOrderService._internal();
  
  // Getters
  List<Order> get activeOrders => List.unmodifiable(_activeOrders);
  List<Order> get completedOrders => List.unmodifiable(_completedOrders);
  List<Order> get allOrders => [..._activeOrders, ..._completedOrders];
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  
  /// Set current user context for logging
  void setCurrentUser(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
    _orderLogService?.setCurrentUser(userId, userName);
  }
  
  /// Initialize order logging service with database service
  void initializeOrderLogging(dynamic databaseService) {
    try {
      _orderLogService = OrderLogService(databaseService);
      if (_currentUserId != null && _currentUserName != null) {
        _orderLogService!.setCurrentUser(_currentUserId!, _currentUserName!);
      }
      debugPrint('✅ Order logging service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize order logging service: $e');
    }
  }
  
  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🚀 Initializing Cross-Platform Order Service...');
      _isLoading = true;
      _lastError = null;
      notifyListeners();
      
      // Initialize database
      await _db.initialize();
      
      // Initialize order logging service
      try {
        // We need to get the database service from the cross-platform service
        // For now, we'll initialize it later when we have access to the regular database service
        debugPrint('⚠️ Order logging will be initialized when database service is available');
      } catch (e) {
        debugPrint('⚠️ Failed to initialize order logging: $e');
      }
      
      // Load existing orders
      await _loadOrders();
      
      // Listen for data changes
      _dataChangeSubscription = _db.dataChanges.listen(_handleDataChange);
      
      _isInitialized = true;
      debugPrint('✅ Cross-Platform Order Service initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize order service: $e';
      debugPrint('❌ $_lastError');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load orders from database
  Future<void> _loadOrders() async {
    try {
      final orderData = await _db.getAllData('orders');
      
      _orderCache.clear();
      _activeOrders.clear();
      _completedOrders.clear();
      
      for (final data in orderData) {
        try {
          final order = _orderFromJson(data);
          
          // Skip orders with no valid items
          if (order.items.isEmpty) {
            debugPrint('⚠️ Skipping order with no items: ${order.id}');
            continue;
          }
          
          // Skip orders with invalid menu item IDs
          bool hasInvalidItems = false;
          for (final item in order.items) {
            if (item.menuItem.id.isEmpty || item.menuItem.id.startsWith('placeholder_')) {
              debugPrint('⚠️ Skipping order with invalid menu item: ${order.id} - ${item.menuItem.id}');
              hasInvalidItems = true;
              break;
            }
          }
          
          if (hasInvalidItems) {
            continue;
          }
          
          _orderCache[order.id] = order;
          
          if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
            _completedOrders.add(order);
          } else {
            _activeOrders.add(order);
          }
        } catch (e) {
          debugPrint('⚠️ Error loading order: $e');
          // Skip corrupted orders
        }
      }
      
      // Sort orders by creation time
      _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      debugPrint('📦 Loaded ${_orderCache.length} valid orders from database');
    } catch (e) {
      debugPrint('❌ Failed to load orders: $e');
      rethrow;
    }
  }
  
  /// Handle data changes from database
  void _handleDataChange(Map<String, dynamic> change) {
    final action = change['action'] as String;
    final collection = change['collection'] as String;
    
    if (collection != 'orders') return;
    
    switch (action) {
      case 'save':
        final data = change['data'] as Map<String, dynamic>;
        final order = _orderFromJson(data);
        _updateOrderInCache(order);
        break;
      case 'delete':
        final id = change['id'] as String;
        _removeOrderFromCache(id);
        break;
    }
    
    notifyListeners();
  }
  
  /// Update order in cache and lists
  void _updateOrderInCache(Order order) {
    final existingOrder = _orderCache[order.id];
    _orderCache[order.id] = order;
    
    // Remove from existing lists
    if (existingOrder != null) {
      _activeOrders.removeWhere((o) => o.id == order.id);
      _completedOrders.removeWhere((o) => o.id == order.id);
    }
    
    // Add to appropriate list
    if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
      _completedOrders.insert(0, order);
    } else {
      _activeOrders.insert(0, order);
    }
    
    // Maintain list size limits
    if (_completedOrders.length > 100) {
      _completedOrders.removeRange(100, _completedOrders.length);
    }
  }
  
  /// Remove order from cache and lists
  void _removeOrderFromCache(String id) {
    _orderCache.remove(id);
    _activeOrders.removeWhere((o) => o.id == id);
    _completedOrders.removeWhere((o) => o.id == id);
  }
  
  /// Create a new order
  Future<Order> createOrder({
    required String type,
    required String userId,
    String? tableId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? specialInstructions,
  }) async {
    try {
      final orderId = _uuid.v4();
      final orderNumber = _generateOrderNumber(type);
      final now = DateTime.now();
      
      final order = Order(
        id: orderId,
        orderNumber: orderNumber,
        status: OrderStatus.pending,
        type: _parseOrderType(type),
        tableId: tableId,
        userId: userId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        specialInstructions: specialInstructions,
        items: [],
        subtotal: 0.0,
        taxAmount: 0.0,
        tipAmount: 0.0,
        hstAmount: 0.0,
        discountAmount: 0.0,
        gratuityAmount: 0.0,
        totalAmount: 0.0,
        orderTime: now,
        createdAt: now,
        updatedAt: now,
      );
      
      await _saveOrder(order);
      
      // Log order creation
      try {
        await _orderLogService?.logOrderCreated(
          order,
          _currentUserId ?? userId,
          _currentUserName ?? 'Unknown User',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log order creation: $e');
      }
      
      return order;
    } catch (e) {
      debugPrint('❌ Failed to create order: $e');
      rethrow;
    }
  }
  
  /// Save order to database
  Future<void> _saveOrder(Order order) async {
    try {
      // Validate order before saving
      if (order.items.isEmpty) {
        debugPrint('⚠️ Cannot save order with no items: ${order.id}');
        return;
      }
      
      // Validate all items have valid menu_item_id
      for (final item in order.items) {
        if (item.menuItem.id.isEmpty || item.menuItem.id.startsWith('placeholder_')) {
          debugPrint('⚠️ Cannot save order with invalid menu item: ${order.id} - ${item.menuItem.id}');
          return;
        }
      }
      
      final data = _orderToJson(order);
      await _db.saveData('orders', order.id, data);
      _updateOrderInCache(order);
      notifyListeners();
      
      debugPrint('✅ Saved order: ${order.id}');
    } catch (e) {
      debugPrint('❌ Error saving order: $e');
      _lastError = 'Failed to save order: $e';
      rethrow;
    }
  }
  
  /// Update order
  Future<void> updateOrder(Order order) async {
    try {
      final updatedOrder = order.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await _saveOrder(updatedOrder);
      debugPrint('✅ Updated order: ${order.orderNumber}');
    } catch (e) {
      _lastError = 'Failed to update order: $e';
      debugPrint('❌ $_lastError');
      rethrow;
    }
  }
  
  /// Add item to order
  Future<void> addItemToOrder(String orderId, OrderItem item) async {
    try {
      final order = _orderCache[orderId];
      if (order == null) throw Exception('Order not found');
      
      final updatedItems = [...order.items, item];
      final updatedOrder = order.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      
      // Recalculate totals
      final recalculatedOrder = _recalculateOrderTotals(updatedOrder);
      await _saveOrder(recalculatedOrder);
      
      // Log item addition
      try {
        await _orderLogService?.logItemAdded(
          recalculatedOrder,
          item,
          _currentUserId ?? 'system',
          _currentUserName ?? 'System',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log item addition: $e');
      }
      
      debugPrint('✅ Added item to order: ${order.orderNumber}');
    } catch (e) {
      _lastError = 'Failed to add item to order: $e';
      debugPrint('❌ $_lastError');
      rethrow;
    }
  }
  
  /// Remove item from order
  Future<void> removeItemFromOrder(String orderId, String itemId) async {
    try {
      final order = _orderCache[orderId];
      if (order == null) throw Exception('Order not found');
      
      final updatedItems = order.items.where((item) => item.id != itemId).toList();
      final updatedOrder = order.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      
      // Recalculate totals
      final recalculatedOrder = _recalculateOrderTotals(updatedOrder);
      await _saveOrder(recalculatedOrder);
      
      debugPrint('✅ Removed item from order: ${order.orderNumber}');
    } catch (e) {
      _lastError = 'Failed to remove item from order: $e';
      debugPrint('❌ $_lastError');
      rethrow;
    }
  }
  
  /// Update order status
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) throw Exception('Order not found');
      
      final oldStatus = order.status;
      final updatedOrder = order.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      
      await _saveOrder(updatedOrder);
      
      // Log status change
      try {
        await _orderLogService?.logStatusChange(
          updatedOrder,
          oldStatus,
          newStatus,
          _currentUserId ?? 'system',
          _currentUserName ?? 'System',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log status change: $e');
      }
      
      debugPrint('✅ Updated order status: ${order.orderNumber} -> ${newStatus.toString().split('.').last}');
    } catch (e) {
      debugPrint('❌ Failed to update order status: $e');
      rethrow;
    }
  }
  
  /// Delete order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _db.deleteData('orders', orderId);
      _removeOrderFromCache(orderId);
      notifyListeners();
      
      debugPrint('✅ Deleted order: $orderId');
    } catch (e) {
      _lastError = 'Failed to delete order: $e';
      debugPrint('❌ $_lastError');
      rethrow;
    }
  }
  
  /// Get order by ID
  Order? getOrderById(String id) {
    return _orderCache[id];
  }
  
  /// Get orders by status
  List<Order> getOrdersByStatus(OrderStatus status) {
    return allOrders.where((order) => order.status == status).toList();
  }
  
  /// Get orders by table
  List<Order> getOrdersByTable(String tableId) {
    return allOrders.where((order) => order.tableId == tableId).toList();
  }
  
  /// Get orders by user
  List<Order> getOrdersByUser(String userId) {
    return allOrders.where((order) => order.userId == userId).toList();
  }
  
  /// Send order to kitchen
  Future<void> sendOrderToKitchen(String orderId, {List<OrderItem>? specificItems}) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) throw Exception('Order not found');
      
      // Update order status if sending full order
      if (specificItems == null) {
        await updateOrderStatus(orderId, OrderStatus.preparing);
      }
      
      // Log sent to kitchen
      try {
        await _orderLogService?.logSentToKitchen(
          order,
          _currentUserId ?? 'system',
          _currentUserName ?? 'System',
          items: specificItems,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log sent to kitchen: $e');
      }
      
      debugPrint('✅ Sent order to kitchen: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to send order to kitchen: $e');
      rethrow;
    }
  }
  
  /// Cancel order
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    try {
      final order = getOrderById(orderId);
      if (order == null) throw Exception('Order not found');
      
      await updateOrderStatus(orderId, OrderStatus.cancelled);
      
      // Log order cancellation
      try {
        await _orderLogService?.logOrderCancelled(
          order,
          _currentUserId ?? 'system',
          _currentUserName ?? 'System',
          reason: reason,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log order cancellation: $e');
      }
      
      debugPrint('✅ Cancelled order: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to cancel order: $e');
      rethrow;
    }
  }
  
  /// Generate order number
  String _generateOrderNumber(String type) {
    final prefix = type.toUpperCase().substring(0, 2);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = (timestamp % 100000).toString().padLeft(5, '0');
    return '$prefix-$randomPart';
  }
  
  /// Recalculate order totals
  Order _recalculateOrderTotals(Order order) {
    double subtotal = 0.0;
    
    for (final item in order.items) {
      subtotal += item.totalPrice;
    }
    
    final hstAmount = subtotal * 0.13; // 13% HST
    final totalAmount = subtotal + hstAmount + order.tipAmount + 
                       order.gratuityAmount - order.discountAmount;
    
    return order.copyWith(
      subtotal: subtotal,
      hstAmount: hstAmount,
      taxAmount: hstAmount, // For backward compatibility
      totalAmount: totalAmount,
    );
  }
  
  /// Convert order to JSON
  Map<String, dynamic> _orderToJson(Order order) {
    return {
      'id': order.id,
      'order_number': order.orderNumber,
      'status': order.status.toString().split('.').last,
      'type': order.type.toString().split('.').last,
      'table_id': order.tableId,
      'user_id': order.userId,
      'customer_info': {
        'name': order.customerName,
        'phone': order.customerPhone,
        'email': order.customerEmail,
        'address': order.customerAddress,
      },
      'items': order.items.map((item) => {
        'id': item.id,
        'menu_item_id': item.menuItem.id,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'selected_variant': item.selectedVariant,
        'selected_modifiers': item.selectedModifiers,
        'special_instructions': item.specialInstructions,
        'notes': item.notes,
        'custom_properties': item.customProperties,
        'is_available': item.isAvailable,
        'sent_to_kitchen': item.sentToKitchen,
        'created_at': item.createdAt.millisecondsSinceEpoch,
      }).toList(),
      'totals': {
        'subtotal': order.subtotal,
        'tax_amount': order.taxAmount,
        'tip_amount': order.tipAmount,
        'hst_amount': order.hstAmount,
        'discount_amount': order.discountAmount,
        'gratuity_amount': order.gratuityAmount,
        'total_amount': order.totalAmount,
      },
      'timestamps': {
        'order_time': order.orderTime.millisecondsSinceEpoch,
        'estimated_ready_time': order.estimatedReadyTime?.millisecondsSinceEpoch,
        'actual_ready_time': order.actualReadyTime?.millisecondsSinceEpoch,
        'served_time': order.servedTime?.millisecondsSinceEpoch,
        'completed_time': order.completedTime?.millisecondsSinceEpoch,
        'created_at': order.createdAt.millisecondsSinceEpoch,
        'updated_at': order.updatedAt.millisecondsSinceEpoch,
      },
      'metadata': {
        'special_instructions': order.specialInstructions,
        'is_urgent': order.isUrgent,
        'priority': order.priority,
        'assigned_to': order.assignedTo,
        'payment_method': order.paymentMethod,
        'payment_status': order.paymentStatus.toString().split('.').last,
        'payment_transaction_id': order.paymentTransactionId,
        'custom_fields': order.customFields,
      },
    };
  }
  
  /// Convert JSON to order
  Order _orderFromJson(Map<String, dynamic> data) {
    final customerInfo = data['customer_info'] as Map<String, dynamic>? ?? {};
    final items = data['items'] as List<dynamic>? ?? [];
    final totals = data['totals'] as Map<String, dynamic>? ?? {};
    final timestamps = data['timestamps'] as Map<String, dynamic>? ?? {};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    
    // Filter out invalid order items to prevent foreign key constraint errors
    final validItems = <OrderItem>[];
    for (final item in items) {
      try {
        final menuItemId = item['menu_item_id'] as String? ?? '';
        
        // Skip items with empty or invalid menu_item_id
        if (menuItemId.isEmpty) {
          debugPrint('⚠️ Skipping order item with empty menu_item_id');
          continue;
        }
        
        final orderItem = OrderItem(
          id: item['id'] as String? ?? '',
          menuItem: _createMenuItemFromId(menuItemId),
          quantity: item['quantity'] as int? ?? 1,
          unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
          selectedVariant: item['selected_variant'] as String?,
          selectedModifiers: _parseModifiers(item['selected_modifiers']),
          specialInstructions: item['special_instructions'] as String?,
          customProperties: _parseCustomProperties(item['custom_properties']),
          isAvailable: item['is_available'] as bool? ?? true,
          sentToKitchen: item['sent_to_kitchen'] as bool? ?? false,
          createdAt: item['created_at'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(item['created_at'] as int)
              : DateTime.now(),
          notes: item['notes'] as String?,
        );
        
        // Only add if the order item ID is not empty
        if (orderItem.id.isNotEmpty) {
          validItems.add(orderItem);
        } else {
          debugPrint('⚠️ Skipping order item with empty ID');
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing order item: $e');
        // Skip invalid items rather than failing the entire order
      }
    }
    
    return Order(
      id: data['id'] as String,
      orderNumber: data['order_number'] as String,
      status: _parseOrderStatus(data['status'] as String?),
      type: _parseOrderType(data['type'] as String?),
      tableId: data['table_id'] as String?,
      userId: data['user_id'] as String?,
      customerName: customerInfo['name'] as String?,
      customerPhone: customerInfo['phone'] as String?,
      customerEmail: customerInfo['email'] as String?,
      customerAddress: customerInfo['address'] as String?,
      specialInstructions: metadata['special_instructions'] as String?,
      items: validItems, // Use filtered valid items
      subtotal: (totals['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (totals['tax_amount'] as num?)?.toDouble() ?? 0.0,
      tipAmount: (totals['tip_amount'] as num?)?.toDouble() ?? 0.0,
      hstAmount: (totals['hst_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (totals['discount_amount'] as num?)?.toDouble() ?? 0.0,
      gratuityAmount: (totals['gratuity_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (totals['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: metadata['payment_method'] as String?,
      paymentStatus: _parsePaymentStatus(metadata['payment_status'] as String?),
      paymentTransactionId: metadata['payment_transaction_id'] as String?,
      orderTime: timestamps['order_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['order_time'] as int)
          : DateTime.now(),
      estimatedReadyTime: timestamps['estimated_ready_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['estimated_ready_time'] as int)
          : null,
      actualReadyTime: timestamps['actual_ready_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['actual_ready_time'] as int)
          : null,
      servedTime: timestamps['served_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['served_time'] as int)
          : null,
      completedTime: timestamps['completed_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['completed_time'] as int)
          : null,
      isUrgent: metadata['is_urgent'] as bool? ?? false,
      priority: metadata['priority'] as int? ?? 0,
      assignedTo: metadata['assigned_to'] as String?,
      customFields: _parseCustomFields(metadata['custom_fields']),
      createdAt: timestamps['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['created_at'] as int)
          : DateTime.now(),
      updatedAt: timestamps['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamps['updated_at'] as int)
          : DateTime.now(),
    );
  }
  
  /// Parse order status from string
  OrderStatus _parseOrderStatus(String? status) {
    if (status == null) return OrderStatus.pending;
    return OrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => OrderStatus.pending,
    );
  }
  
  /// Parse order type from string  
  OrderType _parseOrderType(String? type) {
    if (type == null) return OrderType.dineIn;
    return OrderType.values.firstWhere(
      (e) => e.toString().split('.').last == type,
      orElse: () => OrderType.dineIn,
    );
  }
  
  /// Parse payment status from string
  PaymentStatus _parsePaymentStatus(String? status) {
    if (status == null) return PaymentStatus.pending;
    return PaymentStatus.values.firstWhere(
      (e) => e.toString().split('.').last == status,
      orElse: () => PaymentStatus.pending,
    );
  }
  
  /// Parse modifiers from string or list
  List<String> _parseModifiers(dynamic modifiers) {
    if (modifiers is String) {
      return modifiers.isEmpty ? [] : modifiers.split(',');
    } else if (modifiers is List) {
      return modifiers.cast<String>();
    }
    return [];
  }
  
  /// Parse custom properties from string or map
  Map<String, dynamic> _parseCustomProperties(dynamic properties) {
    if (properties is String) {
      try {
        return json.decode(properties) as Map<String, dynamic>;
      } catch (e) {
        return {};
      }
    } else if (properties is Map<String, dynamic>) {
      return properties;
    }
    return {};
  }
  
  /// Parse custom fields from string or map
  Map<String, dynamic> _parseCustomFields(dynamic fields) {
    if (fields is String) {
      try {
        return json.decode(fields) as Map<String, dynamic>;
      } catch (e) {
        return {};
      }
    } else if (fields is Map<String, dynamic>) {
      return fields;
    }
    return {};
  }
  
  /// Create a basic MenuItem from ID (for compatibility)
  MenuItem _createMenuItemFromId(String menuItemId) {
    // Validate that menuItemId is not empty
    if (menuItemId.isEmpty) {
      debugPrint('⚠️ Cannot create MenuItem with empty ID');
      // Return a default placeholder that won't cause database issues
      return MenuItem(
        id: 'placeholder_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Invalid Item',
        description: 'Item with missing ID',
        price: 0.0,
        categoryId: 'default-category',
        isAvailable: false,
      );
    }
    
    // This is a placeholder - in a real implementation, you'd fetch from menu service
    return MenuItem(
      id: menuItemId,
      name: 'Unknown Item',
      description: 'Item loaded from order history',
      price: 0.0,
      categoryId: 'default-category',
      isAvailable: true,
    );
  }
  
  /// Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _db.getSyncStatus();
  }
  
  /// Force synchronization
  Future<void> forceSyncNow() async {
    await _db.forceSyncNow();
  }
  
  /// Refresh orders from database
  Future<void> refreshOrders() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _loadOrders();
      _lastError = null;
    } catch (e) {
      _lastError = 'Failed to refresh orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _dataChangeSubscription.cancel();
    _db.dispose();
    super.dispose();
  }
} 