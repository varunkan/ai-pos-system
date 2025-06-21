import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/models/menu_item.dart';

void main() {
  group('MenuItem.fromJson', () {
    test('should parse database format correctly', () {
      // Sample data from the database
      final jsonData = {
        'id': 'test-id',
        'name': 'Test Item',
        'description': 'Test description',
        'price': 10.99,
        'category_id': 'starter_veg',
        'image_url': null,
        'is_available': 1,
        'tags': '["test","vegetarian"]',
        'custom_properties': '{}',
        'variants': '[]',
        'modifiers': '[]',
        'nutritional_info': '{}',
        'allergens': '{}',
        'preparation_time': 15,
        'is_vegetarian': 1,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'stock_quantity': 25,
        'low_stock_threshold': 5,
        'created_at': '2025-06-20T17:32:54.932148',
        'updated_at': '2025-06-20T17:32:54.932148',
      };

      final menuItem = MenuItem.fromJson(jsonData);

      expect(menuItem.id, equals('test-id'));
      expect(menuItem.name, equals('Test Item'));
      expect(menuItem.description, equals('Test description'));
      expect(menuItem.price, equals(10.99));
      expect(menuItem.categoryId, equals('starter_veg'));
      expect(menuItem.isAvailable, isTrue);
      expect(menuItem.isVegetarian, isTrue);
      expect(menuItem.isVegan, isFalse);
      expect(menuItem.preparationTime, equals(15));
      expect(menuItem.stockQuantity, equals(25));
      expect(menuItem.tags, equals(['test', 'vegetarian']));
    });

    test('should handle tags as list', () {
      final jsonData = {
        'id': 'test-id',
        'name': 'Test Item',
        'description': 'Test description',
        'price': 10.99,
        'category_id': 'starter_veg',
        'tags': ['test', 'vegetarian'],
        'variants': [],
        'modifiers': [],
        'created_at': '2025-06-20T17:32:54.932148',
        'updated_at': '2025-06-20T17:32:54.932148',
      };

      final menuItem = MenuItem.fromJson(jsonData);

      expect(menuItem.categoryId, equals('starter_veg'));
      expect(menuItem.tags, equals(['test', 'vegetarian']));
    });
  });
} 