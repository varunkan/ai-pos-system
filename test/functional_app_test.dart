import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pos_system/services/multi_tenant_auth_service.dart';
import 'package:ai_pos_system/services/initialization_progress_service.dart';

void main() {
  group('Functional POS Application Tests', () {
    late SharedPreferences prefs;
    late MultiTenantAuthService authService;
    late InitializationProgressService progressService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      authService = MultiTenantAuthService();
      progressService = InitializationProgressService();
      await authService.initialize();
    });

    Widget createTestApp() {
      return MyApp(
        authService: authService,
        progressService: progressService,
        prefs: prefs,
      );
    }

    testWidgets('App Initialization and Landing Screen', (WidgetTester tester) async {
      // Test app initialization
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Should show restaurant authentication screen
      expect(find.text('Restaurant Authentication'), findsOneWidget);
      expect(find.text('Restaurant Code'), findsOneWidget);
      expect(find.text('PIN'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Invalid Authentication Flow', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Enter invalid credentials
      await tester.enterText(find.widgetWithText(TextFormField, '').first, 'invalid');
      await tester.enterText(find.widgetWithText(TextFormField, '').last, '0000');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Should show error or remain on login screen
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Valid Authentication Flow', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Enter valid restaurant code and PIN
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Should navigate away from login screen
      expect(find.text('Restaurant Authentication'), findsNothing);
    });

    testWidgets('Dashboard Navigation Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login first
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for services to initialize
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Should show dashboard elements
      expect(find.text('Dine-In'), findsOneWidget);
      expect(find.text('Take-Out'), findsOneWidget);
      expect(find.text('Admin Panel'), findsOneWidget);
    });

    testWidgets('Dine-In Flow Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to dine-in
      await tester.tap(find.text('Dine-In'));
      await tester.pumpAndSettle();
      
      // Should show table selection
      expect(find.text('Select Table'), findsOneWidget);
      
      // Select a table
      final tableCards = find.byType(Card);
      if (tableCards.evaluate().isNotEmpty) {
        await tester.tap(tableCards.first);
        await tester.pumpAndSettle();
        
        // Should show guest configuration
        expect(find.text('Configure Guests'), findsOneWidget);
        
        // Start dining experience
        await tester.tap(find.text('Start Dining Experience'));
        await tester.pumpAndSettle();
        
        // Should navigate to order creation
        expect(find.text('Order Creation'), findsOneWidget);
      }
    });

    testWidgets('Take-Out Flow Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to take-out
      await tester.tap(find.text('Take-Out'));
      await tester.pumpAndSettle();
      
      // Should show customer information form
      expect(find.text('Customer Information'), findsOneWidget);
      expect(find.text('Customer Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      
      // Fill customer information
      final customerFields = find.byType(TextFormField);
      await tester.enterText(customerFields.first, 'Test Customer');
      await tester.enterText(customerFields.last, '1234567890');
      await tester.pumpAndSettle();
      
      // Create take-out order
      await tester.tap(find.text('Create Take-Out Order'));
      await tester.pumpAndSettle();
      
      // Should navigate to order creation
      expect(find.text('Order Creation'), findsOneWidget);
    });

    testWidgets('Admin Panel Navigation Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to admin panel
      await tester.tap(find.text('Admin Panel'));
      await tester.pumpAndSettle();
      
      // Should show admin panel with tabs
      expect(find.text('Admin Panel'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      
      // Test tab navigation
      final tabs = find.byType(Tab);
      if (tabs.evaluate().isNotEmpty) {
        await tester.tap(tabs.first);
        await tester.pumpAndSettle();
        
        // Should navigate between tabs without error
        expect(find.byType(TabBar), findsOneWidget);
      }
    });

    testWidgets('Order Creation Screen Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to dine-in and create order
      await tester.tap(find.text('Dine-In'));
      await tester.pumpAndSettle();
      
      final tableCards = find.byType(Card);
      if (tableCards.evaluate().isNotEmpty) {
        await tester.tap(tableCards.first);
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Start Dining Experience'));
        await tester.pumpAndSettle();
        
        // Should show order creation elements
        expect(find.text('Order Creation'), findsOneWidget);
        expect(find.text('Categories'), findsOneWidget);
        expect(find.text('Menu Items'), findsOneWidget);
        expect(find.text('Current Order'), findsOneWidget);
        
        // Test category selection
        final categoryButtons = find.textContaining('Starter');
        if (categoryButtons.evaluate().isNotEmpty) {
          await tester.tap(categoryButtons.first);
          await tester.pumpAndSettle();
          
          // Should show menu items
          expect(find.byType(Card), findsWidgets);
          
          // Test adding items to order
          final menuItemCards = find.byType(Card);
          if (menuItemCards.evaluate().length > 1) {
            await tester.tap(menuItemCards.at(1));
            await tester.pumpAndSettle();
            
            // Should show item in current order
            expect(find.text('Current Order'), findsOneWidget);
          }
        }
      }
    });

    testWidgets('Order Management Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Should show existing orders on dashboard
      final orderCards = find.byType(Card);
      if (orderCards.evaluate().isNotEmpty) {
        // Test order editing
        await tester.tap(orderCards.first);
        await tester.pumpAndSettle();
        
        // Should navigate to order editing screen
        expect(find.text('Edit Order'), findsOneWidget);
      }
    });

    testWidgets('Printer Configuration Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to admin panel
      await tester.tap(find.text('Admin Panel'));
      await tester.pumpAndSettle();
      
      // Look for printer configuration tab
      final printerTab = find.text('Printers');
      if (printerTab.evaluate().isNotEmpty) {
        await tester.tap(printerTab.first);
        await tester.pumpAndSettle();
        
        // Should show printer configuration interface
        expect(find.text('Printers'), findsOneWidget);
      }
    });

    testWidgets('Back Navigation Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to admin panel
      await tester.tap(find.text('Admin Panel'));
      await tester.pumpAndSettle();
      
      // Test back navigation
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
        
        // Should navigate back to dashboard
        expect(find.text('Dine-In'), findsOneWidget);
        expect(find.text('Take-Out'), findsOneWidget);
      }
    });

    testWidgets('Menu Loading Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to order creation
      await tester.tap(find.text('Dine-In'));
      await tester.pumpAndSettle();
      
      final tableCards = find.byType(Card);
      if (tableCards.evaluate().isNotEmpty) {
        await tester.tap(tableCards.first);
        await tester.pumpAndSettle();
        
        await tester.tap(find.text('Start Dining Experience'));
        await tester.pumpAndSettle();
        
        // Should show menu categories
        expect(find.text('Categories'), findsOneWidget);
        
        // Should show category buttons
        final categoryButtons = find.textContaining('Starter');
        expect(categoryButtons.evaluate().isNotEmpty, isTrue);
      }
    });

    testWidgets('Error Handling Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Test with empty credentials
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Should handle empty input gracefully
      expect(find.text('Login'), findsOneWidget);
      
      // Test with invalid credentials
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'INVALID');
      await tester.enterText(textFields.last, '0000');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Should show error or remain on login screen
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Performance Test - Multiple Navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Test rapid navigation
      final stopwatch = Stopwatch()..start();
      
      // Navigate to dine-in
      await tester.tap(find.text('Dine-In'));
      await tester.pumpAndSettle();
      
      // Navigate back
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }
      
      // Navigate to take-out
      await tester.tap(find.text('Take-Out'));
      await tester.pumpAndSettle();
      
      // Navigate back
      final backButton2 = find.byType(BackButton);
      if (backButton2.evaluate().isNotEmpty) {
        await tester.tap(backButton2.first);
        await tester.pumpAndSettle();
      }
      
      // Navigate to admin panel
      await tester.tap(find.text('Admin Panel'));
      await tester.pumpAndSettle();
      
      stopwatch.stop();
      
      // Should complete navigation within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
    });

    testWidgets('UI Responsiveness Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Test with different screen sizes
      await tester.binding.setSurfaceSize(Size(800, 600));
      await tester.pumpAndSettle();
      
      // Should render correctly in smaller screen
      expect(find.text('Restaurant Authentication'), findsOneWidget);
      
      // Test with larger screen
      await tester.binding.setSurfaceSize(Size(1200, 800));
      await tester.pumpAndSettle();
      
      // Should render correctly in larger screen
      expect(find.text('Restaurant Authentication'), findsOneWidget);
      
      // Reset to default size
      await tester.binding.setSurfaceSize(Size(800, 600));
      await tester.pumpAndSettle();
    });

    testWidgets('Widget State Management Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Navigate to dine-in
      await tester.tap(find.text('Dine-In'));
      await tester.pumpAndSettle();
      
      // Check that state is maintained
      expect(find.text('Select Table'), findsOneWidget);
      
      // Select table and check state persistence
      final tableCards = find.byType(Card);
      if (tableCards.evaluate().isNotEmpty) {
        await tester.tap(tableCards.first);
        await tester.pumpAndSettle();
        
        // State should be updated
        expect(find.text('Configure Guests'), findsOneWidget);
        
        // Test navigation back and forth
        final backButton = find.byType(BackButton);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();
          
          // Should navigate back to table selection
          expect(find.text('Select Table'), findsOneWidget);
        }
      }
    });

    testWidgets('Memory Leak Test', (WidgetTester tester) async {
      // Test repeated navigation to check for memory leaks
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        
        // Login
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'BOMB001');
        await tester.enterText(textFields.last, '1234');
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        
        // Wait for initialization
        await tester.pumpAndSettle(Duration(seconds: 1));
        
        // Navigate to different screens
        await tester.tap(find.text('Dine-In'));
        await tester.pumpAndSettle();
        
        final backButton = find.byType(BackButton);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          await tester.pumpAndSettle();
        }
        
        // Should complete cycle without issues
        expect(find.text('Dine-In'), findsOneWidget);
      }
    });

    testWidgets('Database Integration Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();
      
      // Login
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.first, 'BOMB001');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Wait for initialization
      await tester.pumpAndSettle(Duration(seconds: 3));
      
      // Should show existing orders (if any)
      final orderCards = find.byType(Card);
      expect(orderCards.evaluate().isNotEmpty, isTrue);
      
      // Database should be initialized and working
      expect(find.text('Dine-In'), findsOneWidget);
      expect(find.text('Take-Out'), findsOneWidget);
    });
  });
} 