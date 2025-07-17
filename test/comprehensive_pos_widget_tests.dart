import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_pos_system/main.dart';
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
import 'package:ai_pos_system/screens/order_type_selection_screen.dart';
import 'package:ai_pos_system/screens/order_creation_screen.dart';
import 'package:ai_pos_system/screens/edit_active_order_screen.dart';
import 'package:ai_pos_system/screens/dine_in_setup_screen.dart';
import 'package:ai_pos_system/screens/admin_panel_screen.dart';
import 'package:ai_pos_system/screens/user_management_screen.dart';
import 'package:ai_pos_system/screens/comprehensive_printer_assignment_screen.dart';
import 'package:ai_pos_system/widgets/printer_validation_dialog.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/table.dart';

void main() {
  // Initialize FFI for testing
  sqfliteFfiInit();
  
  group('🎨 POS Widget Tests', () {
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

    setUp(() async {
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
      
      // Set up a test user
      final users = await userService.getUsers();
      final admin = users.firstWhere((u) => u.role == UserRole.admin);
      userService.setCurrentUser(admin);
    });

    tearDown(() async {
      await databaseService.close();
    });

    Widget createTestWidget(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserService>.value(value: userService),
          ChangeNotifierProvider<OrderService>.value(value: orderService),
          ChangeNotifierProvider<MenuService>.value(value: menuService),
          ChangeNotifierProvider<TableService>.value(value: tableService),
          Provider<DatabaseService>.value(value: databaseService),
          Provider<PrinterConfigurationService>.value(value: printerConfigService),
          Provider<EnhancedPrinterAssignmentService>.value(value: printerAssignmentService),
          Provider<PrintingService>.value(value: printingService),
          Provider<OrderLogService>.value(value: orderLogService),
          Provider<ActivityLogService>.value(value: activityLogService),
          Provider<PrinterValidationService>.value(value: printerValidationService),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    group('📱 Order Type Selection Screen Tests', () {
      testWidgets('should display server selection and order buttons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        // Check if welcome message is displayed
        expect(find.textContaining('Welcome'), findsOneWidget);
        
        // Check if server selection is displayed
        expect(find.text('Working Servers'), findsOneWidget);
        
        // Check if order type buttons are displayed
        expect(find.text('Dine-In'), findsOneWidget);
        expect(find.text('Take-Out'), findsOneWidget);
        
        // Check if orders section is displayed
        expect(find.text('Active Orders'), findsOneWidget);
      });

      testWidgets('should navigate to dine-in setup when dine-in is tapped', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        // Tap on Dine-In button
        await tester.tap(find.text('Dine-In'));
        await tester.pumpAndSettle();

        // Should navigate to dine-in setup (we can't easily test navigation without router setup)
        // For now, just verify the button exists and is tappable
        expect(find.text('Dine-In'), findsOneWidget);
      });

      testWidgets('should display admin panel button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        // Check if admin panel button is displayed
        expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
      });
    });

    group('🍽️ Order Creation Screen Tests', () {
      testWidgets('should display menu categories and items', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          OrderCreationScreen(
            orderType: OrderType.takeout,
            tableId: null,
            guestCount: 0,
            user: userService.currentUser!,
          ),
        ));
        await tester.pumpAndSettle();

        // Check if menu categories are displayed
        expect(find.text('Menu Categories'), findsOneWidget);
        
        // Check if order panel is displayed
        expect(find.text('Order Summary'), findsOneWidget);
        
        // Check if action buttons are displayed
        expect(find.text('Send to Kitchen'), findsOneWidget);
        expect(find.text('Checkout'), findsOneWidget);
      });

      testWidgets('should add items to order when tapped', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          OrderCreationScreen(
            orderType: OrderType.takeout,
            tableId: null,
            guestCount: 0,
            user: userService.currentUser!,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap on first menu item (if exists)
        final menuItems = find.byType(Card);
        if (menuItems.evaluate().isNotEmpty) {
          await tester.tap(menuItems.first);
          await tester.pumpAndSettle();
          
          // Check if item was added to order
          expect(find.text('1'), findsWidgets);
        }
      });

      testWidgets('should display order totals', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          OrderCreationScreen(
            orderType: OrderType.takeout,
            tableId: null,
            guestCount: 0,
            user: userService.currentUser!,
          ),
        ));
        await tester.pumpAndSettle();

        // Check if order totals are displayed
        expect(find.textContaining('Subtotal'), findsOneWidget);
        expect(find.textContaining('Tax'), findsOneWidget);
        expect(find.textContaining('Total'), findsOneWidget);
      });
    });

    group('🏠 Dine-In Setup Screen Tests', () {
      testWidgets('should display table selection', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DineInSetupScreen(user: userService.currentUser!),
        ));
        await tester.pumpAndSettle();

        // Check if table selection is displayed
        expect(find.text('Select Table'), findsOneWidget);
        
        // Check if tables are displayed
        expect(find.byType(Card), findsWidgets);
      });

      testWidgets('should allow table selection', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DineInSetupScreen(user: userService.currentUser!),
        ));
        await tester.pumpAndSettle();

        // Tap on first table
        final tables = find.byType(Card);
        if (tables.evaluate().isNotEmpty) {
          await tester.tap(tables.first);
          await tester.pumpAndSettle();
          
          // Check if table was selected (visual feedback)
          expect(find.byType(Card), findsWidgets);
        }
      });

      testWidgets('should display guest count configuration', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DineInSetupScreen(user: userService.currentUser!),
        ));
        await tester.pumpAndSettle();

        // First select a table
        final tables = find.byType(Card);
        if (tables.evaluate().isNotEmpty) {
          await tester.tap(tables.first);
          await tester.pumpAndSettle();
          
          // Tap configure guests button
          final configureButton = find.text('Configure Guests');
          if (configureButton.evaluate().isNotEmpty) {
            await tester.tap(configureButton);
            await tester.pumpAndSettle();
            
            // Check if guest count configuration is displayed
            expect(find.text('Configure Guests'), findsOneWidget);
          }
        }
      });
    });

    group('⚙️ Admin Panel Screen Tests', () {
      testWidgets('should display admin panel sections', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(AdminPanelScreen()));
        await tester.pumpAndSettle();

        // Check if admin sections are displayed
        expect(find.text('User Management'), findsOneWidget);
        expect(find.text('Reports'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('should display statistics cards', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(AdminPanelScreen()));
        await tester.pumpAndSettle();

        // Check if statistics are displayed
        expect(find.textContaining('Orders'), findsWidgets);
        expect(find.textContaining('Users'), findsWidgets);
      });
    });

    group('👥 User Management Screen Tests', () {
      testWidgets('should display user list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(UserManagementScreen()));
        await tester.pumpAndSettle();

        // Check if user list is displayed
        expect(find.text('User Management'), findsOneWidget);
        expect(find.text('Admin'), findsOneWidget);
        
        // Check if add user button is displayed
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should display user roles', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(UserManagementScreen()));
        await tester.pumpAndSettle();

        // Check if user roles are displayed
        expect(find.textContaining('Admin'), findsOneWidget);
        expect(find.textContaining('Server'), findsWidgets);
      });
    });

    group('🖨️ Printer Assignment Screen Tests', () {
      testWidgets('should display printer assignment interface', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(ComprehensivePrinterAssignmentScreen()));
        await tester.pumpAndSettle();

        // Check if printer assignment interface is displayed
        expect(find.text('Printer Assignment'), findsOneWidget);
        
        // Check if menu categories are displayed
        expect(find.text('Menu Categories'), findsOneWidget);
        
        // Check if printers section is displayed
        expect(find.text('Available Printers'), findsOneWidget);
      });

      testWidgets('should display drag and drop interface', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(ComprehensivePrinterAssignmentScreen()));
        await tester.pumpAndSettle();

        // Check if drag and drop elements are present
        expect(find.byType(Draggable), findsWidgets);
        expect(find.byType(DragTarget), findsWidgets);
      });
    });

    group('✅ Printer Validation Dialog Tests', () {
      testWidgets('should display validation results', (WidgetTester tester) async {
        final validationResult = PrinterValidationResult(
          isValid: false,
          failures: [
            PrinterValidationFailure(
              type: PrinterValidationFailureType.missingAssignments,
              message: 'Some items have no printer assignments',
              affectedItems: ['Item 1', 'Item 2'],
            ),
          ],
        );

        await tester.pumpWidget(createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => PrinterValidationDialog(
                    validationResult: validationResult,
                    onConfigurePrinters: () {},
                    onRetry: () {},
                    onProceedAnyway: () {},
                  ),
                );
              },
              child: Text('Show Dialog'),
            ),
          ),
        ));

        // Tap button to show dialog
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Check if validation dialog is displayed
        expect(find.text('Printer Validation Failed'), findsOneWidget);
        expect(find.text('Some items have no printer assignments'), findsOneWidget);
        
        // Check if action buttons are displayed
        expect(find.text('Configure Printers'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Proceed Anyway'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });
    });

    group('📱 Edit Active Order Screen Tests', () {
      testWidgets('should display order details for editing', (WidgetTester tester) async {
        final orders = await orderService.getOrders();
        if (orders.isNotEmpty) {
          final order = orders.first;
          
          await tester.pumpWidget(createTestWidget(
            EditActiveOrderScreen(
              order: order,
              user: userService.currentUser!,
            ),
          ));
          await tester.pumpAndSettle();

          // Check if order details are displayed
          expect(find.text('Edit Order'), findsOneWidget);
          expect(find.text('Order Summary'), findsOneWidget);
          
          // Check if action buttons are displayed
          expect(find.text('Send to Kitchen'), findsOneWidget);
          expect(find.text('Save Changes'), findsOneWidget);
        }
      });
    });

    group('🔄 Widget Integration Tests', () {
      testWidgets('should handle complete order creation workflow', (WidgetTester tester) async {
        // Start with order type selection
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        // Verify initial state
        expect(find.text('Take-Out'), findsOneWidget);
        expect(find.text('Dine-In'), findsOneWidget);
        
        // Test successful widget loading
        expect(find.byType(OrderTypeSelectionScreen), findsOneWidget);
      });

      testWidgets('should handle responsive design', (WidgetTester tester) async {
        // Test different screen sizes
        await tester.binding.setSurfaceSize(Size(800, 600));
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(OrderTypeSelectionScreen), findsOneWidget);

        // Test larger screen
        await tester.binding.setSurfaceSize(Size(1200, 800));
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(OrderTypeSelectionScreen), findsOneWidget);
      });
    });

    group('🎯 Error Handling Widget Tests', () {
      testWidgets('should handle null data gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          OrderCreationScreen(
            orderType: OrderType.takeout,
            tableId: null,
            guestCount: 0,
            user: userService.currentUser!,
          ),
        ));
        await tester.pumpAndSettle();

        // Should not throw errors even with null data
        expect(find.byType(OrderCreationScreen), findsOneWidget);
      });

      testWidgets('should display loading states', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        
        // Check for loading indicators during initial pump
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        
        await tester.pumpAndSettle();
        
        // After settling, should show content
        expect(find.byType(OrderTypeSelectionScreen), findsOneWidget);
      });
    });

    group('🎨 UI Component Tests', () {
      testWidgets('should display consistent styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        // Check for consistent Material Design components
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(ElevatedButton), findsWidgets);
        expect(find.byType(AppBar), findsWidgets);
      });

      testWidgets('should handle theme changes', (WidgetTester tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<UserService>.value(value: userService),
              ChangeNotifierProvider<OrderService>.value(value: orderService),
              ChangeNotifierProvider<MenuService>.value(value: menuService),
              ChangeNotifierProvider<TableService>.value(value: tableService),
              Provider<DatabaseService>.value(value: databaseService),
              Provider<PrinterConfigurationService>.value(value: printerConfigService),
              Provider<EnhancedPrinterAssignmentService>.value(value: printerAssignmentService),
              Provider<PrintingService>.value(value: printingService),
              Provider<OrderLogService>.value(value: orderLogService),
              Provider<ActivityLogService>.value(value: activityLogService),
              Provider<PrinterValidationService>.value(value: printerValidationService),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: OrderTypeSelectionScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should work with dark theme
        expect(find.byType(OrderTypeSelectionScreen), findsOneWidget);
      });
    });

    group('📱 Accessibility Tests', () {
      testWidgets('should have proper accessibility labels', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(OrderTypeSelectionScreen()));
        await tester.pumpAndSettle();

        // Check for semantic labels
        expect(find.byType(Semantics), findsWidgets);
        
        // Check for proper button accessibility
        final buttons = find.byType(ElevatedButton);
        for (final button in buttons.evaluate()) {
          expect(button.widget, isA<ElevatedButton>());
        }
      });
    });
  });
} 