import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/category.dart' as pos_category;
import 'package:ai_pos_system/services/database_service.dart';

/// Custom exception for menu operations
class MenuServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  MenuServiceException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'MenuServiceException: $message${operation != null ? ' (Operation: $operation)' : ''}';
}

/// Service responsible for all menu-related operations in the POS system.
/// 
/// This service manages menu items, categories, and provides business logic
/// for menu operations including CRUD operations and queries.
class MenuService with ChangeNotifier {
  final DatabaseService _databaseService;
  List<MenuItem> _menuItems = [];
  List<pos_category.Category> _categories = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  MenuService(this._databaseService);

  // Getters
  List<MenuItem> get menuItems => List.unmodifiable(_menuItems);
  List<pos_category.Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Ensures the service is initialized and data is loaded.
  /// 
  /// This method should be called before any data access operations.
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _loadMenuData();
    }
  }

  /// Loads all menu data from the database.
  /// 
  /// This method loads both menu items and categories.
  Future<void> _loadMenuData() async {
    _setLoading(true);
    
    try {
      await Future.wait([
        _loadMenuItems(),
        _loadCategories(),
      ]);
      _isInitialized = true;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during menu data load: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during menu data load: $e');
      }
    } catch (e) {
      throw MenuServiceException('Failed to load menu data', operation: 'load_menu_data', originalError: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Loads all menu items from the database.
  /// 
  /// Throws [MenuServiceException] if loading fails.
  Future<void> _loadMenuItems() async {
    try {
      final itemsData = await _databaseService.query('menu_items');
      
      _menuItems = itemsData.map((data) {
        return MenuItem.fromJson(data);
      }).toList();
      
      // Sort by category and name
      _menuItems.sort((a, b) {
        final categoryCompare = a.categoryId.compareTo(b.categoryId);
        return categoryCompare != 0 ? categoryCompare : a.name.compareTo(b.name);
      });
    } catch (e) {
      throw MenuServiceException('Failed to load menu items', operation: 'load_menu_items', originalError: e);
    }
  }

  /// Loads all categories from the database.
  /// 
  /// Throws [MenuServiceException] if loading fails.
  Future<void> _loadCategories() async {
    try {
      final categoriesData = await _databaseService.query('categories');
      
      _categories = categoriesData.map((data) {
        return pos_category.Category.fromJson(data);
      }).toList();
      
      // Sort by sort order and name
      _categories.sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        return orderCompare != 0 ? orderCompare : a.name.compareTo(b.name);
      });
    } catch (e) {
      throw MenuServiceException('Failed to load categories', operation: 'load_categories', originalError: e);
    }
  }

  /// Gets all menu items.
  /// 
  /// Returns a list of all menu items.
  Future<List<MenuItem>> getMenuItems() async {
    await ensureInitialized();
    return _menuItems;
  }

  /// Gets menu items by category ID.
  /// 
  /// [categoryId] is the ID of the category.
  /// Returns a list of menu items in that category.
  Future<List<MenuItem>> getMenuItemsByCategoryId(String categoryId) async {
    await ensureInitialized();
    final items = _menuItems.where((item) {
      return item.categoryId == categoryId;
    }).toList();
    return items;
  }

  /// Gets menu items by category name.
  /// 
  /// [categoryName] is the name of the category.
  /// Returns a list of menu items in that category.
  Future<List<MenuItem>> getMenuItemsByCategoryName(String categoryName) async {
    await ensureInitialized();
    final category = _categories.firstWhere(
      (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => throw MenuServiceException('Category not found: $categoryName'),
    );
    return getMenuItemsByCategoryId(category.id);
  }

  /// Saves a menu item to the database.
  /// 
  /// [item] is the menu item to save.
  /// Throws [MenuServiceException] if saving fails.
  Future<void> saveMenuItem(MenuItem item) async {
    try {
      final itemData = _menuItemToMap(item);

      // Check if menu item exists in the database
      final existing = await _databaseService.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [item.id],
      );

      if (existing.isEmpty) {
        // Insert new menu item
        await _databaseService.insert('menu_items', itemData);
        _menuItems.add(item);
      } else {
        // Update existing menu item
        await _databaseService.update(
          'menu_items',
          itemData,
          where: 'id = ?',
          whereArgs: [item.id],
        );
        final index = _menuItems.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          _menuItems[index] = item;
        }
      }

      _sortMenuItems();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during menu item save: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during menu item save: $e');
      }
    } catch (e) {
      throw MenuServiceException('Failed to save menu item', operation: 'save_menu_item', originalError: e);
    }
  }

  /// Adds a new menu item.
  /// 
  /// [item] is the menu item to add.
  /// Throws [MenuServiceException] if adding fails.
  Future<void> addMenuItem(MenuItem item) async {
    await saveMenuItem(item);
  }

  /// Updates an existing menu item.
  /// 
  /// [updatedItem] is the updated menu item.
  /// Throws [MenuServiceException] if updating fails.
  Future<void> updateMenuItem(MenuItem updatedItem) async {
    await saveMenuItem(updatedItem);
  }

  /// Deletes a menu item.
  /// 
  /// [id] is the ID of the menu item to delete.
  /// Throws [MenuServiceException] if deleting fails.
  Future<void> deleteMenuItem(String id) async {
    try {
      await _databaseService.delete(
        'menu_items',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      _menuItems.removeWhere((item) => item.id == id);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during menu item delete: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during menu item delete: $e');
      }
    } catch (e) {
      throw MenuServiceException('Failed to delete menu item', operation: 'delete_menu_item', originalError: e);
    }
  }

  /// Gets a menu item by ID.
  /// 
  /// [id] is the ID of the menu item.
  /// Returns the menu item if found, null otherwise.
  Future<MenuItem?> getMenuItemById(String id) async {
    await ensureInitialized();
    try {
      return _menuItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Gets all menu items.
  /// 
  /// Returns a list of all menu items.
  Future<List<MenuItem>> getAllMenuItems() async {
    await ensureInitialized();
    return _menuItems;
  }

  /// Gets all categories.
  /// 
  /// Returns a list of all categories.
  Future<List<pos_category.Category>> getCategories() async {
    await ensureInitialized();
    return _categories;
  }

  /// Gets a category by ID.
  /// 
  /// [id] is the ID of the category.
  /// Returns the category if found, null otherwise.
  Future<pos_category.Category?> getCategoryById(String id) async {
    await ensureInitialized();
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Saves a category to the database.
  /// 
  /// [category] is the category to save.
  /// Throws [MenuServiceException] if saving fails.
  Future<void> saveCategory(pos_category.Category category) async {
    try {
      final categoryData = _categoryToMap(category);

      // Check if category exists in the database
      final existing = await _databaseService.query(
        'categories',
        where: 'id = ?',
        whereArgs: [category.id],
      );

      if (existing.isEmpty) {
        // Insert new category
        await _databaseService.insert('categories', categoryData);
        _categories.add(category);
      } else {
        // Update existing category
        await _databaseService.update(
          'categories',
          categoryData,
          where: 'id = ?',
          whereArgs: [category.id],
        );
        final index = _categories.indexWhere((c) => c.id == category.id);
        if (index != -1) {
          _categories[index] = category;
        }
      }

      _sortCategories();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during category save: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during category save: $e');
      }
    } catch (e) {
      throw MenuServiceException('Failed to save category', operation: 'save_category', originalError: e);
    }
  }

  /// Deletes a category.
  /// 
  /// [id] is the ID of the category to delete.
  /// Throws [MenuServiceException] if deleting fails.
  Future<void> deleteCategory(String id) async {
    try {
      // Check if category has menu items
      final itemsInCategory = await getMenuItemsByCategoryId(id);
      if (itemsInCategory.isNotEmpty) {
        throw MenuServiceException('Cannot delete category with menu items', operation: 'delete_category');
      }
      
      await _databaseService.delete(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      _categories.removeWhere((category) => category.id == id);
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during category delete: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during category delete: $e');
      }
    } catch (e) {
      throw MenuServiceException('Failed to delete category', operation: 'delete_category', originalError: e);
    }
  }

  /// Refreshes menu data from the database.
  /// 
  /// This method can be called to reload all menu data.
  Future<void> refreshMenuData() async {
    await _loadMenuData();
  }

  /// Sets the loading state and notifies listeners.
  /// 
  /// [loading] is the new loading state.
  void _setLoading(bool loading) {
    _isLoading = loading;
    
    // Safely notify listeners using SchedulerBinding to avoid crashes
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during loading state change: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during loading state change: $e');
    }
  }

  /// Sorts menu items by category and name.
  void _sortMenuItems() {
    _menuItems.sort((a, b) {
      final categoryCompare = a.categoryId.compareTo(b.categoryId);
      return categoryCompare != 0 ? categoryCompare : a.name.compareTo(b.name);
    });
  }

  /// Sorts categories by sort order and name.
  void _sortCategories() {
    _categories.sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      return orderCompare != 0 ? orderCompare : a.name.compareTo(b.name);
    });
  }

  /// Converts a MenuItem object to a database map.
  /// 
  /// [item] is the menu item to convert.
  /// Returns a map suitable for database insertion.
  Map<String, dynamic> _menuItemToMap(MenuItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'price': item.price,
      'category_id': item.categoryId,
      'image_url': item.imageUrl,
      'is_available': item.isAvailable ? 1 : 0,
      'tags': jsonEncode(item.tags),
      'custom_properties': jsonEncode(item.customProperties),
      'variants': jsonEncode(item.variants),
      'modifiers': jsonEncode(item.modifiers),
      'nutritional_info': jsonEncode(item.nutritionalInfo),
      'allergens': jsonEncode(item.allergens),
      'preparation_time': item.preparationTime,
      'is_vegetarian': item.isVegetarian ? 1 : 0,
      'is_vegan': item.isVegan ? 1 : 0,
      'is_gluten_free': item.isGlutenFree ? 1 : 0,
      'is_spicy': item.isSpicy ? 1 : 0,
      'spice_level': item.spiceLevel,
      'stock_quantity': item.stockQuantity,
      'low_stock_threshold': item.lowStockThreshold,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  /// Converts a Category object to a database map.
  /// 
  /// [category] is the category to convert.
  /// Returns a map suitable for database insertion.
  Map<String, dynamic> _categoryToMap(pos_category.Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'description': category.description,
      'image_url': category.imageUrl,
      'is_active': category.isActive ? 1 : 0,
      'sort_order': category.sortOrder,
      'created_at': category.createdAt.toIso8601String(),
      'updated_at': category.updatedAt.toIso8601String(),
    };
  }

  /// Gets all menu items as raw data for debugging.
  /// 
  /// Returns raw data from the database.
  Future<List<Map<String, dynamic>>> getAllMenuItemsRaw() async {
    try {
      return await _databaseService.query('menu_items');
    } catch (e) {
      throw MenuServiceException('Failed to get raw menu items', operation: 'get_raw_menu_items', originalError: e);
    }
  }

  /// Loads sample data into the database.
  /// 
  /// This method creates sample categories and menu items to get started.
  Future<void> loadSampleData() async {
    await ensureInitialized();
    
    if (_categories.isNotEmpty && _menuItems.isNotEmpty) {
      debugPrint('Sample menu data already loaded');
      return;
    }

    try {
      // Create sample categories
      final sampleCategories = [
        pos_category.Category(
          name: 'Appetizers',
          description: 'Starters and small plates',
          sortOrder: 1,
        ),
        pos_category.Category(
          name: 'Main Courses',
          description: 'Primary dishes',
          sortOrder: 2,
        ),
        pos_category.Category(
          name: 'Beverages',
          description: 'Drinks and refreshments',
          sortOrder: 3,
        ),
        pos_category.Category(
          name: 'Desserts',
          description: 'Sweet treats',
          sortOrder: 4,
        ),
      ];

      for (final category in sampleCategories) {
        await saveCategory(category);
      }

      // Create sample menu items
      final sampleItems = [
        MenuItem(
          name: 'Caesar Salad',
          description: 'Fresh romaine lettuce with caesar dressing, croutons, and parmesan cheese',
          price: 12.99,
          categoryId: sampleCategories[0].id,
          preparationTime: 10,
          isVegetarian: true,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Buffalo Wings',
          description: 'Spicy buffalo chicken wings with blue cheese dip',
          price: 14.99,
          categoryId: sampleCategories[0].id,
          preparationTime: 15,
          isSpicy: true,
          spiceLevel: 3,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Grilled Salmon',
          description: 'Fresh Atlantic salmon grilled to perfection with lemon butter sauce',
          price: 24.99,
          categoryId: sampleCategories[1].id,
          preparationTime: 20,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Ribeye Steak',
          description: '12oz ribeye steak cooked to your preference with garlic mashed potatoes',
          price: 32.99,
          categoryId: sampleCategories[1].id,
          preparationTime: 25,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Margherita Pizza',
          description: 'Classic pizza with fresh mozzarella, tomato sauce, and basil',
          price: 18.99,
          categoryId: sampleCategories[1].id,
          preparationTime: 18,
          isVegetarian: true,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Coca Cola',
          description: 'Classic Coca Cola soft drink',
          price: 3.99,
          categoryId: sampleCategories[2].id,
          preparationTime: 1,
          stockQuantity: 100,
        ),
        MenuItem(
          name: 'Fresh Orange Juice',
          description: 'Freshly squeezed orange juice',
          price: 5.99,
          categoryId: sampleCategories[2].id,
          preparationTime: 3,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Chocolate Cake',
          description: 'Rich chocolate cake with chocolate ganache',
          price: 8.99,
          categoryId: sampleCategories[3].id,
          preparationTime: 5,
          isVegetarian: true,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Tiramisu',
          description: 'Classic Italian dessert with coffee-soaked ladyfingers',
          price: 9.99,
          categoryId: sampleCategories[3].id,
          preparationTime: 5,
          isVegetarian: true,
          stockQuantity: 12,
        ),
      ];

      for (final item in sampleItems) {
        await saveMenuItem(item);
      }

      debugPrint('Sample menu data loaded successfully');
    } catch (e) {
      throw MenuServiceException('Failed to load sample data', operation: 'load_sample_data', originalError: e);
    }
  }

  /// Clears all menu data from the database.
  /// 
  /// This method deletes all menu items and categories.
  Future<void> clearAllData() async {
    try {
      await _databaseService.delete('menu_items', where: '1=1');
      await _databaseService.delete('categories', where: '1=1');
      _menuItems.clear();
      _categories.clear();
      _isInitialized = false;
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during clear data: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during clear data: $e');
      }
    } catch (e) {
      throw MenuServiceException('Failed to clear data', operation: 'clear_data', originalError: e);
    }
  }

  /// Loads Oh Bombay Milton restaurant menu data into the database.
  /// 
  /// This method creates categories and menu items for Oh Bombay Milton restaurant.
  Future<void> loadOhBombayMenu() async {
    try {
      // Clear existing data first
      await clearAllData();
      
      // Create categories for Oh Bombay Milton
      final categories = [
        pos_category.Category(
          name: 'Starter - Veg',
          description: 'Vegetarian appetizers and starters',
          sortOrder: 1,
        ),
        pos_category.Category(
          name: 'Starter - Non-Veg',
          description: 'Non-vegetarian appetizers and starters',
          sortOrder: 2,
        ),
        pos_category.Category(
          name: 'Starter - Hakka',
          description: 'Hakka style appetizers and Indo-Chinese dishes',
          sortOrder: 3,
        ),
        pos_category.Category(
          name: 'Main Course - Veg',
          description: 'Vegetarian main course dishes',
          sortOrder: 4,
        ),
        pos_category.Category(
          name: 'Main Course - Non-Veg',
          description: 'Non-vegetarian main course dishes',
          sortOrder: 5,
        ),
        pos_category.Category(
          name: 'Momos (Dumplings)',
          description: 'Various styles of momos and dumplings',
          sortOrder: 6,
        ),
        pos_category.Category(
          name: 'Rice Items',
          description: 'Rice dishes and biryanis',
          sortOrder: 7,
        ),
        pos_category.Category(
          name: 'Lunch Special Thali (Mon-Fri till 4PM)',
          description: 'Special lunch thali combinations',
          sortOrder: 8,
        ),
        pos_category.Category(
          name: 'Take-Out Only',
          description: 'Special meal packages for take-out',
          sortOrder: 9,
        ),
        pos_category.Category(
          name: 'Special Orders',
          description: 'Premium special order items',
          sortOrder: 10,
        ),
        pos_category.Category(
          name: 'Wraps',
          description: 'Various wrap options',
          sortOrder: 11,
        ),
        pos_category.Category(
          name: 'Snacks',
          description: 'Street food and snack items',
          sortOrder: 12,
        ),
        pos_category.Category(
          name: 'Soups',
          description: 'Hot soups and broths',
          sortOrder: 13,
        ),
        pos_category.Category(
          name: 'Breads',
          description: 'Naan, roti, and bread varieties',
          sortOrder: 14,
        ),
        pos_category.Category(
          name: 'Kids Menu',
          description: 'Kid-friendly menu items',
          sortOrder: 15,
        ),
      ];

      // Save all categories
      for (final category in categories) {
        await saveCategory(category);
      }

      // Create menu items for each category
      final menuItems = <MenuItem>[];

      // Starter - Veg
      final starterVegCategory = categories[0];
      menuItems.addAll([
        MenuItem(
          name: 'Paneer Tikka Kurkure',
          description: 'Crispy paneer tikka with kurkure coating',
          price: 17.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Bhatti Ka Paneer Tikka',
          description: 'Traditional bhatti style paneer tikka',
          price: 17.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Bharwa Khumb Peshawari',
          description: 'Stuffed mushrooms Peshawari style',
          price: 17.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Soya Chaap (Tandoori/Malai)',
          description: 'Soya chaap in tandoori or malai style',
          price: 17.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Hara Bhara Kebab',
          description: 'Green vegetable kebabs',
          price: 17.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 12,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Dahi Ke Kebab',
          description: 'Yogurt based vegetarian kebabs',
          price: 17.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Veg Platter',
          description: 'Assorted vegetarian starter platter',
          price: 24.99,
          categoryId: starterVegCategory.id,
          isVegetarian: true,
          preparationTime: 20,
          stockQuantity: 10,
        ),
      ]);

      // Starter - Non-Veg
      final starterNonVegCategory = categories[1];
      menuItems.addAll([
        MenuItem(
          name: 'Murg Seekh Kebab',
          description: 'Spiced chicken seekh kebabs',
          price: 18.99,
          categoryId: starterNonVegCategory.id,
          preparationTime: 18,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Ajwaini Mahi Tikka (Fish)',
          description: 'Fish tikka with ajwain flavoring',
          price: 18.99,
          categoryId: starterNonVegCategory.id,
          preparationTime: 15,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Murg-E-Azam Tikka - Oh Bombay Special',
          description: 'Oh Bombay special chicken tikka',
          price: 18.99,
          categoryId: starterNonVegCategory.id,
          preparationTime: 18,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Murg Afghani Malai Tikka - Oh Bombay Special',
          description: 'Creamy Afghani style chicken tikka',
          price: 18.99,
          categoryId: starterNonVegCategory.id,
          preparationTime: 18,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Amritsari Tandoori Chicken',
          description: 'Traditional Amritsari tandoori chicken',
          price: 15.49,
          categoryId: starterNonVegCategory.id,
          preparationTime: 20,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Chef\'s Special Non-Veg Platter',
          description: 'Assorted non-vegetarian starter platter',
          price: 29.99,
          categoryId: starterNonVegCategory.id,
          preparationTime: 25,
          stockQuantity: 8,
        ),
        MenuItem(
          name: 'Lucknowi Galouti Kebab (Lamb Boneless)',
          description: 'Melt-in-mouth lamb kebabs from Lucknow',
          price: 19.99,
          categoryId: starterNonVegCategory.id,
          preparationTime: 20,
          stockQuantity: 12,
        ),
      ]);

      // Starter - Hakka
      final starterHakkaCategory = categories[2];
      menuItems.addAll([
        MenuItem(
          name: 'Crispy Andhra Chilli Cauliflower',
          description: 'Spicy Andhra style cauliflower',
          price: 17.99,
          categoryId: starterHakkaCategory.id,
          isVegetarian: true,
          isSpicy: true,
          spiceLevel: 3,
          preparationTime: 12,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Dry/Gravy Manchurian (Veg/Chicken)',
          description: 'Manchurian in dry or gravy style',
          price: 15.99,
          categoryId: starterHakkaCategory.id,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Chilli (Paneer/Chicken)',
          description: 'Spicy chilli paneer or chicken',
          price: 15.99,
          categoryId: starterHakkaCategory.id,
          isSpicy: true,
          spiceLevel: 3,
          preparationTime: 12,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Veg Spring Rolls',
          description: 'Crispy vegetarian spring rolls',
          price: 10.99,
          categoryId: starterHakkaCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Chilli Garlic Noodles (Veg/Chicken)',
          description: 'Spicy chilli garlic noodles',
          price: 14.99,
          categoryId: starterHakkaCategory.id,
          isSpicy: true,
          spiceLevel: 2,
          preparationTime: 12,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Street Style Chowmein (Veg/Chicken)',
          description: 'Street style chowmein noodles',
          price: 14.99,
          categoryId: starterHakkaCategory.id,
          preparationTime: 12,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Veg/Chicken Fried Rice',
          description: 'Classic fried rice with vegetables or chicken',
          price: 14.99,
          categoryId: starterHakkaCategory.id,
          preparationTime: 12,
          stockQuantity: 25,
        ),
      ]);

      // Main Course - Veg
      final mainVegCategory = categories[3];
      menuItems.addAll([
        MenuItem(
          name: 'Daawat-E-Khas Karahi Paneer',
          description: 'Special karahi paneer preparation',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Rara Paneer Keema - Oh Bombay Special',
          description: 'Oh Bombay special paneer keema',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 20,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Oh Bombay Special Paneer Pasanda',
          description: 'Rich and creamy paneer pasanda',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Palak Dahi Kofta Masala',
          description: 'Spinach and yogurt kofta in masala',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 20,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Soya Chaap Tikka Lababdar - Oh Bombay Special',
          description: 'Oh Bombay special soya chaap in rich gravy',
          price: 17.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Makai Khees Masala - Oh Bombay Special',
          description: 'Oh Bombay special corn khees masala',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Oh Bombay Special Khumb Makai Taka Tak',
          description: 'Mushroom and corn taka tak special',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 18,
        ),
        MenuItem(
          name: 'Pindi Chole',
          description: 'Traditional Pindi style chickpeas',
          price: 16.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Tawa Subz Miloni',
          description: 'Mixed vegetables cooked on tawa',
          price: 18.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Bhuna Baingan Zaykedar - Oh Bombay Special',
          description: 'Oh Bombay special spiced eggplant',
          price: 17.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 18,
        ),
        MenuItem(
          name: 'Daal Makhani',
          description: 'Creamy black lentils',
          price: 17.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 20,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Oh Bombay Special Daal Panch Mahal',
          description: 'Five lentil special preparation',
          price: 17.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 20,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Dahi Bhindi Do Pyaza',
          description: 'Okra with yogurt and onions',
          price: 17.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Dum Aloo Kashmir',
          description: 'Kashmiri style dum aloo',
          price: 16.99,
          categoryId: mainVegCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 20,
        ),
      ]);

      // Main Course - Non-Veg
      final mainNonVegCategory = categories[4];
      menuItems.addAll([
        MenuItem(
          name: 'Delhi 6 Changezi Chicken',
          description: 'Delhi style changezi chicken',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 20,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Town Heaviest Butter Chicken (With Bone/Boneless)',
          description: 'Rich and creamy butter chicken',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 18,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Puran Singh Chicken Curry',
          description: 'Traditional Puran Singh style chicken curry',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 20,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Adraki Bhuna Gosht (Goat)',
          description: 'Ginger flavored goat curry',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 25,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Rara Gosht Zulfikar (Goat)',
          description: 'Special goat curry with minced meat',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 25,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Dawat-E-Khaas Karahi (Chicken/Goat)',
          description: 'Special karahi chicken or goat',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 22,
          stockQuantity: 18,
        ),
        MenuItem(
          name: 'Lemon Pepper Chicken (With Bone)',
          description: 'Tangy lemon pepper chicken',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 18,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Andhra Pepper Chicken',
          description: 'Spicy Andhra style pepper chicken',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          isSpicy: true,
          spiceLevel: 4,
          preparationTime: 18,
          stockQuantity: 18,
        ),
        MenuItem(
          name: 'Anda Keema Ghotala',
          description: 'Scrambled eggs with minced meat',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 15,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Kolkata Fish Masala',
          description: 'Bengali style fish curry',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 18,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Kashmiri Rogan Josh',
          description: 'Traditional Kashmiri lamb curry',
          price: 19.99,
          categoryId: mainNonVegCategory.id,
          preparationTime: 25,
          stockQuantity: 15,
        ),
      ]);

      // Momos (Dumplings)
      final momosCategory = categories[5];
      menuItems.addAll([
        MenuItem(
          name: 'Tandoori Momos (Vegetarian/Chicken)',
          description: 'Tandoori style momos',
          price: 15.99,
          categoryId: momosCategory.id,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Manchurian Style Momos (Vegetarian/Chicken)',
          description: 'Momos in Manchurian sauce',
          price: 15.99,
          categoryId: momosCategory.id,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Honey Chilli Momos (Vegetarian/Chicken)',
          description: 'Sweet and spicy honey chilli momos',
          price: 15.99,
          categoryId: momosCategory.id,
          isSpicy: true,
          spiceLevel: 2,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Afghani Momos (Vegetarian/Chicken)',
          description: 'Creamy Afghani style momos',
          price: 15.99,
          categoryId: momosCategory.id,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Creamy Schezwan Momos (Vegetarian/Chicken)',
          description: 'Creamy schezwan sauce momos',
          price: 15.99,
          categoryId: momosCategory.id,
          isSpicy: true,
          spiceLevel: 3,
          preparationTime: 15,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Steam Veg Momos',
          description: 'Traditional steamed vegetable momos',
          price: 12.99,
          categoryId: momosCategory.id,
          isVegetarian: true,
          preparationTime: 12,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Steamed Chicken Momos',
          description: 'Traditional steamed chicken momos',
          price: 13.99,
          categoryId: momosCategory.id,
          preparationTime: 12,
          stockQuantity: 30,
        ),
      ]);

      // Rice Items
      final riceCategory = categories[6];
      menuItems.addAll([
        MenuItem(
          name: 'Jeera Rice',
          description: 'Cumin flavored basmati rice',
          price: 7.49,
          categoryId: riceCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Lucknowi Chicken/Mutton Biryani',
          description: 'Authentic Lucknowi style biryani',
          price: 16.99,
          categoryId: riceCategory.id,
          preparationTime: 25,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Veg Biryani',
          description: 'Aromatic vegetable biryani',
          price: 14.99,
          categoryId: riceCategory.id,
          isVegetarian: true,
          preparationTime: 20,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Egg Biryani',
          description: 'Spiced egg biryani',
          price: 15.49,
          categoryId: riceCategory.id,
          isVegetarian: true,
          preparationTime: 18,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Steamed Rice',
          description: 'Plain steamed basmati rice',
          price: 5.99,
          categoryId: riceCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 40,
        ),
      ]);

      // Lunch Special Thali
      final thaliCategory = categories[7];
      menuItems.addAll([
        MenuItem(
          name: 'Veg Thali',
          description: 'Complete vegetarian thali (Mon-Fri till 4PM)',
          price: 11.99,
          categoryId: thaliCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Chicken Non-Veg Thali',
          description: 'Complete chicken thali (Mon-Fri till 4PM)',
          price: 12.99,
          categoryId: thaliCategory.id,
          preparationTime: 18,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Mutton Non-Veg Thali',
          description: 'Complete mutton thali (Mon-Fri till 4PM)',
          price: 13.99,
          categoryId: thaliCategory.id,
          preparationTime: 20,
          stockQuantity: 10,
        ),
      ]);

      // Take-Out Only
      final takeoutCategory = categories[8];
      menuItems.addAll([
        MenuItem(
          name: 'Meal For 2 - Veg',
          description: 'Complete vegetarian meal for 2 people',
          price: 52.00,
          categoryId: takeoutCategory.id,
          isVegetarian: true,
          preparationTime: 25,
          stockQuantity: 8,
        ),
        MenuItem(
          name: 'Non Meal For 2 - Non Veg',
          description: 'Complete non-vegetarian meal for 2 people',
          price: 57.00,
          categoryId: takeoutCategory.id,
          preparationTime: 25,
          stockQuantity: 8,
        ),
        MenuItem(
          name: 'Meal For 4 - Veg',
          description: 'Complete vegetarian meal for 4 people',
          price: 74.00,
          categoryId: takeoutCategory.id,
          isVegetarian: true,
          preparationTime: 30,
          stockQuantity: 5,
        ),
        MenuItem(
          name: 'Meal For 4 - Non Veg',
          description: 'Complete non-vegetarian meal for 4 people',
          price: 79.00,
          categoryId: takeoutCategory.id,
          preparationTime: 30,
          stockQuantity: 5,
        ),
      ]);

      // Special Orders
      final specialCategory = categories[9];
      menuItems.addAll([
        MenuItem(
          name: 'Murg Mussalam',
          description: 'Whole chicken in rich gravy',
          price: 65.99,
          categoryId: specialCategory.id,
          preparationTime: 45,
          stockQuantity: 3,
        ),
        MenuItem(
          name: 'Raan-E-Nawabi',
          description: 'Royal leg of lamb preparation',
          price: 85.99,
          categoryId: specialCategory.id,
          preparationTime: 60,
          stockQuantity: 2,
        ),
      ]);

      // Wraps
      final wrapsCategory = categories[10];
      menuItems.addAll([
        MenuItem(
          name: 'Veggie Wrap',
          description: 'Fresh vegetable wrap',
          price: 9.99,
          categoryId: wrapsCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Paneer Wrap',
          description: 'Spiced paneer wrap',
          price: 10.99,
          categoryId: wrapsCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Butter Chicken Wrap',
          description: 'Butter chicken in a wrap',
          price: 10.99,
          categoryId: wrapsCategory.id,
          preparationTime: 10,
          stockQuantity: 20,
        ),
      ]);

      // Snacks
      final snacksCategory = categories[11];
      menuItems.addAll([
        MenuItem(
          name: 'Veg Samosa',
          description: 'Crispy vegetable samosa',
          price: 3.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 5,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Vada Pav',
          description: 'Mumbai style vada pav',
          price: 4.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Pani Puri',
          description: 'Traditional pani puri chaat',
          price: 7.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 5,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Dahi Puri Chaat',
          description: 'Yogurt topped puri chaat',
          price: 7.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Chaat (Papri/Samosa)',
          description: 'Papri or samosa chaat',
          price: 9.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Pav Bhaji',
          description: 'Mumbai style pav bhaji',
          price: 12.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 12,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Chole Bhature',
          description: 'Spiced chickpeas with fried bread',
          price: 13.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Dahi Bhalle',
          description: 'Lentil dumplings in yogurt',
          price: 10.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Amritsari Kulcha With Chole',
          description: 'Stuffed kulcha with chickpeas',
          price: 12.99,
          categoryId: snacksCategory.id,
          isVegetarian: true,
          preparationTime: 15,
          stockQuantity: 15,
        ),
      ]);

      // Soups
      final soupsCategory = categories[12];
      menuItems.addAll([
        MenuItem(
          name: 'Chicken Manchow Soup',
          description: 'Spicy chicken manchow soup',
          price: 7.99,
          categoryId: soupsCategory.id,
          isSpicy: true,
          spiceLevel: 2,
          preparationTime: 10,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Veg Manchow Soup',
          description: 'Spicy vegetable manchow soup',
          price: 6.99,
          categoryId: soupsCategory.id,
          isVegetarian: true,
          isSpicy: true,
          spiceLevel: 2,
          preparationTime: 10,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Cream Of Tomato',
          description: 'Creamy tomato soup',
          price: 5.99,
          categoryId: soupsCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 25,
        ),
      ]);

      // Breads
      final breadsCategory = categories[13];
      menuItems.addAll([
        MenuItem(
          name: 'Butter Naan',
          description: 'Soft butter naan',
          price: 3.49,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 5,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Garlic Naan',
          description: 'Garlic flavored naan',
          price: 3.99,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 5,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Plain Naan',
          description: 'Traditional plain naan',
          price: 2.99,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 5,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Tandoori Roti/Butter Roti',
          description: 'Tandoori or butter roti',
          price: 2.99,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 5,
          stockQuantity: 50,
        ),
        MenuItem(
          name: 'Mirchi Paratha (Red/Green)/Ajawani Paratha',
          description: 'Spiced paratha with chili or ajwain',
          price: 5.49,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          isSpicy: true,
          spiceLevel: 2,
          preparationTime: 8,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Amritsari Kulcha (Chicken/Lamb)',
          description: 'Stuffed kulcha with chicken or lamb',
          price: 8.49,
          categoryId: breadsCategory.id,
          preparationTime: 12,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Amritsari Kulcha (Aloo/Gobi/Paneer)',
          description: 'Stuffed kulcha with potato, cauliflower, or paneer',
          price: 7.49,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 12,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Bhature',
          description: 'Deep fried bread',
          price: 3.99,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Laccha Paratha',
          description: 'Layered laccha paratha',
          price: 4.99,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 30,
        ),
        MenuItem(
          name: 'Stuffed Cheese Pizza Naan',
          description: 'Cheese stuffed pizza style naan',
          price: 7.99,
          categoryId: breadsCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 20,
        ),
      ]);

      // Kids Menu
      final kidsCategory = categories[14];
      menuItems.addAll([
        MenuItem(
          name: 'Stuffed Cheese Pizza Naan',
          description: 'Kid-friendly cheese pizza naan',
          price: 7.99,
          categoryId: kidsCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Pulled Butter Chicken Nachos',
          description: 'Butter chicken nachos for kids',
          price: 11.99,
          categoryId: kidsCategory.id,
          preparationTime: 12,
          stockQuantity: 15,
        ),
        MenuItem(
          name: 'Paneer Makhani Nachos',
          description: 'Paneer makhani nachos',
          price: 7.49,
          categoryId: kidsCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'Kids Aloo/Paneer Paratha',
          description: 'Kid-sized potato or paneer paratha',
          price: 8.49,
          categoryId: kidsCategory.id,
          isVegetarian: true,
          preparationTime: 10,
          stockQuantity: 25,
        ),
        MenuItem(
          name: 'Honey Chilli Potato',
          description: 'Sweet and spicy potato dish',
          price: 10.99,
          categoryId: kidsCategory.id,
          isVegetarian: true,
          isSpicy: true,
          spiceLevel: 1,
          preparationTime: 12,
          stockQuantity: 20,
        ),
        MenuItem(
          name: 'French Fries',
          description: 'Classic crispy french fries',
          price: 5.99,
          categoryId: kidsCategory.id,
          isVegetarian: true,
          preparationTime: 8,
          stockQuantity: 30,
        ),
      ]);

      // Save all menu items
      for (final item in menuItems) {
        await saveMenuItem(item);
      }

      debugPrint('Oh Bombay Milton menu loaded successfully with ${categories.length} categories and ${menuItems.length} items');
    } catch (e) {
      throw MenuServiceException('Failed to load Oh Bombay menu', operation: 'load_oh_bombay_menu', originalError: e);
    }
  }
} 