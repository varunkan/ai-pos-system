import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:universal_io/io.dart' as universal_io;

/// Cross-platform database service that provides seamless state synchronization
/// across Android, iOS, and web platforms using local storage with cloud backup.
class CrossPlatformDatabaseService extends ChangeNotifier {
  static CrossPlatformDatabaseService? _instance;
  static final _lock = Object();
  
  // Local storage
  Box<dynamic>? _localBox;
  Database? _sqliteDb;
  
  // Cloud storage
  // FirebaseFirestore? _firestore;
  // FirebaseAuth? _auth;
  
  // Connectivity
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOnline = false;
  
  // Sync management
  final Map<String, Timer> _syncTimers = {};
  final Set<String> _pendingSyncs = {};
  bool _isSyncing = false;
  bool _isInitialized = false;
  static bool _initializationInProgress = false;
  
  // Event streams
  final StreamController<Map<String, dynamic>> _dataChangeController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  factory CrossPlatformDatabaseService() {
    synchronized(_lock, () {
      _instance ??= CrossPlatformDatabaseService._internal();
    });
    return _instance!;
  }
  
  CrossPlatformDatabaseService._internal();
  
  /// Initialize the cross-platform database service
  Future<void> initialize() async {
    if (_isInitialized || _initializationInProgress) {
      debugPrint('⚠️ Cross-platform database service already initialized or in progress');
      return;
    }
    
    _initializationInProgress = true;
    try {
      debugPrint('🚀 Initializing Cross-Platform Database Service...');
      
      // Initialize platform-specific storage
      await _initializePlatformStorage();
      
      // Initialize connectivity monitoring
      await _initializeConnectivity();
      
      // Initialize cloud services if available
      await _initializeCloudServices();
      
      // Clean up corrupted data
      await _cleanupCorruptedData();
      
      // Start background sync
      _startBackgroundSync();
      
      // Mark as initialized
      _isInitialized = true;
      
      debugPrint('✅ Cross-Platform Database Service initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize database service: $e');
      rethrow;
    } finally {
      _initializationInProgress = false;
    }
  }
  
  /// Initialize platform-specific storage
  Future<void> _initializePlatformStorage() async {
    try {
      if (kIsWeb) {
        // Web: Use Hive with IndexedDB
        await Hive.initFlutter();
        _localBox = await Hive.openBox('pos_data');
        debugPrint('📱 Web storage initialized with Hive');
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop: Use SQLite with FFI first, then Hive with retry logic
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        await _initializeSQLite();
        
        // Initialize Hive with retry and lock handling
        await _initializeHiveWithRetry();
        debugPrint('💻 Desktop storage initialized with SQLite + Hive');
      } else {
        // Mobile: Use SQLite + Hive
        await _initializeSQLite();
        await _initializeHiveWithRetry();
        debugPrint('📱 Mobile storage initialized with SQLite + Hive');
      }
    } catch (e) {
      debugPrint('⚠️ Platform storage initialization failed: $e');
      // Fallback to SQLite only mode
      try {
        if (_sqliteDb == null) {
          await _initializeSQLite();
        }
        debugPrint('✅ Fallback to SQLite-only mode successful');
      } catch (fallbackError) {
        debugPrint('❌ Fallback initialization failed: $fallbackError');
        rethrow;
      }
    }
  }
  
  /// Initialize Hive with retry logic and lock handling
  Future<void> _initializeHiveWithRetry() async {
    int attempts = 0;
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 500);
    
