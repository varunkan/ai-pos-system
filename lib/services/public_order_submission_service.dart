import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/printer_configuration.dart';
import 'cross_platform_database_service.dart';
import 'printing_service.dart';
import 'printer_configuration_service.dart';
import 'order_service.dart';

/// Service for handling public order submissions from customers anywhere in the world
/// Orders are automatically routed to restaurant printers regardless of customer location
class PublicOrderSubmissionService extends ChangeNotifier {
  static const String _logTag = '🌐 PublicOrderService';
  static const String _uuid = 'uuid';
  
  final CrossPlatformDatabaseService _db = CrossPlatformDatabaseService();
  final PrintingService _printingService;
  final PrinterConfigurationService _printerConfigService;
  final OrderService _orderService;
  
  // Real-time order monitoring
  Timer? _orderMonitorTimer;
  final Set<String> _processedOrders = {};
  bool _isMonitoring = false;
  
  // Restaurant configuration
  String? _restaurantId;
  String? _restaurantName;
  bool _isPublicOrderingEnabled = true;
  
  // Statistics
  int _todayOrdersCount = 0;
  int _totalPublicOrders = 0;
  
  PublicOrderSubmissionService({
    required PrintingService printingService,
    required PrinterConfigurationService printerConfigService, 
    required OrderService orderService,
  }) : _printingService = printingService,
       _printerConfigService = printerConfigService,
       _orderService = orderService;

  // Getters
  bool get isPublicOrderingEnabled => _isPublicOrderingEnabled;
  bool get isMonitoring => _isMonitoring;
  int get todayOrdersCount => _todayOrdersCount;
  int get totalPublicOrders => _totalPublicOrders;
  String? get restaurantId => _restaurantId;

  /// Initialize public ordering service for a restaurant
  Future<void> initialize(String restaurantId, String restaurantName) async {
    debugPrint('$_logTag 🚀 Initializing public ordering for: $restaurantName');
    
    _restaurantId = restaurantId;
    _restaurantName = restaurantName;
    
    // Start monitoring for new orders
    await _startOrderMonitoring();
    
    // Load existing statistics
    await _loadStatistics();
    
    debugPrint('$_logTag ✅ Public ordering service initialized');
  }

  /// Start real-time monitoring for new public orders
  Future<void> _startOrderMonitoring() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    debugPrint('$_logTag 👀 Starting real-time order monitoring...');
    
