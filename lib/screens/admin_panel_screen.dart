import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/category.dart';
import '../models/menu_item.dart';

import '../models/reservation.dart';
import '../services/menu_service.dart';
import '../services/table_service.dart';
import '../services/printer_assignment_service.dart';

import '../services/reservation_service.dart';
import '../services/user_service.dart';
import '../widgets/universal_navigation.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/form_field.dart';
import '../screens/reservations_screen.dart';
import '../screens/printer_assignment_screen.dart';

enum UserManagementView { addUser, existingUsers }

class AdminPanelScreen extends StatefulWidget {
  final User user;
  final int initialTabIndex;

  const AdminPanelScreen({super.key, required this.user, this.initialTabIndex = 0});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;
  UserManagementView _userManagementView = UserManagementView.addUser;
  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    debugPrint('ADMIN FLOW: AdminPanelScreen initState, initialTabIndex: $_selectedIndex');
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      
      final categories = await menuService.getCategories();
      final menuItems = await menuService.getMenuItems();

      setState(() {
        _categories = categories;
        _menuItems = menuItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController sortOrderController = TextEditingController();
    bool isActive = true;
    IconData selectedIcon = Icons.restaurant_menu;
    Color selectedColor = Colors.blue;

    // Pre-defined restaurant category options
    final categoryTemplates = [
      {'name': 'Appetizers', 'icon': Icons.local_dining, 'color': Colors.orange},
      {'name': 'Main Courses', 'icon': Icons.dinner_dining, 'color': Colors.red},
      {'name': 'Desserts', 'icon': Icons.cake, 'color': Colors.pink},
      {'name': 'Beverages', 'icon': Icons.local_drink, 'color': Colors.blue},
      {'name': 'Salads', 'icon': Icons.eco, 'color': Colors.green},
      {'name': 'Soups', 'icon': Icons.soup_kitchen, 'color': Colors.amber},
      {'name': 'Seafood', 'icon': Icons.set_meal, 'color': Colors.teal},
      {'name': 'Vegetarian', 'icon': Icons.grass, 'color': Colors.lightGreen},
      {'name': 'Kids Menu', 'icon': Icons.child_friendly, 'color': Colors.purple},
      {'name': 'Specials', 'icon': Icons.star, 'color': Colors.deepOrange},
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.category, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Add New Category'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick templates section
                  const Text(
                    'Quick Templates',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryTemplates.map((template) {
                      return InkWell(
                        onTap: () {
                          nameController.text = template['name'] as String;
                          selectedIcon = template['icon'] as IconData;
                          selectedColor = template['color'] as Color;
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (template['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (template['color'] as Color).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(template['icon'] as IconData, 
                                   size: 16, color: template['color'] as Color),
                              const SizedBox(width: 4),
                              Text(template['name'] as String,
                                   style: TextStyle(color: template['color'] as Color, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  AppFormField(
                    label: 'Category Name *',
                    hint: 'Enter category name',
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Category name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  AppFormField(
                    label: 'Description',
                    hint: 'Brief description of this category',
                    controller: descriptionController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  AppFormField(
                    label: 'Sort Order',
                    hint: 'Display order (1, 2, 3...)',
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  
                  // Icon and color selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(selectedIcon, color: selectedColor),
                                  const SizedBox(width: 8),
                                  const Text('Selected Icon'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: selectedColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Selected Color'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Active toggle
                  Row(
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (value) {
                          isActive = value;
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Active Category'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'sortOrder': int.tryParse(sortOrderController.text) ?? _categories.length,
                    'isActive': isActive,
                    'icon': selectedIcon.codePoint,
                    'color': selectedColor.value,
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Category'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final newCategory = Category(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description']!,
          sortOrder: result['sortOrder'] as int,
          isActive: result['isActive'] as bool,
          iconCodePoint: result['icon'] as int?,
          colorValue: result['color'] as int?,
        );
        await menuService.saveCategory(newCategory);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(newCategory.icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Category "${result['name']}" created successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Adding Category',
            message: 'Failed to add category: $e',
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _editCategory(Category category) async {
    final TextEditingController nameController = TextEditingController(text: category.name);
    final TextEditingController descriptionController = TextEditingController(text: category.description ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormField(
              label: 'Category Name',
              hint: 'Enter category name',
              controller: nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppFormField(
              label: 'Description',
              hint: 'Enter description (optional)',
              controller: descriptionController,
              maxLines: 3,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final updatedCategory = category.copyWith(
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description']!,
        );
        await menuService.saveCategory(updatedCategory);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Updating Category',
            message: 'Failed to update category: $e',
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    // Check if category has menu items
    final itemsInCategory = _menuItems.where((item) => item.categoryId == category.id).toList();
    
    if (itemsInCategory.isNotEmpty) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Cannot Delete Category',
        message: 'This category contains ${itemsInCategory.length} menu item(s). Please remove or reassign all items before deleting the category.',
      );
      return;
    }

    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: category.name,
      message: 'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        await menuService.deleteCategory(category.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Deleting Category',
            message: 'Failed to delete category: $e',
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _addMenuItem() async {
    if (_categories.isEmpty) {
      await ErrorDialogHelper.showError(
        context,
        title: 'No Categories Available',
        message: 'Please create at least one category before adding menu items.',
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String? selectedCategoryId = _categories.first.id;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Item Name',
                hint: 'Enter item name',
                controller: nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Description',
                hint: 'Enter description (optional)',
                controller: descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Price',
                hint: 'Enter price (e.g., 9.99)',
                controller: priceController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                value: selectedCategoryId,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedCategoryId = value;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  priceController.text.trim().isNotEmpty &&
                  double.tryParse(priceController.text) != null) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.parse(priceController.text),
                  'categoryId': selectedCategoryId,
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final newMenuItem = MenuItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description']!,
          price: result['price']!,
          categoryId: result['categoryId']!,
          tags: [],
          customProperties: {},
          variants: [],
          modifiers: [],
          nutritionalInfo: {},
          allergens: {},
          preparationTime: 10,
          isVegetarian: false,
          isVegan: false,
          isGlutenFree: false,
          isSpicy: false,
          spiceLevel: 0,
          stockQuantity: 100,
          lowStockThreshold: 10,
        );
        await menuService.saveMenuItem(newMenuItem);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Menu item "${result['name']}" added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Adding Menu Item',
            message: 'Failed to add menu item: $e',
          );
        }
      }
    }
  }

  Future<void> _editMenuItem(MenuItem item) async {
    final TextEditingController nameController = TextEditingController(text: item.name);
    final TextEditingController descriptionController = TextEditingController(text: item.description ?? '');
    final TextEditingController priceController = TextEditingController(text: item.price.toString());
    String? selectedCategoryId = item.categoryId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Item Name',
                hint: 'Enter item name',
                controller: nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Description',
                hint: 'Enter description (optional)',
                controller: descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Price',
                hint: 'Enter price (e.g., 9.99)',
                controller: priceController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                value: selectedCategoryId,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedCategoryId = value;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  priceController.text.trim().isNotEmpty &&
                  double.tryParse(priceController.text) != null) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.parse(priceController.text),
                  'categoryId': selectedCategoryId,
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final updatedMenuItem = item.copyWith(
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description']!,
          price: result['price']!,
          categoryId: result['categoryId']!,
        );
        await menuService.saveMenuItem(updatedMenuItem);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu item updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Updating Menu Item',
            message: 'Failed to update menu item: $e',
          );
        }
      }
    }
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: item.name,
      message: 'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        await menuService.deleteMenuItem(item.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Deleting Menu Item',
            message: 'Failed to delete menu item: $e',
          );
        }
      }
    }
  }

  // User Management Methods
  // Removed unused methods: _addUser, _editUser, _deleteUser

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Processing...',
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (_selectedIndex == 0) // Only show reset button on categories tab
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_restaurant),
                    label: const Text('Reset Tables to Default'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await ConfirmationDialogHelper.showConfirmation(
                        context,
                        title: 'Reset Tables',
                        message: 'This will delete all existing tables and recreate tables 1-16 with the correct capacities. Are you sure?',
                        confirmText: 'Reset',
                        cancelText: 'Cancel',
                      );
                      if (confirmed == true) {
                        setState(() { _isLoading = true; });
                        try {
                          final tableService = Provider.of<TableService>(context, listen: false);
                          await tableService.resetTablesToDefault();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tables reset to default configuration!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            await ErrorDialogHelper.showError(
                              context,
                              title: 'Error Resetting Tables',
                              message: 'Failed to reset tables: $e',
                            );
                          }
                        } finally {
                          if (mounted) setState(() { _isLoading = false; });
                        }
                      }
                    },
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu),
              label: 'Menu Items',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_seat),
              label: 'Reservations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.print),
              label: 'Printers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return UniversalAppBar(
      currentUser: widget.user,
      title: 'Admin Panel',
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody() {
    debugPrint('ADMIN FLOW: Building tab content for index: $_selectedIndex');
    switch (_selectedIndex) {
      case 0:
        return _buildCategoriesTab();
      case 1:
        return _buildMenuItemsTab();
      case 2:
        return _buildManageUsersTab();
      case 3:
        return _buildReservationsTab();
      case 4:
        return _buildPrinterAssignmentsTab();
      case 5:
        return _buildSettingsTab();
      default:
        return _buildCategoriesTab();
    }
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        _buildTabHeader(
          title: 'Categories',
          subtitle: 'Manage menu categories',
          onAddPressed: _addCategory,
        ),
        Expanded(
          child: _categories.isEmpty
              ? _buildEmptyState(
                  icon: Icons.category,
                  title: 'No Categories',
                  message: 'Add your first category to get started!',
                  actionLabel: 'Add Category',
                  onAction: _addCategory,
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final itemCount = _menuItems.where((item) => item.categoryId == category.id).length;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: category.color.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: category.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: category.color.withOpacity(0.3)),
                            ),
                            child: Icon(
                              category.icon,
                              color: category.color,
                              size: 24,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: category.color.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!category.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'INACTIVE',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (category.description != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    category.description!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: category.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$itemCount item${itemCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        color: category.color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Order: ${category.sortOrder}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _editCategory(category);
                                  break;
                                case 'delete':
                                  _deleteCategory(category);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuItemsTab() {
    // Group items by category
    final itemsByCategory = <String, List<MenuItem>>{};
    for (final item in _menuItems) {
      itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    return Column(
      children: [
        _buildTabHeader(
          title: 'Menu Items',
          subtitle: 'Manage menu items by category',
          onAddPressed: _addMenuItem,
        ),
        Expanded(
          child: _menuItems.isEmpty
              ? _buildEmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'No Menu Items',
                  message: 'Add your first menu item to get started!',
                  actionLabel: 'Add Menu Item',
                  onAction: _addMenuItem,
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final items = itemsByCategory[category.id] ?? [];

                    return ExpansionTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: category.color.withOpacity(0.3)),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: category.color.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: category.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: category.color.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${items.length} item${items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: category.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: items.isEmpty
                          ? [
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No items in this category',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ]
                          : items.map((item) => _buildMenuItemTile(item)).toList(),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuItemTile(MenuItem item) {
    final category = _categories.firstWhere(
      (cat) => cat.id == item.categoryId,
                              orElse: () => Category(
        id: 'unknown',
        name: 'Unknown Category',
        sortOrder: 0,
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: category.color.withOpacity(0.2)),
        ),
        child: ListTile(
          leading: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22.5),
              border: Border.all(color: category.color.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    item.name[0].toUpperCase(),
                    style: TextStyle(
                      color: category.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.description != null) 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: category.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'AVAILABLE',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'UNAVAILABLE',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editMenuItem(item);
                break;
              case 'delete':
                _deleteMenuItem(item);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildManageUsersTab() {
    debugPrint('ADMIN FLOW: _buildManageUsersTab called, _userManagementView: $_userManagementView');
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage Users',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  debugPrint('ADMIN FLOW: Add User button pressed');
                  setState(() {
                    _userManagementView = UserManagementView.addUser;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _userManagementView == UserManagementView.addUser ? Colors.blue : Colors.grey[300],
                  foregroundColor: _userManagementView == UserManagementView.addUser ? Colors.white : Colors.black,
                ),
                child: const Text('Add User'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  debugPrint('ADMIN FLOW: Existing Users button pressed');
                  setState(() {
                    _userManagementView = UserManagementView.existingUsers;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _userManagementView == UserManagementView.existingUsers ? Colors.blue : Colors.grey[300],
                  foregroundColor: _userManagementView == UserManagementView.existingUsers ? Colors.white : Colors.black,
                ),
                child: const Text('Existing Users'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Builder(
              builder: (context) {
                debugPrint('ADMIN FLOW: _userManagementView is $_userManagementView');
                if (_userManagementView == UserManagementView.addUser) {
                  debugPrint('ADMIN FLOW: Showing _AddUserView');
                  return SingleChildScrollView(child: _AddUserView());
                } else {
                  debugPrint('ADMIN FLOW: Showing _ExistingUsersView');
                  return _ExistingUsersView();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Table Reservations',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage table bookings and reservations',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Quick stats
          Consumer<ReservationService>(
            builder: (context, reservationService, child) {
              final todaysReservations = reservationService.todaysReservations;
              final upcomingReservations = reservationService.getUpcomingReservations();
              
              return Row(
                children: [
                  Expanded(
                    child: _buildStatsCard(
                      'Today\'s Bookings',
                      todaysReservations.length.toString(),
                      Icons.today,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatsCard(
                      'Upcoming',
                      upcomingReservations.length.toString(),
                      Icons.schedule,
                      Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReservationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_seat),
                  label: const Text('Manage Reservations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Today's reservations preview
          Expanded(
            child: Consumer<ReservationService>(
              builder: (context, reservationService, child) {
                final todaysReservations = reservationService.todaysReservations;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Reservations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    Expanded(
                      child: todaysReservations.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.event_busy,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No reservations for today',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: todaysReservations.length,
                              itemBuilder: (context, index) {
                                final reservation = todaysReservations[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: reservation.status.color,
                                      child: Text(
                                        reservation.customerName[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      reservation.customerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${reservation.formattedTime} • Party of ${reservation.partySize}'),
                                        Text(
                                          reservation.status.displayName,
                                          style: TextStyle(
                                            color: reservation.status.color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ReservationsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterAssignmentsTab() {
    return Column(
      children: [
        _buildTabHeader(
          title: 'Printer Assignments',
          subtitle: 'Configure kitchen printer routing for menu items',
          onAddPressed: () => _navigateToPrinterAssignments(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Quick Info Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Category Assignment',
                        'Route entire categories to specific printers',
                        Icons.category,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        'Menu Item Assignment',
                        'Route specific items to designated printers',
                        Icons.restaurant_menu,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Action Button
                ElevatedButton.icon(
                  onPressed: () => _navigateToPrinterAssignments(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Manage Printer Assignments'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Benefits List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Benefits of Printer Assignments',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem('Appetizers print to appetizer station'),
                      _buildBenefitItem('Main courses print to grill station'),
                      _buildBenefitItem('Desserts print to dessert station'),
                      _buildBenefitItem('Same order number across all stations'),
                      _buildBenefitItem('Improved kitchen workflow efficiency'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Current Assignments Preview
                Consumer<PrinterAssignmentService>(
                  builder: (context, assignmentService, child) {
                    final stats = assignmentService.getAssignmentStats();
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Assignment Status',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatChip('Total', stats['totalAssignments'], Colors.blue),
                              _buildStatChip('Categories', stats['categoryAssignments'], Colors.green),
                              _buildStatChip('Items', stats['menuItemAssignments'], Colors.orange),
                              _buildStatChip('Printers', stats['uniquePrinters'], Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              benefit,
              style: TextStyle(color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPrinterAssignments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrinterAssignmentScreen(),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.settings,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'App settings and configuration options will be available here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader({
    required String title,
    required String subtitle,
    required VoidCallback onAddPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _AddUserView extends StatefulWidget {
  const _AddUserView();

  @override
  State<_AddUserView> createState() => _AddUserViewState();
}

class _AddUserViewState extends State<_AddUserView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _selectedRole = UserRole.server;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('ADMIN FLOW: _AddUserView initState');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        role: _selectedRole,
      );

      await userService.addUser(newUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _nameController.clear();
        _pinController.clear();
        _selectedRole = UserRole.server;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ADMIN FLOW: _AddUserView build called');
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New User',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          AppFormField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter user\'s full name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppFormField(
            controller: _pinController,
            label: 'PIN',
            hint: 'Enter 4-digit PIN',
            keyboardType: TextInputType.number,
            maxLength: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a PIN';
              }
              if (value.length != 4) {
                return 'PIN must be 4 digits';
              }
              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                return 'PIN must contain only numbers';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: UserRole.values.map((role) {
              return DropdownMenuItem(
                value: role,
                child: Text(role.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRole = value;
                });
              }
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addUser,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Add User'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingUsersView extends StatefulWidget {
  const _ExistingUsersView();

  @override
  State<_ExistingUsersView> createState() => _ExistingUsersViewState();
}

class _ExistingUsersViewState extends State<_ExistingUsersView> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('ADMIN FLOW: _ExistingUsersView initState');
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final users = await userService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ADMIN FLOW: _ExistingUsersView build called');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Existing Users',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            : _users.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text('No users found'),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(user.name[0].toUpperCase()),
                            ),
                            title: Text(
                              '${user.name} (${user.role.name})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PIN: ${user.pin}'),
                                Text('Role: ${user.role.name.toUpperCase()}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Removed edit and delete buttons as their methods were deleted
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ],
    );
  }
} 