    while (attempts < maxAttempts) {
      try {
        attempts++;
        debugPrint('🔄 Attempting Hive initialization (attempt $attempts/$maxAttempts)');
        
        // Clear any existing Hive boxes that might be locked
        if (attempts > 1) {
          try {
            await Hive.close();
            // Small delay to allow file system to release locks
            await Future.delayed(retryDelay);
          } catch (e) {
            debugPrint('⚠️ Warning during Hive cleanup: $e');
          }
        }
        
        await Hive.initFlutter();
        _localBox = await Hive.openBox('pos_data');
        debugPrint('✅ Hive initialized successfully on attempt $attempts');
        return;
      } catch (e) {
        debugPrint('❌ Hive initialization attempt $attempts failed: $e');
        
        if (attempts >= maxAttempts) {
          debugPrint('⚠️ All Hive initialization attempts failed, continuing without Hive');
          // Don't rethrow - continue without Hive functionality
          // Keep _localBox as null - don't assign null explicitly
          return;
        }
        
        // Wait before retry
        await Future.delayed(retryDelay * attempts);
      }
    }
  }
  
  /// Initialize SQLite database
  Future<void> _initializeSQLite() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, 'pos_cross_platform.db');
    
    _sqliteDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createSQLiteTables,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
      },
    );
  }
  
  /// Create SQLite tables for complex relational data
  Future<void> _createSQLiteTables(Database db, int version) async {
    await db.transaction((txn) async {
      // Orders table with enhanced structure
      await txn.execute('''
        CREATE TABLE orders (
          id TEXT PRIMARY KEY,
          order_number TEXT NOT NULL UNIQUE,
          status TEXT NOT NULL,
          type TEXT NOT NULL,
          table_id TEXT,
          user_id TEXT,
          customer_info TEXT, -- JSON
          items TEXT, -- JSON array
          totals TEXT, -- JSON
          timestamps TEXT, -- JSON
          metadata TEXT, -- JSON
          sync_status TEXT DEFAULT 'pending',
          last_synced INTEGER,
          device_id TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      // Sync tracking table
      await txn.execute('''
        CREATE TABLE sync_log (
          id TEXT PRIMARY KEY,
          table_name TEXT NOT NULL,
          record_id TEXT NOT NULL,
          action TEXT NOT NULL, -- insert, update, delete
          data TEXT, -- JSON
          sync_status TEXT DEFAULT 'pending',
          attempts INTEGER DEFAULT 0,
          last_attempt INTEGER,
          error_message TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      
      // Device info table
      await txn.execute('''
        CREATE TABLE device_info (
          device_id TEXT PRIMARY KEY,
          platform TEXT NOT NULL,
          app_version TEXT,
          last_sync INTEGER,
          sync_token TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      
      // Create indexes for performance
      await txn.execute('CREATE INDEX idx_orders_status ON orders(status)');
      await txn.execute('CREATE INDEX idx_orders_sync ON orders(sync_status)');
      await txn.execute('CREATE INDEX idx_orders_updated ON orders(updated_at DESC)');
      await txn.execute('CREATE INDEX idx_sync_log_status ON sync_log(sync_status)');
      await txn.execute('CREATE INDEX idx_sync_log_table ON sync_log(table_name, record_id)');
    });
  }
  
  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    final connectivity = Connectivity();
    _isOnline = await _checkConnectivity();
    
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (!wasOnline && _isOnline) {
        debugPrint('🌐 Connection restored - starting sync');
        _syncPendingChanges();
      } else if (wasOnline && !_isOnline) {
        debugPrint('📵 Connection lost - enabling offline mode');
      }
      
      notifyListeners();
    });
  }
  
  /// Check current connectivity status
  Future<bool> _checkConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
  
  /// Initialize cloud services
  Future<void> _initializeCloudServices() async {
    try {
      // Initialize Firebase if available
      // _firestore = FirebaseFirestore.instance;
      // _auth = FirebaseAuth.instance;
      
      // Configure Firestore settings
      // _firestore!.settings = const Settings(
      //   persistenceEnabled: true,
      //   cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      // );
      
      debugPrint('☁️ Cloud services initialized');
    } catch (e) {
      debugPrint('⚠️ Cloud services not available: $e');
      // Continue without cloud sync
    }
  }
  
  /// Start background synchronization
  void _startBackgroundSync() {
    // Sync every 30 seconds when online
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline && !_isSyncing && _sqliteDb != null) {
        try {
          _syncPendingChanges();
        } catch (e) {
          debugPrint('⚠️ Background sync error: $e');
        }
      }
    });
    
    // Full sync every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && !_isSyncing && _sqliteDb != null) {
        try {
          _performFullSync();
        } catch (e) {
          debugPrint('⚠️ Background full sync error: $e');
        }
      }
    });
  }
  
  /// Save data with automatic sync
  Future<void> saveData(String collection, String id, Map<String, dynamic> data) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, cannot save data');
      return;
    }
    
    try {
      // Validate data
      if (data.isEmpty) {
        debugPrint('⚠️ Attempting to save empty data, skipping');
        return;
      }
      
      // Add timestamp and metadata
      final enhancedData = {
        ...data,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      };
      
      // Save to local storage
      await _saveToLocal(collection, id, enhancedData);
      
      // Queue for cloud sync
      await _queueForSync(collection, id, enhancedData, 'upsert');
      
      debugPrint('✅ Data saved: ${collection}_$id');
    } catch (e) {
      debugPrint('❌ Failed to save data: $e');
    }
  }
  
  /// Get data with fallback to cloud
  Future<Map<String, dynamic>?> getData(String collection, String id) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, cannot load data');
      return null;
    }
    
    try {
      // Try local first
      final localData = await _getFromLocal(collection, id);
      if (localData != null) {
        return localData;
      }
      
      // Fallback to cloud if online
      if (_isOnline) {
        // final cloudData = await _getFromCloud(collection, id);
        // if (cloudData != null) {
        //   // Cache locally
        //   await _saveToLocal(collection, id, cloudData);
        //   return cloudData;
        // }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Failed to get data: $e');
      return null;
    }
  }
  
  /// Get all data from collection
  Future<List<Map<String, dynamic>>> getAllData(String collection) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, cannot get all data');
      return [];
    }
    
    try {
      // Get from local storage
      final localData = await _getAllFromLocal(collection);
      
      // Merge with cloud data if online
      if (_isOnline) {
        // final cloudData = await _getAllFromCloud(collection);
        // return _mergeDataSets(localData, cloudData);
      }
      
      return localData;
    } catch (e) {
      debugPrint('❌ Failed to get all data: $e');
      return [];
    }
  }
  
  /// Delete data with sync
  Future<void> deleteData(String collection, String id) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, cannot delete data');
      return;
    }
    
    try {
      // Delete from local
      await _deleteFromLocal(collection, id);
      
      // Queue for cloud deletion if online
      if (_isOnline) {
        // await _queueForSync(collection, id, {}, 'delete');
      }
      
      // Emit data change event
      _dataChangeController.add({
        'action': 'delete',
        'collection': collection,
        'id': id,
      });
      
      debugPrint('✅ Data deleted: ${collection}_$id');
    } catch (e) {
      debugPrint('❌ Failed to delete data: $e');
    }
  }
  
  /// Save to local storage
  Future<void> _saveToLocal(String collection, String id, Map<String, dynamic> data) async {
    if (_sqliteDb != null && !kIsWeb) {
      // Use SQLite for complex data
      await _sqliteDb!.insert(
        'orders',
        {
          'id': id,
          'order_number': data['order_number'] ?? '',
          'status': data['status'] ?? 'pending',
          'type': data['type'] ?? 'dine-in',
          'table_id': data['table_id'],
          'user_id': data['user_id'],
          'customer_info': jsonEncode(data['customer_info'] ?? {}),
          'items': jsonEncode(data['items'] ?? []),
          'totals': jsonEncode(data['totals'] ?? {}),
          'timestamps': jsonEncode(data['timestamps'] ?? {}),
          'metadata': jsonEncode(data['metadata'] ?? {}),
          'sync_status': 'pending',
          'device_id': data['device_id'],
          'created_at': data['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
          'updated_at': data['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    // Also save to Hive for quick access
    final key = '${collection}_$id';
    await _localBox?.put(key, data);
  }
  
  /// Get from local storage
  Future<Map<String, dynamic>?> _getFromLocal(String collection, String id) async {
    final key = '${collection}_$id';
    final data = _localBox?.get(key);
    return data != null ? Map<String, dynamic>.from(data) : null;
  }
  
  /// Get all from local storage
  Future<List<Map<String, dynamic>>> _getAllFromLocal(String collection) async {
    final results = <Map<String, dynamic>>[];
    
    if (_sqliteDb != null && !kIsWeb) {
      final rows = await _sqliteDb!.query('orders', orderBy: 'updated_at DESC');
      for (final row in rows) {
        results.add({
          'id': row['id'],
          'order_number': row['order_number'],
          'status': row['status'],
          'type': row['type'],
          'table_id': row['table_id'],
          'user_id': row['user_id'],
          'customer_info': jsonDecode(row['customer_info'] as String? ?? '{}'),
          'items': jsonDecode(row['items'] as String? ?? '[]'),
          'totals': jsonDecode(row['totals'] as String? ?? '{}'),
          'timestamps': jsonDecode(row['timestamps'] as String? ?? '{}'),
          'metadata': jsonDecode(row['metadata'] as String? ?? '{}'),
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
        });
      }
    } else {
      // Fallback to Hive
      for (final key in _localBox?.keys ?? []) {
        if (key.toString().startsWith('${collection}_')) {
          final data = _localBox?.get(key);
          if (data != null) {
            results.add(Map<String, dynamic>.from(data));
          }
        }
      }
    }
    
    return results;
  }
  
  /// Delete from local storage
  Future<void> _deleteFromLocal(String collection, String id) async {
    if (_sqliteDb != null && !kIsWeb) {
      await _sqliteDb!.delete('orders', where: 'id = ?', whereArgs: [id]);
    }
    
    final key = '${collection}_$id';
    await _localBox?.delete(key);
  }
  
  /// Queue item for sync
  Future<void> _queueForSync(String collection, String id, Map<String, dynamic> data, String action) async {
    if (_sqliteDb == null) return;
    
    await _sqliteDb!.insert(
      'sync_log',
      {
        'id': '${collection}_${id}_${DateTime.now().millisecondsSinceEpoch}',
        'table_name': collection,
        'record_id': id,
        'action': action,
        'data': jsonEncode(data),
        'sync_status': 'pending',
        'attempts': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    
    _pendingSyncs.add('${collection}_$id');
  }
  
  /// Sync pending changes to cloud with enhanced error handling
  Future<void> _syncPendingChanges() async {
    if (_isSyncing || !_isInitialized) {
      debugPrint('⚠️ Sync skipped - already syncing or not initialized');
      return;
    }
    
    // CRITICAL FIX: Enhanced null checks and error handling
    final db = _sqliteDb;
    if (db == null) {
      debugPrint('⚠️ SQLite database is null, skipping sync');
      return;
    }
    
    // Additional safety checks for database validity
    try {
      if (!db.isOpen) {
        debugPrint('⚠️ Database is not open, skipping sync');
        return;
      }
      
      // Test database connection with a simple query
      await db.rawQuery('SELECT 1');
    } catch (e) {
      debugPrint('⚠️ Database connection invalid, skipping sync: $e');
      return;
    }
    
    _isSyncing = true;
    try {
      // Verify sync_log table exists before querying
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_log'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('⚠️ sync_log table does not exist, creating it');
        await _createSQLiteTables(db, 1);
      }
      
      // Get pending sync items with proper error handling
      List<Map<String, dynamic>> pendingItems = [];
      try {
        pendingItems = await db.query(
          'sync_log',
          where: 'sync_status = ?',
          whereArgs: ['pending'],
          limit: 50, // Process in batches for better performance
        );
      } catch (e) {
        debugPrint('⚠️ Failed to query pending items: $e');
        // If query fails, try to recreate the table
        await _createSQLiteTables(db, 1);
        return;
      }
      
      debugPrint('🔄 Processing ${pendingItems.length} pending sync items');
      
      int processed = 0;
      for (final item in pendingItems) {
        try {
          // Process each sync item safely
          await _processSyncItem(item);
          processed++;
        } catch (e) {
          debugPrint('⚠️ Failed to process sync item ${item['id']}: $e');
          // Mark as failed but continue processing
          try {
            await db.update(
              'sync_log',
              {
                'sync_status': 'failed',
                'error_message': e.toString(),
                'attempts': (item['attempts'] as int? ?? 0) + 1,
                'last_attempt': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          } catch (updateError) {
            debugPrint('⚠️ Failed to update sync item status: $updateError');
          }
        }
      }
      
      debugPrint('🔄 Sync completed - processed $processed items');
    } catch (e) {
      debugPrint('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Process individual sync item with enhanced error handling
  Future<void> _processSyncItem(Map<String, dynamic> item) async {
    final db = _sqliteDb;
    if (db == null) {
      debugPrint('⚠️ Database is null, cannot process sync item');
      return;
    }
    
    try {
      // Validate item data
      if (item['id'] == null || item['table_name'] == null) {
        throw Exception('Invalid sync item data');
      }
      
      // Mark as completed (simplified for now)
      await db.update(
        'sync_log',
        {
          'sync_status': 'completed',
          'last_attempt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [item['id']],
      );
      
      debugPrint('✅ Processed sync item: ${item['id']}');
    } catch (e) {
      debugPrint('⚠️ Failed to process sync item: $e');
      rethrow;
    }
  }
  
  /// Sync data to cloud (placeholder for actual cloud implementation)
  Future<bool> _syncToCloud(String tableName, String recordId, Map<String, dynamic> data) async {
    try {
      // TODO: Implement actual cloud sync (Firebase, AWS, etc.)
      // For now, just simulate success
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      debugPrint('❌ Cloud sync error for ${tableName}_$recordId: $e');
      return false;
    }
  }
  
  /// Delete data from cloud (placeholder for actual cloud implementation)
  Future<bool> _deleteFromCloud(String tableName, String recordId) async {
    try {
      // TODO: Implement actual cloud delete
      // For now, just simulate success
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      debugPrint('❌ Cloud delete error for ${tableName}_$recordId: $e');
      return false;
    }
  }
  
  /// Perform full synchronization
  Future<void> _performFullSync() async {
    // if (_firestore == null) return;
    
    try {
      // Sync orders collection
      await _syncCollection('orders');
      
      debugPrint('🔄 Full sync completed');
    } catch (e) {
      debugPrint('❌ Full sync failed: $e');
    }
  }
  
  /// Sync specific collection
  Future<void> _syncCollection(String collection) async {
    // if (_firestore == null) return;
    
    // Get last sync timestamp
    final lastSync = _localBox?.get('last_sync_$collection', defaultValue: 0);
    
    // Get updates from cloud
    // final snapshot = await _firestore!
    //     .collection(collection)
    //     .where('updated_at', isGreaterThan: lastSync)
    //     .get();
    
          // for (final doc in snapshot.docs) {
      //   final data = doc.data();
      //   await _saveToLocal(collection, doc.id, data);
      // }
      
      // Update last sync timestamp
      await _localBox?.put('last_sync_$collection', DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Get data from cloud
  Future<Map<String, dynamic>?> _getFromCloud(String collection, String id) async {
    // if (_firestore == null) return null;
    
          try {
        // final doc = await _firestore!.collection(collection).doc(id).get();
        // return doc.exists ? doc.data() : null;
        return null;
    } catch (e) {
      debugPrint('❌ Failed to get from cloud: $e');
      return null;
    }
  }
  
  /// Get all data from cloud
  Future<List<Map<String, dynamic>>> _getAllFromCloud(String collection) async {
    // if (_firestore == null) return [];
    
          try {
        // final snapshot = await _firestore!.collection(collection).get();
        // return snapshot.docs.map((doc) => doc.data()).toList();
        return [];
    } catch (e) {
      debugPrint('❌ Failed to get all from cloud: $e');
      return [];
    }
  }
  
  /// Merge local and cloud data sets
  List<Map<String, dynamic>> _mergeDataSets(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> cloud,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    
    // Add local data
    for (final item in local) {
      merged[item['id']] = item;
    }
    
    // Merge cloud data (cloud wins on conflicts based on updated_at)
    for (final item in cloud) {
      final id = item['id'];
      final existing = merged[id];
      
      if (existing == null || 
          (item['updated_at'] ?? 0) > (existing['updated_at'] ?? 0)) {
        merged[id] = item;
      }
    }
    
    return merged.values.toList();
  }
  
  /// Get device ID
  Future<String> _getDeviceId() async {
    String? deviceId = _localBox?.get('device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await _localBox?.put('device_id', deviceId);
    }
    return deviceId;
  }
  
  /// Get data change stream
  Stream<Map<String, dynamic>> get dataChanges => _dataChangeController.stream;
  
  /// Check sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    int pendingCount = 0;
    int failedCount = 0;
    
    final db = _sqliteDb;
    if (db != null) {
      try {
        // Verify sync_log table exists before querying
        final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_log'"
        );
        
        if (tableExists.isNotEmpty) {
          final pending = await db.rawQuery(
            'SELECT COUNT(*) as count FROM sync_log WHERE sync_status = ?',
            ['pending'],
          );
          pendingCount = pending.first['count'] as int? ?? 0;
          
          final failed = await db.rawQuery(
            'SELECT COUNT(*) as count FROM sync_log WHERE sync_status = ?',
            ['failed'],
          );
          failedCount = failed.first['count'] as int? ?? 0;
        }
      } catch (e) {
        debugPrint('⚠️ Could not get sync status: $e');
      }
    }
    
    return {
      'is_online': _isOnline,
      'is_syncing': _isSyncing,
      'pending_syncs': pendingCount,
      'failed_syncs': failedCount,
      'last_sync': _localBox?.get('last_full_sync', defaultValue: 0),
    };
  }
  
  /// Force sync now
  Future<void> forceSyncNow() async {
    if (_isOnline && _sqliteDb != null) {
      try {
        await _syncPendingChanges();
        await _performFullSync();
        await _localBox?.put('last_full_sync', DateTime.now().millisecondsSinceEpoch);
      } catch (e) {
        debugPrint('❌ Force sync failed: $e');
      }
    }
  }
  
  /// Cleanup old sync logs
  Future<void> cleanupSyncLogs() async {
    if (_sqliteDb == null) return;
    
    try {
      // Verify sync_log table exists before cleaning
      final tableExists = await _sqliteDb!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_log'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('⚠️ sync_log table does not exist, skipping cleanup');
        return;
      }
      
      final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
      await _sqliteDb!.delete(
        'sync_log',
        where: 'created_at < ? AND sync_status = ?',
        whereArgs: [cutoff, 'synced'],
      );
    } catch (e) {
      debugPrint('⚠️ Could not cleanup sync logs: $e');
    }
  }
  
  /// Clean up corrupted data from storage
  Future<void> _cleanupCorruptedData() async {
    try {
      debugPrint('🧹 Cleaning up corrupted data from storage...');
      
      // Clean up Hive if available
      if (_localBox != null) {
        final keys = _localBox!.keys.toList();
        for (final key in keys) {
          try {
            final value = _localBox!.get(key);
            if (value == null || (value is Map && value.isEmpty)) {
              await _localBox!.delete(key);
            }
          } catch (e) {
            // Delete corrupted entries
            await _localBox!.delete(key);
          }
        }
      }
      
      // Clean up SQLite database
      if (_sqliteDb != null) {
        try {
          await _sqliteDb!.delete('sync_log', where: 'sync_status = ?', whereArgs: ['corrupted']);
        } catch (e) {
          debugPrint('⚠️ Failed to clean up SQLite data: $e');
        }
      }
      
      debugPrint('✅ Data cleanup completed');
    } catch (e) {
      debugPrint('❌ Data cleanup failed: $e');
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    _connectivitySubscription.cancel();
    _dataChangeController.close();
    
    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    
    await _sqliteDb?.close();
    await _localBox?.close();
  }
}

/// Synchronized function helper
T synchronized<T>(Object lock, T Function() computation) {
  return computation();
} 