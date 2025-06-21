import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/screens/admin_panel_screen.dart';
import 'package:ai_pos_system/screens/manage_categories_screen.dart';
import 'package:ai_pos_system/screens/manage_menu_items_screen.dart';
import 'package:ai_pos_system/screens/server_selection_screen.dart';
import 'package:ai_pos_system/screens/order_type_selection_screen.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/services/settings_service.dart';
import 'package:ai_pos_system/services/inventory_service.dart';
import 'package:ai_pos_system/services/printing_service.dart';
import 'package:ai_pos_system/services/payment_service.dart';
import 'package:ai_pos_system/screens/user_action_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  late final DatabaseService _databaseService;
  late final MenuService _menuService;
  late final OrderService _orderService;
  late final TableService _tableService;
  late final UserService _userService;
  late final SettingsService _settingsService;
  late final InventoryService _inventoryService;
  late final PrintingService _printingService;
  late final PaymentService _paymentService;

  MyApp({super.key, required this.prefs}) {
    _databaseService = DatabaseService();
    _menuService = MenuService(_databaseService);
    _orderService = OrderService(_databaseService);
    _tableService = TableService(prefs);
    _userService = UserService(prefs, _databaseService);
    _settingsService = SettingsService(prefs);
    _inventoryService = InventoryService();
    _printingService = PrintingService(prefs, NetworkInfo());
    _paymentService = PaymentService(_orderService, _inventoryService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: _databaseService),
        ChangeNotifierProvider<MenuService>.value(value: _menuService),
        ChangeNotifierProvider<OrderService>.value(value: _orderService),
        ChangeNotifierProvider<TableService>.value(value: _tableService),
        ChangeNotifierProvider<UserService>.value(value: _userService),
        ChangeNotifierProvider<SettingsService>.value(value: _settingsService),
        ChangeNotifierProvider<InventoryService>.value(value: _inventoryService),
        ChangeNotifierProvider<PrintingService>.value(value: _printingService),
        ChangeNotifierProvider<PaymentService>.value(value: _paymentService),
      ],
      child: MaterialApp(
        title: 'AI POS System',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: FutureBuilder(
          future: _initializeApp(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const LandingScreen();
          },
        ),
        routes: {
          '/admin-panel': (context) => AdminPanelScreen(user: User(
            id: 'admin',
            name: 'Admin',
            role: UserRole.admin,
            pin: '1234',
          )),
          '/manage-categories': (context) => ManageCategoriesScreen(user: User(
            id: 'admin',
            name: 'Admin',
            role: UserRole.admin,
            pin: '1234',
          )),
          '/manage-menu-items': (context) => const ManageMenuItemsScreen(),
        },
      ),
    );
  }

  /// Initialize the app by setting up database and loading initial data.
  Future<void> _initializeApp() async {
    try {
      debugPrint('Initializing app...');
      
      // Temporarily skip menu loading to test stability
      // Check if categories exist, if not load Oh Bombay menu
      // final categories = await _menuService.getCategories();
      // if (categories.isEmpty) {
      //   debugPrint('No categories found, loading Oh Bombay Milton menu...');
      //   await _menuService.loadOhBombayMenu();
      //   debugPrint('Oh Bombay Milton menu loaded successfully');
      // }
      
      debugPrint('App initialization completed');
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      rethrow;
    }
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 60,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // App Title
                  Text(
                    'AI POS System',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Restaurant Point of Sale',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 64),
                  
                  // Continue as Admin Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final adminUser = User(
                          id: 'admin',
                          name: 'Admin',
                          role: UserRole.admin,
                          pin: '1234',
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserActionScreen(user: adminUser),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.admin_panel_settings, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Continue as Admin',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Continue as Server Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ServerSelectionScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                        foregroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Continue as Server',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Version info
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
