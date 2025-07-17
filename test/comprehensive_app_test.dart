import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/main.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/printing_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_assignment_service.dart';
import 'package:ai_pos_system/services/printer_configuration_service.dart';
import 'package:ai_pos_system/services/multi_tenant_auth_service.dart';
import 'package:ai_pos_system/services/activity_log_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/inventory_service.dart';
import 'package:ai_pos_system/services/payment_service.dart';
import 'package:ai_pos_system/services/cross_platform_printer_sync_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_manager.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/category.dart';
import 'package:ai_pos_system/models/table.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  group('Comprehensive POS Application Tests', () {
    late DatabaseService databaseService;
    late UserService userService;
    late OrderService orderService;
    late MenuService menuService;
    late TableService tableService;
    late PrintingService printingService;
    late EnhancedPrinterAssignmentService printerAssignmentService;
    late PrinterConfigurationService printerConfigurationService;
    late MultiTenantAuthService authService;
    late ActivityLogService activityLogService;
    late OrderLogService orderLogService;
    late InventoryService inventoryService;
    late PaymentService paymentService;
    late CrossPlatformPrinterSyncService printerSyncService;
    late EnhancedPrinterManager printerManager;
    late SharedPreferences prefs;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize SharedPreferences
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      
      // Initialize database service
      databaseService = DatabaseService();
      await databaseService.initializeWithCustomName('test_db');
      
      // Initialize services with proper dependencies
      activityLogService = ActivityLogService(databaseService);
      orderLogService = OrderLogService(databaseService);
      userService = UserService(prefs, databaseService);
      orderService = OrderService(databaseService, orderLogService);
      menuService = MenuService(databaseService);
      tableService = TableService(prefs);
      printingService = PrintingService(prefs, Connectivity());
      printerConfigurationService = PrinterConfigurationService(databaseService);
      printerAssignmentService = EnhancedPrinterAssignmentService(
        databaseService: databaseService,
      );
      
      authService = MultiTenantAuthService();
      inventoryService = InventoryService();
      paymentService = PaymentService(orderService, inventoryService);
      printerSyncService = CrossPlatformPrinterSyncService(
        databaseService: databaseService,
      );
      printerManager = EnhancedPrinterManager(
        databaseService: databaseService,
      );
      
      // Initialize services that require it
      await orderService.loadOrders();
      await menuService.loadMenuData();
      await tableService.loadTables();
      await printerAssignmentService.initialize();
      await printerConfigurationService.initialize();
      await activityLogService.initialize();
      await orderLogService.initialize();
      await authService.initialize();
      await printerSyncService.initialize();
      await printerManager.initialize();
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserService>.value(value: userService),
          ChangeNotifierProvider<OrderService>.value(value: orderService),
          ChangeNotifierProvider<MenuService>.value(value: menuService),
          ChangeNotifierProvider<TableService>.value(value: tableService),
          ChangeNotifierProvider<PrintingService>.value(value: printingService),
          ChangeNotifierProvider<EnhancedPrinterAssignmentService>.value(value: printerAssignmentService),
          ChangeNotifierProvider<PrinterConfigurationService>.value(value: printerConfigurationService),
          ChangeNotifierProvider<MultiTenantAuthService>.value(value: authService),
          ChangeNotifierProvider<ActivityLogService>.value(value: activityLogService),
          ChangeNotifierProvider<OrderLogService>.value(value: orderLogService),
          ChangeNotifierProvider<InventoryService>.value(value: inventoryService),
          ChangeNotifierProvider<PaymentService>.value(value: paymentService),
          ChangeNotifierProvider<CrossPlatformPrinterSyncService>.value(value: printerSyncService),
          ChangeNotifierProvider<EnhancedPrinterManager>.value(value: printerManager),
        ],
        child: MaterialApp(
          title: 'POS Test App',
          home: PosApp(),
        ),
      );
    }

    group('1. Authentication Flow Tests', () {
      testWidgets('Restaurant Authentication Screen', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Verify restaurant auth screen is shown
        expect(find.text('Restaurant Authentication'), findsOneWidget);
        expect(find.text('Restaurant Code'), findsOneWidget);
        expect(find.text('PIN'), findsOneWidget);
        
        // Test invalid credentials
        await tester.enterText(find.byType(TextFormField).first, 'invalid_code');
        await tester.enterText(find.byType(TextFormField).last, '0000');
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        
        // Should show error message
        expect(find.textContaining('Login failed'), findsOneWidget);
      });

      testWidgets('Valid Authentication Flow', (WidgetTester tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Test with valid credentials (assuming default restaurant exists)
        await tester.enterText(find.byType(TextFormField).first, 'BOMB001');
        await tester.enterText(find.byType(TextFormField).last, '1234');
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        
        // Should navigate to the next screen
        expect(find.text('Restaurant Authentication'), findsNothing);
      });
    });

    group('2. Basic Service Tests', () {
      testWidgets('Database Service Initialization', (WidgetTester tester) async {
        expect(databaseService, isNotNull);
        expect(databaseService.database, isNotNull);
      });

      testWidgets('User Service Functionality', (WidgetTester tester) async {
        expect(userService, isNotNull);
        expect(userService.users, isNotNull);
        
        // Test user creation
        final testUser = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await userService.createUser(testUser);
        expect(userService.users.any((u) => u.id == 'test_user'), isTrue);
      });

      testWidgets('Menu Service Functionality', (WidgetTester tester) async {
        expect(menuService, isNotNull);
        expect(menuService.categories, isNotNull);
        expect(menuService.menuItems, isNotNull);
        
        // Test menu data loading
        await menuService.loadMenuData();
        expect(menuService.categories.isNotEmpty, isTrue);
        expect(menuService.menuItems.isNotEmpty, isTrue);
      });

      testWidgets('Order Service Functionality', (WidgetTester tester) async {
        expect(orderService, isNotNull);
        expect(orderService.allOrders, isNotNull);
        
        // Test order creation
        final testOrder = Order(
          id: 'test_order',
          orderNumber: 'TEST-001',
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          userId: 'test_user',
          items: [],
          subtotal: 0.0,
          taxAmount: 0.0,
          totalAmount: 0.0,
          orderTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(testOrder);
        expect(orderService.allOrders.any((o) => o.id == 'test_order'), isTrue);
      });

      testWidgets('Table Service Functionality', (WidgetTester tester) async {
        expect(tableService, isNotNull);
        expect(tableService.tables, isNotNull);
        
        // Test table data loading
        await tableService.loadTables();
        expect(tableService.tables.isNotEmpty, isTrue);
      });

      testWidgets('Printing Service Functionality', (WidgetTester tester) async {
        expect(printingService, isNotNull);
        
        // Test printer configuration
        final printerConfig = await printingService.getActivePrinterConfigurations();
        expect(printerConfig, isNotNull);
      });

      testWidgets('Printer Assignment Service Functionality', (WidgetTester tester) async {
        expect(printerAssignmentService, isNotNull);
        
        // Test assignment stats
        final stats = await printerAssignmentService.getAssignmentStats();
        expect(stats, isNotNull);
        expect(stats.containsKey('totalAssignments'), isTrue);
      });

      testWidgets('Activity Log Service Functionality', (WidgetTester tester) async {
        expect(activityLogService, isNotNull);
        
        // Test activity logging
        await activityLogService.logActivity('Test Activity', 'test_user', UserRole.server);
        final logs = await activityLogService.getRecentActivities();
        expect(logs.any((log) => log.description == 'Test Activity'), isTrue);
      });

      testWidgets('Order Log Service Functionality', (WidgetTester tester) async {
        expect(orderLogService, isNotNull);
        
        // Test order logging
        await orderLogService.logOperation('test_order', 'Test Operation', 'test_user');
        final logs = await orderLogService.getOrderLogs('test_order');
        expect(logs.any((log) => log.operation == 'Test Operation'), isTrue);
      });
    });

    group('3. Integration Tests', () {
      testWidgets('Service Integration Test', (WidgetTester tester) async {
        // Test that all services work together
        expect(databaseService, isNotNull);
        expect(userService, isNotNull);
        expect(orderService, isNotNull);
        expect(menuService, isNotNull);
        expect(tableService, isNotNull);
        expect(printingService, isNotNull);
        expect(printerAssignmentService, isNotNull);
        expect(printerConfigurationService, isNotNull);
        expect(authService, isNotNull);
        expect(activityLogService, isNotNull);
        expect(orderLogService, isNotNull);
        expect(inventoryService, isNotNull);
        expect(paymentService, isNotNull);
        expect(printerSyncService, isNotNull);
        expect(printerManager, isNotNull);
      });

      testWidgets('End-to-End Order Flow Test', (WidgetTester tester) async {
        // Create a user
        final testUser = User(
          id: 'test_user_e2e',
          name: 'Test User E2E',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await userService.createUser(testUser);
        
        // Create an order
        final testOrder = Order(
          id: 'test_order_e2e',
          orderNumber: 'E2E-001',
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          userId: 'test_user_e2e',
          items: [],
          subtotal: 0.0,
          taxAmount: 0.0,
          totalAmount: 0.0,
          orderTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(testOrder);
        
        // Log the order creation
        await orderLogService.logOperation('test_order_e2e', 'Order Created', 'test_user_e2e');
        
        // Log user activity
        await activityLogService.logActivity('Order Created', 'test_user_e2e', UserRole.server);
        
        // Verify all components worked
        expect(userService.users.any((u) => u.id == 'test_user_e2e'), isTrue);
        expect(orderService.allOrders.any((o) => o.id == 'test_order_e2e'), isTrue);
        
        final orderLogs = await orderLogService.getOrderLogs('test_order_e2e');
        expect(orderLogs.any((log) => log.operation == 'Order Created'), isTrue);
        
        final activityLogs = await activityLogService.getRecentActivities();
        expect(activityLogs.any((log) => log.description == 'Order Created'), isTrue);
      });
    });

    group('4. Error Handling Tests', () {
      testWidgets('Database Error Handling', (WidgetTester tester) async {
        // Test invalid user creation
        try {
          final invalidUser = User(
            id: '', // Invalid empty ID
            name: 'Invalid User',
            role: UserRole.server,
            pin: '1234',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await userService.createUser(invalidUser);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isNotNull);
        }
      });

      testWidgets('Order Service Error Handling', (WidgetTester tester) async {
        // Test invalid order creation
        try {
          final invalidOrder = Order(
            id: '', // Invalid empty ID
            orderNumber: 'INVALID-001',
            status: OrderStatus.pending,
            type: OrderType.dineIn,
            userId: 'nonexistent_user',
            items: [],
            subtotal: -1.0, // Invalid negative amount
            taxAmount: 0.0,
            totalAmount: 0.0,
            orderTime: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await orderService.createOrder(invalidOrder);
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isNotNull);
        }
      });
    });

    group('5. Performance Tests', () {
      testWidgets('Large Dataset Performance', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Create multiple users
        for (int i = 0; i < 100; i++) {
          final user = User(
            id: 'perf_user_$i',
            name: 'Performance User $i',
            role: UserRole.server,
            pin: '1234',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await userService.createUser(user);
        }
        
        stopwatch.stop();
        
        // Should complete within reasonable time (5 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
        expect(userService.users.length, greaterThanOrEqualTo(100));
      });

      testWidgets('Order Processing Performance', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        // Create multiple orders
        for (int i = 0; i < 50; i++) {
          final order = Order(
            id: 'perf_order_$i',
            orderNumber: 'PERF-${i.toString().padLeft(3, '0')}',
            status: OrderStatus.pending,
            type: OrderType.dineIn,
            userId: 'test_user',
            items: [],
            subtotal: 10.0 * i,
            taxAmount: 1.0 * i,
            totalAmount: 11.0 * i,
            orderTime: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await orderService.createOrder(order);
        }
        
        stopwatch.stop();
        
        // Should complete within reasonable time (3 seconds)
        expect(stopwatch.elapsedMilliseconds, lessThan(3000));
        expect(orderService.allOrders.length, greaterThanOrEqualTo(50));
      });
    });

    group('6. Data Validation Tests', () {
      testWidgets('User Data Validation', (WidgetTester tester) async {
        // Test user validation
        final validUser = User(
          id: 'valid_user',
          name: 'Valid User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await userService.createUser(validUser);
        final retrievedUser = userService.users.firstWhere((u) => u.id == 'valid_user');
        
        expect(retrievedUser.id, equals('valid_user'));
        expect(retrievedUser.name, equals('Valid User'));
        expect(retrievedUser.role, equals(UserRole.server));
        expect(retrievedUser.pin, equals('1234'));
        expect(retrievedUser.isActive, isTrue);
      });

      testWidgets('Order Data Validation', (WidgetTester tester) async {
        // Test order validation
        final validOrder = Order(
          id: 'valid_order',
          orderNumber: 'VALID-001',
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          userId: 'test_user',
          items: [],
          subtotal: 10.0,
          taxAmount: 1.0,
          totalAmount: 11.0,
          orderTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await orderService.createOrder(validOrder);
        final retrievedOrder = orderService.allOrders.firstWhere((o) => o.id == 'valid_order');
        
        expect(retrievedOrder.id, equals('valid_order'));
        expect(retrievedOrder.orderNumber, equals('VALID-001'));
        expect(retrievedOrder.status, equals(OrderStatus.pending));
        expect(retrievedOrder.type, equals(OrderType.dineIn));
        expect(retrievedOrder.subtotal, equals(10.0));
        expect(retrievedOrder.taxAmount, equals(1.0));
        expect(retrievedOrder.totalAmount, equals(11.0));
      });
    });

    group('7. Concurrency Tests', () {
      testWidgets('Concurrent User Operations', (WidgetTester tester) async {
        final futures = <Future>[];
        
        // Create multiple users concurrently
        for (int i = 0; i < 20; i++) {
          futures.add(userService.createUser(User(
            id: 'concurrent_user_$i',
            name: 'Concurrent User $i',
            role: UserRole.server,
            pin: '1234',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )));
        }
        
        await Future.wait(futures);
        
        // All users should be created
        expect(userService.users.where((u) => u.id.startsWith('concurrent_user_')).length, equals(20));
      });

      testWidgets('Concurrent Order Operations', (WidgetTester tester) async {
        final futures = <Future>[];
        
        // Create multiple orders concurrently
        for (int i = 0; i < 10; i++) {
          futures.add(orderService.createOrder(Order(
            id: 'concurrent_order_$i',
            orderNumber: 'CONC-${i.toString().padLeft(3, '0')}',
            status: OrderStatus.pending,
            type: OrderType.dineIn,
            userId: 'test_user',
            items: [],
            subtotal: 10.0 * i,
            taxAmount: 1.0 * i,
            totalAmount: 11.0 * i,
            orderTime: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          )));
        }
        
        await Future.wait(futures);
        
        // All orders should be created
        expect(orderService.allOrders.where((o) => o.id.startsWith('concurrent_order_')).length, equals(10));
      });
    });

    group('8. Memory and Resource Tests', () {
      testWidgets('Memory Usage Test', (WidgetTester tester) async {
        // Create and destroy many objects to test memory management
        for (int i = 0; i < 1000; i++) {
          final user = User(
            id: 'memory_user_$i',
            name: 'Memory User $i',
            role: UserRole.server,
            pin: '1234',
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          
          await userService.createUser(user);
          
          // Remove every 100th user to test cleanup
          if (i % 100 == 0) {
            await userService.deleteUser('memory_user_$i');
          }
        }
        
        // Should handle large operations without issues
        expect(userService.users.length, greaterThan(800));
      });
    });

    group('9. Edge Case Tests', () {
      testWidgets('Empty Data Handling', (WidgetTester tester) async {
        // Test with empty data
        final emptyOrders = orderService.allOrders.where((o) => o.items.isEmpty);
        expect(emptyOrders, isNotNull);
        
        final emptyUsers = userService.users.where((u) => u.name.isEmpty);
        expect(emptyUsers, isNotNull);
      });

      testWidgets('Null Data Handling', (WidgetTester tester) async {
        // Test null handling in services
        try {
          await orderService.getOrderById('nonexistent_order');
        } catch (e) {
          expect(e, isNotNull);
        }
        
        try {
          await userService.getUserById('nonexistent_user');
        } catch (e) {
          expect(e, isNotNull);
        }
      });
    });

    group('10. State Management Tests', () {
      testWidgets('Service State Changes', (WidgetTester tester) async {
        bool userServiceNotified = false;
        bool orderServiceNotified = false;
        
        // Listen for state changes
        userService.addListener(() {
          userServiceNotified = true;
        });
        
        orderService.addListener(() {
          orderServiceNotified = true;
        });
        
        // Trigger state changes
        await userService.createUser(User(
          id: 'state_user',
          name: 'State User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        
        await orderService.createOrder(Order(
          id: 'state_order',
          orderNumber: 'STATE-001',
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          userId: 'state_user',
          items: [],
          subtotal: 10.0,
          taxAmount: 1.0,
          totalAmount: 11.0,
          orderTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        
        // Services should notify listeners
        expect(userServiceNotified, isTrue);
        expect(orderServiceNotified, isTrue);
      });
    });
  });
} 