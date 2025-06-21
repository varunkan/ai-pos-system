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

  /// Creates the orders table.
  Future<void> _createOrdersTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        order_number TEXT NOT NULL,
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
  }

  /// Creates the order_items table.
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
        custom_properties TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        sent_to_kitchen INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id)
      )
    ''');
  }

  /// Creates the menu_items table.
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
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
} 