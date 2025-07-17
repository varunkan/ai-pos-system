import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pos_system/main.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/multi_tenant_auth_service.dart';
import 'package:ai_pos_system/services/initialization_progress_service.dart';
// import 'package:ai_pos_system/services/order_service.dart'; // Removed unused import
import 'package:ai_pos_system/services/settings_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/category.dart';

class MockSharedPreferences implements SharedPreferences {
  final Map<String, Object?> _storage = <String, Object?>{};
  @override
  String? getString(String key) => _storage[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }
  @override
  bool? getBool(String key) => _storage[key] as bool?;
  @override
  Future<bool> setBool(String key, bool value) async {
    _storage[key] = value;
    return true;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Category Management Tests', () {
    late DatabaseService databaseService;
    late MockSharedPreferences mockPrefs;
    late MenuService menuService;
    late SettingsService settingsService;
    late UserService userService;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      databaseService = DatabaseService();
      await databaseService.database;
      mockPrefs = MockSharedPreferences();
      menuService = MenuService(databaseService);
      settingsService = SettingsService(mockPrefs);
      userService = UserService(mockPrefs, databaseService);
      
      // Initialize default users
      final defaultUsers = [
        User(
          id: '1',
          name: 'Admin User',
          role: UserRole.admin,
          pin: '1234',
        ),
      ];

      for (final user in defaultUsers) {
        await userService.addUser(user);
      }

      // Initialize default categories
      final defaultCategories = [
        Category(id: '1', name: 'Appetizers', description: 'Starters and small plates'),
        Category(id: '2', name: 'Main Courses', description: 'Primary dishes'),
        Category(id: '3', name: 'Desserts', description: 'Sweet treats'),
        Category(id: '4', name: 'Beverages', description: 'Drinks and refreshments'),
        Category(id: '5', name: 'Sides', description: 'Side dishes and accompaniments'),
        Category(id: '6', name: 'Snacks', description: 'Quick bites and street food'),
      ];

      for (final category in defaultCategories) {
        await menuService.saveCategory(category);
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
    });

    testWidgets('Basic app functionality and user login', (WidgetTester tester) async {
      final authService = MultiTenantAuthService();
      final progressService = InitializationProgressService();
      await tester.pumpWidget(MyApp(
        authService: authService,
        progressService: progressService,
        prefs: mockPrefs,
      ));
      await tester.pump();

      // Login as admin
      await _loginAsAdmin(tester);

      // Verify we're on the main action screen
      expect(find.text('Welcome, Admin'), findsOneWidget);
      expect(find.text('Tables'), findsOneWidget);
      expect(find.text('Menu Items'), findsOneWidget);
      
      // Verify admin user has admin privileges
      final currentUser = userService.users.firstWhere((u) => u.name == 'Admin User');
      expect(currentUser.isAdmin, isTrue);
      expect(settingsService.isCategoryManagementEnabled, isTrue);
    });

    testWidgets('Database operations work correctly', (WidgetTester tester) async {
      // Test that categories are properly saved and loaded
      final categories = await menuService.getCategories();
      expect(categories.length, equals(6));
      
      // Verify specific categories exist
      final categoryNames = categories.map((c) => c.name).toList();
      expect(categoryNames, contains('Appetizers'));
      expect(categoryNames, contains('Main Courses'));
      expect(categoryNames, contains('Desserts'));
      expect(categoryNames, contains('Beverages'));
      expect(categoryNames, contains('Sides'));
      expect(categoryNames, contains('Snacks'));
    });

    testWidgets('User service operations work correctly', (WidgetTester tester) async {
      // Test that users are properly saved and loaded
      final users = userService.users;
      expect(users.length, greaterThan(0));
      
      // Verify admin user exists
      final adminUser = users.firstWhere((u) => u.name == 'Admin User');
      expect(adminUser.role, equals(UserRole.admin));
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.pin, equals('1234'));
    });
  });
}

// Helper function to login as admin
Future<void> _loginAsAdmin(WidgetTester tester) async {
  // Tap on admin user
  final userCards = find.byType(InkWell);
  await tester.tap(userCards.first);
  await tester.pumpAndSettle();

  // Enter PIN
  final pinField = find.byType(TextField).first;
  await tester.enterText(pinField, '1234');
  await tester.pumpAndSettle();

  // Login
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
} 