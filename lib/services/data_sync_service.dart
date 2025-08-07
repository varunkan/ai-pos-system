import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import '../models/order.dart' as app_order;
import '../models/menu_item.dart' as app_menu_item;
import '../models/category.dart' as app_category;
import '../services/menu_service.dart';
import '../services/database_service.dart';

class DataSyncService extends ChangeNotifier {
  static DataSyncService? _instance;
  static DataSyncService get instance => _instance ??= DataSyncService._();
  
  DataSyncService._();
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // Download data from Firebase
  Future<void> downloadFromCloud() async {
    try {
      _isSyncing = true;
      notifyListeners();
      
      print('🔄 Syncing data from Firebase...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        print('⚠️ No tenant ID available for sync');
        return;
      }
      
      // Sync categories
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .get();
      
      for (final doc in categoriesSnapshot.docs) {
        final categoryData = doc.data();
        final category = app_category.Category(
          id: doc.id,
          name: categoryData['name'] as String,
          description: categoryData['description'] as String? ?? '',
          sortOrder: categoryData['sortOrder'] as int? ?? 0,
          isActive: categoryData['isActive'] as bool? ?? true,
          iconCodePoint: categoryData['iconCodePoint'] as int?,
        );
        
        // Save to local database
        final databaseService = DatabaseService();
        final menuService = MenuService(databaseService);
        await menuService.saveCategory(category);
      }
      
      // Sync menu items
      final menuItemsSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('menuItems')
          .get();
      
      for (final doc in menuItemsSnapshot.docs) {
        final itemData = doc.data();
        final menuItem = app_menu_item.MenuItem(
          id: doc.id,
          name: itemData['name'] as String,
          description: itemData['description'] as String? ?? '',
          price: (itemData['price'] as num).toDouble(),
          categoryId: itemData['categoryId'] as String,
          isAvailable: itemData['isAvailable'] as bool? ?? true,
          imageUrl: itemData['imageUrl'] as String?,
          allergens: Map<String, dynamic>.from(itemData['allergens'] as Map? ?? {}),
        );
        
        // Save to local database
        final databaseService = DatabaseService();
        final menuService = MenuService(databaseService);
        await menuService.saveMenuItem(menuItem);
      }
      
      print('✅ Data synced from Firebase successfully');
    } catch (e) {
      print('❌ Error syncing from Firebase: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Upload local data to Firebase
  Future<void> uploadToCloud() async {
    try {
      _isSyncing = true;
      notifyListeners();
      
      print('🔄 Uploading data to Firebase...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        print('⚠️ No tenant ID available for sync');
        return;
      }
      
      // Upload categories
      final databaseService = DatabaseService();
      final menuService = MenuService(databaseService);
      final categories = await menuService.getCategories();
      
      for (final category in categories) {
        await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantId)
            .collection('categories')
            .doc(category.id)
            .set(category.toJson());
      }
      
      // Upload menu items
      final menuItems = await menuService.getMenuItems();
      
      for (final item in menuItems) {
        await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantId)
            .collection('menuItems')
            .doc(item.id)
            .set(item.toJson());
      }
      
      print('✅ Data uploaded to Firebase successfully');
    } catch (e) {
      print('❌ Error uploading to Firebase: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Clear all local data and sync from Firebase
  Future<void> clearAndSyncData() async {
    try {
      _isSyncing = true;
      notifyListeners();
      
      print('🔄 Starting data cleanup and sync...');
      
      // Clear all local data first
      final databaseService = DatabaseService();
      final menuService = MenuService(databaseService);
      final categories = await menuService.getCategories();
      final menuItems = await menuService.getMenuItems();
      
      // Delete all categories
      for (final category in categories) {
        await menuService.deleteCategory(category.id);
      }
      
      // Delete all menu items
      for (final item in menuItems) {
        await menuService.deleteMenuItem(item.id);
      }
      
      // Now sync from Firebase
      await downloadFromCloud(); // Changed from syncFromCloud to downloadFromCloud
      
      print('✅ Data cleared and synced successfully');
    } catch (e) {
      print('❌ Error clearing and syncing data: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Get sync statistics
  Future<Map<String, int>> getSyncStatistics() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      
      // Get counts from Firebase
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      final menuItemsSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('menuItems')
          .get();
      
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .get();
      
      final tablesSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .get();
      
      return {
        'orders': ordersSnapshot.docs.length,
        'menuItems': menuItemsSnapshot.docs.length,
        'categories': categoriesSnapshot.docs.length,
        'tables': tablesSnapshot.docs.length,
      };
    } catch (e) {
      print('❌ Error getting sync statistics: $e');
      return {
        'orders': 0,
        'menuItems': 0,
        'categories': 0,
        'tables': 0,
      };
    }
  }
} 