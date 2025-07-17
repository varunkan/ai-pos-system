import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/restaurant.dart';
import '../models/user.dart';
import 'database_service.dart';
import 'initialization_progress_service.dart';

/// Multi-tenant authentication service for restaurant POS system
/// Handles restaurant registration, user authentication, and session management
class MultiTenantAuthService extends ChangeNotifier {
  static MultiTenantAuthService? _instance;
  static final _uuid = const Uuid();
  
  // Current session
  RestaurantSession? _currentSession;
  Restaurant? _currentRestaurant;
  
  // Restaurant management
  final List<Restaurant> _registeredRestaurants = [];
  
  // Authentication state
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _lastError;
  
  // Database service for global restaurant data
  late DatabaseService _globalDb;
  DatabaseService? _tenantDb; // Current restaurant's database
  
  // Session management
  Timer? _sessionTimer;
  static const Duration sessionTimeout = Duration(hours: 8);
  
  // Progress service for initialization messages
  InitializationProgressService? _progressService;
  
  factory MultiTenantAuthService() {
    _instance ??= MultiTenantAuthService._internal();
    return _instance!;
  }
  
  MultiTenantAuthService._internal();
  
  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  RestaurantSession? get currentSession => _currentSession;
  Restaurant? get currentRestaurant => _currentRestaurant;
  List<Restaurant> get registeredRestaurants => List.unmodifiable(_registeredRestaurants);
  DatabaseService? get tenantDatabase => _tenantDb;
  
  /// Set progress service for initialization messages
  void setProgressService(InitializationProgressService progressService) {
    _progressService = progressService;
  }
  
  /// Add progress message
  void _addProgressMessage(String message) {
    _progressService?.addMessage(message);
    debugPrint(message);
  }
  
  /// Initialize the multi-tenant auth service
  Future<void> initialize() async {
    try {
      _addProgressMessage('🔐 Initializing Multi-Tenant Auth Service...');
      
      await _initializeGlobalDatabase();
      
      // Clear existing restaurants for fresh start (development mode)
      // await _clearAllRestaurantsForFreshStart();
      
      await _loadRegisteredRestaurants();
      
      // ALWAYS CLEAR SESSION DATA - NEVER AUTO-RESTORE
      _addProgressMessage('🧹 Clearing any existing session data...');
      await _clearSession();
      
      // Ensure we start fresh
      _currentSession = null;
      _currentRestaurant = null;
      _tenantDb = null;
      _isAuthenticated = false;
      
      _addProgressMessage('🚪 Fresh start - login required');
      
      _addProgressMessage('✅ Multi-Tenant Auth Service initialized');
    } catch (e) {
      _addProgressMessage('❌ Failed to initialize auth service: $e');
      _setError('Failed to initialize auth service: $e');
      rethrow; // Re-throw to see the actual error
    }
  }
  
  /// Initialize global database for restaurant management
  Future<void> _initializeGlobalDatabase() async {
    try {
      _addProgressMessage('📱 Initializing global database service for restaurant management...');
      
      _globalDb = DatabaseService();
      // Initialize with a specific global database name
      await _globalDb.initializeWithCustomName('global_restaurant_management');
      
      // Debug: Check if the database is properly initialized
      final db = await _globalDb.database;
      if (db != null) {
        _addProgressMessage('✅ Global database service initialized - database available');
        
        // Debug: Check the actual database path
        final dbPath = db.path;
        _addProgressMessage('🔍 Global database path: $dbPath');
        
        if (!dbPath.contains('global_restaurant_management')) {
          throw Exception('Global database path is incorrect: $dbPath');
        }
      } else {
        throw Exception('Global database is null after initialization');
      }
      
      // Create restaurants table
      await _createGlobalRestaurantTable();
      
    } catch (e) {
      _addProgressMessage('❌ Failed to initialize global database: $e');
      rethrow;
    }
  }
  
