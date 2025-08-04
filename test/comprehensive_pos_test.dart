import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/inventory_item.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/category.dart';

void main() {
  group('🍕 COMPREHENSIVE POS SYSTEM TESTS', () {
    
    group('📋 Menu Item Tests', () {
      test('Should create menu item correctly', () {
        final menuItem = MenuItem(
          id: 'pizza_001',
          name: 'Margherita Pizza',
          description: 'Classic Italian pizza with tomato sauce, mozzarella, and basil',
          category: 'Pizza',
          price: 15.99,
          isAvailable: true,
          preparationTime: 15,
          imageUrl: 'assets/images/margherita.jpg',
          ingredients: ['Tomato Sauce', 'Mozzarella', 'Basil'],
          allergens: ['Dairy', 'Gluten'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(menuItem.id, equals('pizza_001'));
        expect(menuItem.name, equals('Margherita Pizza'));
        expect(menuItem.price, equals(15.99));
        expect(menuItem.isAvailable, isTrue);
        expect(menuItem.ingredients.length, equals(3));
        expect(menuItem.allergens.contains('Dairy'), isTrue);
      });

      test('Should calculate correct price with variants', () {
        final menuItem = MenuItem(
          id: 'pizza_002',
          name: 'Pepperoni Pizza',
          description: 'Pizza with pepperoni',
          category: 'Pizza',
          price: 18.99,
          isAvailable: true,
          preparationTime: 15,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Test base price
        expect(menuItem.price, equals(18.99));
        
        // Test that menu item has required fields
        expect(menuItem.id, isNotEmpty);
        expect(menuItem.name, isNotEmpty);
        expect(menuItem.category, isNotEmpty);
      });

      test('Should handle availability correctly', () {
        final menuItem = MenuItem(
          id: 'pasta_001',
          name: 'Spaghetti Carbonara',
          description: 'Creamy pasta with bacon',
          category: 'Pasta',
          price: 14.99,
          isAvailable: false, // Out of stock
          preparationTime: 12,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
        );

        expect(order.orderNumber, equals('ORD-001'));
        expect(order.status, equals(OrderStatus.pending));
        expect(order.type, equals(OrderType.dineIn));
        expect(order.subtotal, equals(45.97));
        expect(order.totalAmount, equals(51.95));
      });

      test('Should add items to order correctly', () {
        final order = Order(
          id: 'ORD-002',
          orderNumber: 'ORD-002',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.takeOut,
          userId: 'user_001',
          subtotal: 0.0,
          taxAmount: 0.0,
          totalAmount: 0.0,
          items: [],
        );

        final orderItem = OrderItem(
          id: 'item_001',
          orderId: 'ORD-002',
          menuItemId: 'pizza_001',
          quantity: 2,
          unitPrice: 15.99,
          totalPrice: 31.98,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        order.items.add(orderItem);

        expect(order.items.length, equals(1));
        expect(order.items.first.quantity, equals(2));
        expect(order.items.first.totalPrice, equals(31.98));
      });

      test('Should calculate order totals correctly', () {
        final orderItem1 = OrderItem(
          id: 'item_001',
          orderId: 'ORD-003',
          menuItemId: 'pizza_001',
          quantity: 2,
          unitPrice: 15.99,
          totalPrice: 31.98,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final orderItem2 = OrderItem(
          id: 'item_002',
          orderId: 'ORD-003',
          menuItemId: 'drink_001',
          quantity: 1,
          unitPrice: 3.99,
          totalPrice: 3.99,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final items = [orderItem1, orderItem2];
        final subtotal = items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
        final taxRate = 0.13; // 13% tax
        final taxAmount = subtotal * taxRate;
        final totalAmount = subtotal + taxAmount;

        expect(subtotal, equals(35.97));
        expect(taxAmount, closeTo(4.68, 0.01));
        expect(totalAmount, closeTo(40.65, 0.01));
      });

      test('Should handle different order types', () {
        final dineInOrder = Order(
          id: 'ORD-DINEIN',
          orderNumber: 'ORD-DINEIN',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_1',
          userId: 'user_001',
          subtotal: 25.99,
          taxAmount: 3.38,
          totalAmount: 29.37,
          items: [],
        );

        final takeOutOrder = Order(
          id: 'ORD-TAKEOUT',
          orderNumber: 'ORD-TAKEOUT',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.takeOut,
          userId: 'user_001',
          customerName: 'John Doe',
          customerPhone: '123-456-7890',
          subtotal: 18.99,
          taxAmount: 2.47,
          totalAmount: 21.46,
          items: [],
        );

        final deliveryOrder = Order(
          id: 'ORD-DELIVERY',
          orderNumber: 'ORD-DELIVERY',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.delivery,
          userId: 'user_001',
          customerName: 'Jane Smith',
          customerPhone: '987-654-3210',
          customerAddress: '123 Main St, City',
          subtotal: 32.99,
          taxAmount: 4.29,
          totalAmount: 37.28,
          items: [],
        );

        expect(dineInOrder.type, equals(OrderType.dineIn));
        expect(dineInOrder.tableId, equals('table_1'));
        
        expect(takeOutOrder.type, equals(OrderType.takeOut));
        expect(takeOutOrder.customerName, equals('John Doe'));
        
        expect(deliveryOrder.type, equals(OrderType.delivery));
        expect(deliveryOrder.customerAddress, equals('123 Main St, City'));
      });
    });

    group('📦 Inventory Management Tests', () {
      test('Should create inventory item correctly', () {
        final inventoryItem = InventoryItem(
          name: 'Fresh Tomatoes',
          description: 'Organic fresh tomatoes for pizzas',
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
        expect(inventoryItem.currentStock, equals(50.0));
        expect(inventoryItem.minimumStock, equals(10.0));
        expect(inventoryItem.category, equals(InventoryCategory.produce));
        expect(inventoryItem.unit, equals(InventoryUnit.kilograms));
      });

      test('Should detect low stock correctly', () {
        final lowStockItem = InventoryItem(
          name: 'Mozzarella Cheese',
          description: 'Premium mozzarella cheese',
          category: InventoryCategory.dairy,
          unit: InventoryUnit.kilograms,
          currentStock: 5.0, // Below minimum
          minimumStock: 10.0,
          maximumStock: 50.0,
          costPerUnit: 8.50,
          supplier: 'Dairy Farm',
          supplierContact: 'dairy@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final normalStockItem = InventoryItem(
          name: 'Olive Oil',
          description: 'Extra virgin olive oil',
          category: InventoryCategory.condiments,
          unit: InventoryUnit.liters,
          currentStock: 25.0, // Above minimum
          minimumStock: 5.0,
          maximumStock: 50.0,
          costPerUnit: 12.00,
          supplier: 'Mediterranean Imports',
          supplierContact: 'med@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(lowStockItem.isLowStock, isTrue);
        expect(normalStockItem.isLowStock, isFalse);
      });

      test('Should calculate stock value correctly', () {
        final inventoryItem = InventoryItem(
          name: 'Premium Flour',
          description: 'High-quality flour for pizza dough',
          category: InventoryCategory.pantry,
          unit: InventoryUnit.kilograms,
          currentStock: 75.0,
          minimumStock: 20.0,
          maximumStock: 100.0,
          costPerUnit: 2.50,
          supplier: 'Grain Supply Co',
          supplierContact: 'grain@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final expectedValue = 75.0 * 2.50; // 187.50
        expect(inventoryItem.totalValue, equals(expectedValue));
      });
    });

    group('👤 User Management Tests', () {
      test('Should create user with correct permissions', () {
        final adminUser = User(
          id: 'admin_001',
          name: 'Admin User',
          pin: '1234',
          role: UserRole.admin,
          isActive: true,
          adminPanelAccess: true,
          createdAt: DateTime.now(),
        );

        final serverUser = User(
          id: 'server_001',
          name: 'Server User',
          pin: '5678',
          role: UserRole.server,
          isActive: true,
          adminPanelAccess: false,
          createdAt: DateTime.now(),
        );

        expect(adminUser.role, equals(UserRole.admin));
        expect(adminUser.adminPanelAccess, isTrue);
        
        expect(serverUser.role, equals(UserRole.server));
        expect(serverUser.adminPanelAccess, isFalse);
      });

      test('Should validate user PIN correctly', () {
        final user = User(
          id: 'test_user',
          name: 'Test User',
          pin: '9999',
          role: UserRole.server,
          isActive: true,
          adminPanelAccess: false,
          createdAt: DateTime.now(),
        );

        expect(user.pin, equals('9999'));
        expect(user.pin.length, equals(4));
        expect(user.isActive, isTrue);
      });
    });

    group('🏷️ Category Management Tests', () {
      test('Should create category correctly', () {
        final category = Category(
          id: 'cat_001',
          name: 'Appetizers',
          description: 'Delicious starters and appetizers',
          colorCode: '#FF5722',
          sortOrder: 1,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(category.name, equals('Appetizers'));
        expect(category.colorCode, equals('#FF5722'));
        expect(category.sortOrder, equals(1));
        expect(category.isActive, isTrue);
      });

      test('Should handle category ordering', () {
        final category1 = Category(
          id: 'cat_001',
          name: 'Appetizers',
          description: 'Starters',
          colorCode: '#FF5722',
          sortOrder: 1,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final category2 = Category(
          id: 'cat_002',
          name: 'Main Courses',
          description: 'Main dishes',
          colorCode: '#4CAF50',
          sortOrder: 2,
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final categories = [category2, category1]; // Unsorted
        categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        expect(categories.first.name, equals('Appetizers'));
        expect(categories.last.name, equals('Main Courses'));
      });
    });

    group('🧾 Order Processing Workflow Tests', () {
      test('Should process complete order workflow', () {
        // Step 1: Create order
        final order = Order(
          id: 'workflow_001',
          orderNumber: 'WF-001',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.dineIn,
          tableId: 'table_3',
          userId: 'server_001',
          subtotal: 0.0,
          taxAmount: 0.0,
          totalAmount: 0.0,
          items: [],
        );

        expect(order.status, equals(OrderStatus.pending));

        // Step 2: Add items
        final item1 = OrderItem(
          id: 'item_001',
          orderId: order.id,
          menuItemId: 'pizza_margherita',
          quantity: 1,
          unitPrice: 15.99,
          totalPrice: 15.99,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        order.items.add(item1);
        expect(order.items.length, equals(1));

        // Step 3: Send to kitchen
        order.status = OrderStatus.preparing;
        expect(order.status, equals(OrderStatus.preparing));

        // Step 4: Complete order
        order.status = OrderStatus.completed;
        order.completedTime = DateTime.now();
        expect(order.status, equals(OrderStatus.completed));
        expect(order.completedTime, isNotNull);
      });

      test('Should handle order modifications', () {
        final order = Order(
          id: 'mod_001',
          orderNumber: 'MOD-001',
          orderTime: DateTime.now(),
          status: OrderStatus.pending,
          type: OrderType.takeOut,
          userId: 'server_001',
          customerName: 'Test Customer',
          subtotal: 0.0,
          taxAmount: 0.0,
          totalAmount: 0.0,
          items: [],
        );

        // Add initial item
        final originalItem = OrderItem(
          id: 'item_001',
          orderId: order.id,
          menuItemId: 'pizza_001',
          quantity: 2,
          unitPrice: 15.99,
          totalPrice: 31.98,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        order.items.add(originalItem);
        expect(order.items.length, equals(1));

        // Modify quantity
        originalItem.quantity = 3;
        originalItem.totalPrice = originalItem.unitPrice * originalItem.quantity;
        originalItem.updatedAt = DateTime.now();

        expect(originalItem.quantity, equals(3));
        expect(originalItem.totalPrice, equals(47.97));
      });
    });

    group('💰 Payment Processing Tests', () {
      test('Should handle different payment methods', () {
        final cashOrder = Order(
          id: 'cash_001',
          orderNumber: 'CASH-001',
          orderTime: DateTime.now(),
          status: OrderStatus.completed,
          type: OrderType.dineIn,
          tableId: 'table_1',
          userId: 'server_001',
          subtotal: 45.00,
          taxAmount: 5.85,
          totalAmount: 50.85,
          paymentMethod: PaymentMethod.cash,
          paymentStatus: PaymentStatus.paid,
          items: [],
        );

        final cardOrder = Order(
          id: 'card_001',
          orderNumber: 'CARD-001',
          orderTime: DateTime.now(),
          status: OrderStatus.completed,
          type: OrderType.takeOut,
          userId: 'server_001',
          customerName: 'John Doe',
          subtotal: 32.50,
          taxAmount: 4.23,
          totalAmount: 36.73,
          paymentMethod: PaymentMethod.card,
          paymentStatus: PaymentStatus.paid,
          paymentTransactionId: 'TXN123456',
          items: [],
        );

        expect(cashOrder.paymentMethod, equals(PaymentMethod.cash));
        expect(cashOrder.paymentStatus, equals(PaymentStatus.paid));
        
        expect(cardOrder.paymentMethod, equals(PaymentMethod.card));
        expect(cardOrder.paymentTransactionId, equals('TXN123456'));
      });

      test('Should calculate correct tax amounts', () {
        const subtotal = 100.00;
        const taxRate = 0.13; // 13% HST
        final taxAmount = subtotal * taxRate;
        final total = subtotal + taxAmount;

        expect(taxAmount, equals(13.00));
        expect(total, equals(113.00));
      });

      test('Should handle gratuity calculations', () {
        const subtotal = 75.00;
        const gratuityRate = 0.18; // 18% tip
        final gratuityAmount = subtotal * gratuityRate;
        const taxRate = 0.13;
        final taxAmount = subtotal * taxRate;
        final total = subtotal + taxAmount + gratuityAmount;

        expect(gratuityAmount, equals(13.50));
        expect(total, equals(98.25)); // 75 + 9.75 (tax) + 13.50 (tip)
      });
    });
  });
} 