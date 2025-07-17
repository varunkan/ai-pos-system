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
import 'package:ai_pos_system/services/printer_validation_service.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/table.dart';
import 'package:ai_pos_system/models/printer_configuration.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();

  group('🏪 Working POS System Tests', () {
    late DatabaseService databaseService;
    late UserService userService;
    late OrderService orderService;
    late MenuService menuService;
    late TableService tableService;
    late PrinterConfigurationService printerConfigService;
    late EnhancedPrinterAssignmentService printerAssignmentService;
    late PrinterValidationService printerValidationService;

    setUpAll(() async {
      // Override the default database factory
      databaseFactory = databaseFactoryFfi;
      
      // Initialize core services
      databaseService = DatabaseService();
      await databaseService.initialize();
      
      // Initialize services with proper dependencies
      userService = UserService(await databaseService.sharedPreferences, databaseService);
      orderService = OrderService(databaseService, null!); // OrderLogService will be null for tests
      menuService = MenuService(databaseService);
      tableService = TableService(await databaseService.sharedPreferences);
      printerConfigService = PrinterConfigurationService(databaseService);
      printerAssignmentService = EnhancedPrinterAssignmentService(databaseService: databaseService);
      printerValidationService = PrinterValidationService(databaseService: databaseService);
    });

    tearDownAll(() async {
      await databaseService.close();
    });

    group('🗄️ Database Service Tests', () {
      test('should initialize database successfully', () async {
        expect(databaseService.isInitialized, true);
      });

      test('should have database instance', () async {
        final db = await databaseService.database;
        expect(db, isNotNull);
      });

      test('should handle database queries', () async {
        final db = await databaseService.database;
        final result = await db!.rawQuery('SELECT 1 as test');
        expect(result, isNotEmpty);
        expect(result.first['test'], 1);
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

      test('should authenticate admin user', () async {
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.role == UserRole.admin);
        
        final result = await userService.authenticateUser(admin.id, '0000');
        expect(result, true);
      });

      test('should reject wrong PIN', () async {
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.role == UserRole.admin);
        
        final result = await userService.authenticateUser(admin.id, '9999');
        expect(result, false);
      });

      test('should set current user', () async {
        final users = await userService.getUsers();
        final admin = users.firstWhere((u) => u.role == UserRole.admin);
        
        userService.setCurrentUser(admin);
        expect(userService.currentUser, admin);
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
        }
      });

      test('should have valid menu item properties', () async {
        final menuItems = await menuService.getMenuItems();
        
        for (final item in menuItems) {
          expect(item.id, isNotEmpty);
          expect(item.name, isNotEmpty);
          expect(item.price, greaterThan(0));
          expect(item.categoryId, isNotEmpty);
        }
      });

      test('should have valid category properties', () async {
        final categories = await menuService.getCategories();
        
        for (final category in categories) {
          expect(category.id, isNotEmpty);
          expect(category.name, isNotEmpty);
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

      test('should get table by ID', () async {
        final tables = await tableService.getTables();
        final firstTable = tables.first;
        
        final foundTable = await tableService.getTable(firstTable.id);
        expect(foundTable, isNotNull);
        expect(foundTable!.id, firstTable.id);
        expect(foundTable.number, firstTable.number);
      });
    });

    group('📋 Order Service Tests', () {
      test('should load orders', () async {
        final orders = await orderService.getAllOrders();
        
        // Orders list can be empty initially
        expect(orders, isNotNull);
        expect(orders, isA<List<Order>>());
      });

      test('should get active orders', () async {
        final activeOrders = await orderService.getActiveOrders();
        
        expect(activeOrders, isNotNull);
        expect(activeOrders, isA<List<Order>>());
      });

      test('should save order', () async {
        final menuItems = await menuService.getMenuItems();
        final firstItem = menuItems.first;
        
        final order = Order(
          id: 'test_order_001',
          orderNumber: 'TO-TEST-001',
          guest: 'Test Customer',
          userId: 'admin',
          tableId: null,
          orderType: OrderType.takeOut,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'test_item_001',
              menuItem: firstItem,
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

        await orderService.saveOrder(order);
        
        final savedOrders = await orderService.getAllOrders();
        final savedOrder = savedOrders.firstWhere((o) => o.id == 'test_order_001');
        
        expect(savedOrder.orderNumber, 'TO-TEST-001');
        expect(savedOrder.orderType, OrderType.takeOut);
        expect(savedOrder.status, OrderStatus.pending);
        expect(savedOrder.items.length, 1);
      });
    });

    group('🖨️ Printer Configuration Service Tests', () {
      test('should initialize printer configuration service', () async {
        expect(printerConfigService, isNotNull);
        expect(printerConfigService.isInitialized, true);
      });

      test('should load printer configurations', () async {
        final configs = await printerConfigService.loadPrinterConfigurations();
        
        expect(configs, isNotNull);
        expect(configs, isA<List<PrinterConfiguration>>());
      });

      test('should save printer configuration', () async {
        final config = PrinterConfiguration(
          id: 'test_printer_001',
          name: 'Test Kitchen Printer',
          description: 'Test printer for kitchen',
          type: 'wifi',
          model: 'epsonTMGeneric',
          ipAddress: '192.168.1.100',
          port: 9100,
          isActive: true,
          connectionStatus: 'test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerConfigService.savePrinterConfiguration(config);
        
        final configs = await printerConfigService.loadPrinterConfigurations();
        final savedConfig = configs.where((c) => c.id == 'test_printer_001');
        
        expect(savedConfig.isNotEmpty, true);
        if (savedConfig.isNotEmpty) {
          expect(savedConfig.first.name, 'Test Kitchen Printer');
          expect(savedConfig.first.ipAddress, '192.168.1.100');
          expect(savedConfig.first.port, 9100);
        }
      });
    });

    group('🎯 Printer Assignment Service Tests', () {
      test('should initialize printer assignment service', () async {
        expect(printerAssignmentService, isNotNull);
        expect(printerAssignmentService.isInitialized, true);
      });

      test('should get assignment statistics', () async {
        final stats = await printerAssignmentService.getAssignmentStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.keys, contains('totalAssignments'));
        expect(stats.keys, contains('categoryAssignments'));
        expect(stats.keys, contains('menuItemAssignments'));
        expect(stats.keys, contains('uniquePrinters'));
      });

      test('should segregate order items', () async {
        final orders = await orderService.getAllOrders();
        
        if (orders.isNotEmpty) {
          final order = orders.first;
          final itemsByPrinter = await printerAssignmentService.segregateOrderItems(order);
          
          expect(itemsByPrinter, isA<Map<String, List<OrderItem>>>());
        }
      });
    });

    group('🎨 Printer Validation Service Tests', () {
      test('should initialize printer validation service', () async {
        expect(printerValidationService, isNotNull);
      });

      test('should validate printer assignments', () async {
        final orders = await orderService.getAllOrders();
        
        if (orders.isNotEmpty) {
          final order = orders.first;
          final validationResult = await printerValidationService.validateOrder(order);
          
          expect(validationResult, isA<PrinterValidationResult>());
          expect(validationResult.isValid, isA<bool>());
          expect(validationResult.failures, isA<List>());
        }
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
          guest: 'Integration Test Customer',
          userId: admin.id,
          tableId: null,
          orderType: OrderType.takeOut,
          status: OrderStatus.pending,
          items: [
            OrderItem(
              id: 'int_item_001',
              menuItem: firstItem,
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

        // Step 3: Save order
        await orderService.saveOrder(order);
        
        // Step 4: Verify order was saved
        final savedOrders = await orderService.getAllOrders();
        final savedOrder = savedOrders.firstWhere((o) => o.id == 'integration_test_001');
        
        expect(savedOrder.orderNumber, 'IT-001');
        expect(savedOrder.status, OrderStatus.pending);
        expect(savedOrder.items.length, 1);
        
        // Step 5: Update order status
        final updatedOrder = savedOrder.copyWith(status: OrderStatus.confirmed);
        await orderService.saveOrder(updatedOrder);
        
        // Step 6: Verify update
        final finalOrders = await orderService.getAllOrders();
        final finalOrder = finalOrders.firstWhere((o) => o.id == 'integration_test_001');
        
        expect(finalOrder.status, OrderStatus.confirmed);
        
        print('✅ Integration test completed successfully');
      });

      test('should handle table reservation workflow', () async {
        // Step 1: Get available table
        final availableTables = await tableService.getAvailableTables();
        expect(availableTables, isNotEmpty);
        
        final table = availableTables.first;
        
        // Step 2: Reserve table
        final reservedTable = table.copyWith(
          status: TableStatus.occupied,
          guestCount: 4,
        );
        await tableService.updateTable(reservedTable);
        
        // Step 3: Verify reservation
        final updatedTable = await tableService.getTable(table.id);
        expect(updatedTable, isNotNull);
        expect(updatedTable!.status, TableStatus.occupied);
        expect(updatedTable.guestCount, 4);
        
        // Step 4: Release table
        final releasedTable = updatedTable.copyWith(
          status: TableStatus.available,
          guestCount: 0,
        );
        await tableService.updateTable(releasedTable);
        
        // Step 5: Verify release
        final finalTable = await tableService.getTable(table.id);
        expect(finalTable, isNotNull);
        expect(finalTable!.status, TableStatus.available);
        expect(finalTable.guestCount, 0);
        
        print('✅ Table reservation workflow test completed successfully');
      });

      test('should handle printer configuration workflow', () async {
        // Step 1: Create printer configuration
        final config = PrinterConfiguration(
          id: 'workflow_test_printer',
          name: 'Workflow Test Printer',
          description: 'Test printer for workflow',
          type: 'wifi',
          model: 'epsonTMGeneric',
          ipAddress: '192.168.1.200',
          port: 9100,
          isActive: true,
          connectionStatus: 'configured',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await printerConfigService.savePrinterConfiguration(config);
        
        // Step 2: Verify configuration was saved
        final configs = await printerConfigService.loadPrinterConfigurations();
        final savedConfig = configs.where((c) => c.id == 'workflow_test_printer');
        expect(savedConfig.isNotEmpty, true);
        
        // Step 3: Update configuration
        final updatedConfig = config.copyWith(
          name: 'Updated Workflow Test Printer',
          ipAddress: '192.168.1.201',
        );
        await printerConfigService.savePrinterConfiguration(updatedConfig);
        
        // Step 4: Verify update
        final updatedConfigs = await printerConfigService.loadPrinterConfigurations();
        final finalConfig = updatedConfigs.firstWhere((c) => c.id == 'workflow_test_printer');
        expect(finalConfig.name, 'Updated Workflow Test Printer');
        expect(finalConfig.ipAddress, '192.168.1.201');
        
        print('✅ Printer configuration workflow test completed successfully');
      });
    });

    group('🔍 Error Handling Tests', () {
      test('should handle null order gracefully', () async {
        // This should not throw an error
        final emptyResult = await printerAssignmentService.segregateOrderItems(
          Order(
            id: 'empty_order',
            orderNumber: 'EMPTY-001',
            guest: 'Empty',
            userId: 'admin',
            tableId: null,
            orderType: OrderType.takeOut,
            status: OrderStatus.pending,
            items: [],
            subtotal: 0,
            tax: 0,
            total: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )
        );
        
        expect(emptyResult, isA<Map<String, List<OrderItem>>>());
      });

      test('should handle invalid table ID', () async {
        final nonExistentTable = await tableService.getTable('non_existent_table');
        expect(nonExistentTable, isNull);
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
            guest: 'Performance Test $i',
            userId: 'admin',
            tableId: null,
            orderType: OrderType.takeOut,
            status: OrderStatus.pending,
            items: [
              OrderItem(
                id: 'perf_item_$i',
                menuItem: firstItem,
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
          
          await orderService.saveOrder(order);
        }
        
        stopwatch.stop();
        
        expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Should save 5 orders within 3 seconds
        
        print('✅ 5 orders saved in ${stopwatch.elapsedMilliseconds}ms');
      });
    });
  });
} 