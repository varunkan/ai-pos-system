import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/printer_configuration.dart';

import '../services/database_service.dart';
import '../services/printing_service.dart' as printing_service;
import '../services/enhanced_printer_assignment_service.dart';
import '../services/printer_configuration_service.dart';
import '../services/order_log_service.dart';

/// Robust Kitchen Service
/// Handles all "Send to Kitchen" operations with:
/// - Smart item detection (only new items)
/// - Public IP printer support for remote access
/// - Comprehensive error handling
/// - No infinite spinners
/// - Unified logic for all screens
class RobustKitchenService extends ChangeNotifier {
  static const String _logTag = '🍽️ RobustKitchenService';
  
  final DatabaseService _databaseService;
  final printing_service.PrintingService _printingService;
  final EnhancedPrinterAssignmentService _assignmentService;
  final PrinterConfigurationService _printerConfigService;
  final OrderLogService? _orderLogService;
  
  // State management
  bool _isSending = false;
  Map<String, bool> _orderSendingStates = {}; // Track per-order sending states
  String? _lastError;
  DateTime? _lastSuccessfulSend;
  
  // Performance tracking
  int _totalItemsSent = 0;
  int _totalOrdersSent = 0;
  Map<String, int> _printerSuccessCount = {};
  Map<String, int> _printerFailureCount = {};
  
  RobustKitchenService({
    required DatabaseService databaseService,
    required printing_service.PrintingService printingService,
    required EnhancedPrinterAssignmentService assignmentService,
    required PrinterConfigurationService printerConfigService,
    OrderLogService? orderLogService,
  }) : _databaseService = databaseService,
       _printingService = printingService,
       _assignmentService = assignmentService,
       _printerConfigService = printerConfigService,
       _orderLogService = orderLogService;
  
  // Getters
  bool get isSending => _isSending;
  bool isOrderSending(String orderId) => _orderSendingStates[orderId] ?? false;
  String? get lastError => _lastError;
  DateTime? get lastSuccessfulSend => _lastSuccessfulSend;
  int get totalItemsSent => _totalItemsSent;
  int get totalOrdersSent => _totalOrdersSent;
  
  /// Send order to kitchen with comprehensive error handling
  /// Returns: {success: bool, message: String, itemsSent: int, printerCount: int}
  Future<Map<String, dynamic>> sendToKitchen({
    required Order order,
    required String userId,
    required String userName,
  }) async {
    final orderId = order.id;
    
    // Prevent multiple simultaneous sends for same order
    if (isOrderSending(orderId)) {
      return {
        'success': false,
        'message': 'Order is already being sent to kitchen',
        'itemsSent': 0,
        'printerCount': 0,
      };
    }
    
    debugPrint('$_logTag 🚀 Starting robust send to kitchen for order: ${order.orderNumber}');
    
    // Set loading state
    _orderSendingStates[orderId] = true;
    _isSending = true;
    _lastError = null;
    notifyListeners();
    
    try {
      // Step 1: Smart item detection - only send NEW items
      final newItems = _detectNewItems(order);
      if (newItems.isEmpty) {
        return _completeWithResult(orderId, {
          'success': false,
          'message': 'No new items to send to kitchen. All items have already been sent.',
          'itemsSent': 0,
          'printerCount': 0,
        });
      }
      
      debugPrint('$_logTag 🔍 Detected ${newItems.length} new items to send');
      
      // Step 2: Validate printer assignments
      final assignmentValidation = await _validatePrinterAssignments(newItems);
      if (!assignmentValidation['isValid']) {
        return _completeWithResult(orderId, {
          'success': false,
          'message': assignmentValidation['message'],
          'itemsSent': 0,
          'printerCount': 0,
        });
      }
      
      // Step 3: Smart printer segregation
      final itemsByPrinter = await _segregateItemsByPrinter(newItems);
      if (itemsByPrinter.isEmpty) {
        return _completeWithResult(orderId, {
          'success': false,
          'message': 'No valid printer assignments found for items',
          'itemsSent': 0,
          'printerCount': 0,
        });
      }
      
      debugPrint('$_logTag 📋 Items segregated to ${itemsByPrinter.length} printer(s)');
      
      // Step 4: Update order items to mark as sent BEFORE printing
      final updatedOrder = await _markItemsAsSent(order, newItems, userId);
      
      // Step 5: Print to assigned printers with timeout protection
      final printResults = await _printToAssignedPrinters(
        updatedOrder, 
        itemsByPrinter,
        timeout: const Duration(seconds: 15), // Prevent infinite hangs
      );
      
      // Step 6: Log the operation
      await _logKitchenOperation(updatedOrder, newItems, userId, userName, printResults);
      
      // Step 7: Update statistics
      _updateStatistics(newItems.length, printResults);
      
      final successfulPrinters = printResults.values.where((success) => success).length;
      final totalPrinters = printResults.length;
      
      return _completeWithResult(orderId, {
        'success': successfulPrinters > 0,
        'message': _generateSuccessMessage(newItems.length, successfulPrinters, totalPrinters),
        'itemsSent': newItems.length,
        'printerCount': successfulPrinters,
        'printResults': printResults,
      });
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error in send to kitchen: $e');
      _lastError = e.toString();
      
      return _completeWithResult(orderId, {
        'success': false,
        'message': 'Failed to send to kitchen: ${e.toString()}',
        'itemsSent': 0,
        'printerCount': 0,
        'error': e.toString(),
      });
    }
  }
  
