import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/environment_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

// Multi-tenant authentication
import 'services/multi_tenant_auth_service.dart';
import 'screens/restaurant_auth_screen.dart';
import 'screens/order_type_selection_screen.dart';
import 'services/initialization_progress_service.dart';
import 'widgets/initialization_progress_screen.dart';

// All POS services
import 'models/order.dart';
import 'services/database_service.dart';
import 'services/menu_service.dart';
import 'services/order_service.dart';
import 'services/user_service.dart';
import 'services/printing_service.dart';
import 'services/table_service.dart';
import 'services/reservation_service.dart';
import 'services/inventory_service.dart';
import 'services/printer_configuration_service.dart';
import 'services/enhanced_printer_assignment_service.dart';
import 'services/cross_platform_printer_sync_service.dart';
import 'services/printer_validation_service.dart';
import 'services/robust_kitchen_service.dart';
import 'services/free_cloud_printing_service.dart';
// Removed redundant printer services for streamlined architecture
import 'services/analytics_service.dart';
import 'services/settings_service.dart';
import 'services/payment_service.dart';
import 'services/loyalty_service.dart';
import 'services/store_service.dart';
import 'services/order_log_service.dart';
import 'services/activity_log_service.dart';
import 'services/enhanced_printer_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set environment (default to production if not set)
  if (!EnvironmentConfig.isDevelopment && !EnvironmentConfig.isProduction) {
    EnvironmentConfig.setEnvironment(Environment.production);
  }
  
  // Disable Provider debug check to allow nullable service types
  Provider.debugCheckInvalidValueType = null;
  
  debugPrint('🚀 Starting Multi-Tenant AI POS System...');
  debugPrint('🌍 Environment: ${EnvironmentConfig.environment.name.toUpperCase()}');
  debugPrint('🗄️ Database: ${EnvironmentConfig.databaseName}');
  
  // Initialize Flutter services
  final prefs = await SharedPreferences.getInstance();
  final authService = MultiTenantAuthService();
  final progressService = InitializationProgressService();
  
  // Pre-initialize auth service (with normal session restore behavior)
  await authService.initialize();
  
  // Connect progress service to auth service
  authService.setProgressService(progressService);
  
  debugPrint('🚪 Starting with normal session behavior');
  
  runApp(MyApp(
    authService: authService,
    progressService: progressService,
    prefs: prefs,
  ));
}

class MyApp extends StatefulWidget {
  final MultiTenantAuthService authService;
  final InitializationProgressService progressService;
  final SharedPreferences prefs;
  
  const MyApp({
    Key? key,
    required this.authService,
    required this.progressService,
    required this.prefs,
  }) : super(key: key);
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Global navigator key for navigation
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  // Service initialization state
  bool _servicesInitialized = false;
  bool _isInitializing = false; // Add flag to prevent duplicate initialization
  
  // Service instances
  late MenuService _menuService;
  late OrderService _orderService;
  late InventoryService _inventoryService;
  late OrderLogService _orderLogService;
  late ActivityLogService _activityLogService;
  
  // Services that depend on authentication - nullable until properly initialized
  UserService? _userService;
  TableService? _tableService;
  PaymentService? _paymentService;
  PrintingService? _printingService;
  EnhancedPrinterAssignmentService? _enhancedPrinterAssignmentService;
  PrinterConfigurationService? _printerConfigurationService;
  CrossPlatformPrinterSyncService? _crossPlatformPrinterSyncService;
  // Removed: AutoPrinterDiscoveryService (redundant)
  EnhancedPrinterManager? _enhancedPrinterManager;
  PrinterValidationService? _printerValidationService;
  RobustKitchenService? _robustKitchenService;
  FreeCloudPrintingService? _freeCloudPrintingService;

