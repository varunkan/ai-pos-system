import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/back_button.dart';
import 'edit_active_order_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  final User user;

  const AdminOrdersScreen({super.key, required this.user});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _isLoading = false;
  String? _error;
  List<Order> _allOrders = [];
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  OrderType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      final orders = await orderService.getAllOrders();
      
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load orders.\n\nError: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  List<Order> get _filteredOrders {
    return _allOrders.where((order) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = order.orderNumber.toLowerCase().contains(query) ||
            order.customerName?.toLowerCase().contains(query) == true ||
            order.items.any((item) => 
                item.menuItem.name.toLowerCase().contains(query));
        if (!matchesSearch) return false;
      }

      // Status filter
      if (_statusFilter != null && order.status != _statusFilter) {
        return false;
      }

      // Type filter
      if (_typeFilter != null && order.type != _typeFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  // Get server name who cancelled the order
  String? _getCancelledByServerName(Order order) {
    if (order.status != OrderStatus.cancelled) return null;
    
    // Find the last history entry with cancelled status
    final cancelHistory = order.history
        .where((h) => h.status == OrderStatus.cancelled)
        .lastOrNull;
    
    return cancelHistory?.updatedBy;
  }

  // Get server name from user ID
  Future<String?> _getServerNameFromId(String? userId) async {
    if (userId == null) return null;
    
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final user = await userService.getUserById(userId);
      return user?.name;
    } catch (e) {
      return userId; // Return ID if name lookup fails
    }
  }

  Future<void> _viewOrderDetails(Order order) async {
    await showDialog(
      context: context,
      builder: (context) => _OrderDetailsDialog(order: order),
    );
  }

  Future<void> _editOrder(Order order) async {
    // Check if order is closed/completed
    if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Cannot edit ${order.status.name} orders.',
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditActiveOrderScreen(
          order: order,
          user: widget.user,
        ),
      ),
    );

    if (result != null) {
      // Refresh orders if order was modified
      await _loadOrders();
      
      // If coming from send to kitchen, show a success message
      if (result is Map && result['showActiveOrders'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items sent to kitchen successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder(Order order) async {
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
            Text('Order #: ${order.orderNumber}'),
            Text('Customer: ${order.customerName ?? 'No customer name'}'),
            Text('Order Total: \$${order.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Text(
              'This will mark the order as cancelled and cannot be undone.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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

      // Create cancellation history entry
      final cancellationHistory = OrderHistory(
        id: const Uuid().v4(),
        status: OrderStatus.cancelled,
        updatedBy: widget.user.name,
        timestamp: DateTime.now(),
        notes: 'Order cancelled by ${widget.user.name} from Admin Panel',
      );

      // Add cancellation history to the order
      final updatedHistory = List<OrderHistory>.from(order.history);
      updatedHistory.add(cancellationHistory);

      // Mark order as cancelled
      final cancelledOrder = order.copyWith(
        status: OrderStatus.cancelled,
        completedTime: DateTime.now(),
        history: updatedHistory,
      );

      // Save the cancelled order
      final orderService = Provider.of<OrderService>(context, listen: false);
      await orderService.saveOrder(cancelledOrder);
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} cancelled successfully!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
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
          title: 'Error Cancelling Order',
          message: 'Failed to cancel order: $e',
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

  Future<void> _deleteOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to delete order #${order.orderNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final orderService = Provider.of<OrderService>(context, listen: false);
        await orderService.deleteOrder(order.id);
        await _loadOrders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${order.orderNumber} deleted'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
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
            title: 'Error Deleting Order',
            message: 'Failed to delete order: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Admin Orders'),
          backgroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          actions: [
            IconButton(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 16),
          ],
          leading: const CustomBackButton(),
        ),
        body: _error != null
            ? _buildErrorState(_error!)
            : Column(
                children: [
                  _buildFilters(),
                  Expanded(
                    child: _buildOrdersList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadOrders,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isLoading ? 'Loading...' : 'Retry'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Search bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search orders by number, customer, or items...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        isSelected: _statusFilter == null,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...OrderStatus.values.map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: status.name.toUpperCase(),
                          isSelected: _statusFilter == status,
                          onTap: () => setState(() => _statusFilter = status),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(
                label: 'All Types',
                isSelected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              const SizedBox(width: 8),
              ...OrderType.values.map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: type.name.toUpperCase(),
                  isSelected: _typeFilter == type,
                  onTap: () => setState(() => _typeFilter = type),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildOrdersList() {
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt_long,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No orders found for "$_searchQuery"'
                  : 'No orders found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    final canEdit = order.status != OrderStatus.completed && 
                   order.status != OrderStatus.cancelled;
    final cancelledBy = _getCancelledByServerName(order);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.customerName ?? 'No customer name',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  // Show cancellation info for cancelled orders
                  if (order.status == OrderStatus.cancelled && cancelledBy != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelled by: $cancelledBy',
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _buildStatusChip(order.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  order.type == OrderType.dineIn ? Icons.table_restaurant : Icons.takeout_dining,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  order.type.name.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(order.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.items.length} items • \$${order.subtotal.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewOrderDetails(order);
                break;
              case 'edit':
                _editOrder(order);
                break;
              case 'cancel':
                _cancelOrder(order);
                break;
              case 'delete':
                _deleteOrder(order);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 16),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            if (canEdit)
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('Edit Order'),
                  ],
                ),
              ),
            if (canEdit && order.status != OrderStatus.cancelled)
              const PopupMenuItem(
                value: 'cancel',
                child: Row(
                  children: [
                    Icon(Icons.cancel, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Cancel Order', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Order', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'CONFIRMED';
        break;
      case OrderStatus.preparing:
        color = Colors.indigo;
        label = 'PREPARING';
        break;
      case OrderStatus.ready:
        color = Colors.green;
        label = 'READY';
        break;
      case OrderStatus.served:
        color = Colors.teal;
        label = 'SERVED';
        break;
      case OrderStatus.completed:
        color = Colors.green;
        label = 'COMPLETED';
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        label = 'CANCELLED';
        break;
      case OrderStatus.refunded:
        color = Colors.purple;
        label = 'REFUNDED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _OrderDetailsDialog extends StatelessWidget {
  final Order order;

  const _OrderDetailsDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(order.status),
                          const SizedBox(width: 12),
                          Text(
                            order.type.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    _buildSection(
                      'Customer Information',
                      [
                        _buildInfoRow('Name', order.customerName ?? 'N/A'),
                        _buildInfoRow('Phone', order.customerPhone ?? 'N/A'),
                        _buildInfoRow('Email', order.customerEmail ?? 'N/A'),
                        if (order.customerAddress != null)
                          _buildInfoRow('Address', order.customerAddress!),
                      ],
                    ),
                    
                    // Order Information
                    _buildSection(
                      'Order Information',
                      [
                        _buildInfoRow('Order Time', _formatDateTime(order.createdAt)),
                        _buildInfoRow('Order Type', order.type.name.toUpperCase()),
                        if (order.tableId != null)
                          _buildInfoRow('Table', order.tableId!),
                        if (order.specialInstructions != null)
                          _buildInfoRow('Special Instructions', order.specialInstructions!),
                        if (order.assignedTo != null)
                          _buildInfoRow('Assigned To', order.assignedTo!),
                      ],
                    ),
                    
                    // Items
                    _buildSection(
                      'Order Items (${order.items.length})',
                      order.items.map((item) => _buildItemRow(item)).toList(),
                    ),
                    
                    // Order Totals
                    _buildSection(
                      'Order Totals',
                      [
                        _buildInfoRow('Subtotal', '\$${order.subtotal.toStringAsFixed(2)}'),
                        if (order.discountAmount > 0)
                          _buildInfoRow('Discount', '-\$${order.discountAmount.toStringAsFixed(2)}', isDiscount: true),
                        _buildInfoRow('HST (13%)', '\$${order.hstAmount.toStringAsFixed(2)}'),
                        if (order.gratuityAmount > 0)
                          _buildInfoRow('Gratuity', '\$${order.gratuityAmount.toStringAsFixed(2)}'),
                        if (order.tipAmount > 0)
                          _buildInfoRow('Tip', '\$${order.tipAmount.toStringAsFixed(2)}'),
                        const Divider(),
                        _buildInfoRow('Total', '\$${order.totalAmount.toStringAsFixed(2)}', isTotal: true),
                      ],
                    ),
                    
                    // Payment Information
                    if (order.paymentMethod != null)
                      _buildSection(
                        'Payment Information',
                        [
                          _buildInfoRow('Payment Method', order.paymentMethod!),
                          _buildInfoRow('Payment Status', order.paymentStatus.name.toUpperCase()),
                          if (order.paymentTransactionId != null)
                            _buildInfoRow('Transaction ID', order.paymentTransactionId!),
                        ],
                      ),
                    
                    // Order History
                    if (order.history.isNotEmpty)
                      _buildSection(
                        'Order History',
                        order.history.map((history) => _buildHistoryRow(history)).toList(),
                      ),
                    
                    // Order Notes
                    if (order.notes.isNotEmpty)
                      _buildSection(
                        'Order Notes',
                        order.notes.map((note) => _buildNoteRow(note)).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
                color: isDiscount ? Colors.red.shade600 : 
                       isTotal ? Colors.black87 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'x${item.quantity}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '\$${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (item.selectedVariant != null) ...[
            const SizedBox(height: 4),
            Text(
              'Variant: ${item.selectedVariant}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          if (item.selectedModifiers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Modifiers: ${item.selectedModifiers.join(', ')}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          if (item.specialInstructions != null) ...[
            const SizedBox(height: 4),
            Text(
              'Instructions: ${item.specialInstructions}',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (item.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Chef Notes: ${item.notes}',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.sentToKitchen ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.sentToKitchen ? 'SENT TO KITCHEN' : 'NEW',
                  style: TextStyle(
                    color: item.sentToKitchen ? Colors.green.shade700 : Colors.orange.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item.voided == true)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'VOIDED',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(OrderHistory history) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Status changed to: ${history.status.name.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatDateTime(history.timestamp),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (history.updatedBy != null) ...[
            const SizedBox(height: 4),
            Text(
              'Updated by: ${history.updatedBy}',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (history.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${history.notes}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteRow(OrderNote note) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: note.isInternal ? Colors.yellow.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: note.isInternal ? Colors.yellow.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                note.isInternal ? Icons.note : Icons.comment,
                size: 16,
                color: note.isInternal ? Colors.yellow.shade700 : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                note.isInternal ? 'Internal Note' : 'Customer Note',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: note.isInternal ? Colors.yellow.shade700 : Colors.green.shade700,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(note.timestamp),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.note,
            style: const TextStyle(fontSize: 14),
          ),
          if (note.author != null) ...[
            const SizedBox(height: 4),
            Text(
              'By: ${note.author}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'CONFIRMED';
        break;
      case OrderStatus.preparing:
        color = Colors.indigo;
        label = 'PREPARING';
        break;
      case OrderStatus.ready:
        color = Colors.green;
        label = 'READY';
        break;
      case OrderStatus.served:
        color = Colors.teal;
        label = 'SERVED';
        break;
      case OrderStatus.completed:
        color = Colors.green;
        label = 'COMPLETED';
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        label = 'CANCELLED';
        break;
      case OrderStatus.refunded:
        color = Colors.purple;
        label = 'REFUNDED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 