  /// Create global restaurant table for tenant management
  Future<void> _createGlobalRestaurantTable() async {
    if (kIsWeb) {
      // Web platform - use Hive storage
      _addProgressMessage('🌐 Global restaurant table initialized for web');
      return;
    }
    
    try {
      final db = await _globalDb.database;
      if (db == null) throw Exception('Global database not available');
      
      // Debug: Check which database we're actually using
      final dbPath = db.path;
      _addProgressMessage('🔍 Creating restaurants table in database: $dbPath');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restaurants (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          business_type TEXT NOT NULL,
          address TEXT NOT NULL,
          phone TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          admin_user_id TEXT NOT NULL UNIQUE,
          admin_password TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          database_name TEXT NOT NULL,
          settings TEXT NOT NULL DEFAULT '{}'
        )
      ''');
      
      // Debug: Verify the table was created
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='restaurants'"
      );
      
      if (tableExists.isNotEmpty) {
        _addProgressMessage('✅ Global restaurant table created successfully');
      } else {
        throw Exception('Restaurant table creation failed - table not found');
      }
    } catch (e) {
      _addProgressMessage('❌ Failed to create restaurant table: $e');
      rethrow;
    }
  }
  
  /// Clear all restaurants for fresh start (development helper)
  Future<void> _clearAllRestaurantsForFreshStart() async {
    try {
      _addProgressMessage('🧹 Clearing existing restaurants for fresh start...');
      
      if (!kIsWeb) {
        final db = await _globalDb.database;
        if (db != null) {
          await db.delete('restaurants');
          _addProgressMessage('🗑️ Cleared existing restaurants from database');
        }
      }
      
      _registeredRestaurants.clear();
      _addProgressMessage('✅ Fresh start - ready for new restaurant registration');
    } catch (e) {
      _addProgressMessage('⚠️ Could not clear existing restaurants: $e');
      // Continue anyway
    }
  }
  
  /// Load all registered restaurants
  Future<void> _loadRegisteredRestaurants() async {
    try {
      _registeredRestaurants.clear();
      
      if (kIsWeb) {
        // Web platform - load from Hive
        await _loadRestaurantsFromWeb();
      } else {
        // Mobile/Desktop - load from SQLite
        await _loadRestaurantsFromSQLite();
      }
      
      _addProgressMessage('📂 Loaded ${_registeredRestaurants.length} restaurants');
    } catch (e) {
      _addProgressMessage('❌ Failed to load restaurants: $e');
    }
  }
  
  /// Load restaurants from web storage
  Future<void> _loadRestaurantsFromWeb() async {
    // Implementation for web platform using Hive
    // This would load from global web storage
    _addProgressMessage('🌐 Loading restaurants from web storage...');
  }
  
  /// Load restaurants from SQLite
  Future<void> _loadRestaurantsFromSQLite() async {
    final db = await _globalDb.database;
    if (db == null) return;
    
    final results = await db.query('restaurants', where: 'is_active = ?', whereArgs: [1]);
    
    for (final row in results) {
      try {
        final restaurant = Restaurant.fromJson(row);
        _registeredRestaurants.add(restaurant);
      } catch (e) {
        _addProgressMessage('⚠️ Failed to parse restaurant: $e');
      }
    }
    
    // Ensure Oh Bombay Milton restaurant exists
    final ohBombayExists = _registeredRestaurants.any((r) => r.name == 'Oh Bombay Milton');
    if (!ohBombayExists) {
      await _createOhBombayMiltonRestaurant();
    }
  }
  
  /// Create Oh Bombay Milton restaurant for original functionality
  Future<void> _createOhBombayMiltonRestaurant() async {
    try {
      _addProgressMessage('🏪 Creating Oh Bombay Milton restaurant...');
      
      final success = await registerRestaurant(
        name: 'Oh Bombay Milton',
        businessType: 'Restaurant',
        address: '123 Main Street, Milton, ON',
        phone: '905-555-0123',
        email: 'ohbombaymilton@gmail.com',
        adminUserId: 'admin',
        adminPassword: 'admin1',
      );
      
      if (success) {
        _addProgressMessage('✅ Oh Bombay Milton restaurant created successfully');
      } else {
        _addProgressMessage('⚠️ Failed to create Oh Bombay Milton restaurant');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Error creating Oh Bombay Milton restaurant: $e');
    }
  }
  

  
  /// Register a new restaurant
  Future<bool> registerRestaurant({
    required String name,
    required String businessType,
    required String address,
    required String phone,
    required String email,
    required String adminUserId,
    required String adminPassword,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      _addProgressMessage('🏗️ Starting restaurant registration...');
      
      // Check for existing restaurant and clear it completely
      final existingRestaurant = _registeredRestaurants.where((r) => r.email == email || r.adminUserId == adminUserId).firstOrNull;
      if (existingRestaurant != null) {
        _addProgressMessage('🔧 Found existing restaurant registration, clearing it completely...');
        await _clearExistingRestaurant(existingRestaurant);
      }
      
      // Force clear all databases for fresh start
      await _clearAllDatabasesForFreshStart();
      
      // Generate unique IDs
      final restaurantId = _uuid.v4();
      final databaseName = 'restaurant_${restaurantId.replaceAll('-', '_').toLowerCase()}';
      final now = DateTime.now();
      
      // Hash password (in production, use proper hashing)
      final hashedPassword = _hashPassword(adminPassword);
      
      // Create restaurant object
      final restaurant = Restaurant(
        id: restaurantId,
        name: name.trim(),
        businessType: businessType.trim(),
        address: address.trim(),
        phone: phone.trim(),
        email: email.trim().toLowerCase(),
        adminUserId: adminUserId.trim(),
        adminPassword: hashedPassword,
        createdAt: now,
        updatedAt: now,
        databaseName: databaseName,
      );
      
      // Save to global database
      await _saveRestaurantToGlobal(restaurant);
      
      // Create tenant database with proper schema
      await _createTenantDatabase(restaurant, adminUserId, adminPassword);
      
      // Add to local list
      _registeredRestaurants.add(restaurant);
      
      _addProgressMessage('✅ Restaurant registered: ${restaurant.name}');
      notifyListeners();
      return true;
      
    } catch (e) {
      _addProgressMessage('❌ Restaurant registration failed: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Clear all databases for fresh start
  Future<void> _clearAllDatabasesForFreshStart() async {
    try {
      _addProgressMessage('🧹 Clearing all databases for fresh start...');
      
      // Clear global database
      if (!kIsWeb) {
        final db = await _globalDb.database;
        if (db != null) {
          await db.delete('restaurants');
          _addProgressMessage('🗑️ Cleared global restaurant database');
        }
      }
      
      // Clear registered restaurants list
      _registeredRestaurants.clear();
      
      _addProgressMessage('✅ All databases cleared for fresh start');
    } catch (e) {
      _addProgressMessage('⚠️ Could not clear all databases: $e');
      // Continue anyway
    }
  }
  
  /// Clear all existing restaurant registrations (for testing/debugging)
  Future<void> clearAllRestaurants() async {
    try {
      _addProgressMessage('🧹 Clearing all restaurant registrations...');
      
      // Clear from global database
      if (kIsWeb) {
        // Web platform cleanup
        _addProgressMessage('🌐 Clearing all restaurants from web storage');
      } else {
        // Mobile/Desktop cleanup
        final db = await _globalDb.database;
        if (db != null) {
          await db.delete('restaurants');
          _addProgressMessage('🗑️ Cleared all restaurants from global database');
        }
      }
      
      // Clear local list
      _registeredRestaurants.clear();
      
      _addProgressMessage('✅ All restaurant registrations cleared');
      notifyListeners();
    } catch (e) {
      _addProgressMessage('❌ Failed to clear all restaurants: $e');
      _setError('Failed to clear restaurants: $e');
    }
  }
  
  /// Clear existing restaurant registration
  Future<void> _clearExistingRestaurant(Restaurant restaurant) async {
    try {
      _addProgressMessage('🧹 Clearing existing restaurant: ${restaurant.name}');
      
      // Remove from global database
      if (kIsWeb) {
        // Web platform cleanup
        _addProgressMessage('🧹 Clearing restaurant from web storage: ${restaurant.name}');
      } else {
        // Mobile/Desktop cleanup
        final db = await _globalDb.database;
        if (db != null) {
          await db.delete('restaurants', where: 'id = ?', whereArgs: [restaurant.id]);
          _addProgressMessage('🗑️ Removed restaurant from global database');
        }
      }
      
      // Remove from local list
      _registeredRestaurants.removeWhere((r) => r.id == restaurant.id);
      
      _addProgressMessage('✅ Existing restaurant cleared: ${restaurant.name}');
    } catch (e) {
      _addProgressMessage('❌ Failed to clear existing restaurant: $e');
    }
  }
  
  /// Save restaurant to global database
  Future<void> _saveRestaurantToGlobal(Restaurant restaurant) async {
    if (kIsWeb) {
      // Web platform - save to Hive
      await _saveRestaurantToWeb(restaurant);
    } else {
      // Mobile/Desktop - save to SQLite
      await _saveRestaurantToSQLite(restaurant);
    }
  }
  
  /// Save restaurant to web storage
  Future<void> _saveRestaurantToWeb(Restaurant restaurant) async {
    // Implementation for web platform
    _addProgressMessage('🌐 Saving restaurant to web storage: ${restaurant.name}');
  }
  
  /// Save restaurant to SQLite
  Future<void> _saveRestaurantToSQLite(Restaurant restaurant) async {
    final db = await _globalDb.database;
    if (db == null) throw Exception('Global database not available');
    
    // Convert restaurant data to SQLite-compatible format
    final restaurantData = {
      'id': restaurant.id,
      'name': restaurant.name,
      'business_type': restaurant.businessType,
      'address': restaurant.address,
      'phone': restaurant.phone,
      'email': restaurant.email,
      'admin_user_id': restaurant.adminUserId,
      'admin_password': restaurant.adminPassword,
      'created_at': restaurant.createdAt.toIso8601String(),
      'updated_at': restaurant.updatedAt.toIso8601String(),
      'is_active': restaurant.isActive ? 1 : 0, // Convert boolean to integer for SQLite
      'database_name': restaurant.databaseName,
      'settings': jsonEncode(restaurant.settings ?? {}),
    };
    
    await db.insert('restaurants', restaurantData, conflictAlgorithm: ConflictAlgorithm.replace);
    _addProgressMessage('💾 Restaurant saved to SQLite database');
  }
  
  /// Create tenant database for restaurant
  Future<void> _createTenantDatabase(Restaurant restaurant, String adminUserId, String adminPassword) async {
    try {
      _addProgressMessage('🏗️ Creating tenant database: ${restaurant.databaseName}');
      
      // Create new database service for this tenant
      final tenantDb = DatabaseService();
      
      // Force reset the tenant database if it exists with schema issues
      await _forceResetTenantDatabase(restaurant.databaseName);
      
      // Force initialize with tenant-specific database name (ensures clean schema)
      await tenantDb.initializeWithCustomName(restaurant.databaseName);
      
      _addProgressMessage('✅ Tenant database created and initialized');
      
      // Verify the database schema is correct
      await _verifyTenantDatabaseSchema(tenantDb);
      
      // Create admin user in tenant database
      _addProgressMessage('👤 Creating admin user account...');
      
      final adminUser = User(
        id: adminUserId,
        name: 'Admin',
        role: UserRole.admin,
        pin: _hashPassword(adminPassword), // Use hashed password as pin
        isActive: true,
        adminPanelAccess: true, // Grant admin panel access
        createdAt: DateTime.now(),
      );
      
      // Use the User model's toJson method to ensure proper column mapping
      if (!kIsWeb) {
        final db = await tenantDb.database;
        if (db != null) {
          // Use the User model's toJson method for proper column mapping
          final userData = adminUser.toJson();
          
          _addProgressMessage('🔧 Inserting admin user with data: ${userData.keys.join(', ')}');
          
          await db.insert('users', userData, conflictAlgorithm: ConflictAlgorithm.replace);
          
          _addProgressMessage('✅ Admin user created successfully');
        }
      }
      
    } catch (e) {
      _addProgressMessage('❌ Failed to create tenant database: $e');
      
      // Try to recover by clearing the database and retrying
      await _recoverTenantDatabase(restaurant, adminUserId, adminPassword);
    }
  }
  
  /// Force reset the tenant database to ensure clean schema
  Future<void> _forceResetTenantDatabase(String databaseName) async {
    try {
      _addProgressMessage('🔧 Force resetting tenant database: $databaseName');
      
      if (kIsWeb) {
        _addProgressMessage('🌐 Database reset skipped for web platform');
        return;
      }
      
      // Get database path
      final dbPath = await getDatabasesPath();
      final fullPath = '$dbPath/$databaseName.db';
      
      // Delete the database file completely to ensure clean state
      try {
        await deleteDatabase(fullPath);
        _addProgressMessage('🗑️ Existing database file deleted: $fullPath');
      } catch (e) {
        _addProgressMessage('⚠️ Could not delete existing database (may not exist): $e');
      }
      
      // Wait a moment for file system to settle
      await Future.delayed(const Duration(milliseconds: 100));
      
      _addProgressMessage('✅ Tenant database reset completed');
    } catch (e) {
      _addProgressMessage('❌ Failed to reset tenant database: $e');
      throw Exception('Failed to reset tenant database: $e');
    }
  }
  
  /// Verify tenant database schema is correct
  Future<void> _verifyTenantDatabaseSchema(DatabaseService tenantDb) async {
    try {
      _addProgressMessage('🔍 Verifying tenant database schema...');
      
      if (kIsWeb) {
        _addProgressMessage('🌐 Schema verification skipped for web platform');
        return;
      }
      
      final db = await tenantDb.database;
      if (db == null) {
        throw Exception('Tenant database not available for schema verification');
      }
      
      // Check if users table has correct columns
      final tableInfo = await db.rawQuery("PRAGMA table_info(users)");
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();
      
      final requiredColumns = {'id', 'name', 'role', 'pin', 'is_active', 'admin_panel_access', 'created_at', 'last_login'};
      final missingColumns = requiredColumns.difference(columnNames);
      
      if (missingColumns.isNotEmpty) {
        throw Exception('Users table missing columns: ${missingColumns.join(', ')}');
      }
      
      _addProgressMessage('✅ Tenant database schema verified successfully');
    } catch (e) {
      _addProgressMessage('❌ Schema verification failed: $e');
      throw Exception('Tenant database schema is invalid: $e');
    }
  }
  
  /// Recover tenant database by recreating it
  Future<void> _recoverTenantDatabase(Restaurant restaurant, String adminUserId, String adminPassword) async {
    try {
      _addProgressMessage('🔄 Attempting tenant database recovery...');
      
      // Force reset the database
      await _forceResetTenantDatabase(restaurant.databaseName);
      
      // Create a new database service instance
      final tenantDb = DatabaseService();
      
      // Initialize with forced clean creation
      await tenantDb.initializeWithCustomName(restaurant.databaseName);
      
      // Verify schema
      await _verifyTenantDatabaseSchema(tenantDb);
      
      // Create admin user
      final adminUser = User(
        id: adminUserId,
        name: 'Admin',
        role: UserRole.admin,
        pin: _hashPassword(adminPassword),
        isActive: true,
        adminPanelAccess: true,
        createdAt: DateTime.now(),
      );
      
      if (!kIsWeb) {
        final db = await tenantDb.database;
        if (db != null) {
          final userData = adminUser.toJson();
          await db.insert('users', userData, conflictAlgorithm: ConflictAlgorithm.replace);
          _addProgressMessage('✅ Admin user created during recovery');
        }
      }
      
      _addProgressMessage('✅ Tenant database recovery completed successfully');
    } catch (e) {
      _addProgressMessage('❌ Tenant database recovery failed: $e');
      throw Exception('Failed to recover tenant database: $e');
    }
  }
  
  /// Authenticate restaurant user
  Future<bool> login({
    required String restaurantEmail,
    required String userId,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      _addProgressMessage('🔐 Authenticating user...');
      
      // Find restaurant
      final restaurant = _registeredRestaurants.firstWhere(
        (r) => r.email.toLowerCase() == restaurantEmail.toLowerCase(),
        orElse: () => throw Exception('Restaurant not found'),
      );
      
      _addProgressMessage('🏪 Found restaurant: ${restaurant.name}');
      
      // Verify admin credentials
      if (restaurant.adminUserId == userId && _verifyPassword(password, restaurant.adminPassword)) {
        // Create session for admin
        final session = RestaurantSession(
          restaurantId: restaurant.id,
          userId: userId,
          userName: 'Admin',
          userRole: UserRole.admin,
          loginTime: DateTime.now(),
          lastActivity: DateTime.now(),
        );
        
        await _createSession(restaurant, session);
        return true;
      }
      
      // Check other users in restaurant database
      await _connectToTenantDatabase(restaurant);
      
      if (_tenantDb != null) {
        final users = await _tenantDb!.query('users', 
          where: 'id = ? AND is_active = ?', 
          whereArgs: [userId, 1]);
        
        if (users.isNotEmpty) {
          final user = User.fromJson(users.first);
          
          // Verify password (in production, use proper password verification)
          if (_verifyPassword(password, user.pin)) {
            final session = RestaurantSession(
              restaurantId: restaurant.id,
              userId: user.id,
              userName: user.name,
              userRole: user.role,
              loginTime: DateTime.now(),
              lastActivity: DateTime.now(),
            );
            
            await _createSession(restaurant, session);
            return true;
          }
        }
      }
      
      throw Exception('Invalid credentials');
      
    } catch (e) {
      _addProgressMessage('❌ Login failed: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Create authenticated session
  Future<void> _createSession(Restaurant restaurant, RestaurantSession session) async {
    _currentRestaurant = restaurant;
    _currentSession = session;
    
    // Connect to tenant database
    await _connectToTenantDatabase(restaurant);
    
    _isAuthenticated = true;
    
    // Save session to preferences
    await _saveSession();
    
    // Clear the "explicitly closed" flag since user is now actively logged in
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_explicitly_closed', false);
      debugPrint('✅ Cleared app_explicitly_closed flag - session restoration enabled');
    } catch (e) {
      debugPrint('⚠️ Failed to clear app_explicitly_closed flag: $e');
    }
    
    // Start session timer
    _startSessionTimer();
    
    _addProgressMessage('✅ Session created for ${session.userName} at ${restaurant.name}');
    notifyListeners();
  }
  
  /// Connect to tenant database
  Future<void> _connectToTenantDatabase(Restaurant restaurant) async {
    try {
      _tenantDb = DatabaseService();
      await _tenantDb!.initializeWithCustomName(restaurant.databaseName);
      _addProgressMessage('✅ Connected to tenant database: ${restaurant.databaseName}');
    } catch (e) {
      _addProgressMessage('❌ Failed to connect to tenant database: $e');
      _tenantDb = null;
    }
  }
  
  /// Logout current user
  Future<void> logout() async {
    try {
      _addProgressMessage('🚪 Logging out user: ${_currentSession?.userName}');
      
      await _clearSession();
      
      _currentSession = null;
      _currentRestaurant = null;
      _tenantDb = null;
      _isAuthenticated = false;
      
      _stopSessionTimer();
      
      _addProgressMessage('✅ Logout completed');
      notifyListeners();
    } catch (e) {
      _addProgressMessage('❌ Logout failed: $e');
    }
  }
  
  /// Save current session to preferences
  Future<void> _saveSession() async {
    if (_currentSession == null || _currentRestaurant == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session', jsonEncode(_currentSession!.toJson()));
      await prefs.setString('current_restaurant', jsonEncode(_currentRestaurant!.toJson()));
    } catch (e) {
      _addProgressMessage('⚠️ Failed to save session: $e');
    }
  }
  
  /// Restore session from storage
  Future<void> _restoreSession() async {
    try {
      _addProgressMessage('🔄 Checking for existing session...');
      
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('current_session');
      final restaurantJson = prefs.getString('current_restaurant');
      
      if (sessionJson != null && restaurantJson != null) {
        try {
          // Restore from saved session
          final sessionData = jsonDecode(sessionJson);
          final restaurantData = jsonDecode(restaurantJson);
          
          _currentSession = RestaurantSession.fromJson(sessionData);
          _currentRestaurant = Restaurant.fromJson(restaurantData);
          
          // Validate that the restaurant still exists in our registered list
          final restaurantExists = _registeredRestaurants.any((r) => r.id == _currentRestaurant!.id);
          if (!restaurantExists) {
            _addProgressMessage('⚠️ Saved session refers to unregistered restaurant - clearing session');
            await _clearSession();
            _addProgressMessage('👤 No valid session found - login required');
            return;
          }
          
          // Connect to tenant database
          _tenantDb = DatabaseService();
          await _tenantDb!.initializeWithCustomName(_currentRestaurant!.databaseName);
          
          // Set as authenticated
          _isAuthenticated = true;
          
          _addProgressMessage('✅ Session restored for ${_currentRestaurant!.name}');
          notifyListeners();
          
          return;
        } catch (sessionError) {
          _addProgressMessage('⚠️ Session data corrupted - clearing session: $sessionError');
          await _clearSession();
        }
      }
      
      _addProgressMessage('👤 No existing session found - login required');
      
    } catch (e) {
      _addProgressMessage('❌ Session restoration failed: $e');
      debugPrint('Session restoration error: $e');
      
      // Clear any corrupted session data
      try {
        await _clearSession();
      } catch (clearError) {
        debugPrint('Failed to clear corrupted session data: $clearError');
      }
    }
  }
  
  /// Clear saved session
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session');
      await prefs.remove('current_restaurant');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to clear session: $e');
    }
  }
  
  /// Start session timeout timer
  void _startSessionTimer() {
    _stopSessionTimer();
    _sessionTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkSessionTimeout();
    });
  }
  
  /// Stop session timer
  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }
  
  /// Check if session has timed out
  void _checkSessionTimeout() {
    if (_currentSession == null) return;
    
    final now = DateTime.now();
    final lastActivity = _currentSession!.lastActivity ?? _currentSession!.loginTime;
    final timeSinceActivity = now.difference(lastActivity);
    
    if (timeSinceActivity > sessionTimeout) {
      _addProgressMessage('⏰ Session timeout - logging out');
      logout();
    }
  }
  
  /// Update session activity
  void updateActivity() {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(lastActivity: DateTime.now());
      _saveSession();
    }
  }
  
  /// Hash password (simplified - use proper hashing in production)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verify password
  bool _verifyPassword(String password, String hashedPassword) {
    return _hashPassword(password) == hashedPassword;
  }
  
  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Set error state
  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }
  
  /// Clear error state
  void _clearError() {
    _lastError = null;
    notifyListeners();
  }
  
  /// Get restaurant by email
  Restaurant? getRestaurantByEmail(String email) {
    try {
      return _registeredRestaurants.firstWhere(
        (r) => r.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Check if restaurant exists
  bool restaurantExists(String email) {
    return getRestaurantByEmail(email) != null;
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _stopSessionTimer();
    super.dispose();
  }
  
  /// Clear all saved session data (for development/testing)
  Future<void> clearSavedSession() async {
    try {
      _addProgressMessage('🧹 Clearing saved session data...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session');
      await prefs.remove('current_restaurant');
      
      // Reset authentication state
      _currentSession = null;
      _currentRestaurant = null;
      _tenantDb = null;
      _isAuthenticated = false;
      
      _stopSessionTimer();
      
      _addProgressMessage('✅ Session data cleared');
      notifyListeners();
    } catch (e) {
      _addProgressMessage('❌ Failed to clear session: $e');
    }
  }
  
  /// Force login screen - completely disable session restoration
  Future<void> forceLoginScreen() async {
    try {
      _addProgressMessage('🚪 Forcing login screen...');
      
      // Clear all session data
      await clearSavedSession();
      
      // Clear any additional session-related preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('restaurant_session');
      await prefs.setBool('app_explicitly_closed', true);
      
      _addProgressMessage('✅ Login screen forced - all session data cleared');
    } catch (e) {
      _addProgressMessage('❌ Failed to force login: $e');
    }
  }
} 