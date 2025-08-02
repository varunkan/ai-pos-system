import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/category.dart' as pos_category;
import '../models/user.dart';
import '../models/table.dart' as restaurant_table;
import '../services/order_service.dart';
import '../services/menu_service.dart';
import '../services/printing_service.dart';
import '../services/enhanced_printer_assignment_service.dart';
import '../services/order_log_service.dart';

import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';


import '../screens/checkout_screen.dart';
import 'package:uuid/uuid.dart';
import '../screens/order_type_selection_screen.dart'; // Added import for OrderTypeSelectionScreen
import 'kitchen_receipt_preview_dialog.dart'; // Kitchen receipt preview dialog

class OrderCreationScreen extends StatefulWidget {
  final User user;
  final restaurant_table.Table? table;
  final int? numberOfPeople;
  final String? orderNumber;
  final String orderType; // 'dine-in' or 'takeout'
  final Order? existingOrder; // For editing existing orders

  const OrderCreationScreen({
    super.key,
    required this.user,
    this.table,
    this.numberOfPeople,
    this.orderNumber,
    required this.orderType,
    this.existingOrder, // Add existing order parameter
  });

  @override
  State<OrderCreationScreen> createState() => _OrderCreationScreenState();
}

class _OrderCreationScreenState extends State<OrderCreationScreen> {
  Order? _currentOrder;
  List<pos_category.Category> _categories = [];
  final List<MenuItem> _menuItems = [];
  pos_category.Category? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _orderNotesController = TextEditingController();
  final TextEditingController _chefNotesController = TextEditingController();
  
  // Remove search functionality - no longer needed
  // String _searchQuery = '';
  
  // Filtered menu items based only on category (no search)
  List<MenuItem> get _filteredMenuItems {
    return _menuItems; // Return all loaded items for selected category
  }

  @override
  void initState() {
    super.initState();
    _initializeOrder();
    _loadCategories();
  }

  @override
  void dispose() {
    _orderNotesController.dispose();
    _chefNotesController.dispose();
    super.dispose();
  }

