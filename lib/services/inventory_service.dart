import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/inventory_item.dart';

/// Service for managing inventory items and transactions.
class InventoryService with ChangeNotifier {
  static const String _inventoryItemsKey = 'inventory_items';
  static const String _inventoryTransactionsKey = 'inventory_transactions';
  
  static final InventoryService _instance = InventoryService._internal();
  factory InventoryService() => _instance;
  InventoryService._internal();

  List<InventoryItem> _items = [];
  List<InventoryTransaction> _transactions = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  List<InventoryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  /// Initialize the service and load data from storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load inventory items
      final itemsJson = prefs.getStringList(_inventoryItemsKey) ?? [];
      _items = itemsJson
          .map((json) => InventoryItem.fromJson(jsonDecode(json)))
          .where((item) => item.name != 'Error Item')
          .toList();
      
      // Load transactions
      final transactionsJson = prefs.getStringList(_inventoryTransactionsKey) ?? [];
      _transactions = transactionsJson
          .map((json) => InventoryTransaction.fromJson(jsonDecode(json)))
          .where((transaction) => transaction.inventoryItemId != 'error')
          .toList();
      
      _isInitialized = true;
      debugPrint('InventoryService initialized with ${_items.length} items and ${_transactions.length} transactions');
    } catch (e) {
      debugPrint('Error initializing InventoryService: $e');
      _isInitialized = true;
    }
  }

  /// Save data to storage.
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save inventory items
      final itemsJson = _items
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList(_inventoryItemsKey, itemsJson);
      
      // Save transactions
      final transactionsJson = _transactions
          .map((transaction) => jsonEncode(transaction.toJson()))
          .toList();
      await prefs.setStringList(_inventoryTransactionsKey, transactionsJson);
    } catch (e) {
      debugPrint('Error saving inventory data: $e');
    }
  }

  // Inventory Items Management

  /// Get all inventory items.
  List<InventoryItem> getAllItems() {
    return List.unmodifiable(_items);
  }

  /// Get inventory items by category.
  List<InventoryItem> getItemsByCategory(InventoryCategory category) {
    return _items
        .where((item) => item.category == category)
        .toList();
  }

  /// Get inventory items with low stock.
  List<InventoryItem> getLowStockItems() {
    return _items
        .where((item) => item.isLowStock)
        .toList();
  }

  /// Get inventory items that are out of stock.
  List<InventoryItem> getOutOfStockItems() {
    return _items
        .where((item) => item.isOutOfStock)
        .toList();
  }

  /// Get inventory items that are expiring soon.
  List<InventoryItem> getExpiringSoonItems() {
    return _items
        .where((item) => item.isExpiringSoon)
        .toList();
  }

  /// Get inventory items that are expired.
  List<InventoryItem> getExpiredItems() {
    return _items
        .where((item) => item.isExpired)
        .toList();
  }

  /// Get inventory items that are overstocked.
  List<InventoryItem> getOverstockedItems() {
    return _items
        .where((item) => item.isOverstocked)
        .toList();
  }

  /// Search inventory items by name.
  List<InventoryItem> searchItems(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _items
        .where((item) => 
            item.name.toLowerCase().contains(lowercaseQuery) ||
            (item.description != null && item.description!.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  /// Get inventory item by ID.
  InventoryItem? getItemById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Add a new inventory item.
  Future<bool> addItem(InventoryItem item) async {
    try {
      // Check if item with same name already exists
      final existingItem = _items
          .where((existing) => existing.name.toLowerCase() == item.name.toLowerCase())
          .firstOrNull;
      
      if (existingItem != null) {
        debugPrint('Item with name "${item.name}" already exists');
        return false;
      }

      _items.add(item);
      await _saveData();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during add item: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during add item: $e');
      }
      
      debugPrint('Added inventory item: ${item.name}');
      return true;
    } catch (e) {
      debugPrint('Error adding inventory item: $e');
      return false;
    }
  }

  /// Update an existing inventory item.
  Future<bool> updateItem(InventoryItem updatedItem) async {
    try {
      final index = _items.indexWhere((item) => item.id == updatedItem.id);
      if (index == -1) {
        debugPrint('Item not found: ${updatedItem.id}');
        return false;
      }

      // Check if name conflicts with other items
      final nameConflict = _items
          .where((item) => 
              item.id != updatedItem.id && 
              item.name.toLowerCase() == updatedItem.name.toLowerCase())
          .firstOrNull;
      
      if (nameConflict != null) {
        debugPrint('Item with name "${updatedItem.name}" already exists');
        return false;
      }

      _items[index] = updatedItem.copyWith(updatedAt: DateTime.now());
      await _saveData();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during update item: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during update item: $e');
      }
      
      debugPrint('Updated inventory item: ${updatedItem.name}');
      return true;
    } catch (e) {
      debugPrint('Error updating inventory item: $e');
      return false;
    }
  }

  /// Delete an inventory item.
  Future<bool> deleteItem(String id) async {
    try {
      final index = _items.indexWhere((item) => item.id == id);
      if (index == -1) {
        debugPrint('Item not found: $id');
        return false;
      }

      final item = _items[index];
      _items.removeAt(index);
      
      // Also remove related transactions
      _transactions.removeWhere((transaction) => transaction.inventoryItemId == id);
      
      await _saveData();
      debugPrint('Deleted inventory item: ${item.name}');
      return true;
    } catch (e) {
      debugPrint('Error deleting inventory item: $e');
      return false;
    }
  }

  // Stock Management

  /// Adjust stock level for an item.
  Future<bool> adjustStock(String itemId, double quantity, String type, {
    String? reason,
    String? notes,
    String? userId,
  }) async {
    try {
      final itemIndex = _items.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) {
        debugPrint('Item not found: $itemId');
        return false;
      }

      final item = _items[itemIndex];
      double newStock = item.currentStock;

      switch (type) {
        case 'restock':
        case 'adjustment':
          newStock += quantity;
          break;
        case 'usage':
        case 'waste':
        case 'transfer':
          newStock -= quantity;
          break;
        default:
          debugPrint('Invalid transaction type: $type');
          return false;
      }

      if (newStock < 0) {
        debugPrint('Stock cannot be negative');
        return false;
      }

      // Update item stock
      final updatedItem = item.copyWith(
        currentStock: newStock,
        lastRestocked: type == 'restock' ? DateTime.now() : item.lastRestocked,
        updatedAt: DateTime.now(),
      );
      _items[itemIndex] = updatedItem;

      // Create transaction record
      final transaction = InventoryTransaction(
        inventoryItemId: itemId,
        type: type,
        quantity: quantity,
        reason: reason,
        notes: notes,
        userId: userId,
      );
      _transactions.add(transaction);

      await _saveData();
      debugPrint('Stock adjusted for ${item.name}: $type $quantity ${item.unitDisplay}');
      return true;
    } catch (e) {
      debugPrint('Error adjusting stock: $e');
      return false;
    }
  }

  /// Restock an item.
  Future<bool> restockItem(String itemId, double quantity, {
    String? reason,
    String? notes,
    String? userId,
  }) async {
    return adjustStock(itemId, quantity, 'restock',
        reason: reason, notes: notes, userId: userId);
  }

  /// Use stock from an item.
  Future<bool> useStock(String itemId, double quantity, {
    String? reason,
    String? notes,
    String? userId,
  }) async {
    return adjustStock(itemId, quantity, 'usage',
        reason: reason, notes: notes, userId: userId);
  }

  /// Record waste for an item.
  Future<bool> recordWaste(String itemId, double quantity, {
    String? reason,
    String? notes,
    String? userId,
  }) async {
    return adjustStock(itemId, quantity, 'waste',
        reason: reason, notes: notes, userId: userId);
  }

  // Transaction Management

  /// Get all transactions.
  List<InventoryTransaction> getAllTransactions() {
    return List.unmodifiable(_transactions);
  }

  /// Get transactions for a specific item.
  List<InventoryTransaction> getTransactionsForItem(String itemId) {
    return _transactions
        .where((transaction) => transaction.inventoryItemId == itemId)
        .toList();
  }

  /// Get transactions by type.
  List<InventoryTransaction> getTransactionsByType(String type) {
    return _transactions
        .where((transaction) => transaction.type == type)
        .toList();
  }

  /// Get transactions within a date range.
  List<InventoryTransaction> getTransactionsInDateRange(DateTime start, DateTime end) {
    return _transactions
        .where((transaction) => 
            transaction.timestamp.isAfter(start) && 
            transaction.timestamp.isBefore(end))
        .toList();
  }

  // Analytics and Reports

  /// Get total inventory value.
  double getTotalInventoryValue() {
    return _items.fold(0.0, (sum, item) => sum + item.totalValue);
  }

  /// Get low stock value.
  double getLowStockValue() {
    return _items
        .where((item) => item.isLowStock)
        .fold(0.0, (sum, item) => sum + item.totalValue);
  }

  /// Get category-wise inventory summary.
  Map<InventoryCategory, Map<String, dynamic>> getCategorySummary() {
    final summary = <InventoryCategory, Map<String, dynamic>>{};
    
    for (final category in InventoryCategory.values) {
      final items = getItemsByCategory(category);
      final totalItems = items.length;
      final totalValue = items.fold(0.0, (sum, item) => sum + item.totalValue);
      final lowStockItems = items.where((item) => item.isLowStock).length;
      final outOfStockItems = items.where((item) => item.isOutOfStock).length;
      
      summary[category] = {
        'totalItems': totalItems,
        'totalValue': totalValue,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
      };
    }
    
    return summary;
  }

  /// Get recent transactions summary.
  Map<String, dynamic> getRecentTransactionsSummary(int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final recentTransactions = _transactions
        .where((transaction) => transaction.timestamp.isAfter(cutoffDate))
        .toList();

    final summary = <String, int>{};
    final totalQuantity = <String, double>{};
    final totalValue = <String, double>{};

    for (final transaction in recentTransactions) {
      final type = transaction.type;
      summary[type] = (summary[type] ?? 0) + 1;
      totalQuantity[type] = (totalQuantity[type] ?? 0) + transaction.quantity;
      
      // Calculate value for restock transactions
      if (type == 'restock') {
        final item = getItemById(transaction.inventoryItemId);
        if (item != null) {
          totalValue[type] = (totalValue[type] ?? 0) + (transaction.quantity * item.costPerUnit);
        }
      }
    }

    return {
      'totalTransactions': recentTransactions.length,
      'transactionsByType': summary,
      'quantityByType': totalQuantity,
      'valueByType': totalValue,
    };
  }

  // Sample Data

  /// Load sample inventory data for demonstration.
  Future<void> loadSampleData() async {
    if (_items.isNotEmpty) {
      debugPrint('Sample data already loaded');
      return;
    }

    final sampleItems = [
      InventoryItem(
        name: 'Tomatoes',
        description: 'Fresh red tomatoes',
        category: InventoryCategory.produce,
        unit: InventoryUnit.kilograms,
        currentStock: 15.5,
        minimumStock: 5.0,
        maximumStock: 25.0,
        costPerUnit: 2.50,
        supplier: 'Fresh Farms',
        supplierContact: '555-0123',
        expiryDate: DateTime.now().add(const Duration(days: 7)),
      ),
      InventoryItem(
        name: 'Ground Beef',
        description: 'Premium ground beef',
        category: InventoryCategory.meat,
        unit: InventoryUnit.kilograms,
        currentStock: 8.0,
        minimumStock: 3.0,
        maximumStock: 15.0,
        costPerUnit: 12.00,
        supplier: 'Meat Co.',
        supplierContact: '555-0456',
        expiryDate: DateTime.now().add(const Duration(days: 3)),
      ),
      InventoryItem(
        name: 'Milk',
        description: 'Whole milk',
        category: InventoryCategory.dairy,
        unit: InventoryUnit.liters,
        currentStock: 12.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 3.50,
        supplier: 'Dairy Fresh',
        supplierContact: '555-0789',
        expiryDate: DateTime.now().add(const Duration(days: 5)),
      ),
      InventoryItem(
        name: 'Flour',
        description: 'All-purpose flour',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 25.0,
        minimumStock: 10.0,
        maximumStock: 50.0,
        costPerUnit: 1.80,
        supplier: 'Baking Supplies',
        supplierContact: '555-0321',
      ),
      InventoryItem(
        name: 'Coca Cola',
        description: '2L bottles',
        category: InventoryCategory.beverages,
        unit: InventoryUnit.pieces,
        currentStock: 24,
        minimumStock: 10,
        maximumStock: 50,
        costPerUnit: 2.00,
        supplier: 'Beverage Co.',
        supplierContact: '555-0654',
      ),
      InventoryItem(
        name: 'Salt',
        description: 'Table salt',
        category: InventoryCategory.spices,
        unit: InventoryUnit.kilograms,
        currentStock: 2.0,
        minimumStock: 1.0,
        maximumStock: 5.0,
        costPerUnit: 0.50,
        supplier: 'Spice World',
        supplierContact: '555-0987',
      ),
      InventoryItem(
        name: 'French Fries',
        description: 'Frozen french fries',
        category: InventoryCategory.frozen,
        unit: InventoryUnit.kilograms,
        currentStock: 18.0,
        minimumStock: 8.0,
        maximumStock: 30.0,
        costPerUnit: 4.50,
        supplier: 'Frozen Foods',
        supplierContact: '555-0124',
      ),
    ];

    for (final item in sampleItems) {
      await addItem(item);
    }

    // Add some sample transactions
    await restockItem(sampleItems[0].id, 5.0, reason: 'Weekly restock');
    await useStock(sampleItems[1].id, 2.0, reason: 'Kitchen usage');
    await recordWaste(sampleItems[2].id, 0.5, reason: 'Expired');

    debugPrint('Sample inventory data loaded successfully');
  }

  /// Clear all data (for testing).
  Future<void> clearAllData() async {
    _items.clear();
    _transactions.clear();
    await _saveData();
    debugPrint('All inventory data cleared');
  }

} 