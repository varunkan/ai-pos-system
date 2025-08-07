import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import '../config/firebase_config.dart';

/// Service that ensures Firebase schema matches local database schema exactly
/// This is the SINGLE SOURCE OF TRUTH for all Firebase data structure
class FirebaseLocalSchemaSyncService {
  static final FirebaseLocalSchemaSyncService _instance = FirebaseLocalSchemaSyncService._internal();
  factory FirebaseLocalSchemaSyncService() => _instance;
  FirebaseLocalSchemaSyncService._internal();

  static FirebaseLocalSchemaSyncService get instance => _instance;

  /// Initialize Firebase collections using exact local database schema during restaurant registration
  /// This ensures Firebase mirrors the working local structure perfectly
  Future<void> initializeFirebaseSchemaForRestaurant({
    required String tenantId,
    required DatabaseService localDatabase,
  }) async {
    try {
      debugPrint('🔄 Initializing Firebase schema for tenant: $tenantId using local database structure...');
      
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized, skipping schema sync');
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final tenantDoc = firestore.collection('tenants').doc(tenantId);

      // Create tenant metadata using local schema structure
      await tenantDoc.set({
        'id': tenantId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'schema_version': '1.0.0',
        'local_schema_sync': true,
      });

      // Initialize ALL collections using exact local database table structures
      await _initializeCollectionSchemas(tenantDoc, localDatabase);

      debugPrint('✅ Firebase schema initialized for tenant: $tenantId using local structure');
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase schema: $e');
      // Don't throw - Firebase sync is optional
    }
  }

