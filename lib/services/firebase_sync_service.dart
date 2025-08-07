import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../models/order.dart' as app_order;
import '../models/menu_item.dart' as app_menu_item;
import '../models/category.dart' as app_category;
import '../models/table.dart' as app_table;
import '../models/user.dart';
import '../models/inventory_item.dart' as app_inventory_item;
import '../models/activity_log.dart' as app_activity_log;

class FirebaseSyncService extends ChangeNotifier {
  static FirebaseSyncService? _instance;
  static FirebaseSyncService get instance => _instance ??= FirebaseSyncService._();
  
  FirebaseSyncService._();
  
  // Controllers for real-time data
  final StreamController<List<app_order.Order>> _ordersController = StreamController<List<app_order.Order>>.broadcast();
  final StreamController<List<app_menu_item.MenuItem>> _menuItemsController = StreamController<List<app_menu_item.MenuItem>>.broadcast();
  final StreamController<List<app_category.Category>> _categoriesController = StreamController<List<app_category.Category>>.broadcast();
  final StreamController<List<app_table.Table>> _tablesController = StreamController<List<app_table.Table>>.broadcast();
  final StreamController<List<app_inventory_item.InventoryItem>> _inventoryController = StreamController<List<app_inventory_item.InventoryItem>>.broadcast();
  final StreamController<List<app_activity_log.ActivityLog>> _activityController = StreamController<List<app_activity_log.ActivityLog>>.broadcast();
  
  // Streams
  Stream<List<app_order.Order>> get ordersStream => _ordersController.stream;
  Stream<List<app_menu_item.MenuItem>> get menuItemsStream => _menuItemsController.stream;
  Stream<List<app_category.Category>> get categoriesStream => _categoriesController.stream;
  Stream<List<app_table.Table>> get tablesStream => _tablesController.stream;
  Stream<List<app_inventory_item.InventoryItem>> get inventoryStream => _inventoryController.stream;
  Stream<List<app_activity_log.ActivityLog>> get activityStream => _activityController.stream;
  
  // Initialize sync service
  Future<void> initialize() async {
    try {
      // Set up real-time listeners
      _setupOrdersListener();
      _setupMenuItemsListener();
      _setupCategoriesListener();
      _setupTablesListener();
      _setupInventoryListener();
      _setupActivityListener();
      
      print('✅ Firebase Sync Service initialized');
    } catch (e) {
      print('❌ Firebase Sync Service initialization failed: $e');
      rethrow;
    }
  }
  