  @override
  void initState() {
    super.initState();
    
    // Initialize core services immediately
    _initializeCoreServices();
    
    // Add app lifecycle observer for auto-logout on app close
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize service instances for Provider tree
    _initializeServiceInstancesSync();
    
    // Initialize services that need SharedPreferences asynchronously
    _initializeServiceInstancesAsync();
    
    // Add listener to auth service for authentication state changes
    widget.authService.addListener(_onAuthStateChanged);
    
    // Initialize services after authentication (if already authenticated)
    if (widget.authService.isAuthenticated) {
      // Use post frame callback to ensure widget tree is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeServicesAfterAuth();
      });
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove auth listener
    widget.authService.removeListener(_onAuthStateChanged);
    
    // CRITICAL FIX: Do NOT dispose services here!
    // Services should remain available throughout app lifecycle
    // Only dispose when truly shutting down the app
    
    super.dispose();
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        if (widget.authService.isAuthenticated) {
          debugPrint('🔓 Authentication state changed - initializing services...');
          _initializeServicesAfterAuth();
        } else {
          debugPrint('🔒 Authentication state changed - cleaning up services...');
          _cleanupServices();
        }
      });
    }
  }

  /// Handle app lifecycle changes - logout when app is closed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('📱 App lifecycle state changed: $state');
    
    // Only logout when app is truly being closed or detached
    // Do NOT logout for inactive/hidden states (these are normal during app switching)
    if (state == AppLifecycleState.detached) {
      debugPrint('🚪 App truly closing - logging out for security...');
      _logoutOnAppClose();
    }
    // Note: We don't logout on paused/hidden/inactive as these are normal app lifecycle events
  }

  /// Logout when app is closed (for security)
  void _logoutOnAppClose() async {
    try {
      if (widget.authService.isAuthenticated) {
        // Mark that app was explicitly closed
        await widget.prefs.setBool('app_explicitly_closed', true);
        
        await widget.authService.logout();
        debugPrint('✅ Auto-logout completed due to app close');
      }
    } catch (e) {
      debugPrint('❌ Error during auto-logout: $e');
    }
  }

  /// Initialize core services with dummy database instances
  void _initializeCoreServices() {
    final dummyDb = DatabaseService();
    _menuService = MenuService(dummyDb);
    _orderLogService = OrderLogService(dummyDb);
    _activityLogService = ActivityLogService(dummyDb);
    _orderService = OrderService(dummyDb, _orderLogService);
    _inventoryService = InventoryService();
    debugPrint('✅ Core services initialized with dummy instances');
  }

  /// Initialize services that can be created synchronously (before SharedPreferences)
  void _initializeServiceInstancesSync() {
    // All services are already initialized in _initializeCoreServices()
    debugPrint('✅ Sync service instances ready');
  }
  
  /// Initialize services that require SharedPreferences asynchronously
  void _initializeServiceInstancesAsync() async {
    // This will be called after SharedPreferences is available
    debugPrint('✅ Async service instances ready');
  }

  /// Initialize services after authentication
  Future<void> _initializeServicesAfterAuth() async {
    if (_isInitializing) {
      debugPrint('⚠️ Service initialization already in progress');
      return;
    }
    
    if (_servicesInitialized) {
      debugPrint('⚠️ Services already initialized');
      return;
    }
    
    _isInitializing = true;
    
    try {
      debugPrint('🔧 Starting POS service initialization after authentication...');
      
      final tenantDatabase = widget.authService.tenantDatabase;
      if (tenantDatabase == null) {
        throw Exception('Tenant database not available after authentication');
      }
      
      debugPrint('✅ Using tenant database: ${tenantDatabase.runtimeType}');
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      debugPrint('✅ SharedPreferences initialized');
      
      // Reset disposal state for core services before reinitialization
      try {
        _orderService.resetDisposalState();
        _menuService.resetDisposalState();
      } catch (e) {
        debugPrint('⚠️ Could not reset service disposal states: $e');
      }
      
      // Initialize all services with proper tenant database
      await _initializeAllServices(prefs, tenantDatabase);
      
      _servicesInitialized = true;
      debugPrint('🎉 All POS services initialized successfully');
      
      // Trigger UI rebuild
      if (mounted) {
        setState(() {});
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize services after auth: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize services: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Initialize all services with proper error handling
  Future<void> _initializeAllServices(SharedPreferences prefs, DatabaseService tenantDatabase) async {
    try {
      // IMPORTANT: Reinitialize ALL services with proper authenticated instances
      
      // Initialize UserService first (critical for UI)
      widget.progressService.addMessage('👥 Initializing user management...');
      _userService = UserService(prefs, tenantDatabase);
      // Wait for UserService to complete loading users
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('✅ UserService initialized');
      
      // Initialize TableService early (needed for orders)
      widget.progressService.addMessage('🍽️ Setting up table management...');
      _tableService = TableService(prefs);
      debugPrint('✅ TableService initialized');
      
      // Initialize PaymentService early (needed for UI)
      widget.progressService.addMessage('💳 Setting up payment processing...');
      _paymentService = PaymentService(_orderService, _inventoryService);
      debugPrint('✅ PaymentService initialized');
      
      // Initialize PrintingService early (needed for UI)
      widget.progressService.addMessage('🖨️ Configuring printing services...');
      final networkInfo = await _getNetworkInfo();
      _printingService = PrintingService(prefs, networkInfo);
      debugPrint('✅ PrintingService initialized');
      
      // Trigger UI rebuild with basic services ready
      if (mounted) {
        setState(() {});
      }
      
      // Create new OrderService instance with updated database and reload orders
      widget.progressService.addMessage('📋 Reloading existing orders from database...');
      _orderLogService = OrderLogService(tenantDatabase);
      _orderService = OrderService(tenantDatabase, _orderLogService);
      await _orderService.loadOrders();
      debugPrint('✅ OrderService reinitialized with existing orders');
      
      // Create new MenuService instance with updated database
      widget.progressService.addMessage('🍽️ Loading menu items...');
      _menuService = MenuService(tenantDatabase);
      await _menuService.ensureInitialized();
      debugPrint('✅ MenuService reinitialized');
      
      // Create new ActivityLogService instance with updated database
      widget.progressService.addMessage('📝 Initializing activity logging...');
      _activityLogService = ActivityLogService(tenantDatabase);
      await _activityLogService.initialize();
      
      // Set current user context for logging
      final currentSession = widget.authService.currentSession;
      if (currentSession != null) {
        _activityLogService.setCurrentUser(
          currentSession.userId,
          currentSession.userName,
          currentSession.userRole.toString(),
          restaurantId: widget.authService.currentRestaurant?.id,
        );
      }
      
      debugPrint('✅ ActivityLogService reinitialized');
      
      // Log successful authentication
      try {
        final currentSession = widget.authService.currentSession;
        if (currentSession != null) {
          await _activityLogService.logLogin(
            userId: currentSession.userId,
            userName: currentSession.userName,
            userRole: currentSession.userRole.toString(),
            screenName: 'Main App',
            metadata: {
              'restaurant_name': widget.authService.currentRestaurant?.name,
              'initialization_time': DateTime.now().toIso8601String(),
            },
          );
        }
      } catch (e) {
        debugPrint('⚠️ Failed to log authentication: $e');
      }
      
      widget.progressService.addMessage('🔧 Setting up printer configurations...');
      _printerConfigurationService = PrinterConfigurationService(tenantDatabase);
      await _printerConfigurationService!.initializeTable();
      debugPrint('✅ PrinterConfigurationService initialized');
      
      widget.progressService.addMessage('🎛️ Setting up printer assignments...');
      
      // Initialize enhanced printer assignment service (with full multi-printer support)
      widget.progressService.addMessage('🎯 Setting up enhanced printer assignments...');
      _enhancedPrinterAssignmentService = EnhancedPrinterAssignmentService(
        databaseService: tenantDatabase,
        printerConfigService: _printerConfigurationService!,
      );
      
      // Initialize the enhanced assignment service
      await _enhancedPrinterAssignmentService!.initialize();
      debugPrint('✅ EnhancedPrinterAssignmentService initialized with multi-printer support');
      
      // Initialize cross-platform printer sync service
      widget.progressService.addMessage('🌐 Setting up cross-platform sync...');
      _crossPlatformPrinterSyncService = CrossPlatformPrinterSyncService(
        databaseService: tenantDatabase,
        assignmentService: _enhancedPrinterAssignmentService!,
      );
      await _crossPlatformPrinterSyncService!.initialize();
      debugPrint('✅ CrossPlatformPrinterSyncService initialized with automatic persistence');
      
      // Initialize enhanced printer manager (handles all printer functionality)
      widget.progressService.addMessage('🚀 Setting up Enhanced Printer Management System...');
      if (_printingService != null && _printerConfigurationService != null && _enhancedPrinterAssignmentService != null) {
        _enhancedPrinterManager = EnhancedPrinterManager(
          databaseService: tenantDatabase,
          printerConfigService: _printerConfigurationService!,
          printingService: _printingService!,
          assignmentService: _enhancedPrinterAssignmentService!,
        );
        
        // Initialize enhanced printer manager (this will discover, configure, and connect all printers)
        await _enhancedPrinterManager!.initialize();
        debugPrint('✅ EnhancedPrinterManager initialized - comprehensive printer system ready');
      } else {
        debugPrint('⚠️ Could not initialize EnhancedPrinterManager - required services not available');
      }
      
      // Initialize printer validation service (requires all printer services)
      widget.progressService.addMessage('🔒 Setting up printer validation system...');
      if (_printerConfigurationService != null && _enhancedPrinterAssignmentService != null && _enhancedPrinterManager != null) {
        _printerValidationService = PrinterValidationService(
          databaseService: tenantDatabase,
          printerConfigService: _printerConfigurationService!,
          assignmentService: _enhancedPrinterAssignmentService!,
          printerManager: _enhancedPrinterManager!,
        );
        debugPrint('✅ PrinterValidationService initialized - kitchen validation system ready');
      } else {
        debugPrint('⚠️ Could not initialize PrinterValidationService - required services not available');
      }
      
      // Initialize robust kitchen service (unifies all send to kitchen operations)
      widget.progressService.addMessage('🍽️ Setting up robust kitchen service...');
      if (_printingService != null && _enhancedPrinterAssignmentService != null && _printerConfigurationService != null) {
        _robustKitchenService = RobustKitchenService(
          databaseService: tenantDatabase,
          printingService: _printingService!,
          assignmentService: _enhancedPrinterAssignmentService!,
          printerConfigService: _printerConfigurationService!,
          orderLogService: _orderLogService,
        );
        debugPrint('✅ RobustKitchenService initialized - comprehensive send to kitchen system ready');
      } else {
        debugPrint('⚠️ Could not initialize RobustKitchenService - required services not available');
      }
      
      // Initialize free cloud printing service
      widget.progressService.addMessage('🆓 Setting up free cloud printing service...');
      if (_printingService != null && _enhancedPrinterAssignmentService != null) {
        _freeCloudPrintingService = FreeCloudPrintingService(
          printingService: _printingService!,
          assignmentService: _enhancedPrinterAssignmentService!,
        );
        debugPrint('✅ FreeCloudPrintingService initialized - free cloud printing ready');
      } else {
        debugPrint('⚠️ Could not initialize FreeCloudPrintingService - required services not available');
      }
      
      // Initialize auto printer discovery service (requires printing service, printer config service, and multi printer manager)
      widget.progressService.addMessage('🔍 Setting up automatic printer discovery...');
      if (_printingService != null && _printerConfigurationService != null && _enhancedPrinterAssignmentService != null) {
        // Removed: MultiPrinterManager and AutoPrinterDiscoveryService (redundant)
        // Functionality moved to unified printer service
        debugPrint('ℹ️ Printer discovery will be handled by unified printer service');
      } else {
        debugPrint('⚠️ Printer services not available - will be handled by unified service');
      }
      
      debugPrint('🎉 All POS services initialized successfully');
      
      // CREATE DUMMY DATA FOR TESTING (only if no existing data)
      final existingOrderCount = _orderService.allOrders.length;
      if (existingOrderCount == 0) {
        widget.progressService.addMessage('🎯 Creating demo servers and orders...');
        await _createDummyData();
      } else {
        debugPrint('📋 Found $existingOrderCount existing orders - skipping dummy data creation');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing services: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Get network info (using the real NetworkInfo from network_info_plus)
  Future<NetworkInfo> _getNetworkInfo() async {
    // Return the real NetworkInfo instance from network_info_plus package
    return NetworkInfo();
  }
  
  /// Create dummy data for testing
  Future<void> _createDummyData() async {
    try {
      debugPrint('🎯 Creating dummy data...');
      
      // Create dummy servers
      if (_userService != null) {
        await _userService!.createDummyServers();
        debugPrint('✅ Dummy servers created');
      }
      
              // Create a sample order for testing
        try {
          final sampleOrder = await _orderService.createOrder(
            orderType: 'dineIn',
            customerName: 'Demo Customer',
            userId: 'demo-server',
          );
          
          // Add a sample item to the order (if menu items exist)
          final menuItems = await _menuService.getMenuItems();
          if (menuItems.isNotEmpty) {
            final orderItem = OrderItem(
              id: 'demo-item-${DateTime.now().millisecondsSinceEpoch}',
              menuItem: menuItems.first,
              quantity: 1,
            );
            
            // Create new order with the item using copyWith
            final updatedOrder = sampleOrder.copyWith(
              items: [orderItem],
            );
            
            await _orderService.saveOrder(updatedOrder);
          }
          
          debugPrint('✅ Sample order created');
        } catch (e) {
          debugPrint('⚠️ Could not create sample order: $e');
        }
      
      debugPrint('🎉 All dummy data created successfully!');
      
    } catch (e) {
      debugPrint('⚠️ Error creating dummy data (not critical): $e');
      // Don't throw error - dummy data creation failure shouldn't stop the app
    }
  }
  
  /// Cleanup services when user logs out - PRESERVE ORDER DATA AND SERVICE INSTANCES
  void _cleanupServices() {
    try {
      debugPrint('🧹 Starting service cleanup after logout...');
      
      // IMPORTANT: Reset initialization flags
      _servicesInitialized = false;
      _isInitializing = false;
      
      // Reset progress service
      widget.progressService.reset();
      
      // CRITICAL: Do NOT dispose services or clear order data
      // Services should remain functional for next login
      debugPrint('📋 Preserving service instances and order data for next login...');
      
      // Only clear authenticated service references (they will be recreated on next login)
      _userService = null;
      _tableService = null;
      _paymentService = null;
      _printingService = null;
      _enhancedPrinterAssignmentService = null;
      _printerConfigurationService = null;
      _crossPlatformPrinterSyncService = null;
      // Removed: _autoPrinterDiscoveryService reference
      _enhancedPrinterManager = null;
      _freeCloudPrintingService = null;
      
      debugPrint('✅ Service cleanup completed - all services preserved');
    } catch (e) {
      debugPrint('❌ Error during service cleanup: $e');
      // Reset flags even on error
      _servicesInitialized = false;
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build providers list with null safety
    final providers = <ChangeNotifierProvider>[
      // Core service providers - always available
      ChangeNotifierProvider<MultiTenantAuthService>.value(value: widget.authService),
      ChangeNotifierProvider<InitializationProgressService>.value(value: widget.progressService),
      ChangeNotifierProvider<MenuService>.value(value: _menuService),
      ChangeNotifierProvider<OrderService>.value(value: _orderService),
      ChangeNotifierProvider<InventoryService>.value(value: _inventoryService),
      ChangeNotifierProvider<OrderLogService>.value(value: _orderLogService),
      ChangeNotifierProvider<ActivityLogService>.value(value: _activityLogService),
    ];
    
    // Add authenticated services (with null support for safe access)
    providers.add(ChangeNotifierProvider<UserService?>.value(value: _userService));
    providers.add(ChangeNotifierProvider<TableService?>.value(value: _tableService));
    providers.add(ChangeNotifierProvider<PaymentService?>.value(value: _paymentService));
    providers.add(ChangeNotifierProvider<PrintingService?>.value(value: _printingService));
    providers.add(ChangeNotifierProvider<EnhancedPrinterAssignmentService?>.value(value: _enhancedPrinterAssignmentService));
    providers.add(ChangeNotifierProvider<PrinterConfigurationService?>.value(value: _printerConfigurationService));
    providers.add(ChangeNotifierProvider<CrossPlatformPrinterSyncService?>.value(value: _crossPlatformPrinterSyncService));
    // Removed: AutoPrinterDiscoveryService provider (redundant)
    providers.add(ChangeNotifierProvider<EnhancedPrinterManager?>.value(value: _enhancedPrinterManager));
    providers.add(ChangeNotifierProvider<PrinterValidationService?>.value(value: _printerValidationService));
    providers.add(ChangeNotifierProvider<RobustKitchenService?>.value(value: _robustKitchenService));
    providers.add(ChangeNotifierProvider<FreeCloudPrintingService?>.value(value: _freeCloudPrintingService));
    
    return MultiProvider(
      providers: [
        ...providers,
        // Add DatabaseService provider (tenant database) - not a ChangeNotifier
        if (widget.authService.tenantDatabase != null)
          Provider<DatabaseService>.value(value: widget.authService.tenantDatabase!),
      ],
      child: MaterialApp(
        title: 'AI POS System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        navigatorKey: _navigatorKey,
        home: _buildMainScreen(),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Builder(
      builder: (context) {
        debugPrint('🔍 BUILD: isAuthenticated=${widget.authService.isAuthenticated}, servicesInitialized=$_servicesInitialized, userService=${_userService != null}');
        
        // Show authentication screen if not authenticated
        if (!widget.authService.isAuthenticated) {
          debugPrint('🔍 BUILD: Showing RestaurantAuthScreen');
          return const RestaurantAuthScreen();
        }
        
        // Show progress screen while services are initializing
        if (!_servicesInitialized) {
          debugPrint('🔍 BUILD: Showing InitializationProgressScreen');
          return InitializationProgressScreen(
            restaurantName: widget.authService.currentRestaurant?.name ?? 'Restaurant',
          );
        }
        
        // CRITICAL: Ensure ALL required services are available before showing main UI
        if (_userService == null || _tableService == null || _paymentService == null || _printerConfigurationService == null) {
          debugPrint('🔍 BUILD: Services not ready - userService=${_userService != null}, tableService=${_tableService != null}, paymentService=${_paymentService != null}, printerConfigService=${_printerConfigurationService != null}');
          return Scaffold(
            backgroundColor: Colors.blue.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Finalizing services...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Almost ready!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // ADDITIONAL CHECK: Validate that Provider services are actually accessible
        try {
          final orderService = Provider.of<OrderService>(context, listen: false);
          
          // Try to get UserService safely - now using nullable provider
          UserService? userService;
          try {
            userService = Provider.of<UserService?>(context, listen: false);
          } catch (e) {
            debugPrint('🔍 BUILD: UserService not available in Provider tree: $e');
          }
          
          final userCount = userService?.users.length ?? 0;
          final orderCount = orderService.allOrders.length;
          
          debugPrint('🔍 BUILD: Provider validation passed - Users: $userCount, Orders: $orderCount');
          
        } catch (e) {
          debugPrint('❌ BUILD: Provider services not accessible: $e');
          return Scaffold(
            backgroundColor: Colors.orange.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connecting services...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait a moment...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // All services are ready - show main screen with extra safety
        debugPrint('🔍 BUILD: All services ready, showing OrderTypeSelectionScreen');
        try {
          return const OrderTypeSelectionScreen();
        } catch (e, stackTrace) {
          debugPrint('❌ BUILD: Error showing OrderTypeSelectionScreen: $e');
          debugPrint('Stack trace: $stackTrace');
          
          // Fallback error screen
          return Scaffold(
            backgroundColor: Colors.red.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Application Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Retry initialization
                      _initializeServicesAfterAuth();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