  /// Smart detection of items that haven't been sent to kitchen yet
  List<OrderItem> _detectNewItems(Order order) {
    return order.items.where((item) {
      // Only include items that haven't been sent to kitchen
      final isNew = !item.sentToKitchen;
      if (isNew) {
        debugPrint('$_logTag 🆕 New item detected: ${item.menuItem.name} (qty: ${item.quantity})');
      }
      return isNew;
    }).toList();
  }
  
  /// Validate that all items have printer assignments
  Future<Map<String, dynamic>> _validatePrinterAssignments(List<OrderItem> items) async {
    if (!_assignmentService.isInitialized) {
      return {
        'isValid': false,
        'message': 'Printer assignment service not initialized',
      };
    }
    
    final unassignedItems = <OrderItem>[];
    
    for (final item in items) {
      final assignments = _assignmentService.getAssignmentsForMenuItem(
        item.menuItem.id,
        item.menuItem.categoryId ?? '',
      );
      
      if (assignments.isEmpty) {
        unassignedItems.add(item);
      }
    }
    
    if (unassignedItems.isNotEmpty) {
      final itemNames = unassignedItems.map((item) => item.menuItem.name).join(', ');
      return {
        'isValid': false,
        'message': 'Some items have no printer assignments: $itemNames. Please configure printer assignments first.',
      };
    }
    
    return {'isValid': true, 'message': 'All items have valid printer assignments'};
  }
  
  /// Segregate items by their assigned printers (supports multi-printer assignments)
  Future<Map<String, List<OrderItem>>> _segregateItemsByPrinter(List<OrderItem> items) async {
    final Map<String, List<OrderItem>> itemsByPrinter = {};
    
    for (final item in items) {
      final assignments = _assignmentService.getAssignmentsForMenuItem(
        item.menuItem.id,
        item.menuItem.categoryId ?? '',
      );
      
      if (assignments.isNotEmpty) {
        // Support multi-printer assignments - item can go to multiple printers
        for (final assignment in assignments) {
          final printerId = assignment.printerId;
          itemsByPrinter.putIfAbsent(printerId, () => []).add(item);
          debugPrint('$_logTag 🎯 ${item.menuItem.name} → ${assignment.printerName} (${assignment.printerAddress})');
        }
      }
    }
    
    return itemsByPrinter;
  }
  
