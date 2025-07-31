import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../services/menu_service.dart';

class KitchenReceiptPreviewDialog extends StatelessWidget {
  final Order order;
  final String serverName;

  const KitchenReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kitchen Receipt Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '80mm Thermal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Receipt Preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Container(
                    // 80mm thermal printer width simulation (about 384 pixels)
                    width: 384,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildReceiptContent(context),
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.print),
                      label: const Text('Send to Kitchen & Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptContent(BuildContext context) {
    final menuService = Provider.of<MenuService>(context, listen: false);
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    // Calculate estimated ready time (add 20 minutes)
    final estimatedReadyTime = now.add(const Duration(minutes: 20));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Restaurant Header
        _buildReceiptLine('================================', bold: true, fontSize: 12),
        const SizedBox(height: 8),
        _buildReceiptLine('OH BOMBAY MILTON', bold: true, fontSize: 18),
        _buildReceiptLine('KITCHEN ORDER', bold: true, fontSize: 16),
        const SizedBox(height: 8),
        _buildReceiptLine('================================', bold: true, fontSize: 12),
        const SizedBox(height: 16),
        
        // Order Details Header
        _buildReceiptLine('ORDER #${order.orderNumber}', bold: true, fontSize: 20),
        const SizedBox(height: 12),
        
        // Server & Time Info
        _buildReceiptRow('Server:', serverName, bold: true),
        _buildReceiptRow('Date:', dateFormat.format(now)),
        _buildReceiptRow('Time:', timeFormat.format(now)),
        _buildReceiptRow('Ready by:', timeFormat.format(estimatedReadyTime), 
            valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        
        const SizedBox(height: 16),
        _buildReceiptLine('================================', fontSize: 12),
        
        // Order Type & Table
        if (order.type == OrderType.dineIn && order.tableId != null)
          _buildReceiptRow('Table:', _getTableNumber(order.tableId!), bold: true),
        _buildReceiptRow('Type:', _getOrderTypeDisplay(order.type), bold: true),
        
        const SizedBox(height: 16),
        _buildReceiptLine('================================', bold: true, fontSize: 12),
        const SizedBox(height: 16),
        
        // Items grouped by category
        FutureBuilder<Widget>(
          future: _buildGroupedItems(context, menuService),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return snapshot.data!;
            }
            return const CircularProgressIndicator();
          },
        ),
        
        const SizedBox(height: 16),
        _buildReceiptLine('================================', bold: true, fontSize: 12),
        
        // Special Instructions
        if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildReceiptLine('SPECIAL INSTRUCTIONS:', bold: true, fontSize: 14),
          const SizedBox(height: 8),
          _buildReceiptLine(order.specialInstructions!, fontSize: 12),
          const SizedBox(height: 16),
          _buildReceiptLine('================================', fontSize: 12),
        ],
        
        // Footer
        const SizedBox(height: 16),
        _buildReceiptLine('TOTAL ITEMS: ${_getTotalQuantity()}', bold: true, fontSize: 14),
        const SizedBox(height: 8),
        _buildReceiptLine('Please prepare items carefully', fontSize: 11),
        _buildReceiptLine('and mark ready when complete', fontSize: 11),
        const SizedBox(height: 16),
        _buildReceiptLine('================================', fontSize: 12),
        const SizedBox(height: 8),
        _buildReceiptLine('Thank you!', bold: true, fontSize: 14),
      ],
    );
  }

  Future<Widget> _buildGroupedItems(BuildContext context, MenuService menuService) async {
    // Group items by category
    final Map<String, List<OrderItem>> groupedItems = {};
    
    for (final item in order.items.where((item) => !item.sentToKitchen)) {
      final categoryId = item.menuItem.categoryId;
      final category = await menuService.getCategoryById(categoryId);
      final categoryName = category?.name ?? 'Other Items';
      
      if (!groupedItems.containsKey(categoryName)) {
        groupedItems[categoryName] = [];
      }
      groupedItems[categoryName]!.add(item);
    }

    // Build UI for each category
    final List<Widget> categoryWidgets = [];
    
    for (final categoryName in groupedItems.keys) {
      final items = groupedItems[categoryName]!;
      
      // Category header
      categoryWidgets.add(_buildReceiptLine(categoryName.toUpperCase(), bold: true, fontSize: 14));
      categoryWidgets.add(const SizedBox(height: 8));
      categoryWidgets.add(_buildReceiptLine('--------------------------------', fontSize: 10));
      categoryWidgets.add(const SizedBox(height: 8));
      
      // Items in this category
      for (final item in items) {
        categoryWidgets.add(_buildItemDetails(item));
        categoryWidgets.add(const SizedBox(height: 12));
      }
      
      categoryWidgets.add(const SizedBox(height: 8));
    }
    
    return Column(children: categoryWidgets);
  }

  Widget _buildItemDetails(OrderItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name and quantity
        _buildReceiptRow('${item.quantity}x', item.menuItem.name, bold: true),
        
        // Special instructions
        if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildReceiptLine('  → ${item.specialInstructions!}', fontSize: 11, 
              color: Colors.blue.shade700),
        ],
        
        // Spice level
        if (item.notes != null && item.notes!.contains('Spice:')) ...[
          const SizedBox(height: 4),
          _buildReceiptLine('  → ${item.notes!}', fontSize: 11, 
              color: Colors.red.shade700),
        ],
      ],
    );
  }

  Widget _buildReceiptLine(String text, {
    bool bold = false,
    double fontSize = 12,
    Color? color,
    TextAlign textAlign = TextAlign.center,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black,
          fontFamily: 'monospace', // Monospace for thermal printer effect
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {
    bool bold = false,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  String _getTableNumber(String tableId) {
    // Extract table number from tableId
    final match = RegExp(r'table_(\d+)').firstMatch(tableId);
    if (match != null) {
      return match.group(1)!;
    }
    final numbers = RegExp(r'\d+').allMatches(tableId);
    if (numbers.isNotEmpty) {
      return numbers.first.group(0)!;
    }
    return tableId.replaceAll('table_', '').replaceAll('_', ' ').toUpperCase();
  }

  String _getOrderTypeDisplay(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'DINE IN';
      case OrderType.takeaway:
        return 'TAKEAWAY';
      case OrderType.delivery:
        return 'DELIVERY';
      case OrderType.catering:
        return 'CATERING';
    }
  }

  int _getTotalQuantity() {
    return order.items
        .where((item) => !item.sentToKitchen)
        .fold(0, (sum, item) => sum + item.quantity);
  }
} 