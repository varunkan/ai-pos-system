import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pos_system/main.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/models/user.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Login/Selection Flow', () {
    late DatabaseService databaseService;
    late MockSharedPreferences mockPrefs;
    late UserService userService;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      databaseService = DatabaseService();
      await databaseService.database;
      mockPrefs = MockSharedPreferences();
      userService = UserService(mockPrefs);
      
      // Initialize default users manually for testing
      final defaultUsers = [
        User(
          id: '1',
          name: 'Admin User',
          role: UserRole.admin,
          pin: '1234',
        ),
        User(
          id: '2',
          name: 'Server 1',
          role: UserRole.server,
          pin: '1111',
        ),
        User(
          id: '3',
          name: 'Server 2',
          role: UserRole.server,
          pin: '2222',
        ),
      ];

      for (final user in defaultUsers) {
        await userService.addUser(user);
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    });

    testWidgets('User selection and login', (WidgetTester tester) async {
      await tester.pumpWidget(MyApp(
        prefs: mockPrefs,
      ));
      await tester.pumpAndSettle();

      // Wait for the screen to load and check for the welcome text
      expect(find.text('Welcome to World-Class POS'), findsOneWidget);
      expect(find.text('Select Your Profile'), findsOneWidget);

      // Look for user cards - they should be displayed in a GridView
      // Find the first user card (Admin User) by looking for the first CircleAvatar
      final userCards = find.byType(InkWell);
      
      if (userCards.evaluate().isEmpty) {
        // If no InkWell widgets found, try looking for other interactive elements
        final gestureDetectors = find.byType(GestureDetector);
        
        if (gestureDetectors.evaluate().isNotEmpty) {
          await tester.tap(gestureDetectors.first);
          await tester.pumpAndSettle();
        }
      } else {
        // Tap on the first user card (Admin User)
        await tester.tap(userCards.first);
        await tester.pumpAndSettle();
      }

      // Now we should see the PIN dialog
      expect(find.text('Enter PIN for Admin'), findsOneWidget);

      // Enter PIN (default is '1234')
      final pinField = find.byType(TextField).first;
      await tester.enterText(pinField, '1234');
      await tester.pumpAndSettle();

      // Tap the Login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Should navigate to UserActionScreen for admin
      // Look for the welcome message in the app bar
      expect(find.text('Welcome, Admin'), findsOneWidget);
    });
  });
} 