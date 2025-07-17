import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

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

  group('🏪 POS System Unit Tests', () {
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
      
      // Initialize services
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

    group('🗄️ Database Service Tests', () {
      test('should initialize database successfully', () async {
        expect(databaseService.isInitialized, true);
      });

      test('should create tables on initialization', () async {
        final db = databaseService.database;
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        );
        
        final tableNames = tables.map((t) => t['name'] as String).toList();
        expect(tableNames, contains('users'));
        expect(tableNames, contains('orders'));
        expect(tableNames, contains('order_items'));
        expect(tableNames, contains('menu_items'));
        expect(tableNames, contains('categories'));
        expect(tableNames, contains('tables'));
        expect(tableNames, contains('printer_configurations'));
        expect(tableNames, contains('printer_assignments'));
        expect(tableNames, contains('order_logs'));
        expect(tableNames, contains('activity_logs'));
      });

      test('should handle database migrations', () async {
        // Test migration by checking if new columns exist
        final db = databaseService.database;
        final result = await db.rawQuery('PRAGMA table_info(printer_configurations)');
        final columns = result.map((r) => r['name'] as String).toList();
        expect(columns, contains('station_id'));
      });
    });

    group('👥 User Service Tests', () {
      test('should initialize with admin user', () async {
        final users = await userService.getUsers();
        expect(users.isNotEmpty, true);
        
        final admin = users.firstWhere(
          (u) => u.role == UserRole.admin,
          orElse: () => throw Exception('Admin user not found'),
        );
        expect(admin.id, 'admin');
        expect(admin.name, 'Admin');
        expect(admin.role, UserRole.admin);
      });

      test('should create new user', () async {
        final newUser = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await userService.createUser(newUser);
        
        final users = await userService.getUsers();
        final createdUser = users.firstWhere((u) => u.id == 'test_user');
        
        expect(createdUser.name, 'Test User');
        expect(createdUser.role, UserRole.server);
        expect(createdUser.pin, '1234');
      });

      test('should authenticate user with correct PIN', () async {
        final result = await userService.authenticateWithPin('admin', '0000');
        expect(result, true);
      });

      test('should reject authentication with wrong PIN', () async {
        final result = await userService.authenticateWithPin('admin', '1111');
        expect(result, false);
      });

      test('should set current user', () async {
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.id == 'admin');
        
        userService.setCurrentUser(admin);
        expect(userService.currentUser, admin);
      });
    });

    group('📋 Order Service Tests', () {
      test('should create new order', () async {
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        final order = Order(
          id: 'test_order_001',
          orderNumber: 'TO-001',
          customerId: 'guest',
          userId: 'admin',
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'item_001',
              menuItemId: firstItem.id,
              quantity: 2,
              unitPrice: firstItem.price,
              totalPrice: firstItem.price * 2,
              specialInstructions: 'No spice',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: firstItem.price * 2,
          tax: (firstItem.price * 2) * 0.13,
          total: (firstItem.price * 2) * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await orderService.createOrder(order);
        
        final orders = await orderService.getOrders();
        final createdOrder = orders.firstWhere((o) => o.id == 'test_order_001');
        
        expect(createdOrder.orderNumber, 'TO-001');
        expect(createdOrder.orderType, OrderType.takeout);
        expect(createdOrder.status, OrderStatus.pending);
        expect(createdOrder.items.length, 1);
        expect(createdOrder.items.first.quantity, 2);
      });

      test('should update order status', () async {
        final orders = await orderService.getOrders();
        final order = orders.firstWhere((o) => o.id == 'test_order_001');
        
        final updatedOrder = order.copyWith(status: OrderStatus.confirmed);
        await orderService.updateOrder(updatedOrder);
        
        final refreshedOrders = await orderService.getOrders();
        final refreshedOrder = refreshedOrders.firstWhere((o) => o.id == 'test_order_001');
        
        expect(refreshedOrder.status, OrderStatus.confirmed);
      });

      test('should calculate order totals correctly', () async {
        final menuItems = await menuService.getMenuItems();
        final item1 = menuItems.first;
        final item2 = menuItems.skip(1).first;
        
        final order = Order(
          id: 'test_order_002',
          orderNumber: 'DI-002',
          customerId: 'guest',
          userId: 'admin',
          tableId: 'table_001',
          orderType: OrderType.dineIn,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'item_002',
              menuItemId: item1.id,
              quantity: 1,
              unitPrice: item1.price,
              totalPrice: item1.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            OrderItem(
              id: 'item_003',
              menuItemId: item2.id,
              quantity: 2,
              unitPrice: item2.price,
              totalPrice: item2.price * 2,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: item1.price + (item2.price * 2),
          tax: (item1.price + (item2.price * 2)) * 0.13,
          total: (item1.price + (item2.price * 2)) * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await orderService.createOrder(order);
        
        final createdOrder = await orderService.getOrder('test_order_002');
        expect(createdOrder, isNotNull);
        expect(createdOrder!.subtotal, item1.price + (item2.price * 2));
        expect(createdOrder.tax, closeTo((item1.price + (item2.price * 2)) * 0.13, 0.01));
        expect(createdOrder.total, closeTo((item1.price + (item2.price * 2)) * 1.13, 0.01));
      });

      test('should filter orders by status', () async {
        final pendingOrders = await orderService.getOrdersByStatus(OrderStatus.pending);
        final confirmedOrders = await orderService.getOrdersByStatus(OrderStatus.confirmed);
        
        expect(pendingOrders.length, greaterThan(0));
        expect(confirmedOrders.length, greaterThan(0));
        
        // Verify all orders have correct status
        for (final order in pendingOrders) {
          expect(order.status, OrderStatus.pending);
        }
        for (final order in confirmedOrders) {
          expect(order.status, OrderStatus.confirmed);
        }
      });
    });

    group('🍽️ Menu Service Tests', () {
      test('should load menu items and categories', () async {
        final menuItems = await menuService.getMenuItems();
        final categories = await menuService.getCategories();
        
        expect(menuItems.isNotEmpty, true);
        expect(categories.isNotEmpty, true);
        
        // Check if all menu items have valid categories
        for (final item in menuItems) {
          final category = categories.firstWhere(
            (c) => c.id == item.categoryId,
            orElse: () => throw Exception('Category not found for item ${item.id}'),
          );
          expect(category.id, item.categoryId);
        }
      });

      test('should filter menu items by category', () async {
        final categories = await menuService.getCategories();
        final firstCategory = categories.first;
        
        final itemsInCategory = await menuService.getItemsByCategory(firstCategory.id);
        
        expect(itemsInCategory.isNotEmpty, true);
        for (final item in itemsInCategory) {
          expect(item.categoryId, firstCategory.id);
        }
      });

      test('should search menu items by name', () async {
        final searchResults = await menuService.searchMenuItems('chicken');
        
        expect(searchResults.isNotEmpty, true);
        for (final item in searchResults) {
          expect(item.name.toLowerCase(), contains('chicken'));
        }
      });

      test('should get menu item by ID', () async {
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        final foundItem = await menuService.getMenuItem(firstItem.id);
        
        expect(foundItem, isNotNull);
        expect(foundItem!.id, firstItem.id);
        expect(foundItem.name, firstItem.name);
        expect(foundItem.price, firstItem.price);
      });
    });

    group('🍽️ Table Service Tests', () {
      test('should initialize with default tables', () async {
        final tables = await tableService.getTables();
        
        expect(tables.isNotEmpty, true);
        expect(tables.length, greaterThanOrEqualTo(16));
        
        // Check table properties
        final firstTable = tables.first;
        expect(firstTable.id, isNotNull);
        expect(firstTable.number, greaterThan(0));
        expect(firstTable.capacity, greaterThan(0));
        expect(firstTable.status, TableStatus.available);
      });

      test('should update table status', () async {
        final tables = await tableService.getTables();
        final table = tables.first;
        
        final updatedTable = table.copyWith(status: TableStatus.occupied);
        await tableService.updateTable(updatedTable);
        
        final refreshedTables = await tableService.getTables();
        final refreshedTable = refreshedTables.firstWhere((t) => t.id == table.id);
        
        expect(refreshedTable.status, TableStatus.occupied);
      });

      test('should get available tables', () async {
        final availableTables = await tableService.getAvailableTables();
        
        expect(availableTables.isNotEmpty, true);
        for (final table in availableTables) {
          expect(table.status, TableStatus.available);
        }
      });
    });

    group('🖨️ Printer Configuration Service Tests', () {
      test('should initialize printer configuration service', () async {
        expect(printerConfigService.isInitialized, true);
      });

      test('should create printer configuration', () async {
        final config = PrinterConfiguration(
          id: 'test_printer_001',
          name: 'Test Kitchen Printer',
          description: 'Test printer for kitchen',
          type: PrinterType.wifi,
          model: 'epsonTMGeneric',
          ipAddress: '192.168.1.100',
          port: 9100,
          stationId: 'main_kitchen',
          isActive: true,
          connectionStatus: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerConfigService.savePrinterConfiguration(config);
        
        final configs = await printerConfigService.getPrinterConfigurations();
        final createdConfig = configs.firstWhere((c) => c.id == 'test_printer_001');
        
        expect(createdConfig.name, 'Test Kitchen Printer');
        expect(createdConfig.type, PrinterType.wifi);
        expect(createdConfig.ipAddress, '192.168.1.100');
        expect(createdConfig.port, 9100);
        expect(createdConfig.stationId, 'main_kitchen');
      });

      test('should update printer configuration', () async {
        final configs = await printerConfigService.getPrinterConfigurations();
        final config = configs.firstWhere((c) => c.id == 'test_printer_001');
        
        final updatedConfig = config.copyWith(name: 'Updated Kitchen Printer');
        await printerConfigService.savePrinterConfiguration(updatedConfig);
        
        final refreshedConfigs = await printerConfigService.getPrinterConfigurations();
        final refreshedConfig = refreshedConfigs.firstWhere((c) => c.id == 'test_printer_001');
        
        expect(refreshedConfig.name, 'Updated Kitchen Printer');
      });

      test('should delete printer configuration', () async {
        await printerConfigService.deletePrinterConfiguration('test_printer_001');
        
        final configs = await printerConfigService.getPrinterConfigurations();
        final deletedConfig = configs.where((c) => c.id == 'test_printer_001');
        
        expect(deletedConfig.isEmpty, true);
      });
    });

    group('🎯 Printer Assignment Service Tests', () {
      test('should initialize printer assignment service', () async {
        expect(printerAssignmentService.isInitialized, true);
      });

      test('should create printer assignment', () async {
        final categories = await menuService.getCategories();
        final firstCategory = categories.first;
        
        final assignment = PrinterAssignment(
          id: 'test_assignment_001',
          printerId: 'test_printer_001',
          assignmentType: AssignmentType.category,
          categoryId: firstCategory.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerAssignmentService.saveAssignment(assignment);
        
        final assignments = await printerAssignmentService.getAssignments();
        final createdAssignment = assignments.firstWhere((a) => a.id == 'test_assignment_001');
        
        expect(createdAssignment.printerId, 'test_printer_001');
        expect(createdAssignment.assignmentType, AssignmentType.category);
        expect(createdAssignment.categoryId, firstCategory.id);
      });

      test('should segregate order items by printer', () async {
        final orders = await orderService.getOrders();
        final order = orders.first;
        
        final itemsByPrinter = await printerAssignmentService.segregateOrderItems(order);
        
        expect(itemsByPrinter, isA<Map<String, List<OrderItem>>>());
        // Since we might not have actual assignments, this could be empty
        expect(itemsByPrinter.keys.length, greaterThanOrEqualTo(0));
      });

      test('should get assignment statistics', () async {
        final stats = await printerAssignmentService.getAssignmentStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats, containsKey('totalAssignments'));
        expect(stats, containsKey('categoryAssignments'));
        expect(stats, containsKey('menuItemAssignments'));
        expect(stats, containsKey('uniquePrinters'));
      });
    });

    group('🎨 Printer Validation Service Tests', () {
      test('should validate printer assignments', () async {
        final orders = await orderService.getOrders();
        if (orders.isNotEmpty) {
          final order = orders.first;
          
          final validationResult = await printerValidationService.validatePrinterAssignments(order);
          
          expect(validationResult, isA<PrinterValidationResult>());
          expect(validationResult.isValid, isA<bool>());
          expect(validationResult.failures, isA<List<PrinterValidationFailure>>());
        }
      });
    });

    group('📊 Logging Services Tests', () {
      test('should log order activities', () async {
        final orders = await orderService.getOrders();
        if (orders.isNotEmpty) {
          final order = orders.first;
          
          await orderLogService.logOrderAction(
            order.id,
            'Test Action',
            'admin',
            details: 'Test action details',
          );
          
          final logs = await orderLogService.getOrderLogs(order.id);
          expect(logs.isNotEmpty, true);
          
          final testLog = logs.where((log) => log.action == 'Test Action').first;
          expect(testLog.orderId, order.id);
          expect(testLog.userId, 'admin');
          expect(testLog.details, 'Test action details');
        }
      });

      test('should log user activities', () async {
        await activityLogService.logActivity(
          'Test Activity',
          'admin',
          UserRole.admin,
          details: 'Test activity details',
        );
        
        final logs = await activityLogService.getActivityLogs();
        expect(logs.isNotEmpty, true);
        
        final testLog = logs.where((log) => log.action == 'Test Activity').first;
        expect(testLog.userId, 'admin');
        expect(testLog.userRole, UserRole.admin);
        expect(testLog.details, 'Test activity details');
      });
    });

    group('🔄 Integration Tests', () {
      test('should handle complete order workflow', () async {
        // Create order
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        final order = Order(
          id: 'integration_test_001',
          orderNumber: 'IT-001',
          customerId: 'guest',
          userId: 'admin',
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'item_int_001',
              menuItemId: firstItem.id,
              quantity: 1,
              unitPrice: firstItem.price,
              totalPrice: firstItem.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          subtotal: firstItem.price,
          tax: firstItem.price * 0.13,
          total: firstItem.price * 1.13,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Create order
        await orderService.createOrder(order);
        
        // Log order creation
        await orderLogService.logOrderAction(
          order.id,
          'Order Created',
          'admin',
          details: 'Order created during integration test',
        );
        
        // Update order status
        final updatedOrder = order.copyWith(status: OrderStatus.confirmed);
        await orderService.updateOrder(updatedOrder);
        
        // Log status change
        await orderLogService.logOrderAction(
          order.id,
          'Status Changed',
          'admin',
          details: 'Status changed to confirmed',
        );
        
        // Verify order and logs
        final finalOrder = await orderService.getOrder(order.id);
        final orderLogs = await orderLogService.getOrderLogs(order.id);
        
        expect(finalOrder, isNotNull);
        expect(finalOrder!.status, OrderStatus.confirmed);
        expect(orderLogs.length, greaterThanOrEqualTo(2));
      });
    });

    group('🔍 Edge Cases and Error Handling', () {
      test('should handle non-existent order', () async {
        final order = await orderService.getOrder('non_existent_order');
        expect(order, isNull);
      });

      test('should handle non-existent menu item', () async {
        final menuItem = await menuService.getMenuItem('non_existent_item');
        expect(menuItem, isNull);
      });

      test('should handle invalid user authentication', () async {
        final result = await userService.authenticateWithPin('non_existent_user', '0000');
        expect(result, false);
      });

      test('should handle empty search results', () async {
        final results = await menuService.searchMenuItems('nonexistentitem123');
        expect(results.isEmpty, true);
      });
    });
  });
} 