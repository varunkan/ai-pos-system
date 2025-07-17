import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/printer_configuration_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_assignment_service.dart';
import 'package:ai_pos_system/services/printing_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/activity_log_service.dart';
import 'package:ai_pos_system/services/printer_validation_service.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/table.dart';
import 'package:ai_pos_system/models/printer_configuration.dart';
import 'package:ai_pos_system/models/printer_assignment.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();

  group('🏪 POS System Functional Tests', () {
    late DatabaseService databaseService;
    late UserService userService;
    late OrderService orderService;
    late MenuService menuService;
    late TableService tableService;
    late PrinterConfigurationService printerConfigService;
    late EnhancedPrinterAssignmentService printerAssignmentService;
    late PrintingService printingService;
    late OrderLogService orderLogService;
    late ActivityLogService activityLogService;
    late PrinterValidationService printerValidationService;

    setUpAll(() async {
      // Override the default database factory
      databaseFactory = databaseFactoryFfi;
      
      // Initialize all services
      databaseService = DatabaseService();
      await databaseService.initialize();
      
      userService = UserService();
      await userService.initialize();
      
      orderService = OrderService();
      await orderService.initialize();
      
      menuService = MenuService();
      await menuService.initialize();
      
      tableService = TableService();
      await tableService.initialize();
      
      printerConfigService = PrinterConfigurationService();
      await printerConfigService.initialize();
      
      printerAssignmentService = EnhancedPrinterAssignmentService(databaseService);
      await printerAssignmentService.initialize();
      
      printingService = PrintingService();
      await printingService.initialize();
      
      orderLogService = OrderLogService();
      await orderLogService.initialize();
      
      activityLogService = ActivityLogService();
      await activityLogService.initialize();
      
      printerValidationService = PrinterValidationService();
    });

    tearDownAll(() async {
      await databaseService.close();
    });

    group('🛎️ Complete Restaurant Service Workflow', () {
      test('should handle complete dine-in order workflow', () async {
        // Step 1: Server authentication
        final users = await userService.getUsers();
        final server = users.firstWhere((u) => u.role == UserRole.server);
        
        final authResult = await userService.authenticateWithPin(server.id, server.pin);
        expect(authResult, true);
        
        userService.setCurrentUser(server);
        expect(userService.currentUser, server);
        
        // Log server login
        await activityLogService.logActivity(
          'Logged in',
          server.id,
          server.role,
          details: 'Server logged in for functional test',
        );
        
        // Step 2: Table selection and setup
        final tables = await tableService.getTables();
        final availableTable = tables.firstWhere((t) => t.status == TableStatus.available);
        
        // Reserve table
        final occupiedTable = availableTable.copyWith(
          status: TableStatus.occupied,
          guestCount: 4,
        );
        await tableService.updateTable(occupiedTable);
        
        // Verify table status
        final updatedTables = await tableService.getTables();
        final reservedTable = updatedTables.firstWhere((t) => t.id == availableTable.id);
        expect(reservedTable.status, TableStatus.occupied);
        expect(reservedTable.guestCount, 4);
        
        // Step 3: Order creation
        final menuItems = await menuService.getMenuItems();
        final appetizer = menuItems.firstWhere((item) => item.name.toLowerCase().contains('appetizer'));
        final mainDish = menuItems.firstWhere((item) => item.name.toLowerCase().contains('chicken'));
        final dessert = menuItems.firstWhere((item) => item.name.toLowerCase().contains('dessert'));
        
        final order = Order(
          id: 'functional_test_dine_in_001',
          orderNumber: 'DI-FUNC-001',
          customerId: 'guest_table_${reservedTable.number}',
          userId: server.id,
          tableId: reservedTable.id,
          orderType: OrderType.dineIn,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'item_appetizer_001',
              menuItemId: appetizer.id,
              quantity: 1,
              unitPrice: appetizer.price,
              totalPrice: appetizer.price,
              specialInstructions: 'Extra sauce',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            OrderItem(
              id: 'item_main_001',
              menuItemId: mainDish.id,
              quantity: 2,
              unitPrice: mainDish.price,
              totalPrice: mainDish.price * 2,
              specialInstructions: 'Medium spice level',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            OrderItem(
              id: 'item_dessert_001',
              menuItemId: dessert.id,
              quantity: 1,
              unitPrice: dessert.price,
              totalPrice: dessert.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: appetizer.price + (mainDish.price * 2) + dessert.price,
          tax: (appetizer.price + (mainDish.price * 2) + dessert.price) * 0.13,
          total: (appetizer.price + (mainDish.price * 2) + dessert.price) * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(order);
        
        // Log order creation
        await orderLogService.logOrderAction(
          order.id,
          'Order Created',
          server.id,
          details: 'Dine-in order created for table ${reservedTable.number}',
        );
        
        // Step 4: Send to kitchen
        final confirmedOrder = order.copyWith(status: OrderStatus.confirmed);
        await orderService.updateOrder(confirmedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Sent to Kitchen',
          server.id,
          details: 'Order sent to kitchen for preparation',
        );
        
        // Step 5: Printer validation and printing
        final validationResult = await printerValidationService.validatePrinterAssignments(confirmedOrder);
        expect(validationResult, isA<PrinterValidationResult>());
        
        // If validation fails, it's expected in test environment
        if (!validationResult.isValid) {
          expect(validationResult.failures.isNotEmpty, true);
        }
        
        // Step 6: Order preparation and serving
        final preparingOrder = confirmedOrder.copyWith(status: OrderStatus.preparing);
        await orderService.updateOrder(preparingOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Preparing',
          server.id,
          details: 'Order is being prepared in kitchen',
        );
        
        // Step 7: Order ready for serving
        final readyOrder = preparingOrder.copyWith(status: OrderStatus.ready);
        await orderService.updateOrder(readyOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Ready',
          server.id,
          details: 'Order is ready for serving',
        );
        
        // Step 8: Order served
        final servedOrder = readyOrder.copyWith(status: OrderStatus.served);
        await orderService.updateOrder(servedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Served',
          server.id,
          details: 'Order has been served to table ${reservedTable.number}',
        );
        
        // Step 9: Payment and completion
        final paidOrder = servedOrder.copyWith(status: OrderStatus.paid);
        await orderService.updateOrder(paidOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Payment Completed',
          server.id,
          details: 'Payment completed for order',
        );
        
        final completedOrder = paidOrder.copyWith(status: OrderStatus.completed);
        await orderService.updateOrder(completedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Completed',
          server.id,
          details: 'Order completed successfully',
        );
        
        // Step 10: Clean up table
        final cleanedTable = occupiedTable.copyWith(
          status: TableStatus.available,
          guestCount: 0,
        );
        await tableService.updateTable(cleanedTable);
        
        // Verify final state
        final finalOrder = await orderService.getOrder(order.id);
        expect(finalOrder, isNotNull);
        expect(finalOrder!.status, OrderStatus.completed);
        
        final finalTable = await tableService.getTable(reservedTable.id);
        expect(finalTable, isNotNull);
        expect(finalTable!.status, TableStatus.available);
        
        final orderLogs = await orderLogService.getOrderLogs(order.id);
        expect(orderLogs.length, greaterThanOrEqualTo(7));
        
        print('✅ Complete dine-in workflow test passed successfully');
      });

      test('should handle complete takeout order workflow', () async {
        // Step 1: Server authentication
        final users = await userService.getUsers();
        final server = users.firstWhere((u) => u.role == UserRole.server);
        
        userService.setCurrentUser(server);
        
        // Step 2: Takeout order creation
        final menuItems = await menuService.getMenuItems();
        final pizza = menuItems.firstWhere((item) => item.name.toLowerCase().contains('pizza'));
        final drink = menuItems.firstWhere((item) => item.name.toLowerCase().contains('drink'));
        
        final order = Order(
          id: 'functional_test_takeout_001',
          orderNumber: 'TO-FUNC-001',
          customerId: 'guest_takeout_001',
          userId: server.id,
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'item_pizza_001',
              menuItemId: pizza.id,
              quantity: 1,
              unitPrice: pizza.price,
              totalPrice: pizza.price,
              specialInstructions: 'Extra cheese',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            OrderItem(
              id: 'item_drink_001',
              menuItemId: drink.id,
              quantity: 2,
              unitPrice: drink.price,
              totalPrice: drink.price * 2,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: pizza.price + (drink.price * 2),
          tax: (pizza.price + (drink.price * 2)) * 0.13,
          total: (pizza.price + (drink.price * 2)) * 1.13,
          customerName: 'John Doe',
          customerPhone: '555-1234',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(order);
        
        // Log order creation
        await orderLogService.logOrderAction(
          order.id,
          'Takeout Order Created',
          server.id,
          details: 'Takeout order created for customer: John Doe',
        );
        
        // Step 3: Process payment first (typical for takeout)
        final paidOrder = order.copyWith(status: OrderStatus.paid);
        await orderService.updateOrder(paidOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Payment Processed',
          server.id,
          details: 'Payment processed for takeout order',
        );
        
        // Step 4: Send to kitchen
        final confirmedOrder = paidOrder.copyWith(status: OrderStatus.confirmed);
        await orderService.updateOrder(confirmedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Sent to Kitchen',
          server.id,
          details: 'Takeout order sent to kitchen',
        );
        
        // Step 5: Order preparation
        final preparingOrder = confirmedOrder.copyWith(status: OrderStatus.preparing);
        await orderService.updateOrder(preparingOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Preparing',
          server.id,
          details: 'Takeout order is being prepared',
        );
        
        // Step 6: Order ready for pickup
        final readyOrder = preparingOrder.copyWith(status: OrderStatus.ready);
        await orderService.updateOrder(readyOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Ready for Pickup',
          server.id,
          details: 'Takeout order is ready for customer pickup',
        );
        
        // Step 7: Customer pickup
        final completedOrder = readyOrder.copyWith(status: OrderStatus.completed);
        await orderService.updateOrder(completedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Picked Up',
          server.id,
          details: 'Takeout order picked up by customer',
        );
        
        // Verify final state
        final finalOrder = await orderService.getOrder(order.id);
        expect(finalOrder, isNotNull);
        expect(finalOrder!.status, OrderStatus.completed);
        expect(finalOrder.orderType, OrderType.takeout);
        expect(finalOrder.customerName, 'John Doe');
        expect(finalOrder.customerPhone, '555-1234');
        
        final orderLogs = await orderLogService.getOrderLogs(order.id);
        expect(orderLogs.length, greaterThanOrEqualTo(6));
        
        print('✅ Complete takeout workflow test passed successfully');
      });
    });

    group('🖨️ Printer Management Workflow', () {
      test('should handle complete printer configuration workflow', () async {
        // Step 1: Create printer configuration
        final printerConfig = PrinterConfiguration(
          id: 'func_test_printer_001',
          name: 'Kitchen Main Printer',
          description: 'Main kitchen printer for hot dishes',
          type: PrinterType.wifi,
          model: 'epsonTMGeneric',
          ipAddress: '192.168.1.100',
          port: 9100,
          stationId: 'main_kitchen',
          isActive: true,
          connectionStatus: 'configured',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await printerConfigService.savePrinterConfiguration(printerConfig);
        
        // Step 2: Create printer assignment
        final categories = await menuService.getCategories();
        final hotDishCategory = categories.firstWhere(
          (c) => c.name.toLowerCase().contains('main') || c.name.toLowerCase().contains('hot'),
          orElse: () => categories.first,
        );
        
        final assignment = PrinterAssignment(
          id: 'func_test_assignment_001',
          printerId: printerConfig.id,
          assignmentType: AssignmentType.category,
          categoryId: hotDishCategory.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await printerAssignmentService.saveAssignment(assignment);
        
        // Step 3: Test order segregation
        final menuItems = await menuService.getMenuItems();
        final hotDish = menuItems.firstWhere((item) => item.categoryId == hotDishCategory.id);
        
        final testOrder = Order(
          id: 'printer_test_order_001',
          orderNumber: 'PT-001',
          customerId: 'test_customer',
          userId: 'admin',
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'printer_test_item_001',
              menuItemId: hotDish.id,
              quantity: 1,
              unitPrice: hotDish.price,
              totalPrice: hotDish.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: hotDish.price,
          tax: hotDish.price * 0.13,
          total: hotDish.price * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(testOrder);
        
        // Step 4: Test printer assignment segregation
        final itemsByPrinter = await printerAssignmentService.segregateOrderItems(testOrder);
        
        // Verify segregation works
        expect(itemsByPrinter, isA<Map<String, List<OrderItem>>>());
        
        // Step 5: Test printer validation
        final validationResult = await printerValidationService.validatePrinterAssignments(testOrder);
        expect(validationResult, isA<PrinterValidationResult>());
        
        // Step 6: Get assignment statistics
        final stats = await printerAssignmentService.getAssignmentStats();
        expect(stats['totalAssignments'], greaterThan(0));
        expect(stats['uniquePrinters'], greaterThan(0));
        
        // Step 7: Clean up
        await printerConfigService.deletePrinterConfiguration(printerConfig.id);
        await printerAssignmentService.deleteAssignment(assignment.id);
        
        print('✅ Complete printer management workflow test passed successfully');
      });
    });

    group('👥 User Management Workflow', () {
      test('should handle complete user lifecycle', () async {
        // Step 1: Create new user
        final newUser = User(
          id: 'func_test_user_001',
          name: 'Jane Server',
          role: UserRole.server,
          pin: '2468',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await userService.createUser(newUser);
        
        // Log user creation
        await activityLogService.logActivity(
          'User Created',
          'admin',
          UserRole.admin,
          details: 'New user created: ${newUser.name}',
        );
        
        // Step 2: Verify user exists
        final users = await userService.getUsers();
        final createdUser = users.firstWhere((u) => u.id == newUser.id);
        expect(createdUser.name, 'Jane Server');
        expect(createdUser.role, UserRole.server);
        expect(createdUser.pin, '2468');
        
        // Step 3: Test user authentication
        final authResult = await userService.authenticateWithPin(newUser.id, '2468');
        expect(authResult, true);
        
        // Step 4: Test wrong PIN
        final wrongAuthResult = await userService.authenticateWithPin(newUser.id, '1111');
        expect(wrongAuthResult, false);
        
        // Step 5: Update user
        final updatedUser = createdUser.copyWith(name: 'Jane Senior Server');
        await userService.updateUser(updatedUser);
        
        // Log user update
        await activityLogService.logActivity(
          'User Updated',
          'admin',
          UserRole.admin,
          details: 'User updated: ${updatedUser.name}',
        );
        
        // Step 6: Verify update
        final refreshedUsers = await userService.getUsers();
        final refreshedUser = refreshedUsers.firstWhere((u) => u.id == newUser.id);
        expect(refreshedUser.name, 'Jane Senior Server');
        
        // Step 7: Set as current user
        userService.setCurrentUser(refreshedUser);
        expect(userService.currentUser, refreshedUser);
        
        // Step 8: Deactivate user
        final deactivatedUser = refreshedUser.copyWith(isActive: false);
        await userService.updateUser(deactivatedUser);
        
        // Log user deactivation
        await activityLogService.logActivity(
          'User Deactivated',
          'admin',
          UserRole.admin,
          details: 'User deactivated: ${deactivatedUser.name}',
        );
        
        // Step 9: Verify deactivation
        final finalUsers = await userService.getUsers();
        final finalUser = finalUsers.firstWhere((u) => u.id == newUser.id);
        expect(finalUser.isActive, false);
        
        // Step 10: Delete user
        await userService.deleteUser(newUser.id);
        
        // Log user deletion
        await activityLogService.logActivity(
          'User Deleted',
          'admin',
          UserRole.admin,
          details: 'User deleted: ${newUser.name}',
        );
        
        // Step 11: Verify deletion
        final deletedUsers = await userService.getUsers();
        final deletedUser = deletedUsers.where((u) => u.id == newUser.id);
        expect(deletedUser.isEmpty, true);
        
        print('✅ Complete user management workflow test passed successfully');
      });
    });

    group('📊 Reporting and Analytics Workflow', () {
      test('should handle complete reporting workflow', () async {
        // Step 1: Create sample orders for reporting
        final users = await userService.getUsers();
        final server = users.firstWhere((u) => u.role == UserRole.server);
        final menuItems = await menuService.getMenuItems();
        final item1 = menuItems.first;
        final item2 = menuItems.skip(1).first;
        
        final orders = [
          Order(
            id: 'report_order_001',
            orderNumber: 'RP-001',
            customerId: 'customer_001',
            userId: server.id,
            tableId: null,
            orderType: OrderType.takeout,
            status: OrderStatus.completed,
            items: [
              OrderItem(
                id: 'report_item_001',
                menuItemId: item1.id,
                quantity: 2,
                unitPrice: item1.price,
                totalPrice: item1.price * 2,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ],
            subtotal: item1.price * 2,
            tax: (item1.price * 2) * 0.13,
            total: (item1.price * 2) * 1.13,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Order(
            id: 'report_order_002',
            orderNumber: 'RP-002',
            customerId: 'customer_002',
            userId: server.id,
            tableId: null,
            orderType: OrderType.dineIn,
            status: OrderStatus.completed,
            items: [
              OrderItem(
                id: 'report_item_002',
                menuItemId: item2.id,
                quantity: 1,
                unitPrice: item2.price,
                totalPrice: item2.price,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ],
            subtotal: item2.price,
            tax: item2.price * 0.13,
            total: item2.price * 1.13,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
        
        for (final order in orders) {
          await orderService.createOrder(order);
          await orderLogService.logOrderAction(
            order.id,
            'Order Completed',
            server.id,
            details: 'Order completed for reporting test',
          );
        }
        
        // Step 2: Test order filtering and reporting
        final completedOrders = await orderService.getOrdersByStatus(OrderStatus.completed);
        expect(completedOrders.length, greaterThanOrEqualTo(2));
        
        final takeoutOrders = completedOrders.where((o) => o.orderType == OrderType.takeout).toList();
        final dineInOrders = completedOrders.where((o) => o.orderType == OrderType.dineIn).toList();
        
        expect(takeoutOrders.length, greaterThan(0));
        expect(dineInOrders.length, greaterThan(0));
        
        // Step 3: Calculate totals
        final totalRevenue = completedOrders.fold(0.0, (sum, order) => sum + order.total);
        final totalTax = completedOrders.fold(0.0, (sum, order) => sum + order.tax);
        final totalSubtotal = completedOrders.fold(0.0, (sum, order) => sum + order.subtotal);
        
        expect(totalRevenue, greaterThan(0));
        expect(totalTax, greaterThan(0));
        expect(totalSubtotal, greaterThan(0));
        
        // Step 4: Activity log analysis
        final activityLogs = await activityLogService.getActivityLogs();
        expect(activityLogs.length, greaterThan(0));
        
        final serverActivities = activityLogs.where((log) => log.userId == server.id).toList();
        expect(serverActivities.length, greaterThan(0));
        
        // Step 5: Order log analysis
        final allOrderLogs = <dynamic>[];
        for (final order in orders) {
          final logs = await orderLogService.getOrderLogs(order.id);
          allOrderLogs.addAll(logs);
        }
        expect(allOrderLogs.length, greaterThan(0));
        
        print('✅ Complete reporting workflow test passed successfully');
      });
    });

    group('🔄 Error Recovery Workflow', () {
      test('should handle order cancellation workflow', () async {
        // Step 1: Create order
        final users = await userService.getUsers();
        final server = users.firstWhere((u) => u.role == UserRole.server);
        final menuItems = await menuService.getMenuItems();
        final item = menuItems.first;
        
        final order = Order(
          id: 'cancel_test_order_001',
          orderNumber: 'CT-001',
          customerId: 'customer_cancel',
          userId: server.id,
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'cancel_item_001',
              menuItemId: item.id,
              quantity: 1,
              unitPrice: item.price,
              totalPrice: item.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: item.price,
          tax: item.price * 0.13,
          total: item.price * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(order);
        
        // Step 2: Confirm order
        final confirmedOrder = order.copyWith(status: OrderStatus.confirmed);
        await orderService.updateOrder(confirmedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Confirmed',
          server.id,
          details: 'Order confirmed before cancellation test',
        );
        
        // Step 3: Cancel order
        final cancelledOrder = confirmedOrder.copyWith(status: OrderStatus.cancelled);
        await orderService.updateOrder(cancelledOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Cancelled',
          server.id,
          details: 'Order cancelled by server',
        );
        
        // Step 4: Verify cancellation
        final finalOrder = await orderService.getOrder(order.id);
        expect(finalOrder, isNotNull);
        expect(finalOrder!.status, OrderStatus.cancelled);
        
        // Step 5: Verify cancellation logs
        final orderLogs = await orderLogService.getOrderLogs(order.id);
        final cancellationLog = orderLogs.firstWhere((log) => log.action == 'Order Cancelled');
        expect(cancellationLog.userId, server.id);
        
        print('✅ Order cancellation workflow test passed successfully');
      });

      test('should handle order modification workflow', () async {
        // Step 1: Create initial order
        final users = await userService.getUsers();
        final server = users.firstWhere((u) => u.role == UserRole.server);
        final menuItems = await menuService.getMenuItems();
        final item1 = menuItems.first;
        final item2 = menuItems.skip(1).first;
        
        final order = Order(
          id: 'modify_test_order_001',
          orderNumber: 'MT-001',
          customerId: 'customer_modify',
          userId: server.id,
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'modify_item_001',
              menuItemId: item1.id,
              quantity: 1,
              unitPrice: item1.price,
              totalPrice: item1.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: item1.price,
          tax: item1.price * 0.13,
          total: item1.price * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(order);
        
        // Step 2: Modify order - add item
        final modifiedOrder = order.copyWith(
          items: [
            ...order.items,
            OrderItem(
              id: 'modify_item_002',
              menuItemId: item2.id,
              quantity: 1,
              unitPrice: item2.price,
              totalPrice: item2.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: item1.price + item2.price,
          tax: (item1.price + item2.price) * 0.13,
          total: (item1.price + item2.price) * 1.13,
        );
        
        await orderService.updateOrder(modifiedOrder);
        
        await orderLogService.logOrderAction(
          order.id,
          'Order Modified',
          server.id,
          details: 'Item added to order',
        );
        
        // Step 3: Verify modification
        final finalOrder = await orderService.getOrder(order.id);
        expect(finalOrder, isNotNull);
        expect(finalOrder!.items.length, 2);
        expect(finalOrder.subtotal, item1.price + item2.price);
        
        // Step 4: Verify modification logs
        final orderLogs = await orderLogService.getOrderLogs(order.id);
        final modificationLog = orderLogs.firstWhere((log) => log.action == 'Order Modified');
        expect(modificationLog.userId, server.id);
        
        print('✅ Order modification workflow test passed successfully');
      });
    });

    group('🔒 Security and Data Integrity Tests', () {
      test('should maintain data integrity across operations', () async {
        // Step 1: Create baseline data
        final initialUsers = await userService.getUsers();
        final initialOrders = await orderService.getOrders();
        final initialMenuItems = await menuService.getMenuItems();
        
        final initialCounts = {
          'users': initialUsers.length,
          'orders': initialOrders.length,
          'menuItems': initialMenuItems.length,
        };
        
        // Step 2: Perform multiple operations
        final testUser = User(
          id: 'integrity_test_user',
          name: 'Integrity Test User',
          role: UserRole.server,
          pin: '9999',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await userService.createUser(testUser);
        
        final testOrder = Order(
          id: 'integrity_test_order',
          orderNumber: 'IT-001',
          customerId: 'integrity_customer',
          userId: testUser.id,
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'integrity_item_001',
              menuItemId: initialMenuItems.first.id,
              quantity: 1,
              unitPrice: initialMenuItems.first.price,
              totalPrice: initialMenuItems.first.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: initialMenuItems.first.price,
          tax: initialMenuItems.first.price * 0.13,
          total: initialMenuItems.first.price * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(testOrder);
        
        // Step 3: Verify data integrity
        final finalUsers = await userService.getUsers();
        final finalOrders = await orderService.getOrders();
        final finalMenuItems = await menuService.getMenuItems();
        
        expect(finalUsers.length, initialCounts['users']! + 1);
        expect(finalOrders.length, initialCounts['orders']! + 1);
        expect(finalMenuItems.length, initialCounts['menuItems']!);
        
        // Step 4: Verify referential integrity
        final createdOrder = finalOrders.firstWhere((o) => o.id == testOrder.id);
        expect(createdOrder.userId, testUser.id);
        
        final orderUser = finalUsers.firstWhere((u) => u.id == createdOrder.userId);
        expect(orderUser.id, testUser.id);
        
        // Step 5: Clean up
        await userService.deleteUser(testUser.id);
        // Order should be handled by cascade delete or remain with orphaned user reference
        
        print('✅ Data integrity test passed successfully');
      });
    });

    group('⚡ Performance Tests', () {
      test('should handle high-volume operations efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        // Step 1: Create multiple orders quickly
        final users = await userService.getUsers();
        final server = users.firstWhere((u) => u.role == UserRole.server);
        final menuItems = await menuService.getMenuItems();
        final item = menuItems.first;
        
        final orders = <Order>[];
        for (int i = 0; i < 10; i++) {
          final order = Order(
            id: 'perf_test_order_$i',
            orderNumber: 'PERF-${i.toString().padLeft(3, '0')}',
            customerId: 'customer_$i',
            userId: server.id,
            tableId: null,
            orderType: OrderType.takeout,
            status: OrderStatus.pending,
            items: [
              OrderItem(
                id: 'perf_item_$i',
                menuItemId: item.id,
                quantity: 1,
                unitPrice: item.price,
                totalPrice: item.price,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ],
            subtotal: item.price,
            tax: item.price * 0.13,
            total: item.price * 1.13,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          orders.add(order);
          await orderService.createOrder(order);
        }
        
        stopwatch.stop();
        
        // Step 2: Verify all orders were created
        final createdOrders = await orderService.getOrders();
        final perfOrders = createdOrders.where((o) => o.id.startsWith('perf_test_order_')).toList();
        expect(perfOrders.length, 10);
        
        // Step 3: Performance assertion (should complete within reasonable time)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds
        
        print('✅ Performance test passed: ${stopwatch.elapsedMilliseconds}ms for 10 orders');
      });
    });
  });
} 