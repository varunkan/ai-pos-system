import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/order_log.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/utils/exceptions.dart';

/// Custom exception for order operations
class OrderServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  OrderServiceException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'OrderServiceException: $message ${operation != null ? '(Operation: $operation)' : ''}';
}

/// Service for managing orders in the POS system
class OrderService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final OrderLogService _orderLogService;
  
  List<Order> _activeOrders = [];
  List<Order> _completedOrders = [];
  List<Order> _allOrders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  bool _disposed = false;
  Timer? _autoSaveTimer;
  final StreamController<List<Order>> _ordersStreamController = StreamController.broadcast();
  final StreamController<Order> _currentOrderStreamController = StreamController.broadcast();

  // Cache for frequently accessed data
  final Map<String, MenuItem> _menuItemCache = {};
  
  OrderService(this._databaseService, this._orderLogService) {
    debugPrint('🔧 OrderService initialized');
    _initializeCache();
  }

  /// Initialize cache and setup auto-save
  void _initializeCache() {
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _saveOrdersToCache();
    });
  }

  /// Reset disposal state - called when service is reused
  void resetDisposalState() {
    _disposed = false;
    debugPrint('🔄 OrderService disposal state reset');
  }

  // Getters
  List<Order> get activeOrders => List.unmodifiable(_activeOrders);
  List<Order> get completedOrders => List.unmodifiable(_completedOrders);
  List<Order> get allOrders => List.unmodifiable(_allOrders);
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  bool get isDisposed => _disposed;
  Stream<List<Order>> get ordersStream => _ordersStreamController.stream;
  Stream<Order> get currentOrderStream => _currentOrderStreamController.stream;

  /// Get active orders count
  int get activeOrdersCount => _activeOrders.length;

  /// Get total orders count
  int get totalOrdersCount => _allOrders.length;

  /// Get orders by status
  List<Order> getOrdersByStatus(String status) {
    return _allOrders.where((order) => order.status == status).toList();
  }

  /// Get orders by server
  List<Order> getAllOrdersByServer(String serverId) {
    return _allOrders.where((order) => order.userId == serverId).toList();
  }

  /// Get ACTIVE orders by server (for operational UI displays)
  List<Order> getActiveOrdersByServer(String serverId) {
    return _activeOrders.where((order) => order.userId == serverId).toList();
  }

  /// Get active orders count by server
  int getActiveOrdersCountByServer(String serverId) {
    return _activeOrders.where((order) => order.userId == serverId).length;
  }

  /// Validate order integrity before saving
  Future<bool> _validateOrderIntegrity(Order order) async {
    try {
      // Check if order has valid items
      if (order.items.isEmpty) {
        debugPrint('❌ Order has no items');
        return false;
      }

      // Validate menu item references
      for (var item in order.items) {
        if (item.menuItem.id.isEmpty) {
          debugPrint('❌ Order item has empty menu item ID');
          return false;
        }
        
        // Check if menu item exists
        final menuItem = await _getMenuItemById(item.menuItem.id);
        if (menuItem == null) {
          debugPrint('❌ Menu item ${item.menuItem.id} not found');
          return false;
        }
      }

      // Validate order total
      if (order.totalAmount <= 0) {
        debugPrint('❌ Order total amount is invalid: ${order.totalAmount}');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error validating order integrity: $e');
      return false;
    }
  }

  /// Get menu item by ID with caching
  Future<MenuItem?> _getMenuItemById(String menuItemId) async {
    try {
      // Check cache first
      if (_menuItemCache.containsKey(menuItemId)) {
        return _menuItemCache[menuItemId];
      }

      final Database? database = await _databaseService.database;
      if (database == null) return null;

      final List<Map<String, dynamic>> results = await database.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [menuItemId],
      );

      if (results.isEmpty) return null;

      final menuItem = MenuItem.fromJson(results.first);
      _menuItemCache[menuItemId] = menuItem; // Cache the result
      return menuItem;
    } catch (e) {
      debugPrint('❌ Error getting menu item: $e');
      return null;
    }
  }

  /// Safely encode objects to JSON strings for SQLite storage
  String? _safeJsonEncode(dynamic value) {
    if (value == null) return null;
    try {
      // Handle different types of objects
      if (value is Map) {
        if (value.isEmpty) return null;
        // Clean the map to ensure all values are serializable
        final cleanMap = <String, dynamic>{};
        value.forEach((key, val) {
          if (val != null && val is! Function) {
            cleanMap[key.toString()] = val;
          }
        });
        return cleanMap.isNotEmpty ? jsonEncode(cleanMap) : null;
      } else if (value is List) {
        if (value.isEmpty) return null;
        return jsonEncode(value);
      } else if (value is String) {
        return value.isNotEmpty ? value : null;
      } else {
        return jsonEncode(value);
      }
    } catch (e) {
      debugPrint('❌ Error encoding JSON for SQLite: $e');
      return null;
    }
  }

  /// Save order to database
  Future<bool> saveOrder(Order order, {String logAction = 'created'}) async {
    try {
      debugPrint('💾 Saving order to database: ${order.orderNumber}');
      
      // Validate order modification rights
      _validateOrderUpdate(order);
      
      // Validate order integrity before saving
      if (!await _validateOrderIntegrity(order)) {
        debugPrint('❌ Order integrity validation failed');
        return false;
      }
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'save_order');
      }
      
      // Simplified transaction to prevent deadlocks with proper error handling
      await database.transaction((txn) async {
        // CRITICAL: Build clean order map with ONLY primitive types - NO complex objects
        final cleanOrderMap = <String, dynamic>{
          'id': order.id,
          'order_number': order.orderNumber,
          'status': order.status.toString().split('.').last,
          'type': order.type.toString().split('.').last,
          'table_id': order.tableId ?? '',
          'user_id': order.userId ?? '',
          'customer_name': order.customerName ?? '',
          'customer_phone': order.customerPhone ?? '',
          'customer_email': order.customerEmail ?? '',
          'customer_address': order.customerAddress ?? '',
          'special_instructions': order.specialInstructions ?? '',
          'subtotal': order.subtotal ?? 0.0,
          'tax_amount': order.taxAmount ?? 0.0,
          'tip_amount': order.tipAmount ?? 0.0,
          'hst_amount': order.hstAmount ?? 0.0,
          'discount_amount': order.discountAmount ?? 0.0,
          'gratuity_amount': order.gratuityAmount ?? 0.0,
          'total_amount': order.totalAmount ?? 0.0,
          'payment_method': order.paymentMethod ?? '',
          'payment_status': order.paymentStatus.toString().split('.').last,
          'payment_transaction_id': order.paymentTransactionId ?? '',
          'order_time': order.orderTime.toIso8601String(),
          'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
          'actual_ready_time': order.actualReadyTime?.toIso8601String(),
          'served_time': order.servedTime?.toIso8601String(),
          'completed_time': order.completedTime?.toIso8601String(),
          'is_urgent': order.isUrgent ? 1 : 0,  // Convert boolean to integer
          'priority': order.priority ?? 0,
          'assigned_to': order.assignedTo ?? '',
          'created_at': order.createdAt.toIso8601String(),
          'updated_at': order.updatedAt.toIso8601String(),
        };
        
        // Handle custom_fields as JSON string (only if not empty)
        if (order.customFields.isNotEmpty) {
          final cleanCustomFields = <String, String>{};
          order.customFields.forEach((key, value) {
            if (value != null && value is String && value.isNotEmpty) {
              cleanCustomFields[key] = value;
            }
          });
          if (cleanCustomFields.isNotEmpty) {
            cleanOrderMap['custom_fields'] = jsonEncode(cleanCustomFields);
          }
        }
        
        debugPrint('🔧 Order SQLite Map keys: ${cleanOrderMap.keys.join(', ')}');
        
        // Insert or update order - NEVER include items array
        await txn.insert(
          'orders',
          cleanOrderMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Delete existing order items first
        await txn.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [order.id],
        );

        // Insert order items one by one with proper error handling
        for (var item in order.items) {
          try {
            // CRITICAL: Build clean item map with ONLY primitive types - NO complex objects
            final cleanItemMap = <String, dynamic>{
              'id': item.id,
              'order_id': order.id,
              'menu_item_id': item.menuItem.id, // Only store the ID, not the entire object
              'quantity': item.quantity ?? 1,
              'unit_price': item.unitPrice ?? 0.0,
              'total_price': item.totalPrice ?? 0.0,
              'selected_variant': item.selectedVariant ?? '',
              'special_instructions': item.specialInstructions ?? '',
              'notes': item.notes ?? '',
              'is_available': item.isAvailable ? 1 : 0,  // Convert boolean to integer
              'sent_to_kitchen': item.sentToKitchen ? 1 : 0,  // Convert boolean to integer
              'created_at': item.createdAt.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            };
            
            // Handle selected_modifiers as JSON string (only if not empty)
            if (item.selectedModifiers.isNotEmpty) {
              final List<String> cleanModifiers = [];
              for (var modifier in item.selectedModifiers) {
                if (modifier.isNotEmpty) {
                  cleanModifiers.add(modifier);
                }
              }
              if (cleanModifiers.isNotEmpty) {
                cleanItemMap['selected_modifiers'] = jsonEncode(cleanModifiers);
              }
            }
            
            // Handle custom_properties as JSON string (only if not empty)
            if (item.customProperties.isNotEmpty) {
              final Map<String, String> cleanProperties = {};
              item.customProperties.forEach((key, value) {
                if (value != null && value is String && value.isNotEmpty) {
                  cleanProperties[key] = value;
                }
              });
              if (cleanProperties.isNotEmpty) {
                cleanItemMap['custom_properties'] = jsonEncode(cleanProperties);
              }
            }
            
            debugPrint('🔧 Order Item SQLite Map keys: ${cleanItemMap.keys.join(', ')}');
            
            await txn.insert(
              'order_items',
              cleanItemMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            debugPrint('❌ Error inserting order item ${item.id}: $e');
            // Continue with other items
          }
        }
      });

      // Log the order action
      final OrderLogAction action = logAction == 'created' 
          ? OrderLogAction.created 
          : logAction == 'updated' 
              ? OrderLogAction.updated 
              : logAction == 'completed'
                  ? OrderLogAction.completed
                  : logAction == 'modified'
                      ? OrderLogAction.updated  // Use updated instead of modified
                      : OrderLogAction.created;
      
      await _orderLogService.logOperation(
        orderId: order.id,
        orderNumber: order.orderNumber,
        action: action,
        description: 'Order ${order.orderNumber} saved successfully',
      );

      // Update local state
      _updateLocalOrderState(order);
      
      debugPrint('✅ Order saved successfully: ${order.orderNumber}');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving order: $e');
      // Don't rethrow - return false to indicate failure
      return false;
    }
  }

  /// Convert Order object to SQLite-compatible map using only existing columns
  Map<String, dynamic> _orderToSQLiteMap(Order order) {
    try {
      // Create a clean map with only SQLite-compatible values - NO COMPLEX OBJECTS
      // CRITICAL: NEVER include order.items array - it's handled separately
      final Map<String, dynamic> sqliteMap = {
        'id': order.id,
        'order_number': order.orderNumber,
        'status': order.status.toString().split('.').last,
        'type': order.type.toString().split('.').last,
        'table_id': order.tableId ?? '',
        'user_id': order.userId ?? '',
        'customer_name': order.customerName ?? '',
        'customer_phone': order.customerPhone ?? '',
        'customer_email': order.customerEmail ?? '',
        'customer_address': order.customerAddress ?? '',
        'special_instructions': order.specialInstructions ?? '',
        'subtotal': order.subtotal ?? 0.0,
        'tax_amount': order.taxAmount ?? 0.0,
        'tip_amount': order.tipAmount ?? 0.0,
        'hst_amount': order.hstAmount ?? 0.0,
        'discount_amount': order.discountAmount ?? 0.0,
        'gratuity_amount': order.gratuityAmount ?? 0.0,
        'total_amount': order.totalAmount ?? 0.0,
        'payment_method': order.paymentMethod ?? '',
        'payment_status': order.paymentStatus.toString().split('.').last,
        'payment_transaction_id': order.paymentTransactionId ?? '',
        'order_time': order.orderTime.toIso8601String(),
        'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
        'actual_ready_time': order.actualReadyTime?.toIso8601String(),
        'served_time': order.servedTime?.toIso8601String(),
        'completed_time': order.completedTime?.toIso8601String(),
        'is_urgent': order.isUrgent ? 1 : 0,  // Convert boolean to integer
        'priority': order.priority ?? 0,
        'assigned_to': order.assignedTo ?? '',
        'created_at': order.createdAt.toIso8601String(),
        'updated_at': order.updatedAt.toIso8601String(),
      };

      // Handle custom_fields - only include simple string values, convert to JSON string
      if (order.customFields.isNotEmpty) {
        final cleanCustomFields = <String, String>{};
        order.customFields.forEach((key, value) {
          if (value != null && value is String && value.isNotEmpty) {
            cleanCustomFields[key] = value;
          }
        });
        if (cleanCustomFields.isNotEmpty) {
          sqliteMap['custom_fields'] = jsonEncode(cleanCustomFields);
        }
      }

      // Handle metadata - only include simple string values, convert to JSON string
      if (order.metadata.isNotEmpty) {
        final cleanMetadata = <String, String>{};
        order.metadata.forEach((key, value) {
          if (value != null && value is String && value.isNotEmpty) {
            cleanMetadata[key] = value;
          }
        });
        if (cleanMetadata.isNotEmpty) {
          sqliteMap['metadata'] = jsonEncode(cleanMetadata);
        }
      }

      // CRITICAL: Only return primitive types that SQLite supports
      final cleanMap = <String, dynamic>{};
      sqliteMap.forEach((key, value) {
        if (value != null && 
            (value is String || value is num || value is int || value is double)) {
          cleanMap[key] = value;
        }
      });

      return cleanMap;
    } catch (e) {
      debugPrint('❌ Error converting Order to SQLite map: $e');
      // Return minimal valid data to prevent crashes
      return {
        'id': order.id,
        'order_number': order.orderNumber,
        'status': 'pending',
        'type': 'dineIn',
        'subtotal': 0.0,
        'tax_amount': 0.0,
        'tip_amount': 0.0,
        'hst_amount': 0.0,
        'discount_amount': 0.0,
        'gratuity_amount': 0.0,
        'total_amount': 0.0,
        'payment_status': 'pending',
        'order_time': DateTime.now().toIso8601String(),
        'is_urgent': 0,
        'priority': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Convert OrderItem object to SQLite-compatible map
  Map<String, dynamic> _orderItemToSQLiteMap(OrderItem item) {
    try {
      // Create a clean map with only SQLite-compatible values - NO COMPLEX OBJECTS
      // CRITICAL: NEVER include entire menuItem object - only the ID
      final Map<String, dynamic> sqliteMap = {
        'id': item.id,
        'order_id': '', // Will be set when saving to specific order
        'menu_item_id': item.menuItem.id, // Only store the ID, not the entire object
        'quantity': item.quantity ?? 1,
        'unit_price': item.unitPrice ?? 0.0,
        'total_price': item.totalPrice ?? 0.0,
        'selected_variant': item.selectedVariant ?? '',
        'special_instructions': item.specialInstructions ?? '',
        'notes': item.notes ?? '',
        'is_available': item.isAvailable ? 1 : 0,  // Convert boolean to integer
        'sent_to_kitchen': item.sentToKitchen ? 1 : 0,  // Convert boolean to integer
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Handle selected_modifiers - convert to JSON string
      if (item.selectedModifiers.isNotEmpty) {
        final List<String> cleanModifiers = [];
        for (var modifier in item.selectedModifiers) {
          if (modifier.isNotEmpty) {
            cleanModifiers.add(modifier);
          }
        }
        if (cleanModifiers.isNotEmpty) {
          sqliteMap['selected_modifiers'] = jsonEncode(cleanModifiers);
        }
      }

      // Handle custom_properties - convert to JSON string
      if (item.customProperties.isNotEmpty) {
        final Map<String, String> cleanProperties = {};
        item.customProperties.forEach((key, value) {
          if (value != null && value is String && value.isNotEmpty) {
            cleanProperties[key] = value;
          }
        });
        if (cleanProperties.isNotEmpty) {
          sqliteMap['custom_properties'] = jsonEncode(cleanProperties);
        }
      }

      // CRITICAL: Only return primitive types that SQLite supports
      final cleanMap = <String, dynamic>{};
      sqliteMap.forEach((key, value) {
        if (value != null && 
            (value is String || value is num || value is int || value is double)) {
          cleanMap[key] = value;
        }
      });

      return cleanMap;
    } catch (e) {
      debugPrint('❌ Error converting OrderItem to SQLite map: $e');
      // Return minimal valid data to prevent crashes
      return {
        'id': item.id,
        'order_id': '',
        'menu_item_id': item.menuItem.id,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'selected_variant': '',
        'special_instructions': '',
        'notes': '',
        'is_available': 1,
        'sent_to_kitchen': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Convert SQLite map back to Order-compatible format
  Map<String, dynamic> _sqliteMapToOrder(Map<String, dynamic> sqliteMap) {
    try {
      return {
        'id': sqliteMap['id'],
        'orderNumber': sqliteMap['order_number'],  // Read from snake_case
        'status': sqliteMap['status'],
        'type': sqliteMap['type'],
        'tableId': sqliteMap['table_id'],  // Read from snake_case
        'userId': sqliteMap['user_id'],  // Read from snake_case
        'customerName': sqliteMap['customer_name'],  // Read from snake_case
        'customerPhone': sqliteMap['customer_phone'],  // Read from snake_case
        'customerEmail': sqliteMap['customer_email'],  // Read from snake_case
        'customerAddress': sqliteMap['customer_address'],  // Read from snake_case
        'specialInstructions': sqliteMap['special_instructions'],  // Read from snake_case
        'subtotal': sqliteMap['subtotal'],
        'taxAmount': sqliteMap['tax_amount'],  // Read from snake_case
        'tipAmount': sqliteMap['tip_amount'],  // Read from snake_case
        'hstAmount': sqliteMap['hst_amount'],  // Read from snake_case
        'discountAmount': sqliteMap['discount_amount'],  // Read from snake_case
        'gratuityAmount': sqliteMap['gratuity_amount'],  // Read from snake_case
        'totalAmount': sqliteMap['total_amount'],  // Read from snake_case
        'paymentMethod': sqliteMap['payment_method'],  // Read from snake_case
        'paymentStatus': sqliteMap['payment_status'],  // Read from snake_case
        'paymentTransactionId': sqliteMap['payment_transaction_id'],  // Read from snake_case
        'orderTime': sqliteMap['order_time'],  // Read from snake_case
        'estimatedReadyTime': sqliteMap['estimated_ready_time'],  // Read from snake_case
        'actualReadyTime': sqliteMap['actual_ready_time'],  // Read from snake_case
        'servedTime': sqliteMap['served_time'],  // Read from snake_case
        'completedTime': sqliteMap['completed_time'],  // Read from snake_case
        'isUrgent': sqliteMap['is_urgent'] == 1, // Convert integer back to boolean, read from snake_case
        'priority': sqliteMap['priority'],
        'assignedTo': sqliteMap['assigned_to'],
        // Removed 'preferences' - column doesn't exist in database schema
        'preferences': {}, // Default empty map since column doesn't exist
        'createdAt': sqliteMap['created_at'],
        'updatedAt': sqliteMap['updated_at'],
        'items': [], // Will be set separately
      };
    } catch (e) {
      debugPrint('❌ Error converting SQLite map to Order format: $e');
      // Return minimal valid order data
      return {
        'id': sqliteMap['id'] ?? '',
        'orderNumber': sqliteMap['order_number'] ?? '',
        'status': sqliteMap['status'] ?? 'pending',
        'type': sqliteMap['type'] ?? 'dineIn',
        'items': [],
        'isUrgent': false,
        'priority': 0,
        'preferences': {}, // Default empty map since column doesn't exist
        'orderTime': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Convert SQLite map back to OrderItem-compatible format
  Map<String, dynamic> _sqliteMapToOrderItem(Map<String, dynamic> sqliteMap) {
    try {
      return {
        'id': sqliteMap['id'],
        'quantity': sqliteMap['quantity'],
        'unitPrice': sqliteMap['unit_price'] ?? sqliteMap['price'],
        'specialInstructions': sqliteMap['special_instructions'],
        'notes': sqliteMap['notes'],
        'selectedVariant': sqliteMap['selected_variant'],
        'selectedModifiers': sqliteMap['selected_modifiers'] != null ? jsonDecode(sqliteMap['selected_modifiers']) : [],
        'customProperties': sqliteMap['custom_properties'] != null ? jsonDecode(sqliteMap['custom_properties']) : {},
        'isAvailable': sqliteMap['is_available'] == 1,
        'sentToKitchen': sqliteMap['sent_to_kitchen'] == 1,
        'createdAt': sqliteMap['created_at'],
        'voided': sqliteMap['voided'] == 1,
        'voidedBy': sqliteMap['voided_by'],
        'voidedAt': sqliteMap['voided_at'],
        'comped': sqliteMap['comped'] == 1,
        'compedBy': sqliteMap['comped_by'],
        'compedAt': sqliteMap['comped_at'],
        'discountPercentage': sqliteMap['discount_percentage'],
        'discountAmount': sqliteMap['discount_amount'],
        'discountedBy': sqliteMap['discounted_by'],
        'discountedAt': sqliteMap['discounted_at'],
      };
    } catch (e) {
      debugPrint('❌ Error converting SQLite map to OrderItem format: $e');
      // Return minimal valid order item data
      return {
        'id': sqliteMap['id'] ?? '',
        'quantity': sqliteMap['quantity'] ?? 1,
        'unitPrice': sqliteMap['unit_price'] ?? sqliteMap['price'] ?? 0.0,
        'specialInstructions': sqliteMap['special_instructions'],
        'notes': sqliteMap['notes'],
        'selectedVariant': sqliteMap['selected_variant'],
        'selectedModifiers': [],
        'customProperties': {},
        'isAvailable': true,
        'sentToKitchen': false,
        'createdAt': DateTime.now().toIso8601String(),
        'voided': false,
        'comped': false,
      };
    }
  }

  /// Update local order state
  void _updateLocalOrderState(Order order) {
    // Remove from existing lists
    _activeOrders.removeWhere((o) => o.id == order.id);
    _completedOrders.removeWhere((o) => o.id == order.id);
    _allOrders.removeWhere((o) => o.id == order.id);

    // Add to appropriate list
    if (order.isActive) {
      _activeOrders.add(order);
    } else {
      _completedOrders.add(order);
    }
    
    _allOrders.add(order);
    
    // Update current order if it matches
    if (_currentOrder?.id == order.id) {
      _currentOrder = order;
      _currentOrderStreamController.add(order);
    }
    
    // Notify listeners
    notifyListeners();
    _ordersStreamController.add(_allOrders);
  }

  /// Load all orders from database
  Future<void> loadOrders() async {
    if (_disposed) return;
    
    try {
      _setLoading(true);
      debugPrint('📥 Loading orders from database');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'load_orders');
      }

      // Load orders with items
      final List<Map<String, dynamic>> orderResults = await database.query(
        'orders',
        orderBy: 'created_at DESC',  // Use snake_case column name
      );

      final List<Order> orders = [];
      for (var orderMap in orderResults) {
        try {
          // Load order items
          final List<Map<String, dynamic>> itemResults = await database.query(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderMap['id']],
          );

          // Convert order items to proper format
          final List<OrderItem> items = [];
          for (var itemMap in itemResults) {
            try {
              // Get the menu item for this order item
              final menuItem = await _getMenuItemById(itemMap['menu_item_id']);
              if (menuItem != null) {
                // Convert SQLite map to OrderItem-compatible format
                final orderItemJson = _sqliteMapToOrderItem(itemMap);
                orderItemJson['menuItem'] = menuItem.toJson();
                
                final orderItem = OrderItem.fromJson(orderItemJson);
                items.add(orderItem);
              }
            } catch (e) {
              debugPrint('❌ Error loading order item ${itemMap['id']}: $e');
            }
          }

          // Convert database map to Order-compatible format
          final orderJson = _sqliteMapToOrder(orderMap);
          orderJson['items'] = items.map((item) => item.toJson()).toList();
          
          // Create order with items
          final order = Order.fromJson(orderJson);
          
          orders.add(order);
        } catch (e) {
          debugPrint('❌ Error loading order ${orderMap['id']}: $e');
        }
      }

      // Update local state
      _allOrders = orders;
      _activeOrders = orders.where((o) => o.isActive).toList();
      _completedOrders = orders.where((o) => !o.isActive).toList();
      
      debugPrint('✅ Loaded ${orders.length} orders (${_activeOrders.length} active, ${_completedOrders.length} completed)');
      
      notifyListeners();
      _ordersStreamController.add(_allOrders);
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
      throw OrderServiceException('Failed to load orders: $e', operation: 'load_orders', originalError: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Create new order
  Future<Order> createOrder({
    required String orderType,
    String? tableId,
    String? customerName,
    String? customerPhone,
    String? userId,
  }) async {
    try {
      debugPrint('🆕 Creating new order');
      
      final OrderType type = orderType == 'dineIn' 
          ? OrderType.dineIn 
          : orderType == 'takeaway' 
              ? OrderType.takeaway 
              : orderType == 'delivery'
                  ? OrderType.delivery
                  : OrderType.dineIn;
      
      final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderNumber: await _generateOrderNumber(),
        type: type,
        tableId: tableId,
        customerName: customerName,
        customerPhone: customerPhone,
        userId: userId,
        status: OrderStatus.pending,
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _currentOrder = order;
      _currentOrderStreamController.add(order);
      
      debugPrint('✅ New order created: ${order.orderNumber}');
      return order;
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      throw OrderServiceException('Failed to create order: $e', operation: 'create_order', originalError: e);
    }
  }

  /// Generate unique order number
  Future<String> _generateOrderNumber() async {
    try {
      final Database? database = await _databaseService.database;
      if (database == null) {
        return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      }

      final result = await database.rawQuery('SELECT COUNT(*) as count FROM orders');
      final count = result.first['count'] as int;
      final orderNumber = 'ORD-${(count + 1).toString().padLeft(4, '0')}';
      
      return orderNumber;
    } catch (e) {
      debugPrint('❌ Error generating order number: $e');
      return 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      debugPrint('📝 Updating order status: $orderId -> $newStatus');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'update_status');
      }

      await database.update(
        'orders',
        {
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // Update local state
      final orderIndex = _allOrders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        final OrderStatus status = _parseOrderStatus(newStatus);
        final updatedOrder = _allOrders[orderIndex].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        _allOrders[orderIndex] = updatedOrder;
        _updateLocalOrderState(updatedOrder);
      }

      // Log the status change - Fix: Handle case where order might not be in local cache
      String orderNumber = 'UNKNOWN';
      try {
        final order = _allOrders.firstWhere((o) => o.id == orderId);
        orderNumber = order.orderNumber;
      } catch (e) {
        // If order not found in local cache, try to get it from database
        final orderResult = await database.query(
          'orders',
          columns: ['order_number'],
          where: 'id = ?',
          whereArgs: [orderId],
        );
        if (orderResult.isNotEmpty) {
          orderNumber = orderResult.first['order_number'] as String;
        }
      }

      await _orderLogService.logOperation(
        orderId: orderId,
        orderNumber: orderNumber,
        action: OrderLogAction.statusChanged,
        description: 'Status changed to $newStatus',
      );

      debugPrint('✅ Order status updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      throw OrderServiceException('Failed to update order status: $e', operation: 'update_status', originalError: e);
    }
  }

  /// Delete order
  Future<bool> deleteOrder(String orderId) async {
    try {
      debugPrint('🗑️ Deleting order: $orderId');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'delete_order');
      }

      await database.transaction((txn) async {
        // Delete order items first
        await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
        
        // Delete order
        await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
      });

      // Update local state
      _allOrders.removeWhere((o) => o.id == orderId);
      _activeOrders.removeWhere((o) => o.id == orderId);
      _completedOrders.removeWhere((o) => o.id == orderId);
      
      if (_currentOrder?.id == orderId) {
        _currentOrder = null;
      }

      // Log the deletion
      await _orderLogService.logOperation(
        orderId: orderId,
        orderNumber: 'DELETED',
        action: OrderLogAction.cancelled,
        description: 'Order deleted',
      );

      notifyListeners();
      _ordersStreamController.add(_allOrders);
      
      debugPrint('✅ Order deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting order: $e');
      throw OrderServiceException('Failed to delete order: $e', operation: 'delete_order', originalError: e);
    }
  }

  /// Get order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      // Check local cache first
      final localOrder = _allOrders.where((o) => o.id == orderId).firstOrNull;
      if (localOrder != null) {
        return localOrder;
      }

      // Load from database
      final Database? database = await _databaseService.database;
      if (database == null) return null;

      final List<Map<String, dynamic>> results = await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (results.isEmpty) return null;

      // Load order items
      final List<Map<String, dynamic>> itemResults = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final List<OrderItem> items = itemResults.map((itemMap) {
        return OrderItem.fromJson(itemMap);
      }).toList();

      final order = Order.fromJson(results.first);
      order.items.clear();
      order.items.addAll(items);
      
      return order;
    } catch (e) {
      debugPrint('❌ Error getting order by ID: $e');
      return null;
    }
  }

  /// Set current order
  void setCurrentOrder(Order? order) {
    _currentOrder = order;
    if (order != null) {
      _currentOrderStreamController.add(order);
    }
    notifyListeners();
  }

  /// Clear current order
  void clearCurrentOrder() {
    _currentOrder = null;
    notifyListeners();
  }

  /// Parse string status to OrderStatus enum
  OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'served':
        return OrderStatus.served;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      default:
        return OrderStatus.pending;
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Save orders to cache
  void _saveOrdersToCache() {
    // Implementation for caching orders
    debugPrint('💾 Saving orders to cache');
  }

  /// Clear all orders (for testing/reset)
  Future<void> clearAllOrders() async {
    try {
      debugPrint('🧹 Clearing all orders');
      
      final Database? database = await _databaseService.database;
      if (database == null) return;

      await database.transaction((txn) async {
        await txn.delete('order_items');
        await txn.delete('orders');
      });

      _allOrders.clear();
      _activeOrders.clear();
      _completedOrders.clear();
      _currentOrder = null;
      
      notifyListeners();
      _ordersStreamController.add(_allOrders);
      
      debugPrint('✅ All orders cleared');
    } catch (e) {
      debugPrint('❌ Error clearing orders: $e');
    }
  }

  /// Delete all orders from database (for testing/reset purposes)
  /// This preserves users, menu items, and categories - only clears orders
  Future<void> deleteAllOrders() async {
    try {
      debugPrint('🗑️ Starting to delete all orders...');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'delete_all_orders');
      }
      
      await database.transaction((txn) async {
        // Delete all order items first (foreign key constraint)
        final orderItemsDeleted = await txn.delete('order_items');
        debugPrint('✅ Deleted $orderItemsDeleted order items');
        
        // Delete all orders
        final ordersDeleted = await txn.delete('orders');
        debugPrint('✅ Deleted $ordersDeleted orders');
        
        // Delete all order logs
        final orderLogsDeleted = await txn.delete('order_logs');
        debugPrint('✅ Deleted $orderLogsDeleted order logs');
      });
      
      // Clear local state
      _activeOrders.clear();
      _completedOrders.clear();
      _allOrders.clear();
      _currentOrder = null;
      
      // Clear any cached data
      final Map<String, MenuItem> _menuItemCache = {};
      _menuItemCache.clear();
      
      debugPrint('✅ All orders deleted successfully - users and menu items preserved');
      notifyListeners();
      
      // Notify streams
      _ordersStreamController.add([]);
      if (_currentOrder == null) {
        _currentOrderStreamController.add(Order(
          items: [],
          orderNumber: 'TEMP-${DateTime.now().millisecondsSinceEpoch}',
          orderTime: DateTime.now(),
        ));
      }
      
    } catch (e) {
      debugPrint('❌ Error deleting all orders: $e');
      throw OrderServiceException('Failed to delete all orders: $e', operation: 'delete_all_orders', originalError: e);
    }
  }

  /// Get orders for today
  List<Order> getTodaysOrders() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return _allOrders.where((order) {
      return order.createdAt.isAfter(todayStart) && order.createdAt.isBefore(todayEnd);
    }).toList();
  }

  /// Get revenue for today
  double getTodaysRevenue() {
    final todaysOrders = getTodaysOrders();
    return todaysOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  /// Validates if an order can be modified
  void _validateOrderModification(Order order) {
    if (order.isProtected) {
      throw Exception('${order.protectionReason}. Operation not allowed.');
    }
  }

  /// Validates if items can be added to an order
  void _validateAddItems(Order order) {
    _validateOrderModification(order);
  }

  /// Validates if an order can be sent to kitchen
  void _validateSendToKitchen(Order order) {
    _validateOrderModification(order);
    
    // Additional validation for send to kitchen
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    if (newItems.isEmpty) {
      throw Exception('No new items to send to kitchen.');
    }
  }

  /// Validates if an order can be updated
  void _validateOrderUpdate(Order order) {
    // Allow updates during checkout process even if order is completed
    if (order.status == OrderStatus.completed && order.paymentStatus == PaymentStatus.paid) {
      // This is likely a payment completion update, allow it
      return;
    }
    _validateOrderModification(order);
  }

  /// Fix orders with empty userIds by assigning them to the provided userId
  /// Only fixes orders that are truly orphaned (older than 2 minutes)
  Future<void> fixOrdersWithEmptyUserIds(String defaultUserId) async {
    try {
      final now = DateTime.now();
      final cutoffTime = now.subtract(const Duration(minutes: 2));
      
      final orphanedOrders = _allOrders.where((order) => 
        (order.userId == null || order.userId!.isEmpty || order.userId!.trim().isEmpty) &&
        order.orderTime.isBefore(cutoffTime) // Only fix old orders, not newly created ones
      ).toList();
      
      if (orphanedOrders.isEmpty) {
        debugPrint('✅ No truly orphaned orders found that need fixing');
        return;
      }
      
      debugPrint('🔧 Fixing ${orphanedOrders.length} truly orphaned orders (older than 2 minutes)');
      
      final Database? database = await _databaseService.database;
      if (database == null) return;
      
      await database.transaction((txn) async {
        for (final order in orphanedOrders) {
          await txn.update(
            'orders',
            {'user_id': defaultUserId},
            where: 'id = ?',
            whereArgs: [order.id],
          );
          
          // Update the in-memory order object
          final updatedOrder = Order(
            id: order.id,
            orderNumber: order.orderNumber,
            status: order.status,
            type: order.type,
            tableId: order.tableId,
            userId: defaultUserId, // Fix the empty userId
            customerName: order.customerName,
            customerPhone: order.customerPhone,
            customerEmail: order.customerEmail,
            customerAddress: order.customerAddress,
            specialInstructions: order.specialInstructions,
            items: order.items,
            subtotal: order.subtotal,
            taxAmount: order.taxAmount,
            tipAmount: order.tipAmount,
            hstAmount: order.hstAmount,
            discountAmount: order.discountAmount,
            gratuityAmount: order.gratuityAmount,
            totalAmount: order.totalAmount,
            paymentMethod: order.paymentMethod,
            paymentStatus: order.paymentStatus,
            paymentTransactionId: order.paymentTransactionId,
            orderTime: order.orderTime,
            estimatedReadyTime: order.estimatedReadyTime,
            actualReadyTime: order.actualReadyTime,
            servedTime: order.servedTime,
            completedTime: order.completedTime,
            isUrgent: order.isUrgent,
            priority: order.priority,
            assignedTo: order.assignedTo,
            createdAt: order.createdAt,
            updatedAt: DateTime.now(),
          );
          
          // Replace in all lists
          final activeIndex = _activeOrders.indexWhere((o) => o.id == order.id);
          if (activeIndex != -1) {
            _activeOrders[activeIndex] = updatedOrder;
          }
          
          final allIndex = _allOrders.indexWhere((o) => o.id == order.id);
          if (allIndex != -1) {
            _allOrders[allIndex] = updatedOrder;
          }
          
          debugPrint('✅ Fixed orphaned order ${order.orderNumber}: assigned to userId $defaultUserId');
        }
      });
      
      notifyListeners();
      debugPrint('✅ Fixed ${orphanedOrders.length} truly orphaned orders with empty userIds');
      
    } catch (e) {
      debugPrint('❌ Error fixing orders with empty userIds: $e');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    
    debugPrint('🧹 Disposing OrderService');
    _disposed = true;
    _autoSaveTimer?.cancel();
    _ordersStreamController.close();
    _currentOrderStreamController.close();
    _menuItemCache.clear();
    super.dispose();
  }
} 