    // Check for new orders every 10 seconds
    _orderMonitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkForNewOrders();
    });
    
    // Also check immediately
    _checkForNewOrders();
  }

  /// Check for new public orders and process them
  Future<void> _checkForNewOrders() async {
    if (_restaurantId == null) return;
    
    try {
      // Get all orders for this restaurant from cloud database
      final allOrders = await _db.getAllData('public_orders_$_restaurantId');
      
      int newOrdersCount = 0;
      
      for (final orderData in allOrders) {
        final orderId = orderData['id'] as String;
        
        // Skip if already processed
        if (_processedOrders.contains(orderId)) continue;
        
        // Check if order is new (created in last 24 hours and not processed)
        final createdAt = DateTime.parse(orderData['created_at']);
        final isRecent = DateTime.now().difference(createdAt).inDays < 1;
        
        if (isRecent && orderData['status'] == 'submitted') {
          await _processNewPublicOrder(orderData);
          _processedOrders.add(orderId);
          newOrdersCount++;
        }
      }
      
      if (newOrdersCount > 0) {
        debugPrint('$_logTag 📦 Processed $newOrdersCount new public orders');
        notifyListeners();
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error checking for new orders: $e');
    }
  }

  /// Process a new public order - add to restaurant system and print
  Future<void> _processNewPublicOrder(Map<String, dynamic> orderData) async {
    try {
      debugPrint('$_logTag 🆕 Processing new public order: ${orderData['order_number']}');
      
      // Convert public order to internal Order object
      final order = await _convertPublicOrderToInternal(orderData);
      
      // Add to restaurant's order system
      await _orderService.saveOrder(order, logAction: 'public_submission');
      
      // Automatically print to configured printers
      await _printOrderToKitchen(order);
      
      // Update order status to 'received'
      await _updatePublicOrderStatus(orderData['id'], 'received', 'Order received and sent to kitchen');
      
      // Update statistics
      _todayOrdersCount++;
      _totalPublicOrders++;
      
      debugPrint('$_logTag ✅ Public order processed: ${order.orderNumber}');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error processing public order: $e');
      
      // Update order status to error
      await _updatePublicOrderStatus(
        orderData['id'], 
        'error', 
        'Failed to process order: $e'
      );
    }
  }

  /// Convert public order format to internal Order object
  Future<Order> _convertPublicOrderToInternal(Map<String, dynamic> publicOrder) async {
    final orderItems = <OrderItem>[];
    
    // Convert public order items to OrderItem objects
    final items = publicOrder['items'] as List<dynamic>;
    for (final itemData in items) {
      try {
        // Create a MenuItem object (you might need to match with your menu)
        final menuItem = MenuItem(
          id: itemData['menu_item_id'] ?? 'unknown',
          name: itemData['name'] ?? 'Unknown Item',
          description: itemData['description'] ?? '',
          price: (itemData['price'] ?? 0.0).toDouble(),
          categoryId: itemData['categoryId'] ?? itemData['category'] ?? 'general',
          isAvailable: true,
          imageUrl: itemData['image_url'],
        );
        
        final orderItem = OrderItem(
          id: const Uuid().v4(),
          menuItem: menuItem,
          quantity: (itemData['quantity'] ?? 1).toInt(),
          unitPrice: (itemData['price'] ?? 0.0).toDouble(),
          specialInstructions: itemData['special_instructions'],
          selectedVariant: itemData['selected_variant'],
          selectedModifiers: List<String>.from(itemData['selected_modifiers'] ?? []),
          notes: itemData['notes'],
        );
        
        orderItems.add(orderItem);
      } catch (e) {
        debugPrint('$_logTag ⚠️ Error converting order item: $e');
      }
    }
    
    // Create Order object
    final order = Order(
      id: const Uuid().v4(),
      orderNumber: publicOrder['order_number'] ?? 'PUB-${DateTime.now().millisecondsSinceEpoch}',
      type: _parseOrderType(publicOrder['type']),
      status: OrderStatus.pending,
      items: orderItems,
      customerName: publicOrder['customer_name'],
      customerPhone: publicOrder['customer_phone'],
      customerEmail: publicOrder['customer_email'],
      customerAddress: publicOrder['customer_address'],
      specialInstructions: publicOrder['special_instructions'],
      tableId: publicOrder['table_id'], // For dine-in orders
      userId: 'public_customer', // Special user ID for public orders
      subtotal: (publicOrder['subtotal'] ?? 0.0).toDouble(),
      taxAmount: (publicOrder['tax_amount'] ?? 0.0).toDouble(),
      totalAmount: (publicOrder['total_amount'] ?? 0.0).toDouble(),
      paymentMethod: publicOrder['payment_method'],
      paymentStatus: publicOrder['payment_status'],
      createdAt: DateTime.parse(publicOrder['created_at']),
      updatedAt: DateTime.now(),
      metadata: {
        'source': 'public_app',
        'customer_location': publicOrder['customer_location'],
        'app_version': publicOrder['app_version'],
        'public_order_id': publicOrder['id'],
      },
    );
    
    return order;
  }

  /// Print order to kitchen printers automatically
  Future<void> _printOrderToKitchen(Order order) async {
    try {
      debugPrint('$_logTag 🖨️ Auto-printing order to kitchen: ${order.orderNumber}');
      
      // Get active printer configurations
      final printerConfigs = _printerConfigService.activeConfigurations;
      
      if (printerConfigs.isEmpty) {
        debugPrint('$_logTag ⚠️ No active printers configured');
        return;
      }
      
      // Print to all active printers (or implement smart routing)
      for (final config in printerConfigs) {
        try {
          await _printOrderToPrinter(order, config);
        } catch (e) {
          debugPrint('$_logTag ❌ Failed to print to ${config.name}: $e');
        }
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error printing order: $e');
    }
  }

  /// Print order to specific printer
  Future<void> _printOrderToPrinter(Order order, PrinterConfiguration config) async {
    try {
      // Test printer connection first
      final isConnected = await _printerConfigService.testConfiguration(config);
      if (!isConnected) {
        debugPrint('$_logTag ⚠️ Printer ${config.name} is not connected');
        return;
      }
      
      // Send to printer via printing service (use printKitchenTicket instead)
      // Create a temporary order for printing
      final tempOrder = Order(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        orderNumber: order.orderNumber,
        customerName: order.customerName,
        items: order.items,
        subtotal: order.subtotal,
        hstAmount: order.hstAmount ?? 0.0,
        totalAmount: order.totalAmount,
        status: order.status,
        type: order.type,
      );
      await _printingService.printKitchenTicket(tempOrder);
      
      debugPrint('$_logTag ✅ Order printed to ${config.name}');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error printing to ${config.name}: $e');
    }
  }

  /// Generate receipt content for printing
  String _generateReceiptContent(Order order) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('================================');
    buffer.writeln('       NEW ORDER - KITCHEN      ');
    buffer.writeln('================================');
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Type: ${order.type.name.toUpperCase()}');
    buffer.writeln('Time: ${_formatDateTime(order.createdAt)}');
    
    if (order.tableId != null) {
      buffer.writeln('Table: ${order.tableId}');
    }
    
    buffer.writeln('Customer: ${order.customerName ?? 'Walk-in'}');
    
    if (order.customerPhone != null) {
      buffer.writeln('Phone: ${order.customerPhone}');
    }
    
    buffer.writeln('Source: PUBLIC ORDER APP');
    buffer.writeln('================================');
    
    // Items
    buffer.writeln('ITEMS:');
    buffer.writeln('--------------------------------');
    
    for (final item in order.items) {
      buffer.writeln('${item.quantity}x ${item.menuItem.name}');
      
      if (item.selectedVariant != null) {
        buffer.writeln('   Variant: ${item.selectedVariant}');
      }
      
      if (item.selectedModifiers.isNotEmpty) {
        buffer.writeln('   Modifiers: ${item.selectedModifiers.join(', ')}');
      }
      
      if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
        buffer.writeln('   *** ${item.specialInstructions} ***');
      }
      
      buffer.writeln('');
    }
    
    // Special instructions
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      buffer.writeln('--------------------------------');
      buffer.writeln('SPECIAL INSTRUCTIONS:');
      buffer.writeln('*** ${order.specialInstructions} ***');
    }
    
    // Footer
    buffer.writeln('================================');
    buffer.writeln('Total: \$${order.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('Payment: ${order.paymentMethod ?? 'Pending'}');
    buffer.writeln('================================');
    buffer.writeln('');
    buffer.writeln('');
    
    return buffer.toString();
  }

  /// Update public order status in cloud database
  Future<void> _updatePublicOrderStatus(String orderId, String status, String message) async {
    if (_restaurantId == null) return;
    
    try {
      final updateData = {
        'status': status,
        'status_message': message,
        'restaurant_processed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Update in cloud database
      await _db.saveData('public_orders_$_restaurantId', orderId, updateData);
      
      debugPrint('$_logTag 📝 Updated order status: $orderId -> $status');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error updating order status: $e');
    }
  }

  /// Load statistics from storage
  Future<void> _loadStatistics() async {
    try {
      final stats = await _db.getData('restaurant_stats', _restaurantId ?? 'default');
      if (stats != null) {
        _totalPublicOrders = stats['total_public_orders'] ?? 0;
        
        // Reset daily count if it's a new day
        final lastUpdate = stats['last_update'] != null 
            ? DateTime.parse(stats['last_update'])
            : DateTime.now();
        
        if (_isNewDay(lastUpdate)) {
          _todayOrdersCount = 0;
        } else {
          _todayOrdersCount = stats['today_orders_count'] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading statistics: $e');
    }
  }

  /// Save statistics to storage
  Future<void> _saveStatistics() async {
    try {
      final stats = {
        'total_public_orders': _totalPublicOrders,
        'today_orders_count': _todayOrdersCount,
        'last_update': DateTime.now().toIso8601String(),
        'restaurant_id': _restaurantId,
      };
      
      await _db.saveData('restaurant_stats', _restaurantId ?? 'default', stats);
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving statistics: $e');
    }
  }

  /// Enable/disable public ordering
  Future<void> setPublicOrderingEnabled(bool enabled) async {
    _isPublicOrderingEnabled = enabled;
    
    if (enabled && !_isMonitoring) {
      await _startOrderMonitoring();
    } else if (!enabled && _isMonitoring) {
      _stopOrderMonitoring();
    }
    
    debugPrint('$_logTag ${enabled ? '✅ Enabled' : '⏸️ Disabled'} public ordering');
    notifyListeners();
  }

  /// Stop order monitoring
  void _stopOrderMonitoring() {
    _orderMonitorTimer?.cancel();
    _orderMonitorTimer = null;
    _isMonitoring = false;
    debugPrint('$_logTag ⏹️ Stopped order monitoring');
  }

  /// Utility methods
  OrderType _parseOrderType(String? type) {
    switch (type?.toLowerCase()) {
      case 'dine_in':
      case 'dinein':
        return OrderType.dineIn;
      case 'takeaway':
      case 'pickup':
        return OrderType.takeaway;
      case 'delivery':
        return OrderType.delivery;
      default:
        return OrderType.takeaway; // Default for public orders
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  bool _isNewDay(DateTime lastUpdate) {
    final now = DateTime.now();
    return now.day != lastUpdate.day || 
           now.month != lastUpdate.month || 
           now.year != lastUpdate.year;
  }

  @override
  void dispose() {
    _stopOrderMonitoring();
    _saveStatistics();
    super.dispose();
  }
} 