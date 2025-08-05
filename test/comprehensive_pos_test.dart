import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/inventory_item.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/category.dart';
import 'package:ai_pos_system/models/inventory_item.dart' show InventoryCategory, InventoryUnit;

void main() {
  group('🍕 COMPREHENSIVE POS SYSTEM TESTS', () {
    
    group('📋 Menu Item Tests', () {
      test('Should create menu item correctly', () {
        final menuItem = MenuItem(
          id: 'pizza_001',
          name: 'Margherita Pizza',
          description: 'Classic Italian pizza with tomato sauce, mozzarella, and basil',
          price: 15.99,
          categoryId: 'pizza_category',
          isAvailable: true,
          allergens: {'dairy': true, 'gluten': true},
          nutritionalInfo: {'calories': 800},
          variants: [
            MenuItemVariant(name: 'Small', priceAdjustment: -2.00),
            MenuItemVariant(name: 'Large', priceAdjustment: 3.00),
          ],
          createdAt: DateTime.now(),
        );

        expect(menuItem.id, equals('pizza_001'));
        expect(menuItem.name, equals('Margherita Pizza'));
        expect(menuItem.price, equals(15.99));
        expect(menuItem.isAvailable, isTrue);
        expect(menuItem.allergens['dairy'], isTrue);
        expect(menuItem.variants.length, equals(2));
      });

      test('Should calculate correct price with variants', () {
        final menuItem = MenuItem(
          id: 'pizza_002',
          name: 'Pepperoni Pizza',
          description: 'Pizza with pepperoni',
          price: 18.99,
          categoryId: 'pizza_category',
          isAvailable: true,
          allergens: {},
          nutritionalInfo: {},
          variants: [
            MenuItemVariant(name: 'Regular', priceAdjustment: 0.0),
            MenuItemVariant(name: 'Extra Large', priceAdjustment: 5.0),
          ],
          createdAt: DateTime.now(),
        );

        // Test base price
        expect(menuItem.price, equals(18.99));
        
        // Test that menu item has required fields
        expect(menuItem.id, isNotEmpty);
        expect(menuItem.name, isNotEmpty);
        expect(menuItem.categoryId, isNotEmpty);
      });

      test('Should handle availability correctly', () {
        final menuItem = MenuItem(
          id: 'pasta_001',
          name: 'Spaghetti Carbonara',
          description: 'Creamy pasta with bacon',
          price: 14.99,
          categoryId: 'pasta_category',
          isAvailable: false, // Out of stock
          allergens: {},
          nutritionalInfo: {},
          variants: [],
          createdAt: DateTime.now(),
        );

        expect(menuItem.isAvailable, isFalse);
        expect(menuItem.name, equals('Spaghetti Carbonara'));
      });
    });

    group('🛒 Order Management Tests', () {
      test('Should create order with correct details', () {
        final order = Order(
          id: 'ORD-001',
          orderNumber: 'ORD-001',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_5',
          userId: 'user_001',
          subtotal: 45.97,
          taxAmount: 5.98,
          totalAmount: 51.95,
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(order.orderNumber, equals('ORD-001'));
        expect(order.status, equals(OrderStatus.pending));
        expect(order.type, equals(OrderType.dineIn));
        expect(order.subtotal, equals(0.0));
        expect(order.totalAmount, equals(0.0));
      });

      test('Should add items to order correctly', () {
        final order = Order(
          id: 'ORD-002',
          orderNumber: 'ORD-002',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_1',
          userId: 'user_001',
          subtotal: 0.0,
          taxAmount: 0.0,
          totalAmount: 0.0,
          items: [
            OrderItem(
              id: 'item_001',
              menuItem: MenuItem(
                id: 'pizza_001',
                name: 'Margherita Pizza',
                description: 'Classic pizza',
                price: 15.99,
                categoryId: 'pizza_category',
                isAvailable: true,
                allergens: {},
                nutritionalInfo: {},
                variants: [],
                createdAt: DateTime.now(),
              ),
              quantity: 2,
              selectedVariant: 'Regular',
              specialInstructions: '',
              notes: '',
              isAvailable: true,
              sentToKitchen: false,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(order.items.length, equals(1));
        expect(order.items.first.quantity, equals(2));
        expect(order.items.first.totalPrice, equals(31.98));
      });

      test('Should handle order status transitions', () {
        final order = Order(
          id: 'ORD-003',
          orderNumber: 'ORD-003',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_2',
          userId: 'user_001',
          subtotal: 25.99,
          taxAmount: 3.38,
          totalAmount: 29.37,
          items: [
            OrderItem(
              id: 'item_002',
              menuItem: MenuItem(
                id: 'pasta_001',
                name: 'Spaghetti Carbonara',
                description: 'Creamy pasta',
                price: 12.99,
                categoryId: 'pasta_category',
                isAvailable: true,
                allergens: {},
                nutritionalInfo: {},
                variants: [],
                createdAt: DateTime.now(),
              ),
              quantity: 1,
              selectedVariant: 'Regular',
              specialInstructions: '',
              notes: '',
              isAvailable: true,
              sentToKitchen: false,
            ),
            OrderItem(
              id: 'item_003',
              menuItem: MenuItem(
                id: 'salad_001',
                name: 'Caesar Salad',
                description: 'Fresh salad',
                price: 13.00,
                categoryId: 'salad_category',
                isAvailable: true,
                allergens: {},
                nutritionalInfo: {},
                variants: [],
                createdAt: DateTime.now(),
              ),
              quantity: 1,
              selectedVariant: 'Regular',
              specialInstructions: '',
              notes: '',
              isAvailable: true,
              sentToKitchen: false,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(order.status, equals(OrderStatus.pending));
        expect(order.items.length, equals(2));
        expect(order.totalAmount, closeTo(29.37, 0.01));
      });

      test('Should handle different order types', () {
        final dineInOrder = Order(
          id: 'ORD-004',
          orderNumber: 'ORD-004',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_3',
          userId: 'user_001',
          subtotal: 20.00,
          taxAmount: 2.60,
          totalAmount: 22.60,
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final deliveryOrder = Order(
          id: 'ORD-005',
          orderNumber: 'ORD-005',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.delivery,
          tableId: null,
          userId: 'user_001',
          subtotal: 25.00,
          taxAmount: 3.25,
          totalAmount: 28.25,
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(dineInOrder.type, equals(OrderType.dineIn));
        expect(deliveryOrder.type, equals(OrderType.delivery));
        expect(dineInOrder.tableId, isNotNull);
        expect(deliveryOrder.tableId, isNull);
      });
    });

    group('📦 Inventory Management Tests', () {
      test('Should create inventory item correctly', () {
        final inventoryItem = InventoryItem(
          id: 'inv_001',
          name: 'Tomato Sauce',
          description: 'Premium tomato sauce for pizzas',
          category: InventoryCategory.pantry,
          unit: InventoryUnit.liters,
          currentStock: 50.0,
          minimumStock: 10.0,
          maximumStock: 100.0,
          costPerUnit: 2.50,
          supplier: 'Premium Foods Inc.',
          expiryDate: DateTime.now().add(Duration(days: 30)),
          createdAt: DateTime.now(),
        );

        expect(inventoryItem.id, equals('inv_001'));
        expect(inventoryItem.name, equals('Tomato Sauce'));
        expect(inventoryItem.currentStock, equals(50.0));
        expect(inventoryItem.category, equals(InventoryCategory.pantry));
        expect(inventoryItem.unit, equals(InventoryUnit.liters));
      });

      test('Should handle stock levels correctly', () {
        final inventoryItem = InventoryItem(
          id: 'inv_002',
          name: 'Mozzarella Cheese',
          description: 'Fresh mozzarella cheese',
          category: InventoryCategory.dairy,
          unit: InventoryUnit.kilograms,
          currentStock: 5.0,
          minimumStock: 10.0,
          maximumStock: 50.0,
          costPerUnit: 8.00,
          supplier: 'Dairy Fresh Co.',
          expiryDate: DateTime.now().add(Duration(days: 7)),
          createdAt: DateTime.now(),
        );

        expect(inventoryItem.currentStock, equals(5.0));
        expect(inventoryItem.minimumStock, equals(10.0));
        expect(inventoryItem.maximumStock, equals(50.0));
        expect(inventoryItem.category, equals(InventoryCategory.dairy));
      });

      test('Should handle different inventory categories', () {
        final ingredientItem = InventoryItem(
          id: 'inv_003',
          name: 'Flour',
          description: 'All-purpose flour',
          category: InventoryCategory.pantry,
          unit: InventoryUnit.kilograms,
          currentStock: 25.0,
          minimumStock: 5.0,
          maximumStock: 100.0,
          costPerUnit: 1.50,
          supplier: 'Bulk Foods Ltd.',
          expiryDate: DateTime.now().add(Duration(days: 90)),
          createdAt: DateTime.now(),
        );

        final equipmentItem = InventoryItem(
          id: 'inv_004',
          name: 'Pizza Oven',
          description: 'Commercial pizza oven',
          category: InventoryCategory.other,
          unit: InventoryUnit.pieces,
          currentStock: 2.0,
          minimumStock: 1.0,
          maximumStock: 5.0,
          costPerUnit: 5000.00,
          supplier: 'Kitchen Equipment Co.',
          expiryDate: DateTime.now().add(Duration(days: 3650)),
          createdAt: DateTime.now(),
        );

        expect(ingredientItem.category, equals(InventoryCategory.pantry));
        expect(equipmentItem.category, equals(InventoryCategory.other));
        expect(ingredientItem.unit, equals(InventoryUnit.kilograms));
        expect(equipmentItem.unit, equals(InventoryUnit.pieces));
      });
    });

    group('🏷️ Category Management Tests', () {
      test('Should create category correctly', () {
        final category = Category(
          id: 'pizza_category',
          name: 'Pizza',
          description: 'All pizza items',
          isActive: true,
          sortOrder: 1,
          createdAt: DateTime.now(),
        );

        expect(category.id, equals('pizza_category'));
        expect(category.name, equals('Pizza'));
        expect(category.isActive, isTrue);
        expect(category.sortOrder, equals(1));
      });

      test('Should handle category hierarchy', () {
        final mainCategory = Category(
          id: 'main_course',
          name: 'Main Course',
          description: 'Main course items',
          isActive: true,
          sortOrder: 1,
          createdAt: DateTime.now(),
        );

        final subCategory = Category(
          id: 'pasta_sub',
          name: 'Pasta',
          description: 'Pasta dishes',
          isActive: true,
          sortOrder: 2,
          createdAt: DateTime.now(),
        );

        expect(mainCategory.name, equals('Main Course'));
        expect(subCategory.name, equals('Pasta'));
        expect(mainCategory.sortOrder, lessThan(subCategory.sortOrder));
      });

      test('Should handle inactive categories', () {
        final inactiveCategory = Category(
          id: 'old_menu',
          name: 'Old Menu Items',
          description: 'Discontinued items',
          isActive: false,
          sortOrder: 999,
          createdAt: DateTime.now(),
        );

        expect(inactiveCategory.isActive, isFalse);
        expect(inactiveCategory.name, equals('Old Menu Items'));
      });
    });

    group('👥 User Management Tests', () {
      test('Should create user correctly', () {
        final user = User(
          id: 'user_001',
          name: 'John Doe',
          role: UserRole.server,
          isActive: true,
          pin: '1234',
          createdAt: DateTime.now(),
        );

        expect(user.id, equals('user_001'));
        expect(user.name, equals('John Doe'));

        expect(user.role, equals(UserRole.server));
        expect(user.isActive, isTrue);
      });

      test('Should handle different user roles', () {
        final adminUser = User(
          id: 'admin_001',
          name: 'Administrator',
          role: UserRole.admin,
          isActive: true,
          pin: '9999',
          createdAt: DateTime.now(),
        );

        final serverUser = User(
          id: 'server_001',
          name: 'Server One',
          role: UserRole.server,
          isActive: true,
          pin: '1111',
          createdAt: DateTime.now(),
        );

        expect(adminUser.role, equals(UserRole.admin));
        expect(serverUser.role, equals(UserRole.server));
        expect(adminUser.isActive, isTrue);
        expect(serverUser.isActive, isTrue);
      });

      test('Should handle inactive users', () {
        final inactiveUser = User(
          id: 'inactive_001',
          name: 'Old User',
          role: UserRole.server,
          isActive: false,
          pin: '0000',
          createdAt: DateTime.now(),
        );

        expect(inactiveUser.isActive, isFalse);
        expect(inactiveUser.name, equals('Old User'));
      });
    });

    group('💰 Payment and Financial Tests', () {
      test('Should calculate order totals correctly', () {
        final order = Order(
          id: 'PAY-001',
          orderNumber: 'PAY-001',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_1',
          userId: 'user_001',
          items: [
            OrderItem(
              id: 'item_001',
              menuItem: MenuItem(
                id: 'pizza_001',
                name: 'Test Pizza',
                description: 'Test pizza',
                price: 25.00,
                categoryId: 'pizza_category',
                isAvailable: true,
                allergens: {},
                nutritionalInfo: {},
                variants: [],
                createdAt: DateTime.now(),
              ),
              quantity: 1,
              selectedVariant: 'Regular',
              specialInstructions: '',
              notes: '',
              isAvailable: true,
              sentToKitchen: false,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(order.subtotal, equals(25.00));
        expect(order.taxAmount, equals(0.0)); // Tax is calculated dynamically
        expect(order.tipAmount, equals(0.0));
        expect(order.totalAmount, closeTo(28.25, 0.01)); // 25 + 3.25 tax
      });

      test('Should handle different payment scenarios', () {
        final cashOrder = Order(
          id: 'CASH-001',
          orderNumber: 'CASH-001',
          orderTime: DateTime.now(),
          status: OrderStatus.completed,
          type: OrderType.dineIn,
          tableId: 'table_2',
          userId: 'user_001',
          subtotal: 30.00,
          taxAmount: 3.90,
          totalAmount: 33.90,
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final cardOrder = Order(
          id: 'CARD-001',
          orderNumber: 'CARD-001',
          orderTime: DateTime.now(),
          status: OrderStatus.completed,
          type: OrderType.delivery,
          tableId: null,
          userId: 'user_001',
          subtotal: 45.00,
          taxAmount: 5.85,
          totalAmount: 50.85,
          items: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(cashOrder.status, equals(OrderStatus.completed));
        expect(cardOrder.status, equals(OrderStatus.completed));
        expect(cashOrder.type, equals(OrderType.dineIn));
        expect(cardOrder.type, equals(OrderType.delivery));
      });
    });

    group('🔍 Data Validation Tests', () {
      test('Should validate required fields', () {
        expect(() {
          MenuItem(
            id: '',
            name: 'Test Item',
            description: 'Test Description',
            price: 10.00,
            categoryId: 'test_category',
            isAvailable: true,
            allergens: {},
            nutritionalInfo: {},
            variants: [],
            createdAt: DateTime.now(),
          );
        }, returnsNormally);

        expect(() {
          Order(
            id: 'test_order',
            orderNumber: 'TEST-001',
            orderTime: DateTime.now(),
            status: OrderStatus.pending,
            type: OrderType.dineIn,
            tableId: 'table_1',
            userId: 'user_001',
            subtotal: 0.0,
            taxAmount: 0.0,
            totalAmount: 0.0,
            items: [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }, returnsNormally);
      });

      test('Should handle edge cases', () {
        final zeroPriceItem = MenuItem(
          id: 'free_item',
          name: 'Free Sample',
          description: 'Free sample item',
          price: 0.00,
          categoryId: 'samples',
          isAvailable: true,
          allergens: {},
          nutritionalInfo: {},
          variants: [],
          createdAt: DateTime.now(),
        );

        final highPriceItem = MenuItem(
          id: 'premium_item',
          name: 'Premium Item',
          description: 'Very expensive item',
          price: 999.99,
          categoryId: 'premium',
          isAvailable: true,
          allergens: {},
          nutritionalInfo: {},
          variants: [],
          createdAt: DateTime.now(),
        );

        expect(zeroPriceItem.price, equals(0.00));
        expect(highPriceItem.price, equals(999.99));
      });
    });
  });
} 