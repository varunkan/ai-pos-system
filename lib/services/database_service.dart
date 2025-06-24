import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  DatabaseException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'DatabaseException: $message${operation != null ? ' (Operation: $operation)' : ''}';
}

/// Service responsible for all database operations in the POS system.
/// 
/// This service provides a singleton pattern for database access and handles
/// all CRUD operations with proper error handling and transaction support.
class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'ai_pos_database.db';
  static const int _databaseVersion = 1;

  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Gets the database instance, initializing it if necessary.
  /// 
  /// Returns a [Database] instance that can be used for database operations.
  /// Throws [DatabaseException] if initialization fails.
  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      throw DatabaseException('Failed to initialize database', operation: 'get_database', originalError: e);
    }
  }

  /// Initializes the database with proper error handling.
  /// 
  /// Creates the database file and sets up all tables if they don't exist.
  /// Throws [DatabaseException] if initialization fails.
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      // Delete existing database for development (remove in production)
      // if (await databaseExists(path)) {
      //   await deleteDatabase(path);
      // }

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          // Enable foreign key constraints
          await db.execute('PRAGMA foreign_keys = ON');
          debugPrint('Database opened successfully with foreign keys enabled');
          
          // Perform schema migrations for existing databases
          await _performSchemaMigrations(db);
        },
      );
    } catch (e) {
      throw DatabaseException('Failed to initialize database', operation: 'init_database', originalError: e);
    }
  }

  /// Creates all database tables.
  /// 
  /// This method is called when the database is first created.
  /// Throws [DatabaseException] if table creation fails.
  Future<void> _onCreate(Database db, int version) async {
    try {
      debugPrint('Creating database tables...');
      
      // Create all tables in a transaction for consistency
      await db.transaction((txn) async {
        await _createOrdersTable(txn);
        await _createOrderItemsTable(txn);
        await _createMenuItemsTable(txn);
        await _createCategoriesTable(txn);
        await _createUsersTable(txn);
        await _createTablesTable(txn);
        await _createInventoryTable(txn);
        await _createCustomersTable(txn);
        await _createTransactionsTable(txn);
      });
      
      debugPrint('Database tables created successfully');
    } catch (e) {
      throw DatabaseException('Failed to create database tables', operation: 'create_tables', originalError: e);
    }
  }

  /// Creates the orders table with optimized indexes.
  Future<void> _createOrdersTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        order_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        type TEXT NOT NULL,
        table_id TEXT,
        user_id TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        customer_email TEXT,
        customer_address TEXT,
        special_instructions TEXT,
        subtotal REAL NOT NULL,
        tax_amount REAL NOT NULL,
        tip_amount REAL NOT NULL,
        hst_amount REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        gratuity_amount REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        payment_method TEXT,
        payment_status TEXT,
        payment_transaction_id TEXT,
        order_time TEXT NOT NULL,
        estimated_ready_time TEXT,
        actual_ready_time TEXT,
        served_time TEXT,
        completed_time TEXT,
        is_urgent INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        assigned_to TEXT,
        custom_fields TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Create performance indexes
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_type ON orders(type)');
    await db.execute('CREATE INDEX idx_orders_table_id ON orders(table_id)');
    await db.execute('CREATE INDEX idx_orders_user_id ON orders(user_id)');
    await db.execute('CREATE INDEX idx_orders_created_at ON orders(created_at DESC)');
    await db.execute('CREATE INDEX idx_orders_order_time ON orders(order_time DESC)');
    await db.execute('CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC)');
    await db.execute('CREATE INDEX idx_orders_urgent_priority ON orders(is_urgent DESC, priority DESC)');
  }

  /// Creates the order_items table with optimized indexes.
  Future<void> _createOrderItemsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        menu_item_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        selected_variant TEXT,
        selected_modifiers TEXT,
        special_instructions TEXT,
        notes TEXT,
        custom_properties TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        sent_to_kitchen INTEGER NOT NULL DEFAULT 0,
        kitchen_status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id)
      )
    ''');
    
    // Performance indexes for order items
    await db.execute('CREATE INDEX idx_order_items_order_id ON order_items(order_id)');
    await db.execute('CREATE INDEX idx_order_items_menu_item_id ON order_items(menu_item_id)');
    await db.execute('CREATE INDEX idx_order_items_kitchen_status ON order_items(kitchen_status)');
    await db.execute('CREATE INDEX idx_order_items_sent_to_kitchen ON order_items(sent_to_kitchen)');
  }

  /// Creates the menu_items table with optimized indexes.
  Future<void> _createMenuItemsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        category_id TEXT NOT NULL,
        image_url TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        tags TEXT,
        custom_properties TEXT,
        variants TEXT,
        modifiers TEXT,
        nutritional_info TEXT,
        allergens TEXT,
        preparation_time INTEGER NOT NULL DEFAULT 0,
        is_vegetarian INTEGER NOT NULL DEFAULT 0,
        is_vegan INTEGER NOT NULL DEFAULT 0,
        is_gluten_free INTEGER NOT NULL DEFAULT 0,
        is_spicy INTEGER NOT NULL DEFAULT 0,
        spice_level INTEGER NOT NULL DEFAULT 0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        popularity_score REAL DEFAULT 0.0,
        last_ordered TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Performance indexes for menu items
    await db.execute('CREATE INDEX idx_menu_items_category_id ON menu_items(category_id)');
    await db.execute('CREATE INDEX idx_menu_items_available ON menu_items(is_available)');
    await db.execute('CREATE INDEX idx_menu_items_name ON menu_items(name)');
    await db.execute('CREATE INDEX idx_menu_items_popularity ON menu_items(popularity_score DESC)');
    await db.execute('CREATE INDEX idx_menu_items_stock ON menu_items(stock_quantity)');
    await db.execute('CREATE INDEX idx_menu_items_price ON menu_items(price)');
  }

  /// Creates the categories table.
  Future<void> _createCategoriesTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the users table.
  Future<void> _createUsersTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        pin TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        last_login TEXT
      )
    ''');
  }

  /// Creates the tables table.
  Future<void> _createTablesTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE tables (
        id TEXT PRIMARY KEY,
        number INTEGER NOT NULL,
        capacity INTEGER NOT NULL,
        status TEXT NOT NULL,
        user_id TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        customer_email TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the inventory table.
  Future<void> _createInventoryTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        current_stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER NOT NULL DEFAULT 0,
        max_stock INTEGER,
        cost_price REAL NOT NULL DEFAULT 0.0,
        selling_price REAL,
        unit TEXT NOT NULL,
        supplier_id TEXT,
        category TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_updated TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the customers table.
  Future<void> _createCustomersTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        loyalty_points INTEGER NOT NULL DEFAULT 0,
        join_date TEXT NOT NULL,
        preferences TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the transactions table.
  Future<void> _createTransactionsTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'USD',
        payment_method TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        transaction_id TEXT,
        gateway_response TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id)
      )
    ''');
  }

  /// Handles database upgrades.
  /// 
  /// This method is called when the database version is increased.
  /// Add migration logic here when needed.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');
    // Add migration logic here when needed
  }

  /// Inserts a new record into the specified table.
  /// 
  /// [table] is the table name to insert into.
  /// [data] is the data to insert.
  /// Returns the ID of the inserted record.
  /// Throws [DatabaseException] if the operation fails.
  Future<int> insert(String table, Map<String, dynamic> data) async {
    try {
      final db = await database;
      return await db.insert(table, data);
    } catch (e) {
      throw DatabaseException('Failed to insert into $table', operation: 'insert', originalError: e);
    }
  }

  /// Queries records from the specified table.
  /// 
  /// [table] is the table name to query from.
  /// All other parameters are optional query constraints.
  /// Returns a list of records as maps.
  /// Throws [DatabaseException] if the operation fails.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      return await db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw DatabaseException('Failed to query from $table', operation: 'query', originalError: e);
    }
  }

  /// Updates records in the specified table.
  /// 
  /// [table] is the table name to update.
  /// [data] is the data to update.
  /// [where] and [whereArgs] specify which records to update.
  /// Returns the number of updated records.
  /// Throws [DatabaseException] if the operation fails.
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.update(table, data, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw DatabaseException('Failed to update $table', operation: 'update', originalError: e);
    }
  }

  /// Deletes records from the specified table.
  /// 
  /// [table] is the table name to delete from.
  /// [where] and [whereArgs] specify which records to delete.
  /// Returns the number of deleted records.
  /// Throws [DatabaseException] if the operation fails.
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final db = await database;
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw DatabaseException('Failed to delete from $table', operation: 'delete', originalError: e);
    }
  }

  /// Closes the database connection.
  /// 
  /// This should be called when the app is shutting down.
  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        debugPrint('Database connection closed');
      }
    } catch (e) {
      throw DatabaseException('Failed to close database', operation: 'close', originalError: e);
    }
  }

  /// Clears all data from all tables.
  /// 
  /// This is useful for development/testing purposes.
  /// Use with caution in production.
  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('orders');
        await txn.delete('order_items');
        await txn.delete('menu_items');
        await txn.delete('categories');
        await txn.delete('users');
        await txn.delete('tables');
        await txn.delete('inventory');
        await txn.delete('customers');
        await txn.delete('transactions');
      });
      debugPrint('All data cleared from database');
    } catch (e) {
      throw DatabaseException('Failed to clear all data', operation: 'clear_all_data', originalError: e);
    }
  }

  /// Gets the count of records in each table.
  /// 
  /// Returns a map of table names to record counts.
  /// Useful for debugging and monitoring.
  Future<Map<String, int>> getTableCounts() async {
    try {
      final db = await database;
      final tables = ['orders', 'menu_items', 'categories', 'users', 'tables', 'inventory', 'customers'];
      final counts = <String, int>{};
      
      for (final table in tables) {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        counts[table] = result.first['count'] as int;
      }
      
      return counts;
    } catch (e) {
      throw DatabaseException('Failed to get table counts', operation: 'get_table_counts', originalError: e);
    }
  }

  /// Optimized batch query for order with items (eliminates N+1 problem)
  Future<List<Map<String, dynamic>>> getOrdersWithItems({
    String? whereClause,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    try {
      final db = await database;
      
      // Check if notes and kitchen_status columns exist in order_items table
      bool hasNotesColumn = false;
      bool hasKitchenStatusColumn = false;
      try {
        final columns = await db.rawQuery("PRAGMA table_info(order_items)");
        hasNotesColumn = columns.any((col) => col['name'] == 'notes');
        hasKitchenStatusColumn = columns.any((col) => col['name'] == 'kitchen_status');
        
        // Add missing columns if they don't exist
        if (!hasNotesColumn) {
          await db.execute('ALTER TABLE order_items ADD COLUMN notes TEXT');
          debugPrint('Added notes column to order_items table');
        }
        if (!hasKitchenStatusColumn) {
          await db.execute('ALTER TABLE order_items ADD COLUMN kitchen_status TEXT DEFAULT "pending"');
          debugPrint('Added kitchen_status column to order_items table');
        }
      } catch (e) {
        debugPrint('Warning: Could not check/add columns: $e');
      }
      
      // Build query with conditional column selection
      final notesSelect = hasNotesColumn ? 'oi.notes,' : 'NULL as notes,';
      final kitchenStatusSelect = hasKitchenStatusColumn ? 'oi.kitchen_status,' : '"pending" as kitchen_status,';
      
      final query = '''
        SELECT 
          o.*,
          oi.id as item_id,
          oi.quantity,
          oi.unit_price,
          oi.total_price,
          oi.selected_variant,
          oi.selected_modifiers,
          oi.special_instructions,
          $notesSelect
          oi.custom_properties,
          oi.is_available as item_available,
          oi.sent_to_kitchen,
          $kitchenStatusSelect
          oi.created_at as item_created_at,
          mi.name as menu_item_name,
          mi.description as menu_item_description,
          mi.price as menu_item_price,
          mi.category_id as menu_item_category_id,
          mi.image_url as menu_item_image_url,
          mi.is_available as menu_item_available,
          mi.preparation_time,
          mi.is_vegetarian,
          mi.is_vegan,
          mi.is_gluten_free,
          mi.is_spicy,
          mi.spice_level
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN menu_items mi ON oi.menu_item_id = mi.id
        ${whereClause != null ? 'WHERE $whereClause' : ''}
        ${orderBy != null ? 'ORDER BY $orderBy' : 'ORDER BY o.created_at DESC'}
        ${limit != null ? 'LIMIT $limit' : ''}
      ''';
      
      return await db.rawQuery(query, whereArgs);
    } catch (e) {
      throw DatabaseException('Failed to get orders with items', operation: 'get_orders_with_items', originalError: e);
    }
  }

  /// Optimized analytics queries
  Future<Map<String, dynamic>> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final db = await database;
      final start = startDate?.toIso8601String() ?? DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final end = endDate?.toIso8601String() ?? DateTime.now().toIso8601String();
      
      // Single query for comprehensive analytics
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_orders,
          SUM(total_amount) as total_revenue,
          AVG(total_amount) as avg_order_value,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_orders,
          COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders,
          COUNT(CASE WHEN type = 'dineIn' THEN 1 END) as dine_in_orders,
          COUNT(CASE WHEN type = 'takeaway' THEN 1 END) as takeaway_orders,
          COUNT(CASE WHEN type = 'delivery' THEN 1 END) as delivery_orders,
          MIN(order_time) as first_order,
          MAX(order_time) as last_order
        FROM orders 
        WHERE created_at BETWEEN ? AND ?
      ''', [start, end]);
      
      return result.first;
    } catch (e) {
      throw DatabaseException('Failed to get analytics data', operation: 'get_analytics', originalError: e);
    }
  }

  /// Get popular menu items with performance metrics
  Future<List<Map<String, dynamic>>> getPopularMenuItems({int limit = 10}) async {
    try {
      final db = await database;
      
      return await db.rawQuery('''
        SELECT 
          mi.id,
          mi.name,
          mi.price,
          mi.category_id,
          COUNT(oi.id) as order_count,
          SUM(oi.quantity) as total_quantity,
          SUM(oi.total_price) as total_revenue,
          AVG(oi.quantity) as avg_quantity_per_order,
          mi.preparation_time,
          mi.popularity_score
        FROM menu_items mi
        LEFT JOIN order_items oi ON mi.id = oi.menu_item_id
        LEFT JOIN orders o ON oi.order_id = o.id
        WHERE o.status = 'completed' AND o.created_at >= date('now', '-30 days')
        GROUP BY mi.id, mi.name, mi.price, mi.category_id
        ORDER BY order_count DESC, total_revenue DESC
        LIMIT ?
      ''', [limit]);
    } catch (e) {
      throw DatabaseException('Failed to get popular menu items', operation: 'get_popular_items', originalError: e);
    }
  }

  /// Performs schema migrations for existing databases
  /// This ensures compatibility with databases created before schema updates
  static bool _migrationInProgress = false;
  static final Set<String> _completedMigrations = {};
  
  Future<void> _performSchemaMigrations(Database db) async {
    if (_migrationInProgress) {
      return;
    }
    
    _migrationInProgress = true;
    try {
      // Migration 1: Add missing columns to order_items table
      if (!_completedMigrations.contains('order_items_columns')) {
        final orderItemsColumns = await db.rawQuery("PRAGMA table_info(order_items)");
        final columnNames = orderItemsColumns.map((col) => col['name'] as String).toSet();
        
        if (!columnNames.contains('notes')) {
          await db.execute('ALTER TABLE order_items ADD COLUMN notes TEXT');
          debugPrint('✅ Added notes column to order_items table');
        }
        
        if (!columnNames.contains('kitchen_status')) {
          await db.execute('ALTER TABLE order_items ADD COLUMN kitchen_status TEXT DEFAULT "pending"');
          debugPrint('✅ Added kitchen_status column to order_items table');
        }
        
        // Update existing items to have proper kitchen_status
        await db.execute('''
          UPDATE order_items 
          SET kitchen_status = CASE 
            WHEN sent_to_kitchen = 1 THEN 'preparing' 
            ELSE 'pending' 
          END 
          WHERE kitchen_status IS NULL OR kitchen_status = ''
        ''');
        
        _completedMigrations.add('order_items_columns');
      }
      
    } catch (e) {
      debugPrint('⚠️ Warning: Could not complete schema migrations: $e');
    } finally {
      _migrationInProgress = false;
    }
  }
} 