  void _initializeOrder() {
    // If we have an existing order, use it for editing
    if (widget.existingOrder != null) {
      _currentOrder = widget.existingOrder!.copyWith();
      
      // Pre-populate the text controllers with existing data
      _orderNotesController.text = _currentOrder!.specialInstructions ?? '';
      _chefNotesController.text = _currentOrder!.specialInstructions ?? '';
      
      debugPrint('🔄 Loading existing order for editing: ${_currentOrder!.orderNumber}');
      debugPrint('📋 Order has ${_currentOrder!.items.length} items');
    } else {
      // Create new order
      final orderNumber = widget.orderNumber ??
          'DI-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      _currentOrder = Order(
        items: [],
        orderNumber: orderNumber,
        customerName: widget.table?.customerName,
        tableId: widget.table?.id,
        type: widget.orderType == 'dine-in' ? OrderType.dineIn : OrderType.delivery,
        orderTime: DateTime.now(),
        userId: widget.user.id, // Assign order to current user immediately
        status: OrderStatus.pending, // Set initial status
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      debugPrint('🆕 Created new order: ${_currentOrder!.orderNumber} for user: ${widget.user.name}');
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final categories = await menuService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading categories: $e';
      });
    }
  }

  Future<void> _onCategorySelected(pos_category.Category category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
      _error = null;
    });
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final items = await menuService.getMenuItemsByCategoryId(category.id);
      setState(() {
        _menuItems.clear();
        _menuItems.addAll(items);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading menu items: $e';
      });
    }
  }

  void _addItemToOrder(MenuItem item) {
    // Show item configuration dialog first
    _showItemConfigurationDialog(item);
  }

  void _showItemConfigurationDialog(MenuItem item) {
    String selectedSpiceLevel = 'Regular';
    String specialInstructions = '';
    int quantity = 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive dimensions based on screen size
                  final screenWidth = MediaQuery.of(context).size.width;
                  final screenHeight = MediaQuery.of(context).size.height;
                  
                  // Responsive width: 80% of screen width, but between 400-600px
                  final dialogWidth = (screenWidth * 0.8).clamp(400.0, 600.0);
                  
                  // Responsive height: 85% of screen height, but max 650px
                  final maxDialogHeight = (screenHeight * 0.85).clamp(500.0, 650.0);
                  
                  return Container(
                    width: dialogWidth,
                    constraints: BoxConstraints(
                      maxHeight: maxDialogHeight,
                      maxWidth: dialogWidth,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.grey.shade50,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Elegant Header (Fixed height)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Configure Item',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20, // Reduced for better fit
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '\$${item.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Content Section with Scrolling
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Responsive layout based on screen width
                                  if (dialogWidth > 500) ...[
                                    // Wide screen: Two column layout
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left column - Quantity
                                        Expanded(
                                          flex: 1,
                                          child: _buildElegantSection(
                                            'Quantity',
                                            Icons.add_circle_outline,
                                            Theme.of(context).primaryColor,
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: Colors.grey.shade200),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildQuantityButton(
                                                    Icons.remove,
                                                    quantity > 1,
                                                    () {
                                                      if (quantity > 1) {
                                                        setDialogState(() {
                                                          quantity--;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                    child: Text(
                                                      '$quantity',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.bold,
                                                        color: Theme.of(context).primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                  _buildQuantityButton(
                                                    Icons.add,
                                                    true,
                                                    () {
                                                      setDialogState(() {
                                                        quantity++;
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 20),
                                        
                                        // Right column - Spice Level
                                        Expanded(
                                          flex: 2,
                                          child: _buildElegantSection(
                                            'Spice Level',
                                            Icons.local_fire_department,
                                            Colors.orange,
                                            Row(
                                              children: ['Regular', 'Mild', 'Spicy'].map((level) {
                                                final isSelected = selectedSpiceLevel == level;
                                                final color = level == 'Spicy' ? Colors.red :
                                                             level == 'Mild' ? Colors.green :
                                                             Colors.grey;
                                                
                                                return Expanded(
                                                  child: Container(
                                                    margin: const EdgeInsets.only(right: 8),
                                                    child: InkWell(
                                                      onTap: () {
                                                        setDialogState(() {
                                                          selectedSpiceLevel = level;
                                                        });
                                                      },
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(
                                                            color: isSelected ? color : Colors.grey.shade300,
                                                            width: isSelected ? 2 : 1,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Container(
                                                              width: 20,
                                                              height: 20,
                                                              decoration: BoxDecoration(
                                                                color: isSelected ? color : Colors.transparent,
                                                                shape: BoxShape.circle,
                                                                border: Border.all(
                                                                  color: color,
                                                                  width: 2,
                                                                ),
                                                              ),
                                                              child: isSelected
                                                                  ? const Icon(
                                                                      Icons.check,
                                                                      color: Colors.white,
                                                                      size: 14,
                                                                    )
                                                                  : null,
                                                            ),
                                                            const SizedBox(height: 8),
                                                            Text(
                                                              level,
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                                color: isSelected ? color : Colors.grey.shade700,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                            if (level == 'Spicy') ...[
                                                              const SizedBox(height: 4),
                                                              Icon(
                                                                Icons.local_fire_department,
                                                                color: Colors.red.shade400,
                                                                size: 16,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    // Narrow screen: Single column layout
                                    _buildElegantSection(
                                      'Quantity',
                                      Icons.add_circle_outline,
                                      Theme.of(context).primaryColor,
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildQuantityButton(
                                              Icons.remove,
                                              quantity > 1,
                                              () {
                                                if (quantity > 1) {
                                                  setDialogState(() {
                                                    quantity--;
                                                  });
                                                }
                                              },
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              child: Text(
                                                '$quantity',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).primaryColor,
                                                ),
                                              ),
                                            ),
                                            _buildQuantityButton(
                                              Icons.add,
                                              true,
                                              () {
                                                setDialogState(() {
                                                  quantity++;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildElegantSection(
                                      'Spice Level',
                                      Icons.local_fire_department,
                                      Colors.orange,
                                      Column(
                                        children: ['Regular', 'Mild', 'Spicy'].map((level) {
                                          final isSelected = selectedSpiceLevel == level;
                                          final color = level == 'Spicy' ? Colors.red :
                                                       level == 'Mild' ? Colors.green :
                                                       Colors.grey;
                                          
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: InkWell(
                                              onTap: () {
                                                setDialogState(() {
                                                  selectedSpiceLevel = level;
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: isSelected ? color : Colors.grey.shade300,
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 20,
                                                      height: 20,
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? color : Colors.transparent,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: color,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: isSelected
                                                          ? const Icon(
                                                              Icons.check,
                                                              color: Colors.white,
                                                              size: 14,
                                                            )
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      level,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                        color: isSelected ? color : Colors.grey.shade700,
                                                      ),
                                                    ),
                                                    if (level == 'Spicy') ...[
                                                      const Spacer(),
                                                      Icon(
                                                        Icons.local_fire_department,
                                                        color: Colors.red.shade400,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Special Instructions Section - Always full width
                                  _buildElegantSection(
                                    'Special Instructions',
                                    Icons.edit_note,
                                    Colors.blue,
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: TextField(
                                        maxLength: 30,
                                        maxLines: 2,
                                        style: const TextStyle(fontSize: 16),
                                        decoration: InputDecoration(
                                          hintText: 'e.g., No onions, extra sauce...',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.all(16),
                                          counterText: '',
                                        ),
                                        onChanged: (value) {
                                          specialInstructions = value;
                                        },
                                      ),
                                    ),
                                  ),
                                  
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, left: 4),
                                    child: Text(
                                      '${specialInstructions.length}/30 characters',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Action Buttons (Fixed at bottom)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    'Cancel',
                                    Colors.grey.shade600,
                                    Colors.grey.shade100,
                                    () => Navigator.of(dialogContext).pop(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildActionButton(
                                    'Add to Order',
                                    Colors.white,
                                    Theme.of(context).primaryColor,
                                    () {
                                      Navigator.of(dialogContext).pop();
                                      _addConfiguredItemToOrder(item, quantity, selectedSpiceLevel, specialInstructions);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildElegantSection(String title, IconData icon, Color color, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10), // Increased from 8 to 10
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10), // Increased border radius
              ),
              child: Icon(
                icon,
                color: color,
                size: 24, // Increased from 20 to 24
              ),
            ),
            const SizedBox(width: 16), // Increased from 12 to 16
            Text(
              title,
              style: TextStyle(
                fontSize: 20, // Increased from 18 to 20
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20), // Increased from 16 to 20
        content,
      ],
    );
  }

  Widget _buildQuantityButton(IconData icon, bool enabled, VoidCallback onPressed) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(14), // Increased border radius
      child: Container(
        padding: const EdgeInsets.all(16), // Increased from 12 to 16
        child: Icon(
          icon,
          color: enabled ? Theme.of(context).primaryColor : Colors.grey.shade400,
          size: 28, // Increased from 24 to 28
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color textColor, Color backgroundColor, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18), // Increased border radius
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20), // Increased from 16 to 20
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18), // Increased border radius
          boxShadow: backgroundColor != Colors.grey.shade100 ? [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 18, // Increased from 16 to 18
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _addConfiguredItemToOrder(MenuItem item, int quantity, String spiceLevel, String specialInstructions) {
    if (_currentOrder != null) {
      try {
        setState(() {
          // Create special instructions text with spice level
          String finalInstructions = '';
          if (spiceLevel != 'Regular') {
            finalInstructions = 'Spice: $spiceLevel';
          }
          if (specialInstructions.isNotEmpty) {
            if (finalInstructions.isNotEmpty) {
              finalInstructions += ', $specialInstructions';
            } else {
              finalInstructions = specialInstructions;
            }
          }

          // Add new item with configuration
          final orderItem = OrderItem(
            menuItem: item,
            quantity: quantity,
            unitPrice: item.price,
            sentToKitchen: false,
            specialInstructions: finalInstructions.isEmpty ? null : finalInstructions,
          );
          _currentOrder!.items.add(orderItem);
        });
        _updateOrderWithHST();
        _autoSaveOrder();
      } catch (e) {
        debugPrint('Error adding configured item: $e');
        // Fallback to simple add if there's an error
        _addSimpleItemToOrder(item);
      }
    }
  }

  void _addSimpleItemToOrder(MenuItem item) {
    if (_currentOrder != null) {
      setState(() {
        // Look for existing item that hasn't been sent to kitchen yet
        final existingNewItemIndex = _currentOrder!.items.indexWhere(
          (orderItem) => orderItem.menuItem.id == item.id && !orderItem.sentToKitchen,
        );

        if (existingNewItemIndex != -1) {
          // Update quantity of existing NEW item (not sent to kitchen)
          final existingItem = _currentOrder!.items[existingNewItemIndex];
          _currentOrder!.items[existingNewItemIndex] = existingItem.copyWith(
            quantity: existingItem.quantity + 1,
          );
        } else {
          // Add new item (either first time or additional after sending to kitchen)
          final orderItem = OrderItem(
            menuItem: item,
            quantity: 1,
            unitPrice: item.price,
            sentToKitchen: false, // Explicitly mark as new
          );
          _currentOrder!.items.add(orderItem);
          
          // Log item addition
          _logItemAdded(orderItem);
        }
      });
      _updateOrderWithHST();
      _autoSaveOrder(); // Auto-save order when items are added
    }
  }

  void _removeItemFromOrder(int index) async {
    if (_currentOrder != null && index >= 0 && index < _currentOrder!.items.length) {
      final item = _currentOrder!.items[index];
      
      // Check if item has been sent to kitchen and user is not admin
      if (item.sentToKitchen && !widget.user.isAdmin) {
        // Show error message for non-admin users trying to remove sent items
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This item has been sent to kitchen. Only admin users can remove it.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Show confirmation dialog for admin users removing sent items
      if (item.sentToKitchen && widget.user.isAdmin) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Sent Item'),
            content: Text('This item has been sent to kitchen. Are you sure you want to remove "${item.menuItem.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) return;
      }
      
      setState(() {
        _currentOrder!.items.removeAt(index);
      });
      _updateOrderWithHST();
      _autoSaveOrder(); // Auto-save order when items are removed
      
      // Log item removal
      _logItemRemoved(item);
    }
  }

  void _updateItemQuantity(int index, int newQuantity) {
    if (_currentOrder != null && index >= 0 && index < _currentOrder!.items.length) {
      if (newQuantity <= 0) {
        _removeItemFromOrder(index);
      } else {
        setState(() {
          final item = _currentOrder!.items[index];
          final oldQuantity = item.quantity;
          _currentOrder!.items[index] = item.copyWith(quantity: newQuantity);
          
          // Log quantity update
          _logItemModified(_currentOrder!.items[index], 'Quantity updated from $oldQuantity to $newQuantity');
        });
        _updateOrderWithHST();
        _autoSaveOrder(); // Auto-save order when quantities are updated
      }
    }
  }

  void _updateItemNotes(int index, String notes) {
    if (_currentOrder != null && index >= 0 && index < _currentOrder!.items.length) {
      setState(() {
        final item = _currentOrder!.items[index];
        final updatedItem = item.copyWith(notes: notes.isEmpty ? null : notes);
        _currentOrder!.items[index] = updatedItem;
        // Force rebuild by updating the order reference
        _currentOrder = _currentOrder!.copyWith(
          items: List<OrderItem>.from(_currentOrder!.items),
        );
      });
      _autoSaveOrder(); // Auto-save when notes are updated
    }
  }

  void _updateItemSpecialInstructions(int index, String instructions) {
    if (_currentOrder != null && index >= 0 && index < _currentOrder!.items.length) {
      setState(() {
        final item = _currentOrder!.items[index];
        final updatedItem = item.copyWith(specialInstructions: instructions.isEmpty ? null : instructions);
        _currentOrder!.items[index] = updatedItem;
        // Force rebuild by updating the order reference
        _currentOrder = _currentOrder!.copyWith(
          items: List<OrderItem>.from(_currentOrder!.items),
        );
      });
      _autoSaveOrder(); // Auto-save when special instructions are updated
    }
  }

  double _calculateHST(double subtotal) {
    return subtotal * 0.13; // 13% HST for Ontario
  }

  void _updateOrderWithHST() {
    if (_currentOrder != null) {
      final hstAmount = _calculateHST(_currentOrder!.subtotal);
      setState(() {
        _currentOrder = _currentOrder!.copyWith(hstAmount: hstAmount);
      });
    }
  }

  /// Auto-save order to database so it appears in active orders immediately
  Future<void> _autoSaveOrder() async {
    if (_currentOrder == null || _currentOrder!.items.isEmpty) {
      return; // Don't save empty orders
    }

    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      
      // Set the order status and user ID for proper tracking
      final updatedOrder = _currentOrder!.copyWith(
        userId: widget.user.id, // Ensure order is assigned to current user
        status: OrderStatus.pending, // Set proper status
        updatedAt: DateTime.now(),
      );
      
      debugPrint('💾 Auto-saving order: ${updatedOrder.orderNumber} with ${updatedOrder.items.length} items');
      
      final saved = await orderService.saveOrder(updatedOrder, logAction: 'updated');
      if (saved) {
        // Update our local reference
        _currentOrder = updatedOrder;
        debugPrint('✅ Order auto-saved successfully');
      } else {
        debugPrint('⚠️ Order auto-save failed');
      }
    } catch (e) {
      debugPrint('❌ Error auto-saving order: $e');
      // Don't show error to user for auto-save failures
    }
  }

  /// Updates chef notes for the entire order
  void _updateChefNotes(String notes) {
    if (_currentOrder != null) {
      setState(() {
        final chefNote = OrderNote(
          id: const Uuid().v4(),
          note: notes,
          author: widget.user.name,
          timestamp: DateTime.now(),
          isInternal: true, // Chef notes are internal
        );
        final updatedNotes = List<OrderNote>.from(_currentOrder!.notes)..add(chefNote);
        _currentOrder = _currentOrder!.copyWith(notes: updatedNotes);
      });
      _autoSaveOrder(); // Auto-save when chef notes are updated
    }
  }

  /// Navigate to checkout screen
  void _navigateToCheckout() {
    if (_currentOrder != null && _currentOrder!.items.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            order: _currentOrder!,
            user: widget.user,
            orderType: widget.orderType == 'dine-in' ? OrderType.dineIn : OrderType.delivery,
          ),
        ),
      );
    }
  }

  /// Send order to kitchen
  Future<void> _sendOrderToKitchen() async {
    if (_currentOrder == null || _currentOrder!.items.isEmpty) {
      return;
    }

    // Show kitchen receipt preview first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => KitchenReceiptPreviewDialog(
        order: _currentOrder!, 
        serverName: _getServerName(),
      ),
    );

    if (confirmed != true) {
      // User cancelled the preview
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitchen receipt preview cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      // Mark all items as sent to kitchen
      final itemsToSend = <OrderItem>[];
      for (var item in _currentOrder!.items) {
        if (!item.sentToKitchen) {
          final index = _currentOrder!.items.indexOf(item);
          _currentOrder!.items[index] = item.copyWith(sentToKitchen: true);
          itemsToSend.add(_currentOrder!.items[index]);
        }
      }

      // Save the updated order
      await orderService.saveOrder(_currentOrder!);
      
      // Log items sent to kitchen
      _logItemsSentToKitchen(itemsToSend);

      // Print kitchen ticket after saving
      try {
        final printed = await printingService.printKitchenTicket(_currentOrder!);
        if (printed) {
          debugPrint('Kitchen ticket printed successfully for order: ${_currentOrder!.orderNumber}');
        } else {
          debugPrint('Kitchen ticket printing failed - no printer connected');
        }
      } catch (printError) {
        debugPrint('Kitchen ticket printing error: $printError');
        // Continue even if printing fails - don't block the order
      }

      setState(() => _isLoading = false);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order sent to kitchen & printed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ErrorDialogHelper.showValidationError(
          context,
          message: 'Failed to send order to kitchen: $e',
        );
      }
    }
  }

  /// Show chef notes dialog
  void _showChefNotesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chef Notes'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add special instructions for the kitchen:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _chefNotesController,
                decoration: const InputDecoration(
                  hintText: 'Enter chef notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (_currentOrder!.notes.any((note) => note.isInternal)) ...[
                const Text(
                  'Existing Chef Notes:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    itemCount: _currentOrder!.notes.where((note) => note.isInternal).length,
                    itemBuilder: (context, index) {
                      final chefNotes = _currentOrder!.notes.where((note) => note.isInternal).toList();
                      final note = chefNotes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${note.author}: ${note.note}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_chefNotesController.text.trim().isNotEmpty) {
                _updateChefNotes(_chefNotesController.text.trim());
                _chefNotesController.clear();
              }
              Navigator.pop(context);
            },
            child: const Text('Add Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentOrder == null) {
      return const Scaffold(
        body: LoadingOverlay(
          isLoading: true,
          child: SizedBox(),
        ),
      );
    }

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _error != null
            ? _buildErrorState()
            : _buildMainContent(),
        bottomNavigationBar: _buildActionButtons(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50), // Reduced from default 56 to 50
      child: AppBar(
        title: Text(
          '${widget.existingOrder != null ? 'Edit' : 'Create'} Order #${_currentOrder!.orderNumber}',
          style: const TextStyle(fontSize: 16), // Smaller title font
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 1, // Reduced elevation
        toolbarHeight: 50, // Explicit reduced height
        leading: IconButton(
          icon: const Icon(Icons.dashboard, size: 20), // Smaller icon
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderTypeSelectionScreen(),
            ),
          ),
          tooltip: 'POS Dashboard',
        ),
        actions: [
          // Compact server info
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8), // Smaller radius
            ),
            child: Text(
              widget.user.name,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 10, // Smaller font
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text(
            'Error Loading Menu',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'An unknown error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadCategories,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Detect device type for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600; // Phone breakpoint
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200; // Tablet breakpoint
    final isDesktop = screenSize.width >= 1200; // Desktop breakpoint
    
    if (isPhone) {
      // Mobile layout: Stacked panels with scrollable order panel
      return Column(
        children: [
          // Order Panel (Top) - Scrollable on mobile
          Container(
            height: screenSize.height * 0.4, // 40% of screen height
            child: _buildOrderPanel(),
          ),
          const Divider(height: 1),
          // Menu Panel (Bottom) - Takes remaining space
          Expanded(
            child: _buildMenuPanel(),
          ),
        ],
      );
    } else {
      // Tablet/Desktop layout: Side-by-side panels (original layout)
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Panel (Left)
          Expanded(
            flex: 2,
            child: _buildOrderPanel(),
          ),
          const VerticalDivider(width: 1),
          // Menu Panel (Right)
          Expanded(
            flex: 3,
            child: _buildMenuPanel(),
          ),
        ],
      );
    }
  }

  Widget _buildOrderPanel() {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes
    final headerPadding = isPhone ? 12.0 : isTablet ? 14.0 : 16.0;
    final headerFontSize = isPhone ? 16.0 : isTablet ? 17.0 : 18.0;
    final itemCountFontSize = isPhone ? 10.0 : isTablet ? 11.0 : 12.0;
    
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Container(
            padding: EdgeInsets.all(headerPadding),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  color: Theme.of(context).primaryColor,
                  size: isPhone ? 20.0 : 24.0,
                ),
                SizedBox(width: isPhone ? 8.0 : 12.0),
                Text(
                  'Current Order',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPhone ? 6.0 : 8.0, 
                    vertical: isPhone ? 3.0 : 4.0
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentOrder!.items.length} items',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: itemCountFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Order Items - Scrollable on all devices
          Expanded(
            child: _currentOrder!.items.isEmpty
                ? _buildEmptyOrder()
                : _buildOrderItems(),
          ),
          // Order Summary
          _buildOrderSummary(),
        ],
      ),
    );
  }

  Widget _buildEmptyOrder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_shopping_cart,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Items Added',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select items from the menu to add them to your order',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems() {
    // Get responsive padding based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    final padding = isPhone ? 12.0 : isTablet ? 14.0 : 16.0;
    
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: _currentOrder!.items.length,
      itemBuilder: (context, index) {
        final item = _currentOrder!.items[index];
        return _buildOrderItemCard(item, index);
      },
    );
  }

  Widget _buildOrderItemCard(OrderItem item, int index) {
    final bool hasChefNotes = item.notes?.isNotEmpty == true;
    final bool hasSpecialInstructions = item.specialInstructions?.isNotEmpty == true;
    final bool isSentToKitchen = item.sentToKitchen;
    final bool hasNotes = hasChefNotes || hasSpecialInstructions;

    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes
    final cardPadding = isPhone ? 8.0 : isTablet ? 10.0 : 12.0;
    final itemNameFontSize = isPhone ? 12.0 : isTablet ? 13.0 : 14.0;
    final priceFontSize = isPhone ? 10.0 : isTablet ? 11.0 : 12.0;
    final sentFontSize = isPhone ? 7.0 : isTablet ? 7.5 : 8.0;
    final cardMargin = isPhone ? 4.0 : isTablet ? 5.0 : 6.0;

    return Card(
      margin: EdgeInsets.only(bottom: cardMargin),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSentToKitchen ? Colors.green.shade200 : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: cardPadding * 0.7),
        child: Row(
          children: [
            // Item info - name and price (flexible to take remaining space)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.menuItem.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: itemNameFontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSentToKitchen)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SENT',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: sentFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '\$${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: priceFontSize,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Quantity controls (compact)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _updateItemQuantity(index, item.quantity - 1),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.remove, size: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: () => _updateItemQuantity(index, item.quantity + 1),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.add, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Total price
            Text(
              '\$${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).primaryColor,
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Notes indicator and action button
            if (hasNotes)
              GestureDetector(
                onTap: () => _showItemNotesMenu(item, index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasSpecialInstructions ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: hasSpecialInstructions ? Colors.blue.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Icon(
                    hasSpecialInstructions ? Icons.note : Icons.restaurant,
                    size: 16,
                    color: hasSpecialInstructions ? Colors.blue.shade700 : Colors.orange.shade700,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => _showItemNotesMenu(item, index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.note_add,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            
            const SizedBox(width: 8),
            
            // Delete button - only show if user is admin OR item is not sent to kitchen
            if (widget.user.isAdmin || !isSentToKitchen) ...[
              GestureDetector(
                onTap: () => _removeItemFromOrder(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isSentToKitchen && !widget.user.isAdmin 
                        ? Icons.lock_outline 
                        : Icons.delete_outline,
                    size: 16,
                    color: isSentToKitchen && !widget.user.isAdmin 
                        ? Colors.grey.shade400 
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show notes menu with options for chef notes and special instructions
  void _showItemNotesMenu(OrderItem item, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.menuItem.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Current notes display
              if (item.notes?.isNotEmpty == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chef Notes:',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.notes!,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              if (item.specialInstructions?.isNotEmpty == true) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Special Instructions:',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.specialInstructions!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showItemChefNotesDialog(item, index);
                      },
                      icon: const Icon(Icons.restaurant, size: 16),
                      label: const Text('Chef Notes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showItemSpecialInstructionsDialog(item, index);
                      },
                      icon: const Icon(Icons.note_add, size: 16),
                      label: const Text('Instructions'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show chef notes dialog for individual item
  void _showItemChefNotesDialog(OrderItem item, int index) {
    final controller = TextEditingController(text: item.notes);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chef Notes - ${item.menuItem.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add special preparation instructions for the kitchen:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., extra spicy, no onions, well done...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateItemNotes(index, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show special instructions dialog for individual item
  void _showItemSpecialInstructionsDialog(OrderItem item, int index) {
    final controller = TextEditingController(text: item.specialInstructions);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Special Instructions - ${item.menuItem.name}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add customer requests or preferences:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., allergy information, customer preferences...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateItemSpecialInstructions(index, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final discount = _currentOrder!.discountAmount ?? 0.0;
    final gratuity = _currentOrder!.gratuityAmount ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', '\$${_currentOrder!.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          if (discount > 0) ...[
            _buildSummaryRow('Discount', '-\$${discount.toStringAsFixed(2)}', isDiscount: true),
            const SizedBox(height: 8),
          ],
          _buildSummaryRow('HST (13%)', '\$${_currentOrder!.hstAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          if (gratuity > 0) ...[
            _buildSummaryRow('Gratuity', '\$${gratuity.toStringAsFixed(2)}', isGratuity: true),
            const SizedBox(height: 8),
          ],
          const Divider(),
          _buildSummaryRow(
            'Total',
            '\$${_currentOrder!.totalAmount.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, bool isDiscount = false, bool isGratuity = false}) {
    Color? textColor;
    if (isTotal) {
      textColor = Theme.of(context).primaryColor;
    } else if (isDiscount) {
      textColor = Colors.red;
    } else if (isGratuity) {
      textColor = Colors.green;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.red : (isGratuity ? Colors.green : null),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Menu header - shows back button when category is selected
          if (_selectedCategory != null) _buildMenuHeader(),
          // Categories display or divider
          if (_selectedCategory == null) 
            _buildCategoriesView()
          else 
            const Divider(height: 1),
          // Main content area
          if (_selectedCategory != null)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMenuItems(),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader() {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive sizing for mobile - Mobile-friendly design
    final horizontalPadding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable horizontal padding
    final verticalPadding = isPhone ? 12.0 : isTablet ? 10.0 : 12.0; // Comfortable vertical padding
    final titleFontSize = isPhone ? 18.0 : isTablet ? 17.0 : 18.0; // Comfortable title for mobile
    final itemCountFontSize = isPhone ? 14.0 : isTablet ? 13.0 : 14.0; // Comfortable item count for mobile
    final spacing = isPhone ? 8.0 : isTablet ? 7.0 : 8.0; // Comfortable spacing for mobile
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _menuItems.clear();
              });
            },
            icon: Icon(Icons.arrow_back, size: isPhone ? 24.0 : 24.0), // Comfortable icon for mobile
            tooltip: 'Back to Categories',
            padding: EdgeInsets.all(isPhone ? 8.0 : 8.0), // Comfortable padding for mobile
            constraints: BoxConstraints(
              minWidth: isPhone ? 48.0 : 48.0, // Comfortable touch target for mobile
              minHeight: isPhone ? 48.0 : 48.0, // Comfortable touch target for mobile
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Text(
              _selectedCategory?.name ?? '',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_menuItems.length} items',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: itemCountFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesView() {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive grid configuration - Mobile-friendly design
    final crossAxisCount = isPhone ? 2 : isTablet ? 3 : 4; // 2 columns on mobile for better readability
    final childAspectRatio = isPhone ? 1.2 : isTablet ? 1.2 : 1.1; // Comfortable aspect ratio for mobile
    final crossAxisSpacing = isPhone ? 12.0 : isTablet ? 10.0 : 12.0; // Comfortable spacing on mobile
    final mainAxisSpacing = isPhone ? 12.0 : isTablet ? 10.0 : 12.0; // Comfortable spacing on mobile
    final padding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable padding on mobile
    
    // Responsive font sizes - Mobile-friendly readability
    final titleFontSize = isPhone ? 18.0 : isTablet ? 19.0 : 20.0; // Comfortable title for mobile
    
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Text(
              'Select a Category',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _buildElegantCategoryCard(category);
                },
              ),
            ),
          ),
          SizedBox(height: isPhone ? 12.0 : 16.0),
        ],
      ),
    );
  }

  Widget _buildElegantCategoryCard(pos_category.Category category) {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive sizing - Mobile-friendly design
    final iconSize = isPhone ? 24.0 : isTablet ? 28.0 : 32.0; // Comfortable icon size for mobile
    final iconPadding = isPhone ? 8.0 : isTablet ? 10.0 : 12.0; // Comfortable padding for mobile
    final spacing = isPhone ? 8.0 : isTablet ? 10.0 : 12.0; // Comfortable spacing for mobile
    final textPadding = isPhone ? 6.0 : isTablet ? 7.0 : 8.0; // Comfortable text padding for mobile
    final fontSize = isPhone ? 12.0 : isTablet ? 13.0 : 14.0; // Comfortable font for mobile readability
    final borderRadius = isPhone ? 12.0 : isTablet ? 14.0 : 16.0; // Comfortable border radius for mobile
    
    return InkWell(
      onTap: () => _onCategorySelected(category),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade50,
            ],
          ),
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: iconSize,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: spacing),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: textPadding),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: isPhone ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    if (_filteredMenuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No menu items available',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This category appears to be empty',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Get responsive sizing based on device type
        final screenSize = MediaQuery.of(context).size;
        final isPhone = screenSize.width < 600;
        final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
        
        // Responsive grid configuration - Mobile-friendly design
        int crossAxisCount = isPhone ? 1 : isTablet ? 2 : 3; // 1 column on mobile for better readability
        if (constraints.maxWidth > 1400) {
          crossAxisCount = 5; // 5 columns for very wide screens
        } else if (constraints.maxWidth > 1000) {
          crossAxisCount = 4; // 4 columns for wide screens
        }
        
        final childAspectRatio = isPhone ? 0.8 : isTablet ? 0.95 : 0.85; // Comfortable aspect ratio for mobile
        final padding = isPhone ? 12.0 : isTablet ? 7.0 : 8.0; // Comfortable padding on mobile

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _filteredMenuItems.length,
          itemBuilder: (context, index) {
            final item = _filteredMenuItems[index];
            return _buildEnhancedMenuItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildEnhancedMenuItemCard(MenuItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _addItemToOrder(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item image placeholder or icon
              Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.restaurant,
                  size: 32,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              // Item name
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Item description
              if (item.description.isNotEmpty)
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              // Price and add button row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final newItemsCount = _currentOrder!.items.where((item) => !item.sentToKitchen).length;
    final hasNewItems = newItemsCount > 0;
    final hasAnyItems = _currentOrder!.items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row - Quick actions
          Row(
            children: [
              // Print receipt button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasAnyItems ? _printKitchenTicket : null,
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Discount button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasAnyItems ? _showDiscountDialog : null,
                  icon: const Icon(Icons.discount, size: 16),
                  label: const Text('Discount'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Gratuity button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasAnyItems ? _showGratuityDialog : null,
                  icon: const Icon(Icons.attach_money, size: 16),
                  label: const Text('Tip'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Bottom row - Main actions
          Row(
            children: [
              // Send to Kitchen button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: hasNewItems ? _sendOrderToKitchen : null,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.restaurant),
                  label: Text(
                    hasNewItems 
                        ? 'Send to Kitchen ($newItemsCount)'
                        : 'All Items Sent',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasNewItems ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Checkout button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasAnyItems ? _navigateToCheckout : null,
                  icon: const Icon(Icons.payment),
                  label: const Text('Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAnyItems ? Theme.of(context).primaryColor : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Cancel Order button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasAnyItems ? _cancelOrder : null,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAnyItems ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Print kitchen ticket with segregated printing
  Future<void> _printKitchenTicket() async {
    if (_currentOrder == null) return;
    
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printerAssignmentService = Provider.of<EnhancedPrinterAssignmentService>(context, listen: false);
      
      // Segregate items by printer assignments
      final itemsByPrinter = await printingService.segregateOrderItems(
        _currentOrder!,
        printerAssignmentService,
      );
      
      // Print to segregated printers
      await printingService.printOrderSegregated(_currentOrder!, itemsByPrinter);
      
      // Show success message with printer details
      final printerCount = itemsByPrinter.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kitchen tickets printed to $printerCount printer${printerCount == 1 ? '' : 's'} successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error printing kitchen ticket: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to print: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Show discount dialog
  Future<void> _showDiscountDialog() async {
    if (_currentOrder == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.discount, color: Colors.purple.shade700),
            const SizedBox(width: 8),
            const Text('Apply Discount'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order Total: \$${_currentOrder!.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'type': 'percentage'}),
                      child: const Text('Percentage'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'type': 'fixed'}),
                      child: const Text('Fixed Amount'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick discount buttons
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickDiscountButton('5%', 5),
                  _buildQuickDiscountButton('10%', 10),
                  _buildQuickDiscountButton('15%', 15),
                  _buildQuickDiscountButton('20%', 20),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result['type'] == 'percentage' || result['type'] == 'fixed') {
      _showDiscountInputDialog(result['type']);
    }
  }

  Widget _buildQuickDiscountButton(String label, double percentage) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _applyQuickDiscount(percentage);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.purple.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _showDiscountInputDialog(String type) async {
    final controller = TextEditingController();
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter ${type == 'percentage' ? 'Percentage' : 'Amount'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: type == 'percentage' ? 'Percentage (%)' : 'Amount (\$)',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (result != null) {
      _applyDiscount(type, result);
    }
  }

  void _applyQuickDiscount(double percentage) {
    setState(() {
      final discountAmount = _currentOrder!.subtotal * (percentage / 100);
      _currentOrder = _currentOrder!.copyWith(
        discountAmount: discountAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${percentage}% discount'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyDiscount(String type, double value) {
    setState(() {
      double discountAmount;
      if (type == 'percentage') {
        discountAmount = _currentOrder!.subtotal * (value / 100);
      } else {
        discountAmount = value;
      }

      _currentOrder = _currentOrder!.copyWith(
        discountAmount: discountAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${type == 'percentage' ? '${value}%' : '\$${value}'} discount'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show gratuity dialog
  Future<void> _showGratuityDialog() async {
    if (_currentOrder == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.attach_money, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Text('Add Gratuity'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Subtotal: \$${(_currentOrder!.subtotal - (_currentOrder!.discountAmount ?? 0.0)).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'type': 'percentage'}),
                      child: const Text('Percentage'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {'type': 'fixed'}),
                      child: const Text('Fixed Amount'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick gratuity buttons
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickGratuityButton('15%', 15),
                  _buildQuickGratuityButton('18%', 18),
                  _buildQuickGratuityButton('20%', 20),
                  _buildQuickGratuityButton('25%', 25),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result['type'] == 'percentage' || result['type'] == 'fixed') {
      _showGratuityInputDialog(result['type']);
    }
  }

  Widget _buildQuickGratuityButton(String label, double percentage) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _applyQuickGratuity(percentage);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Future<void> _showGratuityInputDialog(String type) async {
    final controller = TextEditingController();
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter ${type == 'percentage' ? 'Percentage' : 'Amount'}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: type == 'percentage' ? 'Percentage (%)' : 'Amount (\$)',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (result != null) {
      _applyGratuity(type, result);
    }
  }

  void _applyQuickGratuity(double percentage) {
    setState(() {
      final subtotalAfterDiscount = _currentOrder!.subtotal - (_currentOrder!.discountAmount ?? 0.0);
      final gratuityAmount = subtotalAfterDiscount * (percentage / 100);
      _currentOrder = _currentOrder!.copyWith(
        gratuityAmount: gratuityAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${percentage}% gratuity'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyGratuity(String type, double value) {
    setState(() {
      double gratuityAmount;
      if (type == 'percentage') {
        final subtotalAfterDiscount = _currentOrder!.subtotal - (_currentOrder!.discountAmount ?? 0.0);
        gratuityAmount = subtotalAfterDiscount * (value / 100);
      } else {
        gratuityAmount = value;
      }

      _currentOrder = _currentOrder!.copyWith(
        gratuityAmount: gratuityAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${type == 'percentage' ? '${value}%' : '\$${value}'} gratuity'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Cancel order with proper validation
  Future<void> _cancelOrder() async {
    if (_currentOrder == null || _currentOrder!.items.isEmpty) return;

    // Check if order has items sent to kitchen
    final sentItems = _currentOrder!.items.where((item) => item.sentToKitchen).toList();
    final newItems = _currentOrder!.items.where((item) => !item.sentToKitchen).toList();

    // If there are items sent to kitchen, order can be cancelled
    // If only new items (not sent to kitchen), they must be removed first
    if (sentItems.isEmpty && newItems.isNotEmpty) {
      // Show dialog asking to remove items first
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Cancel Order'),
          content: const Text(
            'This order has items that haven\'t been sent to the kitchen yet. '
            'Please remove all items first, or send them to the kitchen before cancelling.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'remove_all'),
              child: const Text('Remove All Items'),
            ),
          ],
        ),
      );

      if (result == 'remove_all') {
        setState(() {
          _currentOrder = _currentOrder!.copyWith(
            items: [],
            // Reset all totals, discount, and gratuity when items are removed
            subtotal: 0.0,
            hstAmount: 0.0,
            totalAmount: 0.0,
            discountAmount: 0.0,
            gratuityAmount: 0.0,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All items removed. Order totals reset.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog for cancellation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            if (sentItems.isNotEmpty)
              Text(
                'Warning: ${sentItems.length} item(s) have been sent to the kitchen.',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),
            Text('Order Total: \$${_currentOrder!.totalAmount.toStringAsFixed(2)}'),
            if (_currentOrder!.discountAmount != null && _currentOrder!.discountAmount! > 0)
              Text('Discount: -\$${_currentOrder!.discountAmount!.toStringAsFixed(2)}'),
            if (_currentOrder!.gratuityAmount != null && _currentOrder!.gratuityAmount! > 0)
              Text('Gratuity: +\$${_currentOrder!.gratuityAmount!.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Mark order as cancelled
      final cancelledOrder = _currentOrder!.copyWith(
        status: OrderStatus.cancelled,
        completedTime: DateTime.now(),
      );

      // Save the cancelled order
      await Provider.of<OrderService>(context, listen: false).saveOrder(cancelledOrder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
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

  String _getServerName() {
    return widget.table?.customerName ?? widget.user.name;
  }

  // Logging helper methods for comprehensive audit trail
  void _logItemAdded(OrderItem item) {
    if (_currentOrder == null) return;
    
    try {
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      orderLogService.logItemAdded(
        _currentOrder!,
        item,
        widget.user.id,
        widget.user.name,
      );
    } catch (e) {
      debugPrint('Failed to log item addition: $e');
    }
  }

  void _logItemRemoved(OrderItem item) {
    if (_currentOrder == null) return;
    
    try {
      debugPrint('🔍 Logging item removal: ${item.menuItem.name} (${item.quantity}x) from order ${_currentOrder!.orderNumber}');
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      orderLogService.logItemRemoved(
        _currentOrder!,
        item,
        widget.user.id,
        widget.user.name,
      );
      debugPrint('✅ Item removal logged successfully');
    } catch (e) {
      debugPrint('❌ Failed to log item removal: $e');
    }
  }

  void _logItemModified(OrderItem item, String changeDescription) {
    if (_currentOrder == null) return;
    
    try {
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      orderLogService.logItemVoided(
        _currentOrder!,
        item,
        widget.user.id,
        widget.user.name,
        reason: changeDescription,
      );
    } catch (e) {
      debugPrint('Failed to log item modification: $e');
    }
  }

  void _logItemsSentToKitchen(List<OrderItem> items) {
    if (_currentOrder == null || items.isEmpty) return;
    
    try {
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      orderLogService.logSentToKitchen(
        _currentOrder!,
        widget.user.id,
        widget.user.name,
        items: items,
      );
    } catch (e) {
      debugPrint('Failed to log items sent to kitchen: $e');
    }
  }

} 