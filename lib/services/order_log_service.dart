import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/order_log.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/user_service.dart';

/// Service for comprehensive order operation logging and audit trail
class OrderLogService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final List<OrderLog> _logs = [];
  final Map<String, List<OrderLog>> _orderLogsCache = {};
  bool _isInitialized = false;
  String? _currentSessionId;
  String? _currentDeviceId;
  String? _currentUserId;
  String? _currentUserName;

  OrderLogService(this._databaseService) {
    initialize();
  }

  /// Gets all logs
  List<OrderLog> get allLogs => List.unmodifiable(_logs);

  /// Gets logs for a specific order
  List<OrderLog> getLogsForOrder(String orderId) {
    return _orderLogsCache[orderId] ?? [];
  }

  /// Reload logs for a specific order from database
  Future<void> reloadLogsForOrder(String orderId) async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage
        final webLogs = await _databaseService.getWebOrderLogs();
        final orderLogs = <OrderLog>[];
        
        for (final row in webLogs) {
          final log = OrderLog.fromJson(row);
          if (log.orderId == orderId) {
            orderLogs.add(log);
          }
        }
        
        _orderLogsCache[orderId] = orderLogs;
        debugPrint('✅ Reloaded ${orderLogs.length} logs for order $orderId from web storage');
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        final results = await db.query(
          'order_logs',
          where: 'order_id = ?',
          whereArgs: [orderId],
          orderBy: 'timestamp DESC',
        );

        final orderLogs = <OrderLog>[];
        for (final row in results) {
          final log = OrderLog.fromJson(row);
          orderLogs.add(log);
        }
        
        _orderLogsCache[orderId] = orderLogs;
        debugPrint('✅ Reloaded ${orderLogs.length} logs for order $orderId from database');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to reload logs for order $orderId: $e');
    }
  }

  /// Gets recent logs (last 100)
  List<OrderLog> get recentLogs {
    final sorted = List<OrderLog>.from(_logs);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(100).toList();
  }

  /// Gets logs by action type
  List<OrderLog> getLogsByAction(OrderLogAction action) {
    return _logs.where((log) => log.action == action).toList();
  }

  /// Gets logs by user
  List<OrderLog> getLogsByUser(String userId) {
    return _logs.where((log) => log.performedBy == userId).toList();
  }

  /// Gets logs within date range
  List<OrderLog> getLogsByDateRange(DateTime start, DateTime end) {
    return _logs.where((log) => 
      log.timestamp.isAfter(start) && log.timestamp.isBefore(end)
    ).toList();
  }

  /// Gets financial operation logs
  List<OrderLog> get financialLogs {
    return _logs.where((log) => log.isFinancialOperation).toList();
  }

  /// Gets kitchen operation logs
  List<OrderLog> get kitchenLogs {
    return _logs.where((log) => log.isKitchenOperation).toList();
  }

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _createOrderLogsTable();
      await _generateSessionId();
      await _detectDeviceId();
      await _loadRecentLogs();
      _isInitialized = true;
      debugPrint('✅ OrderLogService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize OrderLogService: $e');
    }
  }

  /// Create the order logs table
  Future<void> _createOrderLogsTable() async {
    if (_databaseService.isWeb) {
      // Web platform - table creation is handled by web storage initialization
      debugPrint('✅ Order logs table created with indexes (web)');
      return;
    }
    
    final db = await _databaseService.database;
    if (db == null) return;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_logs (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        order_number TEXT NOT NULL,
        action TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'info',
        performed_by TEXT NOT NULL,
        performed_by_name TEXT,
        timestamp TEXT NOT NULL,
        description TEXT NOT NULL,
        before_data TEXT,
        after_data TEXT,
        metadata TEXT,
        notes TEXT,
        device_id TEXT,
        session_id TEXT,
        ip_address TEXT,
        is_system_action INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        amount_before REAL,
        amount_after REAL,
        table_id TEXT,
        customer_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_order_id ON order_logs(order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_timestamp ON order_logs(timestamp DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_action ON order_logs(action)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_performed_by ON order_logs(performed_by)');

    debugPrint('✅ Order logs table created with indexes');
  }

  /// Generate a unique session ID
  Future<void> _generateSessionId() async {
    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Detect device ID
  Future<void> _detectDeviceId() async {
    try {
      if (kIsWeb) {
        _currentDeviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid || Platform.isIOS) {
        _currentDeviceId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _currentDeviceId = 'desktop_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _currentDeviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Load recent logs from database
  Future<void> _loadRecentLogs() async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage
        final webLogs = await _databaseService.getWebOrderLogs();
        _logs.clear();
        _orderLogsCache.clear();

        for (final row in webLogs) {
          final log = OrderLog.fromJson(row);
          _logs.add(log);
          
          // Cache logs by order ID
          if (!_orderLogsCache.containsKey(log.orderId)) {
            _orderLogsCache[log.orderId] = [];
          }
          _orderLogsCache[log.orderId]!.add(log);
        }

        debugPrint('✅ Loaded ${_logs.length} order logs from web storage');
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        final results = await db.query(
          'order_logs',
          orderBy: 'timestamp DESC',
          limit: 1000, // Load last 1000 logs
        );

        _logs.clear();
        _orderLogsCache.clear();

        for (final row in results) {
          final log = OrderLog.fromJson(row);
          _logs.add(log);
          
          // Cache logs by order ID
          if (!_orderLogsCache.containsKey(log.orderId)) {
            _orderLogsCache[log.orderId] = [];
          }
          _orderLogsCache[log.orderId]!.add(log);
        }

        debugPrint('✅ Loaded ${_logs.length} order logs from database');
      }
    } catch (e) {
      debugPrint('❌ Failed to load order logs: $e');
    }
  }

  /// Set current user context
  void setCurrentUser(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
  }

  /// Log an order operation
  Future<OrderLog> logOperation({
    required String orderId,
    required String orderNumber,
    required OrderLogAction action,
    String? performedBy,
    String? performedByName,
    LogLevel level = LogLevel.info,
    String? description,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    Map<String, dynamic>? metadata,
    String? notes,
    bool isSystemAction = false,
    String? errorMessage,
    double? amountBefore,
    double? amountAfter,
    String? tableId,
    String? customerId,
  }) async {
    final log = OrderLog(
      orderId: orderId,
      orderNumber: orderNumber,
      action: action,
      level: level,
      performedBy: performedBy ?? _currentUserId ?? 'system',
      performedByName: performedByName ?? _currentUserName ?? 'System',
      description: description ?? action.toString().split('.').last,
      beforeData: beforeData ?? {},
      afterData: afterData ?? {},
      metadata: {
        ...metadata ?? {},
        'session_id': _currentSessionId,
        'device_id': _currentDeviceId,
      },
      notes: notes,
      deviceId: _currentDeviceId,
      sessionId: _currentSessionId,
      isSystemAction: isSystemAction,
      errorMessage: errorMessage,
      amountBefore: amountBefore,
      amountAfter: amountAfter,
      tableId: tableId,
      customerId: customerId,
    );

    try {
      await _saveLogToDatabase(log);
      _addLogToCache(log);
      notifyListeners();
      
      // Trigger haptic feedback for important actions
      if ([
        OrderLogAction.cancelled,
        OrderLogAction.refunded,
        OrderLogAction.paymentProcessed,
        OrderLogAction.completed,
      ].contains(action)) {
        _triggerHapticFeedback();
      }

      debugPrint('✅ Logged operation: ${log.actionDescription} for order $orderNumber by ${log.performedByName}');
      return log;
    } catch (e) {
      debugPrint('❌ Failed to log operation: $e');
      rethrow;
    }
  }

  /// Save log to database
  Future<void> _saveLogToDatabase(OrderLog log) async {
    if (_databaseService.isWeb) {
      // Web platform - use Hive storage
      await _databaseService.saveWebOrderLog({
        'id': log.id,
        'order_id': log.orderId,
        'order_number': log.orderNumber,
        'action': log.action.toString().split('.').last,
        'level': log.level.toString().split('.').last,
        'performed_by': log.performedBy,
        'performed_by_name': log.performedByName,
        'timestamp': log.timestamp.toIso8601String(),
        'description': log.description,
        'before_data': jsonEncode(log.beforeData),
        'after_data': jsonEncode(log.afterData),
        'metadata': jsonEncode(log.metadata),
        'notes': log.notes,
        'device_id': log.deviceId,
        'session_id': log.sessionId,
        'ip_address': log.ipAddress,
        'is_system_action': log.isSystemAction,
        'error_message': log.errorMessage,
        'amount_before': log.amountBefore,
        'amount_after': log.amountAfter,
        'table_id': log.tableId,
        'customer_id': log.customerId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      // Mobile/Desktop platform - use SQLite
      final db = await _databaseService.database;
      if (db == null) return;
      
      await db.insert('order_logs', {
        'id': log.id,
        'order_id': log.orderId,
        'order_number': log.orderNumber,
        'action': log.action.toString().split('.').last,
        'level': log.level.toString().split('.').last,
        'performed_by': log.performedBy,
        'performed_by_name': log.performedByName,
        'timestamp': log.timestamp.toIso8601String(),
        'description': log.description,
        'before_data': jsonEncode(log.beforeData),
        'after_data': jsonEncode(log.afterData),
        'metadata': jsonEncode(log.metadata),
        'notes': log.notes,
        'device_id': log.deviceId,
        'session_id': log.sessionId,
        'ip_address': log.ipAddress,
        'is_system_action': log.isSystemAction ? 1 : 0,
        'error_message': log.errorMessage,
        'amount_before': log.amountBefore,
        'amount_after': log.amountAfter,
        'table_id': log.tableId,
        'customer_id': log.customerId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Add log to cache
  void _addLogToCache(OrderLog log) {
    _logs.insert(0, log); // Add to beginning for newest first
    
    // Maintain cache size
    if (_logs.length > 1000) {
      _logs.removeLast();
    }

    // Add to order-specific cache
    if (!_orderLogsCache.containsKey(log.orderId)) {
      _orderLogsCache[log.orderId] = [];
    }
    _orderLogsCache[log.orderId]!.add(log);
  }

  /// Trigger haptic feedback
  void _triggerHapticFeedback() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore haptic feedback errors
    }
  }

  // Convenience methods for common operations

  /// Log order creation
  Future<OrderLog> logOrderCreated(Order order, String performedBy, String? performedByName) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.created,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Order ${order.orderNumber} created',
      afterData: {
        'order_type': order.type.toString().split('.').last,
        'table_id': order.tableId,
        'customer_name': order.customerName,
        'item_count': order.items.length,
        'total_amount': order.totalAmount,
      },
      tableId: order.tableId,
      customerId: order.customerName,
    );
  }

  /// Log status change
  Future<OrderLog> logStatusChange(
    Order order,
    OrderStatus fromStatus,
    OrderStatus toStatus,
    String performedBy,
    String? performedByName, {
    String? reason,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.statusChanged,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Status changed from ${fromStatus.toString().split('.').last} to ${toStatus.toString().split('.').last}',
      beforeData: {'status': fromStatus.toString().split('.').last},
      afterData: {'status': toStatus.toString().split('.').last},
      notes: reason,
      tableId: order.tableId,
    );
  }

  /// Log item addition
  Future<OrderLog> logItemAdded(
    Order order,
    OrderItem item,
    String performedBy,
    String? performedByName,
  ) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemAdded,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Added ${item.quantity}x ${item.menuItem.name}',
      afterData: {
        'item_name': item.menuItem.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'special_instructions': item.specialInstructions,
      },
      amountAfter: order.totalAmount,
      tableId: order.tableId,
    );
  }

  /// Log item removal
  Future<OrderLog> logItemRemoved(
    Order order,
    OrderItem item,
    String performedBy,
    String? performedByName, {
    String? reason,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemRemoved,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Removed ${item.quantity}x ${item.menuItem.name}',
      beforeData: {
        'item_name': item.menuItem.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
      },
      notes: reason,
      amountAfter: order.totalAmount,
      tableId: order.tableId,
    );
  }

  /// Log item voided
  Future<OrderLog> logItemVoided(
    Order order,
    OrderItem item,
    String performedBy,
    String? performedByName, {
    String? reason,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemVoided,
      performedBy: performedBy,
      performedByName: performedByName,
      level: LogLevel.warning,
      description: 'Voided ${item.quantity}x ${item.menuItem.name}',
      beforeData: {
        'item_name': item.menuItem.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
      },
      notes: reason,
      amountBefore: order.totalAmount + item.totalPrice,
      amountAfter: order.totalAmount,
      tableId: order.tableId,
    );
  }

  /// Log discount applied
  Future<OrderLog> logDiscountApplied(
    Order order,
    double discountAmount,
    String performedBy,
    String? performedByName, {
    String? discountType,
    String? reason,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.discountApplied,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Applied discount of \$${discountAmount.toStringAsFixed(2)}',
      afterData: {
        'discount_amount': discountAmount,
        'discount_type': discountType,
      },
      notes: reason,
      amountBefore: order.totalAmount + discountAmount,
      amountAfter: order.totalAmount,
      tableId: order.tableId,
    );
  }

  /// Log gratuity added
  Future<OrderLog> logGratuityAdded(
    Order order,
    double gratuityAmount,
    String performedBy,
    String? performedByName, {
    String? reason,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.gratuityAdded,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Added gratuity of \$${gratuityAmount.toStringAsFixed(2)}',
      afterData: {
        'gratuity_amount': gratuityAmount,
      },
      notes: reason,
      amountBefore: order.totalAmount - gratuityAmount,
      amountAfter: order.totalAmount,
      tableId: order.tableId,
    );
  }

  /// Log sent to kitchen
  Future<OrderLog> logSentToKitchen(
    Order order,
    String performedBy,
    String? performedByName, {
    List<OrderItem>? items,
  }) async {
    final itemsToLog = items ?? order.items.where((item) => !item.sentToKitchen).toList();
    
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.sentToKitchen,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Sent ${itemsToLog.length} items to kitchen',
      afterData: {
        'items_sent': itemsToLog.map((item) => {
          'id': item.id,
          'name': item.menuItem.name,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
          'selected_variant': item.selectedVariant,
          'selected_modifiers': item.selectedModifiers,
          'special_instructions': item.specialInstructions,
          'notes': item.notes,
          'category': item.menuItem.categoryId,
        }).toList(),
        'total_items_sent': itemsToLog.length,
        'items_details': itemsToLog.map((item) => 
          '${item.quantity}x ${item.menuItem.name}' +
          (item.selectedVariant != null ? ' (${item.selectedVariant})' : '') +
          (item.selectedModifiers.isNotEmpty ? ' + ${item.selectedModifiers.join(', ')}' : '') +
          (item.specialInstructions?.isNotEmpty == true ? ' - ${item.specialInstructions}' : '') +
          (item.notes?.isNotEmpty == true ? ' [Chef: ${item.notes}]' : '')
        ).toList(),
        'order_status': order.status.name,
        'table_id': order.tableId,
      },
      tableId: order.tableId,
    );
  }

  /// Log payment processed
  Future<OrderLog> logPaymentProcessed(
    Order order,
    double amount,
    String paymentMethod,
    String performedBy,
    String? performedByName, {
    String? transactionId,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.paymentProcessed,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Payment of \$${amount.toStringAsFixed(2)} processed via $paymentMethod',
      afterData: {
        'payment_amount': amount,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
      },
      amountAfter: amount,
      tableId: order.tableId,
    );
  }

  /// Log order cancelled
  Future<OrderLog> logOrderCancelled(
    Order order,
    String performedBy,
    String? performedByName, {
    String? reason,
  }) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.cancelled,
      performedBy: performedBy,
      performedByName: performedByName,
      level: LogLevel.warning,
      description: 'Order ${order.orderNumber} cancelled',
      beforeData: {
        'status': order.status.toString().split('.').last,
        'total_amount': order.totalAmount,
        'item_count': order.items.length,
      },
      notes: reason,
      tableId: order.tableId,
    );
  }

  /// Log order completed
  Future<OrderLog> logOrderCompleted(
    Order order,
    String performedBy,
    String? performedByName,
  ) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.completed,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Order ${order.orderNumber} completed',
      afterData: {
        'total_amount': order.totalAmount,
        'item_count': order.items.length,
        'completion_time': DateTime.now().toIso8601String(),
      },
      amountAfter: order.totalAmount,
      tableId: order.tableId,
    );
  }

  /// Log note added
  Future<OrderLog> logNoteAdded(
    Order order,
    String note,
    String performedBy,
    String? performedByName,
  ) async {
    return logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.noteAdded,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Added note to order',
      afterData: {
        'note': note,
      },
      notes: note,
      tableId: order.tableId,
    );
  }

  /// Get analytics data
  Map<String, dynamic> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filteredLogs = _logs.where((log) {
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList();

    final actionCounts = <String, int>{};
    final userCounts = <String, int>{};
    final hourlyActivity = <int, int>{};
    double totalFinancialImpact = 0.0;

    for (final log in filteredLogs) {
      // Count actions
      final actionKey = log.action.toString().split('.').last;
      actionCounts[actionKey] = (actionCounts[actionKey] ?? 0) + 1;

      // Count by user
      final userKey = log.performedByName ?? log.performedBy;
      userCounts[userKey] = (userCounts[userKey] ?? 0) + 1;

      // Hourly activity
      final hour = log.timestamp.hour;
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;

      // Financial impact
      if (log.financialImpact != null) {
        totalFinancialImpact += log.financialImpact!;
      }
    }

    return {
      'total_logs': filteredLogs.length,
      'action_counts': actionCounts,
      'user_counts': userCounts,
      'hourly_activity': hourlyActivity,
      'total_financial_impact': totalFinancialImpact,
      'financial_operations': filteredLogs.where((log) => log.isFinancialOperation).length,
      'kitchen_operations': filteredLogs.where((log) => log.isKitchenOperation).length,
      'error_count': filteredLogs.where((log) => log.level == LogLevel.error).length,
      'warning_count': filteredLogs.where((log) => log.level == LogLevel.warning).length,
    };
  }

  /// Clean up old logs (keep last 30 days)
  Future<void> cleanupOldLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final db = await _databaseService.database;
      if (db == null) return;
      
      final deletedCount = await db.delete(
        'order_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      // Reload logs after cleanup
      await _loadRecentLogs();
      
      debugPrint('✅ Cleaned up $deletedCount old log entries');
    } catch (e) {
      debugPrint('❌ Failed to cleanup old logs: $e');
    }
  }

  /// Export logs to JSON
  Map<String, dynamic> exportLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? orderId,
    String? userId,
  }) {
    var filteredLogs = _logs.where((log) {
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      if (orderId != null && log.orderId != orderId) return false;
      if (userId != null && log.performedBy != userId) return false;
      return true;
    }).toList();

    return {
      'export_date': DateTime.now().toIso8601String(),
      'total_logs': filteredLogs.length,
      'filters': {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'order_id': orderId,
        'user_id': userId,
      },
      'logs': filteredLogs.map((log) => log.toJson()).toList(),
    };
  }

  /// Delete old order logs (older than specified days)
  Future<int> deleteOldLogs({int daysToKeep = 30}) async {
    if (kIsWeb) {
      // Web platform - clean up web storage
      try {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
        final allLogs = await _databaseService.getWebOrderLogs();
        
        int deletedCount = 0;
        final updatedLogs = <Map<String, dynamic>>[];
        
        for (final log in allLogs) {
          final logDate = DateTime.tryParse(log['timestamp']?.toString() ?? '') ?? DateTime.now();
          if (logDate.isAfter(cutoffDate)) {
            updatedLogs.add(log);
          } else {
            deletedCount++;
          }
        }
        
        // Save updated logs back to web storage
        await _databaseService.saveWebOrderLogs(updatedLogs);
        
        debugPrint('🧹 Deleted $deletedCount old order logs from web storage');
        return deletedCount;
      } catch (e) {
        debugPrint('❌ Error deleting old web order logs: $e');
        return 0;
      }
    }
    
    try {
      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available for deleting old logs');
        return 0;
      }
      
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final deletedCount = await db.delete(
        'order_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      
      debugPrint('🧹 Deleted $deletedCount old order logs');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error deleting old order logs: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _logs.clear();
    _orderLogsCache.clear();
    super.dispose();
  }
} 