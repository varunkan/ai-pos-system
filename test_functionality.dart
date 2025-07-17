import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/order.dart';

void main() {
  group('POS System Core Functionality Tests', () {
    late DatabaseService databaseService;
    late MenuService menuService;
    late OrderService orderService;
    late OrderLogService orderLogService;

    setUpAll(() async {
      // Initialize services
      databaseService = DatabaseService();
      menuService = MenuService(databaseService);
      orderLogService = OrderLogService(databaseService);
      orderService = OrderService(databaseService, orderLogService);
      
      // Initialize database
      await databaseService.database;
      
      // Load sample menu data
      await menuService.ensureInitialized();
    });

    test('Menu Service - Load Sample Data', () async {
      final categories = await menuService.getCategories();
      final menuItems = await menuService.getMenuItems();
      
      expect(categories.isNotEmpty, true, reason: 'Should have sample categories');
      expect(menuItems.isNotEmpty, true, reason: 'Should have sample menu items');
      
      debugPrint('✅ Loaded ${categories.length} categories and ${menuItems.length} menu items');
    });

    test('Order Creation - Basic Functionality', () async {
      final menuItems = await menuService.getMenuItems();
      expect(menuItems.isNotEmpty, true, reason: 'Need menu items to create order');
      
      // Create a test order using the service
      final order = await orderService.createOrder(
        orderType: 'dineIn',
        customerName: 'Test Customer',
        userId: 'test-user',
      );
      
      // Add items to the order
      final firstMenuItem = menuItems.first;
      final orderItem = OrderItem(
        id: 'test-item-${DateTime.now().millisecondsSinceEpoch}',
        menuItem: firstMenuItem,
        quantity: 1,
        unitPrice: firstMenuItem.price,
        notes: '',
      );
      
      order.items.add(orderItem);
      
      // Save the order
      final success = await orderService.saveOrder(order);
      expect(success, true, reason: 'Order should be saved successfully');
      
      // Verify order was saved
      final savedOrder = await orderService.getOrderById(order.id);
      expect(savedOrder, isNotNull);
      expect(savedOrder!.items.length, equals(1));
      expect(savedOrder.items.first.menuItem.id, equals(firstMenuItem.id));
      
      debugPrint('✅ Order creation and saving works correctly');
    });

    test('Send to Kitchen Functionality', () async {
      // Load all orders
      await orderService.loadOrders();
      final orders = orderService.allOrders;
      expect(orders.isNotEmpty, true, reason: 'Need existing orders to test');
      
      final testOrder = orders.first;
      
      // Send to kitchen
      final success = await orderService.updateOrderStatus(testOrder.id, 'confirmed');
      expect(success, true, reason: 'Status update should succeed');
      
      // Verify status update
      final updatedOrder = await orderService.getOrderById(testOrder.id);
      expect(updatedOrder!.status.toString().split('.').last, equals('confirmed'));
      
      debugPrint('✅ Send to kitchen functionality works correctly');
    });

    test('Order Item Management', () async {
      // Load all orders
      await orderService.loadOrders();
      final orders = orderService.allOrders;
      expect(orders.isNotEmpty, true, reason: 'Need existing orders to test');
      
      final testOrder = orders.first;
      final originalItemCount = testOrder.items.length;
      
      // Add another item to the order
      final menuItems = await menuService.getMenuItems();
      final secondMenuItem = menuItems.length > 1 ? menuItems[1] : menuItems.first;
      
      final newOrderItem = OrderItem(
        id: 'test-item-2-${DateTime.now().millisecondsSinceEpoch}',
        menuItem: secondMenuItem,
        quantity: 2,
        unitPrice: secondMenuItem.price,
        notes: '',
      );
      
      // Add the new item to the existing order
      testOrder.items.add(newOrderItem);
      
      final success = await orderService.saveOrder(testOrder);
      expect(success, true, reason: 'Order update should succeed');
      
      // Verify item was added
      final savedOrder = await orderService.getOrderById(testOrder.id);
      expect(savedOrder!.items.length, equals(originalItemCount + 1));
      
      debugPrint('✅ Order item management works correctly');
    });
  });
} 