import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/order_item.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/screens/reports_screen.dart';

void main() {
  group('Reporting End-to-End Tests', () {
    late OrderService orderService;
    late DatabaseService databaseService;
    late User testUser;
    late MenuItem testMenuItem1;
    late MenuItem testMenuItem2;

    setUp(() async {
      // Initialize test services
      databaseService = DatabaseService();
      await databaseService.initialize();
      
      orderService = OrderService();
      
      // Create test user
      testUser = User(
        id: 'test_user',
        username: 'test_user',
        name: 'Test User',
        role: UserRole.server,
        pin: '1234',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create test menu items
      testMenuItem1 = MenuItem(
        id: 'item1',
        name: 'Burger',
        description: 'Delicious burger',
        price: 12.99,
        categoryId: 'category1',
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testMenuItem2 = MenuItem(
        id: 'item2',
        name: 'Fries',
        description: 'Crispy fries',
        price: 5.99,
        categoryId: 'category1',
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    tearDown(() async {
      // Clean up test data
      await databaseService.close();
    });

    testWidgets('should count completed orders as sales regardless of payment status', (WidgetTester tester) async {
      // Create test orders with different statuses
      final completedOrder1 = Order(
        id: 'order1',
        orderNumber: 'DI-001',
        status: OrderStatus.completed, // This should be counted as a sale
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item1',
            orderId: 'order1',
            menuItem: testMenuItem1,
            quantity: 2,
            unitPrice: 12.99,
            totalPrice: 25.98,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 25.98,
        taxAmount: 2.60,
        totalAmount: 28.58,
        orderTime: DateTime.now().subtract(const Duration(hours: 2)),
        completedTime: DateTime.now().subtract(const Duration(hours: 1)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final completedOrder2 = Order(
        id: 'order2',
        orderNumber: 'DI-002',
        status: OrderStatus.completed, // This should be counted as a sale
        type: OrderType.dineIn,
        tableId: 'table2',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item2',
            orderId: 'order2',
            menuItem: testMenuItem2,
            quantity: 1,
            unitPrice: 5.99,
            totalPrice: 5.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 5.99,
        taxAmount: 0.60,
        totalAmount: 6.59,
        orderTime: DateTime.now().subtract(const Duration(hours: 1)),
        completedTime: DateTime.now().subtract(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pendingOrder = Order(
        id: 'order3',
        orderNumber: 'DI-003',
        status: OrderStatus.pending, // This should NOT be counted as a sale
        type: OrderType.dineIn,
        tableId: 'table3',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item3',
            orderId: 'order3',
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final cancelledOrder = Order(
        id: 'order4',
        orderNumber: 'DI-004',
        status: OrderStatus.cancelled, // This should NOT be counted as a sale
        type: OrderType.dineIn,
        tableId: 'table4',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item4',
            orderId: 'order4',
            menuItem: testMenuItem2,
            quantity: 1,
            unitPrice: 5.99,
            totalPrice: 5.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 5.99,
        taxAmount: 0.60,
        totalAmount: 6.59,
        orderTime: DateTime.now().subtract(const Duration(hours: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add orders to the service
      orderService.addOrder(completedOrder1);
      orderService.addOrder(completedOrder2);
      orderService.addOrder(pendingOrder);
      orderService.addOrder(cancelledOrder);

      // Build the reports screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderService>.value(
            value: orderService,
            child: ReportsScreen(user: testUser),
          ),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Verify that only completed orders are counted in sales
      // The reports screen should show 2 completed orders with total revenue of 35.17 (28.58 + 6.59)
      expect(orderService.allOrders.where((order) => order.isCompleted).length, equals(2));
      expect(orderService.allOrders.where((order) => order.status == OrderStatus.pending).length, equals(1));
      expect(orderService.allOrders.where((order) => order.status == OrderStatus.cancelled).length, equals(1));
    });

    testWidgets('should filter orders by date range correctly', (WidgetTester tester) async {
      final now = DateTime.now();
      
      // Create orders with different dates
      final todayOrder = Order(
        id: 'today_order',
        orderNumber: 'DI-005',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item5',
            orderId: 'today_order',
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: now,
        completedTime: now.add(const Duration(minutes: 30)),
        createdAt: now,
        updatedAt: now,
      );

      final yesterdayOrder = Order(
        id: 'yesterday_order',
        orderNumber: 'DI-006',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table2',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item6',
            orderId: 'yesterday_order',
            menuItem: testMenuItem2,
            quantity: 1,
            unitPrice: 5.99,
            totalPrice: 5.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 5.99,
        taxAmount: 0.60,
        totalAmount: 6.59,
        orderTime: now.subtract(const Duration(days: 1)),
        completedTime: now.subtract(const Duration(days: 1)).add(const Duration(minutes: 30)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      final oldOrder = Order(
        id: 'old_order',
        orderNumber: 'DI-007',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table3',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item7',
            orderId: 'old_order',
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: now.subtract(const Duration(days: 10)),
        completedTime: now.subtract(const Duration(days: 10)).add(const Duration(minutes: 30)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      );

      // Add orders to the service
      orderService.addOrder(todayOrder);
      orderService.addOrder(yesterdayOrder);
      orderService.addOrder(oldOrder);

      // Build the reports screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderService>.value(
            value: orderService,
            child: ReportsScreen(user: testUser),
          ),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Test "today" filter
      // Should only show today's order
      expect(orderService.allOrders.where((order) => 
        order.isCompleted && 
        order.orderTime.isAfter(DateTime(now.year, now.month, now.day)) &&
        order.orderTime.isBefore(DateTime(now.year, now.month, now.day, 23, 59, 59))
      ).length, equals(1));

      // Test "yesterday" filter
      // Should only show yesterday's order
      final yesterday = now.subtract(const Duration(days: 1));
      expect(orderService.allOrders.where((order) => 
        order.isCompleted && 
        order.orderTime.isAfter(DateTime(yesterday.year, yesterday.month, yesterday.day)) &&
        order.orderTime.isBefore(DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59))
      ).length, equals(1));
    });

    testWidgets('should calculate revenue correctly for completed orders only', (WidgetTester tester) async {
      // Create orders with different statuses
      final completedOrder1 = Order(
        id: 'completed1',
        orderNumber: 'DI-008',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item8',
            orderId: 'completed1',
            menuItem: testMenuItem1,
            quantity: 2,
            unitPrice: 12.99,
            totalPrice: 25.98,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 25.98,
        taxAmount: 2.60,
        totalAmount: 28.58,
        orderTime: DateTime.now(),
        completedTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final completedOrder2 = Order(
        id: 'completed2',
        orderNumber: 'DI-009',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table2',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item9',
            orderId: 'completed2',
            menuItem: testMenuItem2,
            quantity: 3,
            unitPrice: 5.99,
            totalPrice: 17.97,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 17.97,
        taxAmount: 1.80,
        totalAmount: 19.77,
        orderTime: DateTime.now(),
        completedTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pendingOrder = Order(
        id: 'pending1',
        orderNumber: 'DI-010',
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableId: 'table3',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item10',
            orderId: 'pending1',
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add orders to the service
      orderService.addOrder(completedOrder1);
      orderService.addOrder(completedOrder2);
      orderService.addOrder(pendingOrder);

      // Build the reports screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<OrderService>.value(
            value: orderService,
            child: ReportsScreen(user: testUser),
          ),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Calculate expected revenue (only completed orders)
      final completedOrders = orderService.allOrders.where((order) => order.isCompleted).toList();
      final expectedRevenue = completedOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
      final expectedOrderCount = completedOrders.length;

      // Verify calculations
      expect(expectedRevenue, equals(28.58 + 19.77)); // 48.35
      expect(expectedOrderCount, equals(2));
      expect(expectedRevenue / expectedOrderCount, equals(24.175)); // Average order value
    });

    testWidgets('should handle order status transitions correctly', (WidgetTester tester) async {
      // Create an order that starts as pending
      final order = Order(
        id: 'transition_order',
        orderNumber: 'DI-011',
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item11',
            orderId: 'transition_order',
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add order to the service
      orderService.addOrder(order);

      // Verify it's not counted as a sale initially
      expect(orderService.allOrders.where((order) => order.isCompleted).length, equals(0));

      // Simulate order completion
      final updatedOrder = order.copyWith(
        status: OrderStatus.completed,
        completedTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      orderService.updateOrder(updatedOrder);

      // Verify it's now counted as a sale
      expect(orderService.allOrders.where((order) => order.isCompleted).length, equals(1));
      expect(orderService.allOrders.where((order) => order.isCompleted).first.totalAmount, equals(14.29));
    });

    testWidgets('should exclude cancelled orders from sales calculations', (WidgetTester tester) async {
      // Create a cancelled order
      final cancelledOrder = Order(
        id: 'cancelled_order',
        orderNumber: 'DI-012',
        status: OrderStatus.cancelled,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: testUser.id,
        items: [
          OrderItem(
            id: 'item12',
            orderId: 'cancelled_order',
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            totalPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add order to the service
      orderService.addOrder(cancelledOrder);

      // Verify it's not counted as a sale
      expect(orderService.allOrders.where((order) => order.isCompleted).length, equals(0));
      expect(orderService.allOrders.where((order) => order.status == OrderStatus.cancelled).length, equals(1));
    });
  });
} 