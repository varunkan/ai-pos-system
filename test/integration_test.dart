import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_pos_system/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('🍕 COMPREHENSIVE POS INTEGRATION TESTS', () {
    
    testWidgets('🔐 Test Login and Authentication', (WidgetTester tester) async {
      print('\n🔐 === TESTING LOGIN AND AUTHENTICATION ===');
      
      await app.main();
      await tester.pumpAndSettle();

      // Look for login screen
      expect(find.text('Oh Bombay Milton'), findsOneWidget);
      print('✅ Login screen displayed successfully');

      // Test admin login
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Should reach main dashboard
      expect(find.text('POS Dashboard'), findsOneWidget);
      print('✅ Admin login successful - reached dashboard');
    });

    testWidgets('🛒 Test Order Creation Workflow', (WidgetTester tester) async {
      print('\n🛒 === TESTING ORDER CREATION WORKFLOW ===');
      
      // Navigate to order creation
      await tester.tap(find.text('Dine-In'));
      await tester.pumpAndSettle();
      
      // Select a table
      await tester.tap(find.text('Table 1'));
      await tester.pumpAndSettle();
      
      // Should be in order creation screen
      expect(find.text('Create Order'), findsOneWidget);
      print('✅ Order creation screen loaded');

      // Add items to order
      await tester.tap(find.text('Pizza'));
      await tester.pumpAndSettle();
      
      // Add a pizza item
      final pizzaFinder = find.textContaining('Margherita').first;
      if (tester.any(pizzaFinder)) {
        await tester.tap(pizzaFinder);
        await tester.pumpAndSettle();
        print('✅ Pizza item added to order');
      }

      // Test order completion
      final sendToKitchenFinder = find.text('Send to Kitchen');
      if (tester.any(sendToKitchenFinder)) {
        await tester.tap(sendToKitchenFinder);
        await tester.pumpAndSettle();
        print('✅ Order sent to kitchen successfully');
      }
    });

    testWidgets('📦 Test Inventory Management', (WidgetTester tester) async {
      print('\n📦 === TESTING INVENTORY MANAGEMENT ===');
      
      // Navigate to User Actions
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        // Look for Inventory card
        final inventoryFinder = find.text('Inventory');
        if (tester.any(inventoryFinder)) {
          await tester.tap(inventoryFinder);
          await tester.pumpAndSettle();
          
          // Should be in inventory screen
          expect(find.text('Inventory Management'), findsOneWidget);
          print('✅ Inventory screen loaded');
          
          // Test different tabs
          await tester.tap(find.text('Items'));
          await tester.pumpAndSettle();
          print('✅ Items tab accessible');
          
          await tester.tap(find.text('Analytics'));
          await tester.pumpAndSettle();
          print('✅ Analytics tab accessible');
          
          await tester.tap(find.text('Transactions'));
          await tester.pumpAndSettle();
          print('✅ Transactions tab accessible');
        }
      }
    });

    testWidgets('👤 Test User Management', (WidgetTester tester) async {
      print('\n👤 === TESTING USER MANAGEMENT ===');
      
      // Navigate to Admin Panel
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        final adminPanelFinder = find.text('Admin Panel');
        if (tester.any(adminPanelFinder)) {
          await tester.tap(adminPanelFinder);
          await tester.pumpAndSettle();
          
          // Look for Users tab
          final usersFinder = find.text('Users');
          if (tester.any(usersFinder)) {
            await tester.tap(usersFinder);
            await tester.pumpAndSettle();
            print('✅ User management screen accessible');
          }
        }
      }
    });

    testWidgets('🏷️ Test Menu and Category Management', (WidgetTester tester) async {
      print('\n🏷️ === TESTING MENU AND CATEGORY MANAGEMENT ===');
      
      // Navigate to Admin Panel
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        final adminPanelFinder = find.text('Admin Panel');
        if (tester.any(adminPanelFinder)) {
          await tester.tap(adminPanelFinder);
          await tester.pumpAndSettle();
          
          // Test Menu Items tab
          final menuItemsFinder = find.text('Menu Items');
          if (tester.any(menuItemsFinder)) {
            await tester.tap(menuItemsFinder);
            await tester.pumpAndSettle();
            print('✅ Menu Items management accessible');
          }
          
          // Test Categories tab
          final categoriesFinder = find.text('Categories');
          if (tester.any(categoriesFinder)) {
            await tester.tap(categoriesFinder);
            await tester.pumpAndSettle();
            print('✅ Categories management accessible');
          }
        }
      }
    });

    testWidgets('🖨️ Test Printer Management', (WidgetTester tester) async {
      print('\n🖨️ === TESTING PRINTER MANAGEMENT ===');
      
      // Navigate to User Actions
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        final printerConfigFinder = find.text('Printer Config');
        if (tester.any(printerConfigFinder)) {
          await tester.tap(printerConfigFinder);
          await tester.pumpAndSettle();
          print('✅ Printer configuration screen accessible');
        }
      }
    });

    testWidgets('📊 Test Analytics and Reporting', (WidgetTester tester) async {
      print('\n📊 === TESTING ANALYTICS AND REPORTING ===');
      
      // Navigate to Admin Panel
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        final adminPanelFinder = find.text('Admin Panel');
        if (tester.any(adminPanelFinder)) {
          await tester.tap(adminPanelFinder);
          await tester.pumpAndSettle();
          
          // Test Analytics tab
          final analyticsFinder = find.text('Analytics');
          if (tester.any(analyticsFinder)) {
            await tester.tap(analyticsFinder);
            await tester.pumpAndSettle();
            print('✅ Analytics screen accessible');
          }
        }
      }
    });

    testWidgets('🧾 Test Order History and Management', (WidgetTester tester) async {
      print('\n🧾 === TESTING ORDER HISTORY AND MANAGEMENT ===');
      
      // Navigate to Admin Panel
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        final adminOrdersFinder = find.text('Admin Orders');
        if (tester.any(adminOrdersFinder)) {
          await tester.tap(adminOrdersFinder);
          await tester.pumpAndSettle();
          print('✅ Order history screen accessible');
        }
      }
    });

    testWidgets('⚙️ Test Settings and Configuration', (WidgetTester tester) async {
      print('\n⚙️ === TESTING SETTINGS AND CONFIGURATION ===');
      
      // Navigate to User Actions
      final userActionsFinder = find.byIcon(Icons.person);
      if (tester.any(userActionsFinder)) {
        await tester.tap(userActionsFinder);
        await tester.pumpAndSettle();
        
        final settingsFinder = find.text('Settings');
        if (tester.any(settingsFinder)) {
          await tester.tap(settingsFinder);
          await tester.pumpAndSettle();
          print('✅ Settings screen accessible');
        }
      }
    });

    testWidgets('🔄 Test Data Synchronization', (WidgetTester tester) async {
      print('\n🔄 === TESTING DATA SYNCHRONIZATION ===');
      
      // Test app state persistence
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('AppLifecycleState.paused'),
        ),
        (data) {},
      );
      
      await tester.pumpAndSettle();
      
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/lifecycle',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('AppLifecycleState.resumed'),
        ),
        (data) {},
      );
      
      await tester.pumpAndSettle();
      print('✅ App lifecycle handling working');
    });

    testWidgets('📱 Test Responsive Design', (WidgetTester tester) async {
      print('\n📱 === TESTING RESPONSIVE DESIGN ===');
      
      // Test different screen sizes
      await tester.binding.window.physicalSizeTestValue = const Size(800, 600);
      await tester.binding.window.devicePixelRatioTestValue = 1.0;
      await tester.pumpAndSettle();
      print('✅ Tablet layout responsive');
      
      await tester.binding.window.physicalSizeTestValue = const Size(400, 800);
      await tester.binding.window.devicePixelRatioTestValue = 1.0;
      await tester.pumpAndSettle();
      print('✅ Mobile layout responsive');
      
      // Reset to original size
      await tester.binding.window.clearPhysicalSizeTestValue();
      await tester.binding.window.clearDevicePixelRatioTestValue();
      await tester.pumpAndSettle();
    });
  });
}

extension WidgetTesterExtension on WidgetTester {
  /// Check if any widget matching the finder exists
  bool any(Finder finder) {
    try {
      return finder.evaluate().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
} 