// This is a basic Flutter widget test for the Restaurant POS app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/screens/restaurant_auth_screen.dart';
import 'package:ai_pos_system/screens/dine_in_setup_screen.dart';
import 'package:ai_pos_system/screens/takeout_setup_screen.dart';
import 'package:ai_pos_system/screens/order_creation_screen.dart';
import 'package:ai_pos_system/screens/admin_panel_screen.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/table.dart' as PosTable;
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/category.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/activity_log_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Widget Tests', () {
    late SharedPreferences prefs;
    late DatabaseService databaseService;
    late UserService userService;
    late OrderService orderService;
    late MenuService menuService;
    late TableService tableService;
    late ActivityLogService activityLogService;
    late OrderLogService orderLogService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      
      // Initialize basic services for testing
      databaseService = DatabaseService();
      activityLogService = ActivityLogService(databaseService);
      orderLogService = OrderLogService(databaseService);
      userService = UserService(prefs, databaseService);
      orderService = OrderService(databaseService, orderLogService);
      menuService = MenuService(databaseService);
      tableService = TableService(prefs);
    });

    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<UserService>.value(value: userService),
            ChangeNotifierProvider<OrderService>.value(value: orderService),
            ChangeNotifierProvider<MenuService>.value(value: menuService),
            ChangeNotifierProvider<TableService>.value(value: tableService),
            ChangeNotifierProvider<ActivityLogService>.value(value: activityLogService),
            ChangeNotifierProvider<OrderLogService>.value(value: orderLogService),
          ],
          child: child,
        ),
      );
    }

    group('Authentication Screen Tests', () {
      testWidgets('Restaurant Auth Screen renders correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RestaurantAuthScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Check if key elements are present
        expect(find.text('Restaurant Authentication'), findsOneWidget);
        expect(find.text('Restaurant Code'), findsOneWidget);
        expect(find.text('PIN'), findsOneWidget);
        expect(find.text('Login'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('Restaurant Auth Screen handles empty input', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RestaurantAuthScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap login without entering credentials
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Should show validation errors or handle gracefully
        expect(find.byType(TextFormField), findsNWidgets(2));
      });

      testWidgets('Restaurant Auth Screen form validation', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: RestaurantAuthScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Enter some test data
        await tester.enterText(find.byType(TextFormField).first, 'TEST123');
        await tester.enterText(find.byType(TextFormField).last, '1234');
        await tester.pumpAndSettle();

        // Verify input is accepted
        expect(find.text('TEST123'), findsOneWidget);
        expect(find.text('1234'), findsOneWidget);
      });
    });

    group('Take-Out Setup Screen Tests', () {
      testWidgets('Take-Out Setup Screen renders correctly', (WidgetTester tester) async {
        final testUser = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            TakeoutSetupScreen(user: testUser),
          ),
        );
        await tester.pumpAndSettle();

        // Check if key elements are present
        expect(find.text('Customer Information'), findsOneWidget);
        expect(find.text('Customer Name'), findsOneWidget);
        expect(find.text('Phone Number'), findsOneWidget);
        expect(find.text('Create Take-Out Order'), findsOneWidget);
      });

      testWidgets('Take-Out Setup Screen form input', (WidgetTester tester) async {
        final testUser = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            TakeoutSetupScreen(user: testUser),
          ),
        );
        await tester.pumpAndSettle();

        // Enter customer information
        await tester.enterText(find.byType(TextFormField).first, 'John Doe');
        await tester.enterText(find.byType(TextFormField).at(1), '1234567890');
        await tester.pumpAndSettle();

        // Verify input is accepted
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('1234567890'), findsOneWidget);
      });
    });

    group('Dine-In Setup Screen Tests', () {
      testWidgets('Dine-In Setup Screen renders correctly', (WidgetTester tester) async {
        final testUser = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            DineInSetupScreen(user: testUser),
          ),
        );
        await tester.pumpAndSettle();

        // Check if key elements are present
        expect(find.text('Select Table'), findsOneWidget);
        expect(find.text('Configure Guests'), findsOneWidget);
      });

      testWidgets('Dine-In Setup Screen table selection', (WidgetTester tester) async {
        final testUser = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            DineInSetupScreen(user: testUser),
          ),
        );
        await tester.pumpAndSettle();

        // Look for table selection elements
        expect(find.text('Select Table'), findsOneWidget);
        
        // Check if any table cards are present
        final tableCards = find.byType(Card);
        expect(tableCards.evaluate().isNotEmpty, isTrue);
      });
    });

    group('Model Tests', () {
      testWidgets('User Model Creation', (WidgetTester tester) async {
        final user = User(
          id: 'test_user',
          name: 'Test User',
          role: UserRole.server,
          pin: '1234',
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(user.id, equals('test_user'));
        expect(user.name, equals('Test User'));
        expect(user.role, equals(UserRole.server));
        expect(user.pin, equals('1234'));
        expect(user.isActive, isTrue);
      });

      testWidgets('Order Model Creation', (WidgetTester tester) async {
        final order = Order(
          id: 'test_order',
          orderNumber: 'TEST-001',
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          userId: 'test_user',
          items: [],
          subtotal: 10.0,
          taxAmount: 1.0,
          totalAmount: 11.0,
          orderTime: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(order.id, equals('test_order'));
        expect(order.orderNumber, equals('TEST-001'));
        expect(order.status, equals(OrderStatus.pending));
        expect(order.type, equals(OrderType.dineIn));
        expect(order.userId, equals('test_user'));
        expect(order.subtotal, equals(10.0));
        expect(order.taxAmount, equals(1.0));
        expect(order.totalAmount, equals(11.0));
      });

      testWidgets('Table Model Creation', (WidgetTester tester) async {
        final table = PosTable.Table(
          number: 1,
          capacity: 4,
        );

        expect(table.number, equals(1));
        expect(table.capacity, equals(4));
        expect(table.status, equals(PosTable.TableStatus.available));
      });

      testWidgets('MenuItem Model Creation', (WidgetTester tester) async {
        final menuItem = MenuItem(
          id: 'test_item',
          name: 'Test Item',
          description: 'Test Description',
          price: 10.0,
          categoryId: 'test_category',
          isAvailable: true,
          createdAt: DateTime.now(),
        );

        expect(menuItem.id, equals('test_item'));
        expect(menuItem.name, equals('Test Item'));
        expect(menuItem.description, equals('Test Description'));
        expect(menuItem.price, equals(10.0));
        expect(menuItem.categoryId, equals('test_category'));
        expect(menuItem.isAvailable, isTrue);
      });

      testWidgets('Category Model Creation', (WidgetTester tester) async {
        final category = Category(
          id: 'test_category',
          name: 'Test Category',
          description: 'Test Description',
          sortOrder: 1,
          isActive: true,
          createdAt: DateTime.now(),
        );

        expect(category.id, equals('test_category'));
        expect(category.name, equals('Test Category'));
        expect(category.description, equals('Test Description'));
        expect(category.sortOrder, equals(1));
        expect(category.isActive, isTrue);
      });
    });

    group('Widget Component Tests', () {
      testWidgets('MaterialApp structure', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: Text('Test App')),
              body: Center(child: Text('Hello World')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test App'), findsOneWidget);
        expect(find.text('Hello World'), findsOneWidget);
      });

      testWidgets('Button interactions', (WidgetTester tester) async {
        bool buttonPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    buttonPressed = true;
                  },
                  child: Text('Test Button'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Button'), findsOneWidget);
        
        await tester.tap(find.text('Test Button'));
        await tester.pumpAndSettle();

        expect(buttonPressed, isTrue);
      });

      testWidgets('Text input fields', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Test Input',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Input'), findsOneWidget);
        
        await tester.enterText(find.byType(TextFormField), 'Test Value');
        await tester.pumpAndSettle();

        expect(find.text('Test Value'), findsOneWidget);
      });

      testWidgets('Card widgets', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Card Content'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Card Content'), findsOneWidget);
      });

      testWidgets('ListView widgets', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  ListTile(title: Text('Item 1')),
                  ListTile(title: Text('Item 2')),
                  ListTile(title: Text('Item 3')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
        expect(find.text('Item 2'), findsOneWidget);
        expect(find.text('Item 3'), findsOneWidget);
      });

      testWidgets('TabBar and TabBarView', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  bottom: TabBar(
                    tabs: [
                      Tab(text: 'Tab 1'),
                      Tab(text: 'Tab 2'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    Center(child: Text('Content 1')),
                    Center(child: Text('Content 2')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tab 1'), findsOneWidget);
        expect(find.text('Tab 2'), findsOneWidget);
        expect(find.text('Content 1'), findsOneWidget);
        
        // Tap on Tab 2
        await tester.tap(find.text('Tab 2'));
        await tester.pumpAndSettle();

        expect(find.text('Content 2'), findsOneWidget);
      });
    });

    group('Error Handling Tests', () {
      testWidgets('Error dialog display', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: tester.element(find.byType(ElevatedButton)),
                      builder: (context) => AlertDialog(
                        title: Text('Error'),
                        content: Text('An error occurred'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Text('Show Error'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show Error'));
        await tester.pumpAndSettle();

        expect(find.text('Error'), findsOneWidget);
        expect(find.text('An error occurred'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
      });

      testWidgets('Loading states', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading...'), findsOneWidget);
      });
    });

    group('Navigation Tests', () {
      testWidgets('Basic navigation', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: Text('First Screen')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      tester.element(find.byType(ElevatedButton)).findRootAncestorStateOfType<NavigatorState>()!.context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: Text('Second Screen')),
                          body: Center(child: Text('Welcome to second screen')),
                        ),
                      ),
                    );
                  },
                  child: Text('Go to Second Screen'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('First Screen'), findsOneWidget);
        expect(find.text('Go to Second Screen'), findsOneWidget);

        await tester.tap(find.text('Go to Second Screen'));
        await tester.pumpAndSettle();

        expect(find.text('Second Screen'), findsOneWidget);
        expect(find.text('Welcome to second screen'), findsOneWidget);
      });

      testWidgets('Back button navigation', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: Text('First Screen')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      tester.element(find.byType(ElevatedButton)).findRootAncestorStateOfType<NavigatorState>()!.context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(title: Text('Second Screen')),
                          body: Center(child: Text('Welcome to second screen')),
                        ),
                      ),
                    );
                  },
                  child: Text('Go to Second Screen'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go to Second Screen'));
        await tester.pumpAndSettle();

        expect(find.text('Second Screen'), findsOneWidget);

        // Tap back button
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('First Screen'), findsOneWidget);
      });
    });

    group('Performance Tests', () {
      testWidgets('Rapid widget creation', (WidgetTester tester) async {
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Widget $i'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      testWidgets('Large list performance', (WidgetTester tester) async {
        final items = List.generate(1000, (index) => 'Item $index');
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(items[index]),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should handle large lists
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Item 0'), findsOneWidget);
        
        // Scroll to test performance
        await tester.fling(find.byType(ListView), Offset(0, -300), 1000);
        await tester.pumpAndSettle();
        
        // Should still work after scrolling
        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('Semantic labels', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Semantics(
                  label: 'Test button',
                  child: ElevatedButton(
                    onPressed: () {},
                    child: Text('Click me'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Test button'), findsOneWidget);
      });

      testWidgets('Text field accessibility', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Enter your name',
                    hintText: 'John Doe',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Enter your name'), findsOneWidget);
        expect(find.text('John Doe'), findsOneWidget);
      });
    });
  });
}