  /// Mark items as sent to kitchen in database
  Future<Order> _markItemsAsSent(Order order, List<OrderItem> itemsToMark, String userId) async {
    try {
      // Create updated items list
      final updatedItems = order.items.map((item) {
        final shouldMark = itemsToMark.any((newItem) => newItem.id == item.id);
        return shouldMark ? item.copyWith(sentToKitchen: true) : item;
      }).toList();
      
      // Create updated order
      final updatedOrder = order.copyWith(
        items: updatedItems,
        userId: userId, // Ensure correct user association
        updatedAt: DateTime.now(),
      );
      
      // Save to database
      await _saveOrderDirectly(updatedOrder);
      
      debugPrint('$_logTag ✅ Marked ${itemsToMark.length} items as sent to kitchen');
      return updatedOrder;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error marking items as sent: $e');
      rethrow;
    }
  }
  
  /// Print to assigned printers with timeout protection
  Future<Map<String, bool>> _printToAssignedPrinters(
    Order order,
    Map<String, List<OrderItem>> itemsByPrinter, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Map<String, bool> results = {};
    
    debugPrint('$_logTag 🖨️ Starting printing to ${itemsByPrinter.length} printer(s)');
    
    // Print to each printer with timeout protection
    for (final entry in itemsByPrinter.entries) {
      final printerId = entry.key;
      final items = entry.value;
      
      try {
        // Get printer configuration (supports both local and public IPs)
        final printerConfig = await _printerConfigService.getConfigurationById(printerId);
        if (printerConfig == null) {
          debugPrint('$_logTag ❌ Printer configuration not found: $printerId');
          results[printerId] = false;
          continue;
        }
        
        debugPrint('$_logTag 🖨️ Printing ${items.length} items to: ${printerConfig.name} (${printerConfig.fullAddress})');
        
        // Create order subset for this printer
        final printerOrder = order.copyWith(items: items);
        
        // Print with timeout protection to prevent infinite hangs
        final printResult = await _printWithTimeout(
          printerConfig,
          printerOrder,
          timeout,
        );
        
        results[printerId] = printResult;
        
        if (printResult) {
          debugPrint('$_logTag ✅ Successfully printed to ${printerConfig.name}');
          _printerSuccessCount[printerId] = (_printerSuccessCount[printerId] ?? 0) + 1;
        } else {
          debugPrint('$_logTag ❌ Failed to print to ${printerConfig.name}');
          _printerFailureCount[printerId] = (_printerFailureCount[printerId] ?? 0) + 1;
        }
        
        // Small delay between printers to prevent connection conflicts
        await Future.delayed(const Duration(milliseconds: 500));
        
      } catch (e) {
        debugPrint('$_logTag ❌ Error printing to $printerId: $e');
        results[printerId] = false;
        _printerFailureCount[printerId] = (_printerFailureCount[printerId] ?? 0) + 1;
      }
    }
    
    return results;
  }
  