  // Set up orders listener
  void _setupOrdersListener() {
    FirebaseConfig.ordersCollection
        ?.orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      try {
        final orders = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return app_order.Order.fromJson(data);
        }).toList();
        _ordersController.add(orders);
      } catch (e) {
        print('❌ Error processing orders: $e');
      }
    });
  }
  
  // Set up menu items listener
  void _setupMenuItemsListener() {
    FirebaseConfig.menuItemsCollection
        ?.orderBy('name')
        .snapshots()
        .listen((snapshot) {
      try {
        final menuItems = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return app_menu_item.MenuItem.fromJson(data);
        }).toList();
        _menuItemsController.add(menuItems);
      } catch (e) {
        print('❌ Error processing menu items: $e');
      }
    });
  }
  
  // Set up categories listener
  void _setupCategoriesListener() {
    FirebaseConfig.categoriesCollection
        ?.orderBy('name')
        .snapshots()
        .listen((snapshot) {
      try {
        final categories = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return app_category.Category.fromJson(data);
        }).toList();
        _categoriesController.add(categories);
      } catch (e) {
        print('❌ Error processing categories: $e');
      }
    });
  }
  
  // Set up tables listener
  void _setupTablesListener() {
    FirebaseConfig.tablesCollection
        ?.orderBy('number')
        .snapshots()
        .listen((snapshot) {
      try {
        final tables = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return app_table.Table.fromJson(data);
        }).toList();
        _tablesController.add(tables);
      } catch (e) {
        print('❌ Error processing tables: $e');
      }
    });
  }
  
  // Set up inventory listener
  void _setupInventoryListener() {
    FirebaseConfig.inventoryCollection
        ?.orderBy('name')
        .snapshots()
        .listen((snapshot) {
      try {
        final inventory = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return app_inventory_item.InventoryItem.fromJson(data);
        }).toList();
        _inventoryController.add(inventory);
      } catch (e) {
        print('❌ Error processing inventory: $e');
      }
    });
  }
  
  // Set up activity listener
  void _setupActivityListener() {
    FirebaseConfig.activityLogCollection
        ?.orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      try {
        final activities = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return app_activity_log.ActivityLog.fromJson(data);
        }).toList();
        _activityController.add(activities);
      } catch (e) {
        print('❌ Error processing activities: $e');
      }
    });
  }
  
  // Add order to Firestore
  Future<void> addOrder(app_order.Order order) async {
    try {
      final orderData = order.toJson();
      await FirebaseConfig.ordersCollection?.add(orderData);
      print('✅ Order added to Firestore');
    } catch (e) {
      print('❌ Error adding order: $e');
      rethrow;
    }
  }
  
  // Update order in Firestore
  Future<void> updateOrder(app_order.Order order) async {
    try {
      final orderData = order.toJson();
      await FirebaseConfig.ordersCollection?.doc(order.id).update(orderData);
      print('✅ Order updated in Firestore');
    } catch (e) {
      print('❌ Error updating order: $e');
      rethrow;
    }
  }
  
  // Add menu item to Firestore
  Future<void> addMenuItem(app_menu_item.MenuItem menuItem) async {
    try {
      final menuItemData = menuItem.toJson();
      await FirebaseConfig.menuItemsCollection?.add(menuItemData);
      print('✅ Menu item added to Firestore');
    } catch (e) {
      print('❌ Error adding menu item: $e');
      rethrow;
    }
  }
  
  // Update menu item in Firestore
  Future<void> updateMenuItem(app_menu_item.MenuItem menuItem) async {
    try {
      final menuItemData = menuItem.toJson();
      await FirebaseConfig.menuItemsCollection?.doc(menuItem.id).update(menuItemData);
      print('✅ Menu item updated in Firestore');
    } catch (e) {
      print('❌ Error updating menu item: $e');
      rethrow;
    }
  }
  
  // Add table to Firestore
  Future<void> addTable(app_table.Table table) async {
    try {
      final tableData = table.toJson();
      await FirebaseConfig.tablesCollection?.add(tableData);
      print('✅ Table added to Firestore');
    } catch (e) {
      print('❌ Error adding table: $e');
      rethrow;
    }
  }
  
  // Update table in Firestore
  Future<void> updateTable(app_table.Table table) async {
    try {
      final tableData = table.toJson();
      await FirebaseConfig.tablesCollection?.doc(table.id).update(tableData);
      print('✅ Table updated in Firestore');
    } catch (e) {
      print('❌ Error updating table: $e');
      rethrow;
    }
  }
  
  // Add inventory item to Firestore
  Future<void> addInventoryItem(app_inventory_item.InventoryItem item) async {
    try {
      final itemData = item.toJson();
      await FirebaseConfig.inventoryCollection?.add(itemData);
      print('✅ Inventory item added to Firestore');
    } catch (e) {
      print('❌ Error adding inventory item: $e');
      rethrow;
    }
  }
  
  // Update inventory item in Firestore
  Future<void> updateInventoryItem(app_inventory_item.InventoryItem item) async {
    try {
      final itemData = item.toJson();
      await FirebaseConfig.inventoryCollection?.doc(item.id).update(itemData);
      print('✅ Inventory item updated in Firestore');
    } catch (e) {
      print('❌ Error updating inventory item: $e');
      rethrow;
    }
  }
  
  // Add activity log to Firestore
  Future<void> addActivityLog(app_activity_log.ActivityLog activity) async {
    try {
      final activityData = activity.toJson();
      await FirebaseConfig.activityLogCollection?.add(activityData);
      print('✅ Activity log added to Firestore');
    } catch (e) {
      print('❌ Error adding activity log: $e');
      rethrow;
    }
  }
  
  // Dispose resources
  @override
  void dispose() {
    _ordersController.close();
    _menuItemsController.close();
    _categoriesController.close();
    _tablesController.close();
    _inventoryController.close();
    _activityController.close();
    super.dispose();
  }
} 