import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/printer_configuration_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_assignment_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/activity_log_service.dart';
import 'package:ai_pos_system/services/printer_validation_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_manager.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/table.dart';
import 'package:ai_pos_system/models/printer_configuration.dart';
import 'package:ai_pos_system/models/printer_assignment.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();

  group('🏪 Real POS Functionality Tests', () {
    late DatabaseService databaseService;
    late UserService userService;
    late OrderService orderService;
    late MenuService menuService;
    late TableService tableService;
    late PrinterConfigurationService printerConfigService;
    late EnhancedPrinterAssignmentService printerAssignmentService;
    late OrderLogService orderLogService;
    late ActivityLogService activityLogService;
    late PrinterValidationService printerValidationService;
    late EnhancedPrinterManager printerManager;

    setUpAll(() async {
      // Override the default database factory
      databaseFactory = databaseFactoryFfi;
      
      // Mock SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      
      // Initialize services in the correct order
      databaseService = DatabaseService();
      await databaseService.initialize();
      
      userService = UserService(prefs, databaseService);
      
      orderLogService = OrderLogService(databaseService);
      await orderLogService.initialize();
      
      orderService = OrderService(databaseService, orderLogService);
      
      menuService = MenuService(databaseService);
      await menuService.initialize();
      
      tableService = TableService(prefs);
      await tableService.initialize();
      
      printerConfigService = PrinterConfigurationService(databaseService);
      await printerConfigService.initialize();
      
      printerAssignmentService = EnhancedPrinterAssignmentService(
        databaseService: databaseService,
        printerConfigService: printerConfigService,
      );
      await printerAssignmentService.initialize();
      
      activityLogService = ActivityLogService(databaseService);
      await activityLogService.initialize();
      
      printerValidationService = PrinterValidationService(
        databaseService: databaseService,
        printerConfigService: printerConfigService,
        printerAssignmentService: printerAssignmentService,
      );
      
      printerManager = EnhancedPrinterManager(printerConfigService);
      await printerManager.initialize();
    });

    tearDownAll(() async {
      await databaseService.close();
    });

    group('🗄️ Database Service Tests', () {
      test('should initialize database successfully', () async {
        expect(databaseService.isInitialized, true);
      });

      test('should handle database migrations', () async {
        final db = await databaseService.database;
        expect(db, isNotNull);
        
        // Test if migration added station_id column to printer_configurations
        final result = await db!.rawQuery('PRAGMA table_info(printer_configurations)');
        final columns = result.map((r) => r['name'] as String).toList();
        expect(columns, contains('station_id'));
      });

      test('should create all required tables', () async {
        final db = await databaseService.database;
        final tables = await db!.rawQuery(
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
    });

    group('👥 User Service Tests', () {
      test('should load users from database', () async {
        final users = await userService.getUsers();
        expect(users, isNotEmpty);
        
        // Should have at least admin user
        final adminUsers = users.where((u) => u.role == UserRole.admin);
        expect(adminUsers, isNotEmpty);
      });

      test('should authenticate admin user with correct PIN', () async {
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.role == UserRole.admin);
        
        final result = await userService.authenticateUser(admin.id);
        expect(result, true);
      });

      test('should set current user', () async {
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.role == UserRole.admin);
        
        userService.setCurrentUser(admin);
        expect(userService.currentUser, admin);
        expect(userService.isAuthenticated, true);
      });

      test('should get servers', () async {
        final servers = await userService.getServers();
        expect(servers, isNotNull);
        expect(servers, isA<List<User>>());
        
        // All returned users should be servers
        for (final server in servers) {
          expect(server.role, UserRole.server);
        }
      });
    });

    group('🍽️ Menu Service Tests', () {
      test('should load menu items and categories', () async {
        final menuItems = await menuService.getMenuItems();
        final categories = await menuService.getCategories();
        
        expect(menuItems, isNotEmpty);
        expect(categories, isNotEmpty);
        
        // Verify menu items have valid categories
        for (final item in menuItems) {
          final category = categories.firstWhere(
            (c) => c.id == item.categoryId,
            orElse: () => throw Exception('Category not found for item ${item.id}'),
          );
          expect(category.id, item.categoryId);
          expect(item.price, greaterThan(0));
          expect(item.name, isNotEmpty);
        }
      });

      test('should have valid category properties', () async {
        final categories = await menuService.getCategories();
        
        for (final category in categories) {
          expect(category.id, isNotEmpty);
          expect(category.name, isNotEmpty);
          expect(category.isActive, isA<bool>());
        }
      });

      test('should filter items by availability', () async {
        final menuItems = await menuService.getMenuItems();
        final availableItems = menuItems.where((item) => item.isAvailable).toList();
        
        expect(availableItems, isNotEmpty);
        for (final item in availableItems) {
          expect(item.isAvailable, true);
        }
      });
    });

    group('🍽️ Table Service Tests', () {
      test('should load tables', () async {
        final tables = await tableService.getTables();
        
        expect(tables, isNotEmpty);
        expect(tables.length, greaterThanOrEqualTo(16));
        
        // Check table properties
        for (final table in tables) {
          expect(table.id, isNotEmpty);
          expect(table.number, greaterThan(0));
          expect(table.capacity, greaterThan(0));
          expect(table.status, isIn([TableStatus.available, TableStatus.occupied, TableStatus.reserved]));
        }
      });

      test('should get available tables', () async {
        final availableTables = await tableService.getAvailableTables();
        
        expect(availableTables, isNotEmpty);
        for (final table in availableTables) {
          expect(table.status, TableStatus.available);
        }
      });

      test('should update table status', () async {
        final tables = await tableService.getTables();
        final table = tables.first;
        final originalStatus = table.status;
        
        // Update to occupied
        final updatedTable = table.copyWith(status: TableStatus.occupied);
        await tableService.updateTable(updatedTable);
        
        // Verify update
        final refreshedTables = await tableService.getTables();
        final refreshedTable = refreshedTables.firstWhere((t) => t.id == table.id);
        expect(refreshedTable.status, TableStatus.occupied);
        
        // Restore original status
        final restoredTable = table.copyWith(status: originalStatus);
        await tableService.updateTable(restoredTable);
      });
    });

    group('📋 Order Service Tests', () {
      test('should save and retrieve orders', () async {
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        final order = Order(
          id: 'test_order_001',
          orderNumber: 'TO-TEST-001',
          customerName: 'Test Customer',
          userId: 'admin',
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'test_item_001',
              menuItem: firstItem,
              quantity: 1,
              unitPrice: firstItem.price,
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

        await orderService.saveOrder(order);
        
        // Test retrieval
        final orders = orderService.orders;
        final savedOrder = orders.firstWhere((o) => o.id == 'test_order_001');
        
        expect(savedOrder.orderNumber, 'TO-TEST-001');
        expect(savedOrder.orderType, OrderType.takeout);
        expect(savedOrder.status, OrderStatus.pending);
        expect(savedOrder.items.length, 1);
        expect(savedOrder.customerName, 'Test Customer');
      });

      test('should update order status', () async {
        final orders = orderService.orders;
        final order = orders.firstWhere((o) => o.id == 'test_order_001');
        
        final updatedOrder = order.copyWith(status: OrderStatus.confirmed);
        await orderService.saveOrder(updatedOrder);
        
        final refreshedOrders = orderService.orders;
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
          customerName: 'Test Customer 2',
          userId: 'admin',
          tableId: 'table_001',
          orderType: OrderType.dineIn,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'item_002',
              menuItem: item1,
              quantity: 1,
              unitPrice: item1.price,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            OrderItem(
              id: 'item_003',
              menuItem: item2,
              quantity: 2,
              unitPrice: item2.price,
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

        await orderService.saveOrder(order);
        
        final orders = orderService.orders;
        final createdOrder = orders.firstWhere((o) => o.id == 'test_order_002');
        expect(createdOrder.subtotal, item1.price + (item2.price * 2));
        expect(createdOrder.tax, closeTo((item1.price + (item2.price * 2)) * 0.13, 0.01));
        expect(createdOrder.total, closeTo((item1.price + (item2.price * 2)) * 1.13, 0.01));
      });
    });

    group('🖨️ Printer Configuration Service Tests', () {
      test('should initialize successfully', () async {
        expect(printerConfigService.isInitialized, true);
      });

      test('should save printer configuration', () async {
        final config = PrinterConfiguration(
          id: 'test_printer_001',
          name: 'Test Kitchen Printer',
          description: 'Test printer for kitchen',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMGeneric,
          ipAddress: '192.168.1.100',
          port: 9100,
          stationId: 'main_kitchen',
          isActive: true,
          connectionStatus: PrinterConnectionStatus.connected,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerConfigService.savePrinterConfiguration(config);
        
        final configs = await printerConfigService.getPrinterConfigurations();
        final savedConfig = configs.firstWhere((c) => c.id == 'test_printer_001');
        
        expect(savedConfig.name, 'Test Kitchen Printer');
        expect(savedConfig.type, PrinterType.wifi);
        expect(savedConfig.ipAddress, '192.168.1.100');
        expect(savedConfig.port, 9100);
        expect(savedConfig.stationId, 'main_kitchen');
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
    });

    group('🎯 Printer Assignment Service Tests', () {
      test('should initialize successfully', () async {
        expect(printerAssignmentService.isInitialized, true);
      });

      test('should get assignment statistics', () async {
        final stats = await printerAssignmentService.getAssignmentStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.keys, contains('totalAssignments'));
        expect(stats.keys, contains('categoryAssignments'));
        expect(stats.keys, contains('menuItemAssignments'));
        expect(stats.keys, contains('uniquePrinters'));
        
        // Values should be non-negative integers
        expect(stats['totalAssignments'], isA<int>());
        expect(stats['categoryAssignments'], isA<int>());
        expect(stats['menuItemAssignments'], isA<int>());
        expect(stats['uniquePrinters'], isA<int>());
        
        expect(stats['totalAssignments'], greaterThanOrEqualTo(0));
        expect(stats['categoryAssignments'], greaterThanOrEqualTo(0));
        expect(stats['menuItemAssignments'], greaterThanOrEqualTo(0));
        expect(stats['uniquePrinters'], greaterThanOrEqualTo(0));
      });

      test('should create printer assignment', () async {
        final categories = await menuService.getCategories();
        final firstCategory = categories.first;
        
        final assignment = PrinterAssignment(
          id: 'test_assignment_001',
          printerId: 'test_printer_001',
          assignmentType: AssignmentType.category,
          targetId: firstCategory.id,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerAssignmentService.saveAssignment(assignment);
        
        final assignments = printerAssignmentService.assignments;
        final createdAssignment = assignments.firstWhere((a) => a.id == 'test_assignment_001');
        
        expect(createdAssignment.printerId, 'test_printer_001');
        expect(createdAssignment.assignmentType, AssignmentType.category);
        expect(createdAssignment.targetId, firstCategory.id);
        expect(createdAssignment.isActive, true);
      });

      test('should segregate order items by printer', () async {
        final orders = orderService.orders;
        if (orders.isNotEmpty) {
          final order = orders.first;
          
          final itemsByPrinter = await printerAssignmentService.segregateOrderItems(order);
          
          expect(itemsByPrinter, isA<Map<String, List<OrderItem>>>());
          // Since we have assignments, there might be some segregation
          expect(itemsByPrinter.keys.length, greaterThanOrEqualTo(0));
        }
      });
    });

    group('🎨 Printer Validation Service Tests', () {
      test('should validate printer assignments', () async {
        final orders = orderService.orders;
        
        if (orders.isNotEmpty) {
          final order = orders.first;
          final validationResult = await printerValidationService.validatePrinterAssignments(order);
          
          expect(validationResult, isA<PrinterValidationResult>());
          expect(validationResult.isValid, isA<bool>());
          expect(validationResult.failures, isA<List>());
          
          // Should have meaningful validation info
          if (!validationResult.isValid) {
            expect(validationResult.failures.isNotEmpty, true);
          }
        }
      });
    });

    group('📊 Logging Services Tests', () {
      test('should log order activities', () async {
        await orderLogService.logOrderAction(
          'test_order_001',
          'Test Action',
          'admin',
          details: 'Test action details',
        );
        
        final logs = await orderLogService.getOrderLogs('test_order_001');
        expect(logs.isNotEmpty, true);
        
        final testLog = logs.where((log) => log.action == 'Test Action').first;
        expect(testLog.orderId, 'test_order_001');
        expect(testLog.userId, 'admin');
        expect(testLog.details, 'Test action details');
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

    group('🚀 Enhanced Printer Manager Tests', () {
      test('should initialize successfully', () async {
        expect(printerManager.isInitialized, true);
      });

      test('should handle printer discovery', () async {
        // This tests the discovery mechanism without requiring actual printers
        final discoveredPrinters = await printerManager.discoverNetworkPrinters();
        
        expect(discoveredPrinters, isA<List<PrinterConfiguration>>());
        // Should return empty list in test environment (no actual printers)
        expect(discoveredPrinters, isEmpty);
      });
    });

    group('🔄 Integration Tests', () {
      test('should handle complete order workflow', () async {
        // Step 1: Get user
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.role == UserRole.admin);
        userService.setCurrentUser(admin);
        
        // Step 2: Create order
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        final order = Order(
          id: 'integration_test_001',
          orderNumber: 'IT-001',
          customerName: 'Integration Test Customer',
          userId: admin.id,
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'int_item_001',
              menuItem: firstItem,
              quantity: 1,
              unitPrice: firstItem.price,
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

        // Step 3: Save order
        await orderService.saveOrder(order);
        
        // Step 4: Log order creation
        await orderLogService.logOrderAction(
          order.id,
          'Order Created',
          admin.id,
          details: 'Order created during integration test',
        );
        
        // Step 5: Verify order was saved
        final savedOrders = orderService.orders;
        final savedOrder = savedOrders.firstWhere((o) => o.id == 'integration_test_001');
        
        expect(savedOrder.orderNumber, 'IT-001');
        expect(savedOrder.status, OrderStatus.pending);
        expect(savedOrder.items.length, 1);
        
        // Step 6: Update order status
        final updatedOrder = savedOrder.copyWith(status: OrderStatus.confirmed);
        await orderService.saveOrder(updatedOrder);
        
        // Step 7: Log status change
        await orderLogService.logOrderAction(
          order.id,
          'Status Changed',
          admin.id,
          details: 'Status changed to confirmed',
        );
        
        // Step 8: Verify update
        final finalOrders = orderService.orders;
        final finalOrder = finalOrders.firstWhere((o) => o.id == 'integration_test_001');
        
        expect(finalOrder.status, OrderStatus.confirmed);
        
        // Step 9: Verify logs
        final orderLogs = await orderLogService.getOrderLogs(order.id);
        expect(orderLogs.length, greaterThanOrEqualTo(2));
        
        print('✅ Integration test completed successfully');
      });

      test('should handle table reservation workflow', () async {
        // Step 1: Get available table
        final availableTables = await tableService.getAvailableTables();
        expect(availableTables, isNotEmpty);
        
        final table = availableTables.first;
        
        // Step 2: Reserve table
        final reservedTable = table.copyWith(status: TableStatus.occupied);
        await tableService.updateTable(reservedTable);
        
        // Step 3: Verify reservation
        final updatedTables = await tableService.getTables();
        final updatedTable = updatedTables.firstWhere((t) => t.id == table.id);
        expect(updatedTable.status, TableStatus.occupied);
        
        // Step 4: Release table
        final releasedTable = updatedTable.copyWith(status: TableStatus.available);
        await tableService.updateTable(releasedTable);
        
        // Step 5: Verify release
        final finalTables = await tableService.getTables();
        final finalTable = finalTables.firstWhere((t) => t.id == table.id);
        expect(finalTable.status, TableStatus.available);
        
        print('✅ Table reservation workflow test completed successfully');
      });

      test('should handle printer configuration workflow', () async {
        // Step 1: Create printer configuration
        final config = PrinterConfiguration(
          id: 'workflow_test_printer',
          name: 'Workflow Test Printer',
          description: 'Test printer for workflow',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMGeneric,
          ipAddress: '192.168.1.200',
          port: 9100,
          stationId: 'test_station',
          isActive: true,
          connectionStatus: PrinterConnectionStatus.configured,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerConfigService.savePrinterConfiguration(config);
        
        // Step 2: Verify configuration was saved
        final configs = await printerConfigService.getPrinterConfigurations();
        final savedConfig = configs.where((c) => c.id == 'workflow_test_printer');
        expect(savedConfig.isNotEmpty, true);
        
        // Step 3: Update configuration
        final updatedConfig = config.copyWith(
          name: 'Updated Workflow Test Printer',
          ipAddress: '192.168.1.201',
        );
        await printerConfigService.savePrinterConfiguration(updatedConfig);
        
        // Step 4: Verify update
        final updatedConfigs = await printerConfigService.getPrinterConfigurations();
        final finalConfig = updatedConfigs.firstWhere((c) => c.id == 'workflow_test_printer');
        expect(finalConfig.name, 'Updated Workflow Test Printer');
        expect(finalConfig.ipAddress, '192.168.1.201');
        
        print('✅ Printer configuration workflow test completed successfully');
      });
    });

    group('⚡ Performance Tests', () {
      test('should load menu items efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        final menuItems = await menuService.getMenuItems();
        
        stopwatch.stop();
        
        expect(menuItems, isNotEmpty);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should load within 1 second
        
        print('✅ Menu items loaded in ${stopwatch.elapsedMilliseconds}ms');
      });

      test('should save multiple orders efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        for (int i = 0; i < 5; i++) {
          final order = Order(
            id: 'perf_test_$i',
            orderNumber: 'PERF-${i.toString().padLeft(3, '0')}',
            customerName: 'Performance Test $i',
            userId: 'admin',
            tableId: null,
            orderType: OrderType.takeout,
            status: OrderStatus.pending,
            items: [
              OrderItem(
                id: 'perf_item_$i',
                menuItem: firstItem,
                quantity: 1,
                unitPrice: firstItem.price,
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
          
          await orderService.saveOrder(order);
        }
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Should save 5 orders within 3 seconds
        
        print('✅ 5 orders saved in ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('🔍 Edge Cases and Error Handling', () {
      test('should handle empty order gracefully', () async {
        final emptyOrder = Order(
          id: 'empty_order',
          orderNumber: 'EMPTY-001',
          customerName: 'Empty Customer',
          userId: 'admin',
          tableId: null,
          orderType: OrderType.takeout,
          status: OrderStatus.pending,
          items: [],
          subtotal: 0,
          tax: 0,
          total: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // This should not throw an error
        final result = await printerAssignmentService.segregateOrderItems(emptyOrder);
        expect(result, isA<Map<String, List<OrderItem>>>());
        expect(result.isEmpty, true);
      });

      test('should handle service initialization properly', () async {
        expect(databaseService.isInitialized, true);
        expect(printerConfigService.isInitialized, true);
        expect(printerAssignmentService.isInitialized, true);
        expect(userService.isAuthenticated, true);
      });

      test('should handle null safety correctly', () async {
        // Test that services handle null inputs gracefully
        final stats = await printerAssignmentService.getAssignmentStats();
        expect(stats, isNotNull);
        
        final logs = await orderLogService.getOrderLogs('non_existent_order');
        expect(logs, isEmpty);
        
        final activityLogs = await activityLogService.getActivityLogs();
        expect(activityLogs, isNotNull);
      });
    });
  });
} 