  /// Print with timeout protection to prevent infinite hangs
  Future<bool> _printWithTimeout(
    PrinterConfiguration printerConfig,
    Order order,
    Duration timeout,
  ) async {
    try {
      // Create timeout completer
      final completer = Completer<bool>();
      late Timer timeoutTimer;
      
      // Start the print operation
      final printFuture = _printToSpecificPrinter(printerConfig, order);
      
      // Set up timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
          debugPrint('$_logTag ⏰ Print timeout for ${printerConfig.name}');
        }
      });
      
      // Wait for either completion or timeout
      printFuture.then((result) {
        timeoutTimer.cancel();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }).catchError((error) {
        timeoutTimer.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      return await completer.future;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error in print with timeout: $e');
      return false;
    }
  }
  
  /// Print to specific printer (supports both local and public IPs)
  Future<bool> _printToSpecificPrinter(PrinterConfiguration config, Order order) async {
    try {
      // Generate kitchen ticket content
      final ticketContent = _generateKitchenTicket(order, config);
      
      // Support for public IP addresses for remote printing
      final printerAddress = config.fullAddress;
      final isPublicIP = _isPublicIPAddress(printerAddress);
      
      if (isPublicIP) {
        debugPrint('$_logTag 🌐 Printing to public IP: $printerAddress');
      } else {
        debugPrint('$_logTag 🏠 Printing to local IP: $printerAddress');
      }
      
      // Use printing service to send content
      final success = await _printingService.printToSpecificPrinter(
        printerAddress,
        ticketContent,
        printing_service.PrinterType.wifi, // Support both local and public WiFi printing
      );
      
      if (success) {
        await _updatePrinterLastConnected(config.id);
      }
      
      return success;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error printing to ${config.name}: $e');
      return false;
    }
  }
  
  /// Check if IP address is public (for remote access)
  bool _isPublicIPAddress(String address) {
    // Extract IP from address:port format
    final ip = address.split(':')[0];
    
    // Check if it's a public IP (not private/local)
    if (ip.startsWith('192.168.') || 
        ip.startsWith('10.') ||
        ip.startsWith('172.16.') ||
        ip.startsWith('127.')) {
      return false; // Private/local IP
    }
    
    return true; // Likely public IP
  }
  
  /// Generate kitchen ticket content
  String _generateKitchenTicket(Order order, PrinterConfiguration config) {
    final buffer = StringBuffer();
    
    // Header with restaurant info
    buffer.writeln('================================');
    buffer.writeln('        KITCHEN TICKET');
    buffer.writeln('================================');
    buffer.writeln('Order: ${order.orderNumber}');
    buffer.writeln('Time: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('Table: ${order.tableId ?? 'Take-Out'}');
    buffer.writeln('Customer: ${order.customerName ?? 'Walk-in'}');
    buffer.writeln('Server: ${order.userId}');
    buffer.writeln('Printer: ${config.name}');
    buffer.writeln('================================');
    buffer.writeln();
    
    // Items for this printer
    buffer.writeln('ITEMS:');
    buffer.writeln('--------------------------------');
    
    int itemCount = 0;
    for (final item in order.items) {
      itemCount++;
      buffer.writeln('${item.quantity}x ${item.menuItem.name}');
      
      if (item.selectedVariant?.isNotEmpty == true) {
        buffer.writeln('   Variant: ${item.selectedVariant}');
      }
      
      if (item.specialInstructions?.isNotEmpty == true) {
        buffer.writeln('   Special: ${item.specialInstructions}');
      }
      
      if (item.notes?.isNotEmpty == true) {
        buffer.writeln('   Notes: ${item.notes}');
      }
      
      buffer.writeln();
    }
    
    // Footer
    buffer.writeln('--------------------------------');
    buffer.writeln('Total Items: $itemCount');
    buffer.writeln('Priority: ${order.isUrgent ? 'URGENT ⚡' : 'Normal'}');
    buffer.writeln('================================');
    buffer.writeln();
    buffer.writeln();
    buffer.writeln(); // Extra spacing for tear-off
    
    return buffer.toString();
  }
  
  /// Save order directly to database
  Future<void> _saveOrderDirectly(Order order) async {
    try {
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');
      
      await db.transaction((txn) async {
        // Update order
        await txn.update(
          'orders',
          _orderToMap(order),
          where: 'id = ?',
          whereArgs: [order.id],
        );
        
        // Update order items
        for (final item in order.items) {
          await txn.update(
            'order_items',
            _orderItemToMap(item, order.id),
            where: 'id = ?',
            whereArgs: [item.id],
          );
        }
      });
      
      debugPrint('$_logTag ✅ Order saved directly to database: ${order.orderNumber}');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving order: $e');
      rethrow;
    }
  }
  
  /// Convert order to database map
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
      'payment_method': order.paymentMethod?.toString().split('.').last,
      'payment_status': order.paymentStatus?.toString().split('.').last,
      'payment_transaction_id': order.paymentTransactionId,
      'order_time': order.orderTime.toIso8601String(),
      'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
      'actual_ready_time': order.actualReadyTime?.toIso8601String(),
      'served_time': order.servedTime?.toIso8601String(),
      'completed_time': order.completedTime?.toIso8601String(),
      'is_urgent': order.isUrgent ? 1 : 0,
      'priority': order.priority,
      'assigned_to': order.assignedTo,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// Convert order item to database map
  Map<String, dynamic> _orderItemToMap(OrderItem item, String orderId) {
    return {
      'id': item.id,
      'order_id': orderId,
      'menu_item_id': item.menuItem.id,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'total_price': item.totalPrice,
      'selected_variant': item.selectedVariant,
      'special_instructions': item.specialInstructions,
      'notes': item.notes,
      'is_available': item.isAvailable ? 1 : 0,
      'sent_to_kitchen': item.sentToKitchen ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
  
  /// Log kitchen operation
  Future<void> _logKitchenOperation(
    Order order,
    List<OrderItem> items,
    String userId,
    String userName,
    Map<String, bool> printResults,
  ) async {
    try {
      await _orderLogService?.logSentToKitchen(
        order,
        userId,
        userName,
        items: items,
      );
      
      debugPrint('$_logTag ✅ Kitchen operation logged successfully');
      
    } catch (e) {
      debugPrint('$_logTag ⚠️ Failed to log kitchen operation: $e');
      // Don't throw - logging failure shouldn't stop the operation
    }
  }
  
  /// Update printer last connected time
  Future<void> _updatePrinterLastConnected(String printerId) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      await db.update(
        'printer_configurations',
        {
          'last_connected': DateTime.now().toIso8601String(),
          'connection_status': 'connected',
        },
        where: 'id = ?',
        whereArgs: [printerId],
      );
      
    } catch (e) {
      debugPrint('$_logTag ⚠️ Failed to update printer last connected: $e');
    }
  }
  
  /// Update statistics
  void _updateStatistics(int itemsSent, Map<String, bool> printResults) {
    _totalItemsSent += itemsSent;
    _totalOrdersSent += 1;
    _lastSuccessfulSend = DateTime.now();
    
    final successfulPrints = printResults.values.where((success) => success).length;
    if (successfulPrints > 0) {
      debugPrint('$_logTag 📊 Stats updated: $itemsSent items sent, $successfulPrints successful prints');
    }
  }
  
  /// Generate success message
  String _generateSuccessMessage(int itemsSent, int successfulPrinters, int totalPrinters) {
    if (successfulPrinters == totalPrinters) {
      return '$itemsSent items sent to kitchen successfully! Printed to $successfulPrinters printer${successfulPrinters == 1 ? '' : 's'}.';
    } else if (successfulPrinters > 0) {
      return '$itemsSent items sent to kitchen! Printed to $successfulPrinters of $totalPrinters printers (some prints failed).';
    } else {
      return '$itemsSent items marked as sent to kitchen, but all prints failed. Check printer connections.';
    }
  }
  
  /// Complete operation with result
  Map<String, dynamic> _completeWithResult(String orderId, Map<String, dynamic> result) {
    // Clear loading states
    _orderSendingStates[orderId] = false;
    _isSending = _orderSendingStates.values.any((sending) => sending);
    notifyListeners();
    
    debugPrint('$_logTag 🏁 Send to kitchen completed for order $orderId: ${result['success'] ? 'SUCCESS' : 'FAILED'}');
    
    return result;
  }
  
  /// Get printer statistics
  Map<String, dynamic> getPrinterStatistics() {
    return {
      'totalItemsSent': _totalItemsSent,
      'totalOrdersSent': _totalOrdersSent,
      'lastSuccessfulSend': _lastSuccessfulSend,
      'printerSuccessCount': Map.from(_printerSuccessCount),
      'printerFailureCount': Map.from(_printerFailureCount),
    };
  }
  
  /// Reset statistics
  void resetStatistics() {
    _totalItemsSent = 0;
    _totalOrdersSent = 0;
    _printerSuccessCount.clear();
    _printerFailureCount.clear();
    _lastSuccessfulSend = null;
    notifyListeners();
  }
} 