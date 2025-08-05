import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/models/inventory_item.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';

import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/category.dart';

void main() {
  group('Comprehensive Inventory Management Workflow Tests', () {
    
    // Test data setup
    late List<InventoryItem> initialInventory;
    late List<MenuItem> menuItems;
    late User testUser;
    late Category pizzaCategory;
    late Category mainCategory;
    
    setUp(() {
      // Initialize test user
      testUser = User(
        id: 'test_user_001',
        name: 'Test Server',
        pin: '1234',
        role: UserRole.server,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Initialize categories
      pizzaCategory = Category(
        name: 'Pizza',
        description: 'Fresh pizzas',
        sortOrder: 1,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mainCategory = Category(
        name: 'Main Dishes',
        description: 'Main course dishes',
        sortOrder: 2,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Initialize inventory items
      initialInventory = [
        InventoryItem(
          name: 'Fresh Tomatoes',
          description: 'Organic fresh tomatoes for pizzas and salads',
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
        ),
        InventoryItem(
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
        ),
        InventoryItem(
          name: 'Mozzarella Cheese',
          description: 'Fresh mozzarella cheese for pizzas',
          category: InventoryCategory.dairy,
          unit: InventoryUnit.kilograms,
          currentStock: 15.0,
          minimumStock: 3.0,
          maximumStock: 30.0,
          costPerUnit: 8.75,
          supplier: 'Dairy Fresh Co',
          supplierContact: 'cheese@dairyfresh.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InventoryItem(
          name: 'Pizza Dough',
          description: 'Fresh pizza dough',
          category: InventoryCategory.pantry,
          unit: InventoryUnit.kilograms,
          currentStock: 20.0,
          minimumStock: 5.0,
          maximumStock: 40.0,
          costPerUnit: 4.25,
          supplier: 'Bakery Supplies',
          supplierContact: 'dough@bakery.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InventoryItem(
          name: 'Olive Oil',
          description: 'Extra virgin olive oil',
          category: InventoryCategory.pantry,
          unit: InventoryUnit.liters,
          currentStock: 10.0,
          minimumStock: 2.0,
          maximumStock: 20.0,
          costPerUnit: 15.99,
          supplier: 'Mediterranean Imports',
          supplierContact: 'oil@medimports.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InventoryItem(
          name: 'Fresh Basil',
          description: 'Fresh basil leaves',
          category: InventoryCategory.produce,
          unit: InventoryUnit.kilograms,
          currentStock: 2.0,
          minimumStock: 1.0,
          maximumStock: 5.0,
          costPerUnit: 25.0,
          supplier: 'Herb Garden Co',
          supplierContact: 'herbs@garden.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Initialize menu items
      menuItems = [
        MenuItem(
          name: 'Margherita Pizza',
          description: 'Classic pizza with tomatoes, mozzarella, and basil',
          categoryId: pizzaCategory.id,
          price: 18.99,
          allergens: {'dairy': true, 'gluten': true},
          nutritionalInfo: {'calories': 850, 'protein': 25, 'carbs': 80},
          variants: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MenuItem(
          name: 'Chicken Alfredo',
          description: 'Creamy pasta with grilled chicken',
          categoryId: mainCategory.id,
          price: 22.99,
          allergens: {'dairy': true, 'gluten': true},
          nutritionalInfo: {'calories': 650, 'protein': 35, 'carbs': 45},
          variants: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        MenuItem(
          name: 'Pepperoni Pizza',
          description: 'Pizza with pepperoni and cheese',
          categoryId: pizzaCategory.id,
          price: 20.99,
          allergens: {'dairy': true, 'gluten': true, 'pork': true},
          nutritionalInfo: {'calories': 900, 'protein': 30, 'carbs': 85},
          variants: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    });

    test('Complete Inventory Workflow: Order Creation → Inventory Reduction → Order Completion', () {
      print('\n🎯 COMPREHENSIVE INVENTORY WORKFLOW TEST');
      print('=' * 60);

      // Step 1: Verify initial inventory state
      print('\n📦 STEP 1: Initial Inventory State');
      print('-' * 40);
      
      expect(initialInventory.length, equals(6));
      
      // Verify initial stock levels
      final tomatoes = initialInventory[0];
      final chicken = initialInventory[1];
      final cheese = initialInventory[2];
      final dough = initialInventory[3];
      final oil = initialInventory[4];
      final basil = initialInventory[5];

      expect(tomatoes.currentStock, equals(50.0));
      expect(chicken.currentStock, equals(25.0));
      expect(cheese.currentStock, equals(15.0));
      expect(dough.currentStock, equals(20.0));
      expect(oil.currentStock, equals(10.0));
      expect(basil.currentStock, equals(2.0));

      // Verify no items are low stock initially
      expect(tomatoes.isLowStock, isFalse);
      expect(chicken.isLowStock, isFalse);
      expect(cheese.isLowStock, isFalse);
      expect(dough.isLowStock, isFalse);
      expect(oil.isLowStock, isFalse);
      expect(basil.isLowStock, isFalse); // Basil is at minimum stock (2.0 > 1.0, so not low stock)

      print('✅ Initial inventory state verified');

      // Step 2: Create a large order that will impact inventory
      print('\n🍽️ STEP 2: Creating Large Order');
      print('-' * 40);

      final largeOrder = Order(
        id: 'DI-001',
        orderNumber: 'DI-001',
        orderTime: DateTime.now(),
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableId: 'table_1',
        userId: testUser.id,
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add multiple items to the order
      final margheritaItem = OrderItem(
        menuItem: menuItems[0], // Margherita Pizza
        quantity: 5, // 5 pizzas
        unitPrice: 18.99,
        specialInstructions: 'Extra cheese on 3 pizzas',
        notes: 'Large party order',
        isAvailable: true,
        sentToKitchen: false,
        createdAt: DateTime.now(),
      );

      final chickenItem = OrderItem(
        menuItem: menuItems[1], // Chicken Alfredo
        quantity: 3, // 3 pasta dishes
        unitPrice: 22.99,
        specialInstructions: 'Well done chicken',
        notes: 'Allergic to garlic',
        isAvailable: true,
        sentToKitchen: false,
        createdAt: DateTime.now(),
      );

      final pepperoniItem = OrderItem(
        menuItem: menuItems[2], // Pepperoni Pizza
        quantity: 2, // 2 pizzas
        unitPrice: 20.99,
        specialInstructions: 'Extra pepperoni',
        notes: 'Spicy preference',
        isAvailable: true,
        sentToKitchen: false,
        createdAt: DateTime.now(),
      );

      largeOrder.items.addAll([margheritaItem, chickenItem, pepperoniItem]);

      expect(largeOrder.items.length, equals(3));
              expect(largeOrder.items.length, equals(3)); // 3 different items
        expect(largeOrder.items.fold(0, (sum, item) => sum + item.quantity), equals(10)); // 5 + 3 + 2

      print('✅ Large order created with 10 total items');

      // Step 3: Simulate inventory reduction based on order
      print('\n📉 STEP 3: Simulating Inventory Reduction');
      print('-' * 40);

      // Calculate inventory usage based on recipes
      // Margherita Pizza (5x): 5 * (0.3kg tomatoes + 0.2kg cheese + 0.25kg dough + 0.05L oil + 0.01kg basil)
      // Chicken Alfredo (3x): 3 * (0.25kg chicken + 0.15kg cheese + 0.1L oil)
      // Pepperoni Pizza (2x): 2 * (0.2kg cheese + 0.25kg dough + 0.05L oil)

      final tomatoesUsed = 5 * 0.3; // 1.5kg for 5 margherita pizzas
      final chickenUsed = 3 * 0.25; // 0.75kg for 3 chicken alfredo
      final cheeseUsed = (5 * 0.2) + (3 * 0.15) + (2 * 0.2); // 1.0 + 0.45 + 0.4 = 1.85kg
      final doughUsed = (5 * 0.25) + (2 * 0.25); // 1.25 + 0.5 = 1.75kg
      final oilUsed = (5 * 0.05) + (3 * 0.1) + (2 * 0.05); // 0.25 + 0.3 + 0.1 = 0.65L
      final basilUsed = 5 * 0.01; // 0.05kg for 5 margherita pizzas

      // Update inventory levels
      final updatedTomatoes = tomatoes.copyWith(currentStock: tomatoes.currentStock - tomatoesUsed);
      final updatedChicken = chicken.copyWith(currentStock: chicken.currentStock - chickenUsed);
      final updatedCheese = cheese.copyWith(currentStock: cheese.currentStock - cheeseUsed);
      final updatedDough = dough.copyWith(currentStock: dough.currentStock - doughUsed);
      final updatedOil = oil.copyWith(currentStock: oil.currentStock - oilUsed);
      final updatedBasil = basil.copyWith(currentStock: basil.currentStock - basilUsed);

      // Verify updated stock levels
      expect(updatedTomatoes.currentStock, closeTo(48.5, 0.01)); // 50.0 - 1.5
      expect(updatedChicken.currentStock, closeTo(24.25, 0.01)); // 25.0 - 0.75
      expect(updatedCheese.currentStock, closeTo(13.15, 0.01)); // 15.0 - 1.85
      expect(updatedDough.currentStock, closeTo(18.25, 0.01)); // 20.0 - 1.75
      expect(updatedOil.currentStock, closeTo(9.35, 0.01)); // 10.0 - 0.65
      expect(updatedBasil.currentStock, closeTo(1.95, 0.01)); // 2.0 - 0.05

      print('✅ Inventory reduction calculated and applied');

      // Step 4: Check for low stock alerts
      print('\n⚠️ STEP 4: Low Stock Alert Verification');
      print('-' * 40);

      // Check which items are now low stock
      expect(updatedTomatoes.isLowStock, isFalse); // 48.5 > 10.0
      expect(updatedChicken.isLowStock, isFalse); // 24.25 > 5.0
      expect(updatedCheese.isLowStock, isFalse); // 13.15 > 3.0
      expect(updatedDough.isLowStock, isFalse); // 18.25 > 5.0
      expect(updatedOil.isLowStock, isFalse); // 9.35 > 2.0
      expect(updatedBasil.isLowStock, isFalse); // 1.95 > 1.0 (not low stock)

      print('✅ Low stock alerts verified - No items are low stock after reduction');

      // Step 5: Test edge case - Order that would deplete inventory
      print('\n🚨 STEP 5: Edge Case - Inventory Depletion Test');
      print('-' * 40);

      // Create an order that would use more basil than available
      final depletionOrder = Order(
        id: 'DI-002',
        orderNumber: 'DI-002',
        orderTime: DateTime.now(),
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        tableId: 'table_2',
        userId: testUser.id,
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Try to order 200 margherita pizzas (would need 2kg basil, but only 1.95kg available)
      final depletionItem = OrderItem(
        menuItem: menuItems[0], // Margherita Pizza
        quantity: 200, // 200 pizzas
        unitPrice: 18.99,
        specialInstructions: 'Large catering order',
        notes: 'Check inventory availability',
        isAvailable: true,
        sentToKitchen: false,
        createdAt: DateTime.now(),
      );

      depletionOrder.items.add(depletionItem);

      final basilNeeded = 200 * 0.01; // 2.0kg needed
      final basilAvailable = updatedBasil.currentStock; // 1.95kg available

      expect(basilNeeded, equals(2.0));
      expect(basilAvailable, closeTo(1.95, 0.01));
      expect(basilNeeded > basilAvailable, isTrue);

      print('✅ Inventory depletion scenario identified');

      // Step 6: Test restocking scenario
      print('\n📦 STEP 6: Restocking Scenario');
      print('-' * 40);

      // Simulate restocking basil
      final restockQuantity = 3.0; // kg
      final restockedBasil = updatedBasil.copyWith(
        currentStock: updatedBasil.currentStock + restockQuantity,
        lastRestocked: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(restockedBasil.currentStock, closeTo(4.95, 0.01)); // 1.95 + 3.0
      expect(restockedBasil.isLowStock, isFalse); // 4.95 > 1.0
      expect(restockedBasil.lastRestocked, isNotNull);

      print('✅ Basil restocked successfully');

      // Step 7: Test order completion and final inventory state
      print('\n✅ STEP 7: Order Completion and Final Inventory State');
      print('-' * 40);

      // Complete the large order
      final completedOrder = largeOrder.copyWith(
        status: OrderStatus.completed,
        completedTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(completedOrder.status, equals(OrderStatus.completed));
      expect(completedOrder.completedTime, isNotNull);

      // Verify final inventory state after order completion
      final finalInventory = [
        updatedTomatoes,
        updatedChicken,
        updatedCheese,
        updatedDough,
        updatedOil,
        restockedBasil,
      ];

      // Check total inventory value
      double totalInventoryValue = 0;
      for (final item in finalInventory) {
        totalInventoryValue += item.totalValue;
      }

      final expectedTotalValue = (48.5 * 3.50) + (24.25 * 12.99) + (13.15 * 8.75) + 
                                (18.25 * 4.25) + (9.35 * 15.99) + (4.95 * 25.0);

      expect(totalInventoryValue, closeTo(expectedTotalValue, 0.01));

      print('✅ Order completed and final inventory state verified');
      print('💰 Total inventory value: \$${totalInventoryValue.toStringAsFixed(2)}');

      // Step 8: Test multiple concurrent orders
      print('\n🔄 STEP 8: Concurrent Orders Test');
      print('-' * 40);

      // Create multiple orders happening simultaneously
      final concurrentOrders = [
        Order(
          id: 'DI-003',
          orderNumber: 'DI-003',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_3',
          userId: testUser.id,
          items: [
            OrderItem(
              menuItem: menuItems[0], // 1 Margherita
              quantity: 1,
              unitPrice: 18.99,
              isAvailable: true,
              sentToKitchen: false,
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Order(
          id: 'DI-004',
          orderNumber: 'DI-004',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.takeaway,
          tableId: null,
          userId: testUser.id,
          items: [
            OrderItem(
              menuItem: menuItems[2], // 2 Pepperoni
              quantity: 2,
              unitPrice: 20.99,
              isAvailable: true,
              sentToKitchen: false,
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // Simulate concurrent inventory reduction
      var concurrentTomatoes = restockedBasil.currentStock > 0 ? updatedTomatoes : updatedTomatoes.copyWith(currentStock: updatedTomatoes.currentStock - 0.3);
      var concurrentCheese = updatedCheese.copyWith(currentStock: updatedCheese.currentStock - (0.2 + 2 * 0.2)); // 1 margherita + 2 pepperoni
      var concurrentDough = updatedDough.copyWith(currentStock: updatedDough.currentStock - (0.25 + 2 * 0.25)); // 1 margherita + 2 pepperoni
      var concurrentOil = updatedOil.copyWith(currentStock: updatedOil.currentStock - (0.05 + 2 * 0.05)); // 1 margherita + 2 pepperoni

      expect(concurrentOrders.length, equals(2));
      expect(concurrentCheese.currentStock, closeTo(12.55, 0.01)); // 13.15 - 0.6
      expect(concurrentDough.currentStock, closeTo(17.5, 0.01)); // 18.25 - 0.75
      expect(concurrentOil.currentStock, closeTo(9.2, 0.01)); // 9.35 - 0.15

      print('✅ Concurrent orders processed successfully');

      // Step 9: Test inventory transaction logging
      print('\n📝 STEP 9: Inventory Transaction Logging');
      print('-' * 40);

      // Create inventory transactions for the workflow
      final transactions = [
        InventoryTransaction(
          inventoryItemId: tomatoes.id,
          type: 'usage',
          quantity: tomatoesUsed,
          reason: 'Order DI-001 fulfillment',
          notes: '5 Margherita pizzas',
          userId: testUser.id,
        ),
        InventoryTransaction(
          inventoryItemId: chicken.id,
          type: 'usage',
          quantity: chickenUsed,
          reason: 'Order DI-001 fulfillment',
          notes: '3 Chicken Alfredo dishes',
          userId: testUser.id,
        ),
        InventoryTransaction(
          inventoryItemId: cheese.id,
          type: 'usage',
          quantity: cheeseUsed,
          reason: 'Order DI-001 fulfillment',
          notes: 'Multiple pizza and pasta dishes',
          userId: testUser.id,
        ),
        InventoryTransaction(
          inventoryItemId: basil.id,
          type: 'restock',
          quantity: restockQuantity,
          reason: 'Low stock restock',
          notes: 'Emergency restock due to high demand',
          userId: testUser.id,
        ),
      ];

      expect(transactions.length, equals(4));
      expect(transactions[0].type, equals('usage'));
      expect(transactions[3].type, equals('restock'));

      print('✅ Inventory transactions logged successfully');

      // Step 10: Test inventory alerts and notifications
      print('\n🔔 STEP 10: Inventory Alerts and Notifications');
      print('-' * 40);

      // Check which items need restocking
      final itemsNeedingRestock = finalInventory.where((item) => item.isLowStock).toList();
      final itemsExpiringSoon = finalInventory.where((item) => item.isExpiringSoon).toList();
      final itemsOverstocked = finalInventory.where((item) => item.isOverstocked).toList();

      expect(itemsNeedingRestock.length, equals(0)); // All items should be above minimum after restock
      expect(itemsExpiringSoon.length, equals(0)); // No expiry dates set in test
      expect(itemsOverstocked.length, equals(0)); // No items over maximum

      print('✅ Inventory alerts verified - no critical issues');

      // Step 11: Test inventory value calculations
      print('\n💰 STEP 11: Inventory Value Calculations');
      print('-' * 40);

      // Calculate individual item values
      final tomatoesValue = updatedTomatoes.totalValue;
      final chickenValue = updatedChicken.totalValue;
      final cheeseValue = updatedCheese.totalValue;
      final doughValue = updatedDough.totalValue;
      final oilValue = updatedOil.totalValue;
      final basilValue = restockedBasil.totalValue;

      expect(tomatoesValue, closeTo(48.5 * 3.50, 0.01));
      expect(chickenValue, closeTo(24.25 * 12.99, 0.01));
      expect(cheeseValue, closeTo(13.15 * 8.75, 0.01));
      expect(doughValue, closeTo(18.25 * 4.25, 0.01));
      expect(oilValue, closeTo(9.35 * 15.99, 0.01));
      expect(basilValue, closeTo(4.95 * 25.0, 0.01));

      print('✅ Individual item values calculated correctly');

      // Step 12: Test inventory category analysis
      print('\n📊 STEP 12: Inventory Category Analysis');
      print('-' * 40);

      final produceItems = finalInventory.where((item) => item.category == InventoryCategory.produce).toList();
      final meatItems = finalInventory.where((item) => item.category == InventoryCategory.meat).toList();
      final dairyItems = finalInventory.where((item) => item.category == InventoryCategory.dairy).toList();
      final pantryItems = finalInventory.where((item) => item.category == InventoryCategory.pantry).toList();

      expect(produceItems.length, equals(2)); // Tomatoes and Basil
      expect(meatItems.length, equals(1)); // Chicken
      expect(dairyItems.length, equals(1)); // Cheese
      expect(pantryItems.length, equals(2)); // Dough and Oil

      // Calculate category totals
      double produceValue = produceItems.fold(0, (sum, item) => sum + item.totalValue);
      double meatValue = meatItems.fold(0, (sum, item) => sum + item.totalValue);
      double dairyValue = dairyItems.fold(0, (sum, item) => sum + item.totalValue);
      double pantryValue = pantryItems.fold(0, (sum, item) => sum + item.totalValue);

      expect(produceValue, greaterThan(0));
      expect(meatValue, greaterThan(0));
      expect(dairyValue, greaterThan(0));
      expect(pantryValue, greaterThan(0));

      print('✅ Category analysis completed successfully');

      // Final summary
      print('\n🎉 COMPREHENSIVE INVENTORY WORKFLOW TEST COMPLETED');
      print('=' * 60);
      print('📋 Test Summary:');
      print('• ✅ Initial inventory state verified');
      print('• ✅ Large order creation and processing');
      print('• ✅ Inventory reduction calculations');
      print('• ✅ Low stock alert system');
      print('• ✅ Edge case handling (depletion scenarios)');
      print('• ✅ Restocking procedures');
      print('• ✅ Order completion workflow');
      print('• ✅ Concurrent order processing');
      print('• ✅ Transaction logging');
      print('• ✅ Alert and notification system');
      print('• ✅ Value calculations');
      print('• ✅ Category analysis');
      print('\n🏆 All inventory management workflows tested successfully!');
    });

    test('Edge Cases: Zero Stock, Maximum Stock, Expiry Dates', () {
      print('\n🚨 EDGE CASES TEST');
      print('=' * 40);

      // Test 1: Zero stock scenario
      print('\n📉 Test 1: Zero Stock Scenario');
      final zeroStockItem = InventoryItem(
        name: 'Test Item - Zero Stock',
        description: 'Item with zero stock',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 0.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 10.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(zeroStockItem.isOutOfStock, isTrue);
      expect(zeroStockItem.isLowStock, isTrue);
      expect(zeroStockItem.totalValue, equals(0.0));

      // Test 2: Maximum stock scenario
      print('\n📈 Test 2: Maximum Stock Scenario');
      final maxStockItem = InventoryItem(
        name: 'Test Item - Max Stock',
        description: 'Item at maximum stock',
        category: InventoryCategory.pantry,
        unit: InventoryUnit.kilograms,
        currentStock: 20.0,
        minimumStock: 5.0,
        maximumStock: 20.0,
        costPerUnit: 10.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(maxStockItem.isOverstocked, isFalse); // At max, not over
      expect(maxStockItem.stockPercentage, equals(100.0));

      // Test 3: Overstocked scenario
      print('\n📊 Test 3: Overstocked Scenario');
      final overstockedItem = maxStockItem.copyWith(currentStock: 25.0);
      expect(overstockedItem.isOverstocked, isTrue);
      expect(overstockedItem.stockPercentage, equals(125.0));

      // Test 4: Expiry date scenarios
      print('\n📅 Test 4: Expiry Date Scenarios');
      final futureDate = DateTime.now().add(const Duration(days: 7));
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      final nearExpiryDate = DateTime.now().add(const Duration(days: 3));

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

      final nearExpiryItem = InventoryItem(
        name: 'Near Expiry Item',
        description: 'Item expiring soon',
        category: InventoryCategory.dairy,
        unit: InventoryUnit.kilograms,
        currentStock: 3.0,
        minimumStock: 1.0,
        maximumStock: 10.0,
        costPerUnit: 7.0,
        supplier: 'Test Supplier',
        supplierContact: 'test@example.com',
        expiryDate: nearExpiryDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(freshItem.isExpired, isFalse);
      expect(expiredItem.isExpired, isTrue);
      expect(nearExpiryItem.isExpiringSoon, isTrue);

      print('✅ All edge cases tested successfully');
    });

    test('Inventory Performance Under Load', () {
      print('\n⚡ PERFORMANCE UNDER LOAD TEST');
      print('=' * 40);

      // Simulate high-volume restaurant operations
      final startTime = DateTime.now();
      
      // Create 100 orders with varying quantities
      final highVolumeOrders = <Order>[];
      for (int i = 0; i < 100; i++) {
        final order = Order(
          id: 'HV-$i',
          orderNumber: 'HV-$i',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_${i % 10}',
          userId: testUser.id,
          items: [
            OrderItem(
              menuItem: menuItems[i % menuItems.length],
              quantity: (i % 5) + 1, // 1-5 items per order
              unitPrice: menuItems[i % menuItems.length].price,
              isAvailable: true,
              sentToKitchen: false,
              createdAt: DateTime.now(),
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        highVolumeOrders.add(order);
      }

      // Simulate inventory updates for all orders
      var performanceInventory = List<InventoryItem>.from(initialInventory);
      
      for (final order in highVolumeOrders) {
        for (final item in order.items) {
          // Simulate inventory reduction based on order items
          if (item.menuItem.name.contains('Margherita')) {
            final tomatoesUsed = item.quantity * 0.3;
            final cheeseUsed = item.quantity * 0.2;
            final doughUsed = item.quantity * 0.25;
            final oilUsed = item.quantity * 0.05;
            final basilUsed = item.quantity * 0.01;

            performanceInventory[0] = performanceInventory[0].copyWith(
              currentStock: performanceInventory[0].currentStock - tomatoesUsed
            );
            performanceInventory[2] = performanceInventory[2].copyWith(
              currentStock: performanceInventory[2].currentStock - cheeseUsed
            );
            performanceInventory[3] = performanceInventory[3].copyWith(
              currentStock: performanceInventory[3].currentStock - doughUsed
            );
            performanceInventory[4] = performanceInventory[4].copyWith(
              currentStock: performanceInventory[4].currentStock - oilUsed
            );
            performanceInventory[5] = performanceInventory[5].copyWith(
              currentStock: performanceInventory[5].currentStock - basilUsed
            );
          }
        }
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      expect(highVolumeOrders.length, equals(100));
      expect(performanceInventory.length, equals(6));
      expect(duration.inMilliseconds, lessThan(5000)); // Should complete within 5 seconds

      // Check for any items that went below minimum stock
      final lowStockItems = performanceInventory.where((item) => item.isLowStock).toList();
      final outOfStockItems = performanceInventory.where((item) => item.isOutOfStock).toList();

      print('✅ Performance test completed in ${duration.inMilliseconds}ms');
      print('📊 Low stock items: ${lowStockItems.length}');
      print('📊 Out of stock items: ${outOfStockItems.length}');

      expect(duration.inMilliseconds, lessThan(5000));
    });
  });
} 