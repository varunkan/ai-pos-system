import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/table.dart' as restaurant_table;
import 'package:ai_pos_system/models/category.dart' as pos_category;
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/printing_service.dart';
import 'package:ai_pos_system/services/settings_service.dart';
import 'package:ai_pos_system/widgets/loading_overlay.dart';
import 'package:ai_pos_system/widgets/error_dialog.dart';
import 'package:ai_pos_system/widgets/back_button.dart';
import 'package:ai_pos_system/screens/checkout_screen.dart';
import 'package:uuid/uuid.dart';

class OrderCreationScreen extends StatefulWidget {
  final User user;
  final restaurant_table.Table? table;
  final int? numberOfPeople;
  final String? orderNumber;
  final String orderType; // 'dine-in' or 'takeout'

  const OrderCreationScreen({
    super.key,
    required this.user,
    this.table,
    this.numberOfPeople,
    this.orderNumber,
    required this.orderType,
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
  
  // Search functionality
  String _searchQuery = '';
  
  // Filtered menu items based on search and category
  List<MenuItem> get _filteredMenuItems {
    List<MenuItem> items = _menuItems;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return items;
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
    super.dispose();
  }

  void _initializeOrder() {
    final orderNumber = widget.orderNumber ??
        'DI-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    _currentOrder = Order(
      items: [],
      orderNumber: orderNumber,
      customerName: widget.table?.customerName,
      tableId: widget.table?.id,
      type: widget.orderType == 'dine-in' ? OrderType.dineIn : OrderType.delivery,
      orderTime: DateTime.now(),
    );
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
        }
      });
      _updateOrderWithHST();
    }
  }

  void _updateItemQuantity(int itemIndex, int newQuantity) {
    if (_currentOrder != null && itemIndex >= 0 && itemIndex < _currentOrder!.items.length) {
      setState(() {
        if (newQuantity <= 0) {
          _currentOrder!.items.removeAt(itemIndex);
        } else {
          final item = _currentOrder!.items[itemIndex];
          _currentOrder!.items[itemIndex] = item.copyWith(
            quantity: newQuantity,
          );
        }
      });
      _updateOrderWithHST();
    }
  }

  void _removeItemFromOrder(OrderItem item) {
    if (_currentOrder != null) {
      setState(() {
        _currentOrder!.items.removeWhere((orderItem) => orderItem.id == item.id);
      });
      _updateOrderWithHST();
    }
  }

  Future<void> _sendOrderToKitchen() async {
    final newItems = _currentOrder!.items.where((item) => !item.sentToKitchen).toList();
    
    if (newItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No new items to send to kitchen'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final printingService = Provider.of<PrintingService>(context, listen: false);

      // Mark items as sent to kitchen
      setState(() {
        for (int i = 0; i < _currentOrder!.items.length; i++) {
          if (!_currentOrder!.items[i].sentToKitchen) {
            _currentOrder!.items[i] = _currentOrder!.items[i].copyWith(
              sentToKitchen: true,
            );
          }
        }
      });

      // Set the user ID for the order and update status to confirmed
      final orderWithUser = _currentOrder!.copyWith(
        userId: widget.user.id,
        status: OrderStatus.confirmed,
      );

      // Save the order to the service
      await orderService.saveOrder(orderWithUser);

      // Send to kitchen
      await printingService.printKitchenTicket(orderWithUser);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newItems.length} items sent to kitchen successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        // Stay in the screen to allow adding more items
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Sending Order',
          message: 'Failed to send order to kitchen: $e',
        );
      }
    }
  }

  /// Calculates HST amount based on subtotal and tax rate from settings.
  double _calculateHST(double subtotal) {
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final taxRate = settingsService.settings.taxRate;
    return subtotal * (taxRate / 100);
  }

  /// Updates the order with calculated HST when items change.
  void _updateOrderWithHST() {
    if (_currentOrder != null) {
      final hstAmount = _calculateHST(_currentOrder!.subtotal);
      setState(() {
        _currentOrder = _currentOrder!.copyWith(hstAmount: hstAmount);
      });
    }
  }

  /// Updates order notes
  void _updateOrderNotes(String notes) {
    if (_currentOrder != null) {
      setState(() {
        final orderNote = OrderNote(
          id: const Uuid().v4(),
          note: notes,
          author: widget.user.name,
          timestamp: DateTime.now(),
          isInternal: false,
        );
        final updatedNotes = List<OrderNote>.from(_currentOrder!.notes)..add(orderNote);
        _currentOrder = _currentOrder!.copyWith(notes: updatedNotes);
      });
    }
  }

  /// Updates item notes
  void _updateItemNotes(OrderItem item, String notes) {
    if (_currentOrder != null) {
      setState(() {
        final itemIndex = _currentOrder!.items.indexWhere(
          (orderItem) => orderItem.id == item.id,
        );
        if (itemIndex != -1) {
          _currentOrder!.items[itemIndex] = item.copyWith(notes: notes);
        }
      });
    }
  }

  /// Navigate to checkout screen
  Future<void> _navigateToCheckout() async {
    if (_currentOrder!.items.isEmpty) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Please add items to the order before checkout.',
      );
      return;
    }

    try {
      final result = await Navigator.push<Order>(
        context,
        MaterialPageRoute<Order>(
          builder: (context) => CheckoutScreen(
            order: _currentOrder!,
            user: widget.user,
            orderType: widget.orderType == 'dine-in' ? OrderType.dineIn : OrderType.takeaway,
            table: null, // Takeout orders don't have tables
          ),
        ),
      );
      
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Checkout Error',
          message: 'Failed to open checkout: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _error != null
            ? _buildErrorState(_error!)
            : _buildMainContent(),
        bottomNavigationBar: _buildActionButtons(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Order #${_currentOrder!.orderNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.orderType == 'dine-in' ? 'Dine-In' : 'Takeout',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            'Server: ${widget.user.name}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      actions: [
        // Admin actions
        if (widget.user.isAdmin) ...[
          PopupMenuButton<String>(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.purple),
            tooltip: 'Admin Actions',
            onSelected: (value) async {
              switch (value) {
                case 'reprint':
                  await _reprintKitchenTicket();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reprint',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Reprint Kitchen Ticket'),
                  ],
                ),
              ),
            ],
          ),
        ],
        const CustomBackButton(),
        const SizedBox(width: 16),
      ],
    );
  }

  /// Builds main content with side-by-side layout
  Widget _buildMainContent() {
    return Row(
      children: [
        // Left Panel - Order Details
        Expanded(
          flex: 1,
          child: _buildOrderPanel(),
        ),
        // Right Panel - Menu
        Expanded(
          flex: 2,
          child: _buildMenuPanel(),
        ),
      ],
    );
  }

  Widget _buildOrderPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOrderHeader(),
          Expanded(
            child: _buildOrderItems(),
          ),
          _buildOrderSummary(),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    final newItemsCount = _currentOrder!.items.where((item) => !item.sentToKitchen).length;
    final sentItemsCount = _currentOrder!.items.where((item) => item.sentToKitchen).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.orderType == 'dine-in' ? 'Dine-In Order' : 'Takeout Order',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Server: ${widget.user.name}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          if (_currentOrder!.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (newItemsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$newItemsCount New',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (sentItemsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$sentItemsCount Sent',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItems() {
    if (_currentOrder!.items.isEmpty) {
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
              'No items added yet',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select items from the menu to add to this order',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _currentOrder!.items.length,
      itemBuilder: (context, index) {
        final item = _currentOrder!.items[index];
        return _buildOrderItemCard(item, index);
      },
    );
  }

  Widget _buildOrderItemCard(OrderItem item, int index) {
    final isNewItem = !item.sentToKitchen;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isNewItem ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNewItem ? Colors.orange.shade200 : Colors.green.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.menuItem.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isNewItem ? Colors.orange.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isNewItem ? 'NEW' : 'SENT',
                    style: TextStyle(
                      color: isNewItem ? Colors.orange.shade700 : Colors.green.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${item.unitPrice.toStringAsFixed(2)} each',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (item.specialInstructions?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 12,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.specialInstructions!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isNewItem) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  // Quantity controls
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
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _updateItemQuantity(index, item.quantity + 1),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Remove button
                  InkWell(
                    onTap: () => _updateItemQuantity(index, 0),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _currentOrder!.totalAmount;
    final discount = _currentOrder!.discountAmount;
    final gratuity = _currentOrder!.gratuityAmount;
    final finalTotal = subtotal - discount + gratuity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', subtotal),
          if (discount > 0) _buildSummaryRow('Discount', -discount, isDiscount: true),
          if (gratuity > 0) _buildSummaryRow('Gratuity', gratuity, isGratuity: true),
          const Divider(),
          _buildSummaryRow('Total', finalTotal, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isDiscount = false, bool isGratuity = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal 
                  ? Theme.of(context).primaryColor
                  : isDiscount 
                      ? Colors.red.shade600
                      : isGratuity 
                          ? Colors.green.shade600
                          : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuHeader(),
          _buildSearchBar(),
          _buildCategoriesTabs(),
          Expanded(
            child: _buildMenuItems(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.restaurant_menu,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Menu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${_filteredMenuItems.length} items',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildCategoriesTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory?.id == category.id;
          
          return Container(
            margin: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _onCategorySelected(category);
                }
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Theme.of(context).primaryColor,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            ),
          );
        },
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
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No items found' : 'No menu items available',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search terms',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _filteredMenuItems.length,
      itemBuilder: (context, index) {
        final item = _filteredMenuItems[index];
        return _buildMenuItemCard(item);
      },
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _addItemToOrder(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Description
              Text(
                item.description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Price and add button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(6),
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
    if (_currentOrder!.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final newItemsCount = _currentOrder!.items.where((item) => !item.sentToKitchen).length;
    final canSendToKitchen = newItemsCount > 0;
    final isDineIn = widget.orderType == 'dine-in';
    final isAdmin = widget.user.isAdmin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
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
              // Print button
              Expanded(
                child: _buildActionButton(
                  icon: Icons.print,
                  label: 'Print',
                  color: Colors.blue,
                  onPressed: () => _printKitchenTicket(),
                ),
              ),
              const SizedBox(width: 8),
              // Discount button (Admin only)
              if (isAdmin) ...[
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.percent,
                    label: 'Discount',
                    color: Colors.purple,
                    onPressed: () => _showDiscountDialog(),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Gratuity button (Dine-in only)
              if (isDineIn) ...[
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.attach_money,
                    label: 'Gratuity',
                    color: Colors.green,
                    onPressed: () => _showGratuityDialog(),
                  ),
                ),
                const SizedBox(width: 8),
              ],
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
                  onPressed: canSendToKitchen ? _sendOrderToKitchen : null,
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
                    canSendToKitchen 
                        ? 'Send to Kitchen ($newItemsCount)'
                        : 'All Items Sent',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSendToKitchen ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                  onPressed: () => _navigateToCheckout(),
                  icon: const Icon(Icons.payment),
                  label: const Text('Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  // Print kitchen ticket
  Future<void> _printKitchenTicket() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.printKitchenTicket(_currentOrder!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitchen ticket printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Print Error',
          message: 'Failed to print kitchen ticket: $e',
        );
      }
    }
  }

  // Reprint kitchen ticket (admin only)
  Future<void> _reprintKitchenTicket() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.printKitchenTicket(_currentOrder!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitchen ticket reprinted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Print Error',
          message: 'Failed to reprint kitchen ticket: $e',
        );
      }
    }
  }

  // Show discount dialog (admin only) - placeholder
  Future<void> _showDiscountDialog() async {
    if (!widget.user.isAdmin) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Discount feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Show gratuity dialog (dine-in only) - placeholder
  Future<void> _showGratuityDialog() async {
    if (widget.orderType != 'dine-in') return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gratuity feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
} 