import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';

void main() {
  group('Reporting Logic Tests', () {
    late MenuItem testMenuItem1;
    late MenuItem testMenuItem2;

    setUp(() {
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

    test('should count completed orders as sales regardless of payment status', () {
      // Create test orders with different statuses
      final completedOrder1 = Order(
        id: 'order1',
        orderNumber: 'DI-001',
        status: OrderStatus.completed, // This should be counted as a sale
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 2,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem2,
            quantity: 1,
            unitPrice: 5.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem2,
            quantity: 1,
            unitPrice: 5.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 5.99,
        taxAmount: 0.60,
        totalAmount: 6.59,
        orderTime: DateTime.now().subtract(const Duration(hours: 3)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create a list of all orders
      final allOrders = [completedOrder1, completedOrder2, pendingOrder, cancelledOrder];

      // Filter to get only completed orders (sales)
      final completedOrders = allOrders.where((order) => order.isCompleted).toList();
      final pendingOrders = allOrders.where((order) => order.status == OrderStatus.pending).toList();
      final cancelledOrders = allOrders.where((order) => order.status == OrderStatus.cancelled).toList();

      // Verify that only completed orders are counted as sales
      expect(completedOrders.length, equals(2), reason: 'Should have 2 completed orders');
      expect(pendingOrders.length, equals(1), reason: 'Should have 1 pending order');
      expect(cancelledOrders.length, equals(1), reason: 'Should have 1 cancelled order');

      // Calculate total revenue from completed orders only
      final totalRevenue = completedOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
      expect(totalRevenue, closeTo(36.13, 0.01), reason: 'Total revenue should be calculated dynamically');

      // Verify individual order amounts
      expect(completedOrder1.totalAmount, closeTo(29.36, 0.01));
      expect(completedOrder2.totalAmount, closeTo(6.77, 0.01));
    });

    test('should filter orders by date range correctly', () {
      final now = DateTime.now();
      
      // Create orders with different dates
      final todayOrder = Order(
        id: 'today_order',
        orderNumber: 'DI-005',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem2,
            quantity: 1,
            unitPrice: 5.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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

      final allOrders = [todayOrder, yesterdayOrder, oldOrder];

      // Test "today" filter
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final todayOrders = allOrders.where((order) => 
        order.isCompleted && 
        order.orderTime.isAfter(todayStart) &&
        order.orderTime.isBefore(todayEnd)
      ).toList();

      expect(todayOrders.length, equals(1), reason: 'Should have 1 order from today');
      expect(todayOrders.first.orderNumber, equals('DI-005'));

      // Test "yesterday" filter
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final yesterdayEnd = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
      final yesterdayOrders = allOrders.where((order) => 
        order.isCompleted && 
        order.orderTime.isAfter(yesterdayStart) &&
        order.orderTime.isBefore(yesterdayEnd)
      ).toList();

      expect(yesterdayOrders.length, equals(1), reason: 'Should have 1 order from yesterday');
      expect(yesterdayOrders.first.orderNumber, equals('DI-006'));

      // Test "week" filter (last 7 days)
      final weekStart = now.subtract(const Duration(days: 7));
      final weekOrders = allOrders.where((order) => 
        order.isCompleted && 
        order.orderTime.isAfter(weekStart) &&
        order.orderTime.isBefore(now)
      ).toList();

      expect(weekOrders.length, equals(1), reason: 'Should have 1 order from the last week (today)');
    });

    test('should calculate revenue correctly for completed orders only', () {
      // Create orders with different statuses
      final completedOrder1 = Order(
        id: 'completed1',
        orderNumber: 'DI-008',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 2,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem2,
            quantity: 3,
            unitPrice: 5.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
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
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final allOrders = [completedOrder1, completedOrder2, pendingOrder];

      // Calculate expected revenue (only completed orders)
      final completedOrders = allOrders.where((order) => order.isCompleted).toList();
      final expectedRevenue = completedOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
      final expectedOrderCount = completedOrders.length;
      final expectedAverageOrderValue = expectedRevenue / expectedOrderCount;

      // Verify calculations
      expect(expectedRevenue, closeTo(49.66, 0.01), reason: 'Total revenue should be calculated dynamically');
      expect(expectedOrderCount, equals(2), reason: 'Should have 2 completed orders');
      expect(expectedAverageOrderValue, closeTo(24.83, 0.01), reason: 'Average order value should be calculated dynamically');

      // Verify that pending orders are not included in revenue
      final pendingOrders = allOrders.where((order) => order.status == OrderStatus.pending).toList();
      expect(pendingOrders.length, equals(1), reason: 'Should have 1 pending order');
      expect(pendingOrders.first.totalAmount, closeTo(14.68, 0.01), reason: 'Pending order should have amount calculated dynamically');
    });

    test('should handle order status transitions correctly', () {
      // Create an order that starts as pending
      final order = Order(
        id: 'transition_order',
        orderNumber: 'DI-011',
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify it's not counted as a sale initially
      expect(order.isCompleted, isFalse, reason: 'Pending order should not be completed');
      expect(order.totalAmount, closeTo(14.68, 0.01), reason: 'Order should have correct total amount');

      // Simulate order completion
      final updatedOrder = order.copyWith(
        status: OrderStatus.completed,
        completedTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify it's now counted as a sale
      expect(updatedOrder.isCompleted, isTrue, reason: 'Completed order should be marked as completed');
      expect(updatedOrder.totalAmount, closeTo(14.68, 0.01), reason: 'Completed order should have correct total amount');
      expect(updatedOrder.completedTime, isNotNull, reason: 'Completed order should have completion time');
    });

    test('should exclude cancelled orders from sales calculations', () {
      // Create a cancelled order
      final cancelledOrder = Order(
        id: 'cancelled_order',
        orderNumber: 'DI-012',
        status: OrderStatus.cancelled,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1,
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify it's not counted as a sale
      expect(cancelledOrder.isCompleted, isFalse, reason: 'Cancelled order should not be completed');
      expect(cancelledOrder.status, equals(OrderStatus.cancelled), reason: 'Order should be cancelled');
      expect(cancelledOrder.totalAmount, closeTo(14.68, 0.01), reason: 'Cancelled order should have correct total amount');

      // Test with a list of orders
      final allOrders = [cancelledOrder];
      final completedOrders = allOrders.where((order) => order.isCompleted).toList();
      final cancelledOrders = allOrders.where((order) => order.status == OrderStatus.cancelled).toList();

      expect(completedOrders.length, equals(0), reason: 'Should have 0 completed orders');
      expect(cancelledOrders.length, equals(1), reason: 'Should have 1 cancelled order');
    });

    test('should calculate popular items correctly from completed orders', () {
      // Create orders with different items
      final completedOrder1 = Order(
        id: 'order1',
        orderNumber: 'DI-013',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table1',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1, // Burger
            quantity: 2,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
          ),
          OrderItem(
            menuItem: testMenuItem2, // Fries
            quantity: 1,
            unitPrice: 5.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 31.97,
        taxAmount: 3.20,
        totalAmount: 35.17,
        orderTime: DateTime.now(),
        completedTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final completedOrder2 = Order(
        id: 'order2',
        orderNumber: 'DI-014',
        status: OrderStatus.completed,
        type: OrderType.dineIn,
        tableId: 'table2',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem1, // Burger
            quantity: 1,
            unitPrice: 12.99,
            isAvailable: true,
            sentToKitchen: true,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 12.99,
        taxAmount: 1.30,
        totalAmount: 14.29,
        orderTime: DateTime.now(),
        completedTime: DateTime.now().add(const Duration(minutes: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final pendingOrder = Order(
        id: 'order3',
        orderNumber: 'DI-015',
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableId: 'table3',
        userId: 'user1',
        items: [
          OrderItem(
            menuItem: testMenuItem2, // Fries
            quantity: 3,
            unitPrice: 5.99,
            isAvailable: true,
            sentToKitchen: false,
            createdAt: DateTime.now(),
          ),
        ],
        subtotal: 17.97,
        taxAmount: 1.80,
        totalAmount: 19.77,
        orderTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final allOrders = [completedOrder1, completedOrder2, pendingOrder];

      // Calculate popular items from completed orders only
      final completedOrders = allOrders.where((order) => order.isCompleted).toList();
      final itemCounts = <String, int>{};
      
      for (final order in completedOrders) {
        for (final item in order.items) {
          final itemName = item.menuItem.name;
          itemCounts[itemName] = (itemCounts[itemName] ?? 0) + item.quantity;
        }
      }

      // Verify popular items calculation
      expect(itemCounts['Burger'], equals(3), reason: 'Should have 3 burgers sold');
      expect(itemCounts['Fries'], equals(1), reason: 'Should have 1 fries sold');
      expect(itemCounts.length, equals(2), reason: 'Should have 2 different items');

      // Verify that pending orders are not included
      expect(itemCounts['Fries'], equals(1), reason: 'Pending order should not be included in popular items');
    });
  });
} 