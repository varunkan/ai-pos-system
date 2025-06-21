import 'package:flutter/material.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import '../widgets/back_button.dart';
import 'dine_in_setup_screen.dart';
import 'takeout_setup_screen.dart';
import 'edit_active_order_screen.dart';
import '../services/order_service.dart';
import 'package:provider/provider.dart';

class OrderTypeSelectionScreen extends StatelessWidget {
  final User user;

  const OrderTypeSelectionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        // Get real data from OrderService with safety checks
        List<dynamic> activeOrders = [];
        List<dynamic> completedOrders = [];
        List<Map<String, dynamic>> recentOrders = [];
        
        try {
          activeOrders = orderService.activeOrders ?? [];
          completedOrders = orderService.completedOrders ?? [];
          recentOrders = activeOrders.take(3).map((order) => {
            'number': order.orderNumber,
            'type': order.type == OrderType.dineIn ? 'Dine-In' : 'Takeout',
            'amount': '\$${order.totalAmount.toStringAsFixed(2)}',
          }).toList();
        } catch (e) {
          debugPrint('Error in OrderTypeSelectionScreen Consumer: $e');
          // Return a fallback UI if there's an error
          return Scaffold(
            appBar: AppBar(title: Text('Welcome, ${user.name}')),
            body: const Center(
              child: Text('Loading orders...'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Welcome, ${user.name}'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.list_alt),
                tooltip: 'View My Orders',
                onPressed: () => _showServerOrders(context),
              ),
              const SizedBox(width: 8),
              const CustomBackButton(),
              const SizedBox(width: 16),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showNewOrderDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Order'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Select Order Type',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Recent Orders Section
                  if (recentOrders.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Orders',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recentOrders.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final order = recentOrders[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        order['type'] == 'Dine-In' ? Icons.table_restaurant : Icons.takeout_dining,
                                        color: order['type'] == 'Dine-In' ? Colors.blue : Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Order #${order['number']}'),
                                      const SizedBox(width: 8),
                                      Text(order['amount']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  // First row - Dine-in and Takeout
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildAnimatedOrderTypeCard(
                          context,
                          'Dine-In Order',
                          Icons.table_restaurant,
                          Colors.blue,
                          'Create order for customers dining in',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DineInSetupScreen(user: user),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: _buildAnimatedOrderTypeCard(
                          context,
                          'Takeout Order',
                          Icons.takeout_dining,
                          Colors.green,
                          'Create order for customers taking food to go',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TakeoutSetupScreen(user: user),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Second row - Active Orders and Closed Orders
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: Stack(
                          children: [
                            _buildAnimatedOrderTypeCard(
                              context,
                              'Active Orders',
                              Icons.pending_actions,
                              Colors.orange,
                              'View and manage your current orders',
                              () => _showServerOrders(context),
                            ),
                            if (activeOrders.isNotEmpty)
                              Positioned(
                                top: 12,
                                right: 24,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    '${activeOrders.length}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: Stack(
                          children: [
                            _buildAnimatedOrderTypeCard(
                              context,
                              'Closed Orders',
                              Icons.check_circle,
                              Colors.purple,
                              'View completed and cancelled orders',
                              () => _showServerOrders(context),
                            ),
                            if (completedOrders.isNotEmpty)
                              Positioned(
                                top: 12,
                                right: 24,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.grey.shade700,
                                  child: Text(
                                    '${completedOrders.length}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showServerOrders(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.list_alt),
            const SizedBox(width: 8),
            Text('${user.name}\'s Orders'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: _buildServerOrdersList(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerOrdersList(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        try {
          final activeOrders = orderService.activeOrders ?? [];
          final completedOrders = orderService.completedOrders ?? [];
          final totalSales = completedOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
        
        return Column(
          children: [
            // Summary section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOrderStat('Active Orders', '${activeOrders.length}', Colors.blue),
                  _buildOrderStat('Closed Today', '${completedOrders.length}', Colors.green),
                  _buildOrderStat('Total Sales', '\$${totalSales.toStringAsFixed(2)}', Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Orders tabs
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TabBar(
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.black,
                        indicator: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        tabs: [
                          Tab(
                            icon: Icon(Icons.pending_actions),
                            text: 'Active Orders',
                          ),
                          Tab(
                            icon: Icon(Icons.check_circle),
                            text: 'Closed Orders',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildActiveOrdersTab(context),
                          _buildClosedOrdersTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        } catch (e) {
          debugPrint('Error in _buildServerOrdersList Consumer: $e');
          return const Center(
            child: Text('Loading orders...'),
          );
        }
      },
    );
  }

  Widget _buildActiveOrdersTab(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        try {
          final activeOrders = orderService.activeOrders ?? [];
        
        if (activeOrders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No active orders',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Create a new order to get started',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            final order = activeOrders[index];
            final isDineIn = order.type == OrderType.dineIn;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDineIn ? Colors.blue : Colors.green,
                  child: Icon(
                    isDineIn ? Icons.table_restaurant : Icons.takeout_dining,
                    color: Colors.white,
                  ),
                ),
                title: Text('Order #${order.orderNumber}'),
                subtitle: Text(
                  isDineIn 
                    ? 'Table ${order.tableId ?? 'N/A'} • Dine-in • ${order.items.length} items'
                    : 'Takeout • ${order.items.length} items • ${order.status.toString().split('.').last}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.status.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditActiveOrderScreen(
                              user: user,
                              order: order,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Edit Order',
                    ),
                  ],
                ),
                onTap: () {
                  // Also allow tapping the entire tile to edit
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditActiveOrderScreen(
                        user: user,
                        order: order,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
        } catch (e) {
          debugPrint('Error in _buildActiveOrdersTab Consumer: $e');
          return const Center(
            child: Text('Loading active orders...'),
          );
        }
      },
    );
  }

  Widget _buildClosedOrdersTab(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        try {
          final completedOrders = orderService.completedOrders ?? [];
        
        if (completedOrders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed orders',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                Text(
                  'Completed orders will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: completedOrders.length,
          itemBuilder: (context, index) {
            final order = completedOrders[index];
            final isDineIn = order.type == OrderType.dineIn;
            final isCompleted = order.status == OrderStatus.completed;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDineIn ? Colors.blue : Colors.green,
                  child: Icon(
                    isDineIn ? Icons.table_restaurant : Icons.takeout_dining,
                    color: Colors.white,
                  ),
                ),
                title: Text('Order #${order.orderNumber}'),
                subtitle: Text(
                  isDineIn 
                    ? 'Table ${order.tableId ?? 'N/A'} • Dine-in • ${order.items.length} items'
                    : 'Takeout • ${order.items.length} items',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green.shade100 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'Cancelled',
                        style: TextStyle(
                          color: isCompleted ? Colors.green.shade800 : Colors.grey.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  // Show read-only snackbar for closed/cancelled orders
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order #${order.orderNumber} is ${isCompleted ? 'completed' : 'cancelled'} and cannot be edited.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            );
          },
        );
        } catch (e) {
          debugPrint('Error in _buildClosedOrdersTab Consumer: $e');
          return const Center(
            child: Text('Loading completed orders...'),
          );
        }
      },
    );
  }

  Widget _buildOrderStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAnimatedOrderTypeCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String description,
    VoidCallback onTap,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 56,
                  color: color,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNewOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a New Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.table_restaurant),
              label: const Text('Dine-In Order'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DineInSetupScreen(user: user),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.takeout_dining),
              label: const Text('Takeout Order'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TakeoutSetupScreen(user: user),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
} 