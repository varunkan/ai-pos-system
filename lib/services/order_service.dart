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

/// Service responsible for all order-related operations in the POS system.
/// 
/// This service manages order lifecycle, persistence, and business logic
/// for orders including creation, updates, status changes, and queries.
class OrderService with ChangeNotifier {
  DatabaseService _databaseService;
  List<Order> _activeOrders = [];
  List<Order> _completedOrders = [];
  bool _isLoading = false;

  OrderService(this._databaseService) {
    // Temporarily disable automatic order loading to prevent crashes
    // _loadOrders();
    debugPrint('OrderService initialized without loading orders to prevent crashes');
  }

  // Getters
  List<Order> get activeOrders => List.unmodifiable(_activeOrders);
  List<Order> get completedOrders => List.unmodifiable(_completedOrders);
  bool get isLoading => _isLoading;

  /// Loads all orders from the database and categorizes them.
  /// 
  /// This method is called during service initialization and can be
  /// called manually to refresh the order lists.
  Future<void> _loadOrders() async {
    _setLoading(true);
    
    try {
      final ordersData = await _databaseService.query('orders');
      final allOrders = <Order>[];
      
      for (final orderData in ordersData) {
        try {
          final order = await _buildOrderFromData(orderData);
          allOrders.add(order);
        } catch (e) {
          debugPrint('Error loading order ${orderData['id']}: $e');
          // Continue loading other orders even if one fails
        }
      }
      
      _categorizeOrders(allOrders);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during load: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during load: $e');
      }
    } catch (e) {
      throw OrderServiceException('Failed to load orders', operation: 'load_orders', originalError: e);
    } finally {
      _setLoading(false);
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

  /// Builds an Order object from database data.
  /// 
  /// [orderData] is the raw database data for the order.
  /// Returns the built Order object.
  /// Throws [OrderServiceException] if building fails.
  Future<Order> _buildOrderFromData(Map<String, dynamic> orderData) async {
    try {
      // Get order items
      final orderItemsData = await _databaseService.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderData['id']],
      );
      
      final orderItems = <OrderItem>[];
      for (final itemData in orderItemsData) {
        try {
          final menuItemData = await _databaseService.query(
            'menu_items',
            where: 'id = ?',
            whereArgs: [itemData['menu_item_id']],
          );
          
          if (menuItemData.isNotEmpty) {
            final menuItem = MenuItem.fromJson(menuItemData.first);
            // Convert database field names to JSON field names for OrderItem
            final orderItemJson = {
              'id': itemData['id'],
              'quantity': itemData['quantity'],
              'unitPrice': itemData['unit_price'], // Fix: map database field to JSON field
              'selectedVariant': itemData['selected_variant'],
              'selectedModifiers': itemData['selected_modifiers'] != null 
                  ? jsonDecode(itemData['selected_modifiers']) 
                  : [],
              'specialInstructions': itemData['special_instructions'],
              'customProperties': itemData['custom_properties'] != null 
                  ? jsonDecode(itemData['custom_properties']) 
                  : {},
              'isAvailable': itemData['is_available'] == 1,
              'sentToKitchen': itemData['sent_to_kitchen'] == 1,
              'createdAt': itemData['created_at'],
              'menuItem': menuItem.toJson(),
            };
            final orderItem = OrderItem.fromJson(orderItemJson);
            orderItems.add(orderItem);
          }
        } catch (e) {
          debugPrint('Error loading order item: $e');
          // Continue loading other items even if one fails
        }
      }
      
      // Convert database field names to JSON field names
      final jsonData = {
        'id': orderData['id'],
        'orderNumber': orderData['order_number'],
        'status': orderData['status'],
        'type': orderData['type'],
        'tableId': orderData['table_id'],
        'userId': orderData['user_id'],
        'customerName': orderData['customer_name'],
        'customerPhone': orderData['customer_phone'],
        'customerEmail': orderData['customer_email'],
        'customerAddress': orderData['customer_address'],
        'specialInstructions': orderData['special_instructions'],
        'subtotal': orderData['subtotal'],
        'taxAmount': orderData['tax_amount'],
        'tipAmount': orderData['tip_amount'],
        'hstAmount': orderData['hst_amount'] ?? 0.0,
        'discountAmount': orderData['discount_amount'] ?? 0.0,
        'gratuityAmount': orderData['gratuity_amount'] ?? 0.0,
        'totalAmount': orderData['total_amount'],
        'paymentMethod': orderData['payment_method'],
        'paymentStatus': orderData['payment_status'],
        'paymentTransactionId': orderData['payment_transaction_id'],
        'orderTime': orderData['order_time'],
        'estimatedReadyTime': orderData['estimated_ready_time'],
        'actualReadyTime': orderData['actual_ready_time'],
        'servedTime': orderData['served_time'],
        'completedTime': orderData['completed_time'],
        'isUrgent': orderData['is_urgent'] == 1,
        'priority': orderData['priority'],
        'assignedTo': orderData['assigned_to'],
        'customFields': orderData['custom_fields'] != null ? jsonDecode(orderData['custom_fields']) : {},
        'metadata': orderData['metadata'] != null ? jsonDecode(orderData['metadata']) : {},
        'createdAt': orderData['created_at'],
        'updatedAt': orderData['updated_at'],
        'items': orderItems.map((item) => item.toJson()).toList(),
      };
      
      return Order.fromJson(jsonData);
    } catch (e) {
      throw OrderServiceException('Failed to build order from data', operation: 'build_order', originalError: e);
    }
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

  /// Gets an order by its ID.
  /// 
  /// [orderId] is the ID of the order to retrieve.
  /// Returns the order if found, null otherwise.
  Future<Order?> getOrderById(String orderId) async {
    try {
      final orderData = await _databaseService.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );
      
      if (orderData.isEmpty) return null;
      
      return await _buildOrderFromData(orderData.first);
    } catch (e) {
      throw OrderServiceException('Failed to get order by ID', operation: 'get_by_id', originalError: e);
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
      'custom_properties': jsonEncode(item.customProperties),
      'is_available': item.isAvailable ? 1 : 0,
      'sent_to_kitchen': item.sentToKitchen ? 1 : 0,
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
} 