  /// Initialize all Firebase collections using exact local table schemas
  Future<void> _initializeCollectionSchemas(DocumentReference tenantDoc, DatabaseService localDb) async {
    try {
      // Get all table schemas from local database - this is the SINGLE SOURCE OF TRUTH
      final localTableSchemas = await _getLocalTableSchemas(localDb);

      for (final tableSchema in localTableSchemas.entries) {
        final tableName = tableSchema.key;
        final columns = tableSchema.value;

        // Create Firebase collection with same structure as local table
        final collection = tenantDoc.collection(tableName);
        
        // Create a schema document that mirrors the local table structure exactly
        await collection.doc('_schema').set({
          'table_name': tableName,
          'columns': columns,
          'source': 'local_database',
          'sync_type': 'exact_mirror',
          'created_at': DateTime.now().toIso8601String(),
        });

        debugPrint('✅ Initialized Firebase collection: $tableName with local schema');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize collection schemas: $e');
    }
  }

  /// Get all table schemas from local database - THE SINGLE SOURCE OF TRUTH
  Future<Map<String, Map<String, String>>> _getLocalTableSchemas(DatabaseService localDb) async {
    final schemas = <String, Map<String, String>>{};

    try {
      // Get all table names from local database
      final tableNames = [
        'categories',
        'menu_items', 
        'orders',
        'order_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'transactions',
        'reservations',
        'printer_configurations',
        'printer_assignments',
        'order_logs',
        'app_metadata',
      ];

      for (final tableName in tableNames) {
        try {
          // Get column information from local SQLite database
          final columns = await _getTableColumns(localDb, tableName);
          schemas[tableName] = columns;
          debugPrint('📋 Captured local schema for table: $tableName (${columns.length} columns)');
        } catch (e) {
          debugPrint('⚠️ Could not get schema for table $tableName: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to get local table schemas: $e');
    }

    return schemas;
  }

  /// Get column information from local SQLite table
  Future<Map<String, String>> _getTableColumns(DatabaseService localDb, String tableName) async {
    final columns = <String, String>{};

    try {
      final result = await localDb.query('sqlite_master', 
        where: 'type = ? AND name = ?', 
        whereArgs: ['table', tableName]);
      
      for (final row in result) {
        final columnName = row['name'] as String;
        final columnType = row['type'] as String;
        columns[columnName] = columnType;
      }
    } catch (e) {
      debugPrint('⚠️ Could not get columns for table $tableName: $e');
    }

    return columns;
  }

  /// Sync data FROM local database TO Firebase using exact local data structure
  /// This ensures Firebase data matches local data exactly
  Future<void> syncLocalDataToFirebase({
    required String tenantId,
    required DatabaseService localDatabase,
    List<String>? specificTables,
  }) async {
    try {
      debugPrint('🔄 Syncing local data to Firebase for tenant: $tenantId...');
      
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized, skipping data sync');
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final tenantDoc = firestore.collection('tenants').doc(tenantId);

      // Tables to sync (use all if not specified)
      final tablesToSync = specificTables ?? [
        'categories',
        'menu_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'printer_configurations',
        'printer_assignments',
        'app_metadata',
      ];

      for (final tableName in tablesToSync) {
        await _syncTableToFirebase(tenantDoc, localDatabase, tableName);
      }

      debugPrint('✅ Local data synced to Firebase for tenant: $tenantId');
    } catch (e) {
      debugPrint('❌ Failed to sync local data to Firebase: $e');
    }
  }

  /// Sync a specific table from local database to Firebase
  Future<void> _syncTableToFirebase(
    DocumentReference tenantDoc,
    DatabaseService localDb,
    String tableName,
  ) async {
    try {
      // Get all data from local table
      final localData = await localDb.query(tableName);
      
      if (localData.isEmpty) {
        debugPrint('📭 No data to sync for table: $tableName');
        return;
      }

      final collection = tenantDoc.collection(tableName);
      
      // Batch write for efficiency
      final batch = FirebaseFirestore.instance.batch();
      
      for (final row in localData) {
        // Use the 'id' field as document ID if it exists, otherwise generate one
        final docId = row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        final docRef = collection.doc(docId);
        
        // Convert data to Firebase-compatible format while preserving local structure
        final firebaseData = _convertLocalDataForFirebase(row);
        
        batch.set(docRef, firebaseData);
      }
      
      await batch.commit();
      debugPrint('✅ Synced ${localData.length} records from table: $tableName to Firebase');
    } catch (e) {
      debugPrint('❌ Failed to sync table $tableName to Firebase: $e');
    }
  }

  /// Convert local database data to Firebase format while preserving exact structure
  Map<String, dynamic> _convertLocalDataForFirebase(Map<String, dynamic> localData) {
    final firebaseData = <String, dynamic>{};
    
    for (final entry in localData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Preserve the exact local data structure
      if (value != null) {
        firebaseData[key] = value;
      }
    }
    
    return firebaseData;
  }

  /// Sync data FROM Firebase TO local database using exact Firebase data structure
  /// This ensures local data matches Firebase data exactly  
  Future<void> syncFirebaseDataToLocal({
    required String tenantId,
    required DatabaseService localDatabase,
    List<String>? specificTables,
  }) async {
    try {
      debugPrint('🔄 Syncing Firebase data to local for tenant: $tenantId...');
      
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized, skipping data sync');
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final tenantDoc = firestore.collection('tenants').doc(tenantId);

      // Tables to sync (use all if not specified)
      final tablesToSync = specificTables ?? [
        'categories',
        'menu_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'printer_configurations',
        'printer_assignments',
        'app_metadata',
      ];

      for (final tableName in tablesToSync) {
        await _syncFirebaseTableToLocal(tenantDoc, localDatabase, tableName);
      }

      debugPrint('✅ Firebase data synced to local for tenant: $tenantId');
    } catch (e) {
      debugPrint('❌ Failed to sync Firebase data to local: $e');
    }
  }

  /// Sync a specific Firebase collection to local table
  Future<void> _syncFirebaseTableToLocal(
    DocumentReference tenantDoc,
    DatabaseService localDb,
    String tableName,
  ) async {
    try {
      // Get all data from Firebase collection
      final collection = tenantDoc.collection(tableName);
      final snapshot = await collection.get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('📭 No Firebase data to sync for collection: $tableName');
        return;
      }

      // Clear local table first to ensure clean sync
      await localDb.delete(tableName);
      
      // Insert Firebase data into local table preserving exact structure
      for (final doc in snapshot.docs) {
        if (doc.id == '_schema') continue; // Skip schema document
        
        final firebaseData = doc.data();
        
        // Convert Firebase data to local format while preserving structure
        final localData = _convertFirebaseDataForLocal(firebaseData);
        
        await localDb.insert(tableName, localData);
      }
      
      debugPrint('✅ Synced ${snapshot.docs.length - 1} records from Firebase collection: $tableName to local table');
    } catch (e) {
      debugPrint('❌ Failed to sync Firebase collection $tableName to local: $e');
    }
  }

  /// Convert Firebase data to local database format while preserving exact structure
  Map<String, dynamic> _convertFirebaseDataForLocal(Map<String, dynamic> firebaseData) {
    final localData = <String, dynamic>{};
    
    for (final entry in firebaseData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Preserve the exact Firebase data structure
      if (value != null) {
        localData[key] = value;
      }
    }
    
    return localData;
  }
} 