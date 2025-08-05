import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/models/inventory_item.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';

void main() {
  group('Inventory Management Tests', () {
    
    test('Should create inventory items with correct properties', () {
      final inventoryItem = InventoryItem(
        name: 'Fresh Tomatoes',
        description: 'Organic fresh tomatoes',
        category: InventoryCategory.produce,
        unit: InventoryUnit.kilograms,
        currentStock: 50.0,
        minimumStock: 10.0,
        maximumStock: 100.0,
        costPerUnit: 3.50,
        supplier: 'Local Farm Co',
        supplierContact: 'farm@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(inventoryItem.name, equals('Fresh Tomatoes'));
      expect(inventoryItem.category, equals(InventoryCategory.produce));
      expect(inventoryItem.currentStock, equals(50.0));
      expect(inventoryItem.costPerUnit, equals(3.50));
      expect(inventoryItem.isLowStock, isFalse);
      expect(inventoryItem.isOutOfStock, isFalse);
    });

    test('Should detect low stock correctly', () {
      final lowStockItem = InventoryItem(
        name: 'Low Stock Item',
        description: 'Item with low stock',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 5.0,
        minimumStock: 10.0,
        maximumStock: 50.0,
        costPerUnit: 5.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(lowStockItem.isLowStock, isTrue);
      expect(lowStockItem.isOutOfStock, isFalse);
    });

    test('Should detect out of stock correctly', () {
      final outOfStockItem = InventoryItem(
        name: 'Out of Stock Item',
        description: 'Item with no stock',
        category: InventoryCategory.meat,
        unit: InventoryUnit.kilograms,
        currentStock: 0.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 12.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(outOfStockItem.isOutOfStock, isTrue);
      expect(outOfStockItem.isLowStock, isTrue);
    });

    test('Should calculate inventory value correctly', () {
      final inventoryItem = InventoryItem(
        name: 'Test Item',
        description: 'Test item for value calculation',
        category: InventoryCategory.dairy,
        unit: InventoryUnit.kilograms,
        currentStock: 25.0,
        minimumStock: 5.0,
        maximumStock: 50.0,
        costPerUnit: 8.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expectedValue = 25.0 * 8.0; // currentStock * costPerUnit
      expect(inventoryItem.totalValue, equals(expectedValue));
    });

    test('Should handle inventory categories correctly', () {
      final produceItem = InventoryItem(
        name: 'Produce Item',
        description: 'Fresh produce',
        category: InventoryCategory.produce,
        unit: InventoryUnit.kilograms,
        currentStock: 10.0,
        minimumStock: 2.0,
        maximumStock: 20.0,
        costPerUnit: 4.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final meatItem = InventoryItem(
        name: 'Meat Item',
        description: 'Fresh meat',
        category: InventoryCategory.meat,
        unit: InventoryUnit.kilograms,
        currentStock: 15.0,
        minimumStock: 3.0,
        maximumStock: 30.0,
        costPerUnit: 15.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(produceItem.category, equals(InventoryCategory.produce));
      expect(meatItem.category, equals(InventoryCategory.meat));
    });

    test('Should handle inventory units correctly', () {
      final kgItem = InventoryItem(
        name: 'Kilogram Item',
        description: 'Item measured in kg',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 5.0,
        minimumStock: 1.0,
        maximumStock: 10.0,
        costPerUnit: 10.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final literItem = InventoryItem(
        name: 'Liter Item',
        description: 'Item measured in liters',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.liters,
        currentStock: 2.5,
        minimumStock: 0.5,
        maximumStock: 5.0,
        costPerUnit: 5.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(kgItem.unit, equals(InventoryUnit.kilograms));
      expect(literItem.unit, equals(InventoryUnit.liters));
    });

    test('Should handle expiry dates correctly', () {
      final futureDate = DateTime.now().add(const Duration(days: 7));
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      final freshItem = InventoryItem(
        name: 'Fresh Item',
        description: 'Item with future expiry',
        category: InventoryCategory.dairy,
        unit: InventoryUnit.kilograms,
        currentStock: 10.0,
        minimumStock: 2.0,
        maximumStock: 20.0,
        costPerUnit: 8.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        expiryDate: futureDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final expiredItem = InventoryItem(
        name: 'Expired Item',
        description: 'Item with past expiry',
        category: InventoryCategory.dairy,
        unit: InventoryUnit.kilograms,
        currentStock: 5.0,
        minimumStock: 1.0,
        maximumStock: 10.0,
        costPerUnit: 6.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        expiryDate: pastDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(freshItem.isExpired, isFalse);
      expect(expiredItem.isExpired, isTrue);
    });

    test('Should simulate inventory reduction from order', () {
      // Create inventory items
      final tomatoes = InventoryItem(
        name: 'Fresh Tomatoes',
        description: 'Organic fresh tomatoes',
        category: InventoryCategory.produce,
        unit: InventoryUnit.kilograms,
        currentStock: 50.0,
        minimumStock: 10.0,
        maximumStock: 100.0,
        costPerUnit: 3.50,
        supplier: 'Local Farm Co',
        supplierContact: 'farm@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final chicken = InventoryItem(
        name: 'Chicken Breast',
        description: 'Premium boneless chicken breast',
        category: InventoryCategory.meat,
        unit: InventoryUnit.kilograms,
        currentStock: 25.0,
        minimumStock: 5.0,
        maximumStock: 50.0,
        costPerUnit: 12.99,
        supplier: 'Meat Suppliers Inc',
        supplierContact: 'orders@meatsuppliers.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create menu items that use these inventory items
      final pizzaMenuItem = MenuItem(
        name: 'Margherita Pizza',
        description: 'Classic pizza with tomatoes and mozzarella',
        categoryId: 'pizza',
        price: 18.99,
        allergens: {'dairy': true, 'gluten': true},
        nutritionalInfo: {'calories': 850, 'protein': 25},
        variants: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final chickenMenuItem = MenuItem(
        name: 'Grilled Chicken',
        description: 'Grilled chicken breast with herbs',
        categoryId: 'main',
        price: 22.99,
        allergens: {},
        nutritionalInfo: {'calories': 450, 'protein': 35},
        variants: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create order items
      final pizzaOrderItem = OrderItem(
        menuItem: pizzaMenuItem,
        quantity: 2,
        unitPrice: 18.99,
        specialInstructions: 'Extra cheese',
        notes: 'Customer prefers crispy crust',
        isAvailable: true,
        sentToKitchen: false,
        createdAt: DateTime.now(),
      );

      final chickenOrderItem = OrderItem(
        menuItem: chickenMenuItem,
        quantity: 1,
        unitPrice: 22.99,
        specialInstructions: 'Well done',
        notes: 'Allergic to garlic',
        isAvailable: true,
        sentToKitchen: false,
        createdAt: DateTime.now(),
      );

      // Simulate inventory reduction (this would normally be handled by the service)
      // For 2 pizzas: 2 * 0.3kg tomatoes = 0.6kg tomatoes
      // For 1 chicken dish: 1 * 0.25kg chicken = 0.25kg chicken
      
      final tomatoesUsed = 0.6; // kg
      final chickenUsed = 0.25; // kg

      // Verify initial stock levels
      expect(tomatoes.currentStock, equals(50.0));
      expect(chicken.currentStock, equals(25.0));

      // Simulate stock reduction using copyWith
      final updatedTomatoes = tomatoes.copyWith(currentStock: tomatoes.currentStock - tomatoesUsed);
      final updatedChicken = chicken.copyWith(currentStock: chicken.currentStock - chickenUsed);

      // Verify updated stock levels
      expect(updatedTomatoes.currentStock, equals(49.4)); // 50.0 - 0.6
      expect(updatedChicken.currentStock, equals(24.75)); // 25.0 - 0.25

      // Verify items are still in stock
      expect(updatedTomatoes.isOutOfStock, isFalse);
      expect(updatedChicken.isOutOfStock, isFalse);
    });

    test('Should handle inventory alerts correctly', () {
      final criticalItem = InventoryItem(
        name: 'Critical Item',
        description: 'Item with very low stock',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 2.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 10.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final normalItem = InventoryItem(
        name: 'Normal Item',
        description: 'Item with normal stock',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 15.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 8.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Critical item should trigger alerts
      expect(criticalItem.isLowStock, isTrue);
      expect(criticalItem.isOutOfStock, isFalse);

      // Normal item should not trigger alerts
      expect(normalItem.isLowStock, isFalse);
      expect(normalItem.isOutOfStock, isFalse);
    });

    test('Should calculate stock percentage correctly', () {
      final inventoryItem = InventoryItem(
        name: 'Test Item',
        description: 'Item for percentage calculation',
        category: InventoryCategory.dairy,
        unit: InventoryUnit.kilograms,
        currentStock: 15.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 10.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Stock percentage should be (15.0 / 20.0) * 100 = 75%
      expect(inventoryItem.stockPercentage, equals(75.0));
    });

    test('Should handle inventory item updates correctly', () {
      final inventoryItem = InventoryItem(
        name: 'Original Name',
        description: 'Original description',
        category: InventoryCategory.produce,
        unit: InventoryUnit.kilograms,
        currentStock: 10.0,
        minimumStock: 2.0,
        maximumStock: 20.0,
        costPerUnit: 5.0,
        supplier: 'Original Supplier',
        supplierContact: 'original@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Simulate updating the item using copyWith
      final originalUpdatedAt = inventoryItem.updatedAt;
      
      // Update properties
      final updatedItem = inventoryItem.copyWith(
        name: 'Updated Name',
        currentStock: 15.0,
        costPerUnit: 6.0,
        updatedAt: DateTime.now(),
      );

      expect(updatedItem.name, equals('Updated Name'));
      expect(updatedItem.currentStock, equals(15.0));
      expect(updatedItem.costPerUnit, equals(6.0));
      expect(updatedItem.updatedAt.isAfter(originalUpdatedAt), isTrue);
    });

    test('Should handle inventory transactions correctly', () {
      final inventoryItem = InventoryItem(
        name: 'Test Item',
        description: 'Item for transaction testing',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 10.0,
        minimumStock: 2.0,
        maximumStock: 20.0,
        costPerUnit: 8.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create inventory transactions
      final restockTransaction = InventoryTransaction(
        inventoryItemId: inventoryItem.id,
        type: 'restock',
        quantity: 5.0,
        reason: 'Regular restock',
        notes: 'Received from supplier',
        userId: 'admin',
      );

      final usageTransaction = InventoryTransaction(
        inventoryItemId: inventoryItem.id,
        type: 'usage',
        quantity: 2.0,
        reason: 'Order fulfillment',
        notes: 'Used for menu items',
        userId: 'kitchen',
      );

      expect(restockTransaction.type, equals('restock'));
      expect(restockTransaction.quantity, equals(5.0));
      expect(usageTransaction.type, equals('usage'));
      expect(usageTransaction.quantity, equals(2.0));
    });

    test('Should handle unit display correctly', () {
      final kgItem = InventoryItem(
        name: 'Kilogram Item',
        description: 'Item in kg',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 5.0,
        minimumStock: 1.0,
        maximumStock: 10.0,
        costPerUnit: 10.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final literItem = InventoryItem(
        name: 'Liter Item',
        description: 'Item in liters',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.liters,
        currentStock: 2.5,
        minimumStock: 0.5,
        maximumStock: 5.0,
        costPerUnit: 5.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(kgItem.unitDisplay, equals('kg'));
      expect(literItem.unitDisplay, equals('L'));
    });

    test('Should handle category display correctly', () {
      final produceItem = InventoryItem(
        name: 'Produce Item',
        description: 'Fresh produce',
        category: InventoryCategory.produce,
        unit: InventoryUnit.kilograms,
        currentStock: 10.0,
        minimumStock: 2.0,
        maximumStock: 20.0,
        costPerUnit: 4.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final meatItem = InventoryItem(
        name: 'Meat Item',
        description: 'Fresh meat',
        category: InventoryCategory.meat,
        unit: InventoryUnit.kilograms,
        currentStock: 15.0,
        minimumStock: 3.0,
        maximumStock: 30.0,
        costPerUnit: 15.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(produceItem.category.categoryDisplay, equals('Produce'));
      expect(meatItem.category.categoryDisplay, equals('Meat'));
    });
  });
} 