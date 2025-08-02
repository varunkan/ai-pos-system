import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../config/security_config.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../services/table_service.dart';

import '../services/multi_tenant_auth_service.dart';
import '../screens/dine_in_setup_screen.dart';
import '../screens/takeout_setup_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/order_creation_screen.dart';
import '../screens/restaurant_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderTypeSelectionScreen extends StatefulWidget {
  const OrderTypeSelectionScreen({super.key});

  @override
  State<OrderTypeSelectionScreen> createState() => _OrderTypeSelectionScreenState();
}

class _OrderTypeSelectionScreenState extends State<OrderTypeSelectionScreen> {
  String? _selectedServerId;
  List<Order> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 POS DASHBOARD: initState() called');
    
    // Set current user as selected server by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use Consumer pattern to safely access UserService
      _setDefaultServer();
      _loadOrders();
    });
  }

  void _setDefaultServer() {
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      if (userService != null && userService.currentUser != null) {
        setState(() {
          _selectedServerId = userService.currentUser!.id;
        });
        debugPrint('🎯 Default server set to: ${userService.currentUser!.name}');
      } else {
        debugPrint('⚠️ UserService or currentUser not available yet');
      }
    } catch (e) {
      debugPrint('❌ Error setting default server: $e');
    }
  }

  void _loadOrders() {
    try {
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService == null) {
        debugPrint('⚠️ OrderService not available yet');
        return;
      }
      
      // Use the proper activeOrders getter instead of filtering allOrders
      final activeOrders = orderService.activeOrders;
      
      if (_selectedServerId == null) {
        // "All Servers" view - don't load individual orders, only show counts
        setState(() {
          _filteredOrders = []; // Empty list - we'll show server summary instead
        });
        debugPrint('📊 ALL SERVERS VIEW: Showing server summary with order counts');
      } else {
        // Specific server selected - show only orders created by that server
        final serverOrders = activeOrders.where((order) => order.userId == _selectedServerId).toList();
        setState(() {
          _filteredOrders = serverOrders;
        });
        debugPrint('📋 Loaded ${_filteredOrders.length} ACTIVE orders for server: $_selectedServerId');
      }
      
      // Debug server order counts (reduced frequency)
      if (orderService.activeOrders.isNotEmpty) {
        debugPrint('🔍 ORDER COUNTS: ${orderService.activeOrders.length} active orders found');
        for (final order in orderService.activeOrders) {
          if (order.userId == null || order.userId!.isEmpty) {
            debugPrint('  ⚠️ Order ${order.orderNumber} has empty userId - needs assignment');
          } else {
            debugPrint('  ✅ Order ${order.orderNumber}: server=${order.userId}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
      setState(() {
        _filteredOrders = [];
      });
    }
  }

  void _selectServer(String? serverId) {
    setState(() {
      _selectedServerId = serverId;
    });
    _loadOrders();
    debugPrint('🎯 Selected server: $serverId');
  }

  void _createDineInOrder() {
    if (_selectedServerId == null) {
      _showServerSelectionError();
      return;
    }
    
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      final selectedUser = userService.users.firstWhere(
        (user) => user.id == _selectedServerId,
        orElse: () => userService.currentUser!,
      );
    
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DineInSetupScreen(user: selectedUser),
        ),
      ).then((_) {
        _loadOrders();
      });
    } catch (e) {
      debugPrint('❌ Error creating dine-in order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to create order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createTakeoutOrder() {
    if (_selectedServerId == null) {
      _showServerSelectionError();
      return;
    }
    
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      final selectedUser = userService.users.firstWhere(
        (user) => user.id == _selectedServerId,
        orElse: () => userService.currentUser!,
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakeoutSetupScreen(user: selectedUser),
        ),
      ).then((_) {
        _loadOrders();
      });
    } catch (e) {
      debugPrint('❌ Error creating takeout order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to create order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showServerSelectionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot create orders in "All Servers" view. Please select a specific server first.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showServiceNotAvailableError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Services are still loading. Please wait a moment.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _editOrder(Order order) {
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      // Find the user who created the order or use admin as fallback
      User? orderUser;
      try {
        orderUser = userService.users.firstWhere((user) => user.id == order.userId);
      } catch (e) {
        // If original user not found, use admin or first available user
        try {
          orderUser = userService.users.firstWhere(
            (user) => user.role == UserRole.admin,
          );
        } catch (e) {
          // If no admin found, use first available user
          if (userService.users.isNotEmpty) {
            orderUser = userService.users.first;
          }
        }
      }
      
      if (orderUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Unable to edit order: No valid user found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      debugPrint('🔍 DASHBOARD: Editing order ${order.orderNumber} with user ${orderUser.name} (${orderUser.id})');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCreationScreen(
            user: orderUser!,
            orderType: order.type == OrderType.dineIn ? 'dine-in' : 'takeout',
            existingOrder: order, // Pass the existing order for editing
            table: order.tableId != null ? 
              Provider.of<TableService?>(context, listen: false)?.getTableById(order.tableId!) : null,
            numberOfPeople: order.type == OrderType.dineIn ? order.items.length : null,
            orderNumber: order.orderNumber,
          ),
        ),
      ).then((_) {
        debugPrint('🔄 DASHBOARD: Returned from edit order, reloading orders...');
        _loadOrders();
      });
    } catch (e) {
      debugPrint('❌ Error editing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to edit order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openAdminPanel() async {
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      // Check for current user first
      User? adminUser = userService.currentUser;
      
      // If no current user, look for an admin user in the system
      if (adminUser == null) {
        try {
          adminUser = userService.users.firstWhere(
            (user) => user.role == UserRole.admin && user.isActive,
          );
          debugPrint('🔧 Found admin user: ${adminUser.name} (${adminUser.id})');
        } catch (e) {
          debugPrint('❌ No admin user found in system');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No admin user found. Please contact system administrator.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
      
      // At this point, adminUser should not be null, but let's add a safety check
      if (adminUser == null) {
        debugPrint('❌ Admin user is null after all checks');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Unable to find admin user. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if user has admin panel access
      if (!adminUser.canAccessAdminPanel) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Access Denied: You do not have permission to access the admin panel'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Show PIN authentication dialog for admin access
      final isPinVerified = await _showAdminPinDialog();
      if (!isPinVerified) {
        return; // User cancelled or entered wrong PIN
      }
      
      // Set admin user as current user if not already set
      if (userService.currentUser == null) {
        userService.setCurrentUser(adminUser);
        debugPrint('✅ Set admin user as current user for admin panel access');
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPanelScreen(user: adminUser!),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening admin panel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to open admin panel. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showAdminPinDialog() async {
    final TextEditingController pinController = TextEditingController();
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.deepOrange),
              const SizedBox(width: 8),
              const Text('Admin Panel Access'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please enter your admin PIN to access the admin panel:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Admin PIN',
                  hintText: 'Enter 4-digit PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  counterText: '',
                ),
                onSubmitted: (value) async {
                  if (await SecurityConfig.validateAdminCredentials(value)) {
                    Navigator.of(context).pop(true);
                  } else {
                    pinController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Invalid PIN. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text.trim();
                if (await SecurityConfig.validateAdminCredentials(pin)) {
                  Navigator.of(context).pop(true);
                } else {
                  pinController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Invalid PIN. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Access Admin Panel'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Add logout functionality
  void _logout() async {
    try {
      final authService = Provider.of<MultiTenantAuthService?>(context, listen: false);
      
      if (authService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
      
      if (shouldLogout == true) {
        // Mark that user explicitly logged out (don't restore session next time)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_explicitly_closed', true);
        
        await authService.logout();
        
        if (mounted) {
          // Navigate to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const RestaurantAuthScreen(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Consumer2<UserService?, OrderService?>(
            builder: (context, userService, orderService, _) {
              // Show loading if services aren't ready
              if (userService == null || orderService == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Loading Dashboard...',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                );
              }

              final users = userService.users;
              final currentUser = userService.currentUser;
              
              // Set default server if none selected
              if (_selectedServerId == null && currentUser != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _selectedServerId = currentUser.id;
                  });
                  _loadOrders();
                });
              }

              // Note: Consumer automatically rebuilds when OrderService changes
              // Removed excessive reload to prevent infinite rebuild loop

              return CustomScrollView(
                slivers: [
                  // Modern App Bar
                  SliverAppBar(
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.1),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              Text(
                                'POS Dashboard',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (currentUser != null)
                                Text(
                                  'Welcome, ${currentUser.name}!',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      // Quick Access Icons
                      IconButton(
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                        onPressed: _openAdminPanel,
                        tooltip: 'Admin Panel',
                      ),
                      IconButton(
                        icon: const Icon(Icons.kitchen, color: Colors.white),
                        onPressed: () {
                          final userService = Provider.of<UserService?>(context, listen: false);
                          final currentUser = userService?.currentUser;
                          if (currentUser != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KitchenScreen(user: currentUser),
                              ),
                            );
                          }
                        },
                        tooltip: 'Kitchen',
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: _logout,
                        tooltip: 'Logout',
                      ),
                    ],
                  ),

                  // Main Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                                                     // Server Selection Section
                           _buildServerSelectionCard(users, userService, orderService),
                          
                          const SizedBox(height: 16),
                          
                          // Action Cards Section
                          _buildActionCardsSection(),
                          
                          const SizedBox(height: 16),
                          
                          // Active Orders Section
                          _buildActiveOrdersSection(orderService),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

     Widget _buildServerSelectionCard(List<User> users, UserService userService, OrderService orderService) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Server:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildServerChip(
                  label: 'All Servers',
                  serverId: null,
                  isSelected: _selectedServerId == null,
                  orderCount: orderService.activeOrdersCount,
                ),
                ...users.where((user) => 
                  user.role == UserRole.server || 
                  user.role == UserRole.admin || 
                  user.role == UserRole.manager
                ).map((server) {
                  final serverOrderCount = orderService.getActiveOrdersCountByServer(server.id);
                  return _buildServerChip(
                    label: server.name,
                    serverId: server.id,
                    isSelected: _selectedServerId == server.id,
                    orderCount: serverOrderCount,
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerChip({
    required String label,
    required String? serverId,
    required bool isSelected,
    required int orderCount,
  }) {
    return GestureDetector(
      onTap: () => _selectServer(serverId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                orderCount.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCardsSection() {
    // Only show order creation when a specific server is selected
    // "All Servers" should be read-only monitoring view
    if (_selectedServerId == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'All Servers - Monitoring View',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
                          Text(
              'This shows order counts per server. Select a specific server to view orders and create new ones.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
              ),
            ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Create New Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: 'Dine-In',
                    subtitle: 'Table service',
                    icon: Icons.restaurant,
                    color: Colors.green,
                    onTap: _createDineInOrder,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    title: 'Take-Out',
                    subtitle: 'Quick pickup',
                    icon: Icons.takeout_dining,
                    color: Colors.orange,
                    onTap: _createTakeoutOrder,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrdersSection(OrderService orderService) {
    // If "All Servers" is selected, show server summary instead of individual orders
    if (_selectedServerId == null) {
      return _buildServerSummarySection(orderService);
    }
    
    // Show individual orders for the selected server
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'My Active Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredOrders.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_filteredOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active orders',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Create a new order to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 400, // Set a fixed height for the scrollable area
                child: SingleChildScrollView(
                  child: _buildOrderTilesGrid(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSummarySection(OrderService orderService) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.orange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'Order Summary by Server',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select a specific server to view and create orders',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<UserService?>(
              builder: (context, userService, _) {
                if (userService == null) return const SizedBox.shrink();
                
                final servers = userService.users.where((user) =>
                  user.role == UserRole.server ||
                  user.role == UserRole.admin ||
                  user.role == UserRole.manager
                ).toList();
                
                if (servers.isEmpty) {
                  return Center(
                    child: Text(
                      'No servers available',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    final orderCount = orderService.getActiveOrdersCountByServer(server.id);
                    
                    return _buildServerSummaryTile(server, orderCount);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSummaryTile(User server, int orderCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _selectServer(server.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.shade300,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: orderCount > 0 ? Colors.orange.shade600 : Colors.grey.shade400,
                child: Text(
                  server.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      server.role.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: orderCount > 0 ? Colors.orange.shade600 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$orderCount',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTilesGrid() {
    // Calculate how many rows we need for 4 tiles per row
    final tilesPerRow = 4;
    final rowCount = (_filteredOrders.length / tilesPerRow).ceil();
    
    return Column(
      children: List.generate(rowCount, (rowIndex) {
        final startIndex = rowIndex * tilesPerRow;
        final endIndex = (startIndex + tilesPerRow).clamp(0, _filteredOrders.length);
        final rowOrders = _filteredOrders.sublist(startIndex, endIndex);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              ...rowOrders.map((order) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildSquareOrderTile(order),
                ),
              )).toList(),
              // Fill remaining spaces in incomplete rows
              ...List.generate(
                tilesPerRow - rowOrders.length,
                (index) => const Expanded(child: SizedBox()),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderTile(Order order) {
    final statusColor = _getStatusColor(order.status);
    
    return GestureDetector(
      onTap: () => _editOrder(order),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '\$${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              order.status.toString().split('.').last.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // Show table number for dine-in orders
                            if (order.type == OrderType.dineIn && order.tableId != null && order.tableId!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Consumer<TableService>(
                                builder: (context, tableService, child) {
                                  final table = tableService.getTableById(order.tableId!);
                                  
                                  // Improved table number extraction and fallback
                                  String tableDisplay;
                                  if (table != null) {
                                    tableDisplay = table.number.toString();
                                  } else {
                                    // Try to extract table number from ID pattern
                                    final match = RegExp(r'table_(\d+)').firstMatch(order.tableId!);
                                    if (match != null) {
                                      tableDisplay = match.group(1)!;
                                    } else {
                                      // Fallback: try to extract any numbers from the ID
                                      final numbers = RegExp(r'\d+').allMatches(order.tableId!);
                                      if (numbers.isNotEmpty) {
                                        tableDisplay = numbers.first.group(0)!;
                                      } else {
                                        tableDisplay = 'Unknown';
                                      }
                                    }
                                    debugPrint('⚠️ TABLE DISPLAY: Table not found for ID ${order.tableId!}, using fallback: $tableDisplay');
                                  }
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.table_restaurant,
                                          size: 12,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Table $tableDisplay',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${order.items.length} items',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSquareOrderTile(Order order) {
    final statusColor = _getStatusColor(order.status);
    
    return GestureDetector(
      onTap: () => _editOrder(order),
      child: AspectRatio(
        aspectRatio: 1.0, // Square aspect ratio
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: Order number and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '#${order.orderNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.status.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              // Middle section: Table info (if dine-in)
              if (order.type == OrderType.dineIn && order.tableId != null && order.tableId!.isNotEmpty)
                Consumer<TableService>(
                  builder: (context, tableService, child) {
                    final table = tableService.getTableById(order.tableId!);
                    
                    String tableDisplay;
                    if (table != null) {
                      tableDisplay = table.number.toString();
                    } else {
                      final match = RegExp(r'table_(\d+)').firstMatch(order.tableId!);
                      if (match != null) {
                        tableDisplay = match.group(1)!;
                      } else {
                        final numbers = RegExp(r'\d+').allMatches(order.tableId!);
                        if (numbers.isNotEmpty) {
                          tableDisplay = numbers.first.group(0)!;
                        } else {
                          tableDisplay = '?';
                        }
                      }
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.table_restaurant,
                            size: 10,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'T$tableDisplay',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                const SizedBox.shrink(),
              
              // Bottom section: Total and items count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${order.items.length} items',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
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

  Widget _buildQuickAccessSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAccessButton(
                    title: 'Admin Panel',
                    icon: Icons.admin_panel_settings,
                    color: Colors.purple,
                    onTap: _openAdminPanel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAccessButton(
                    title: 'Kitchen',
                    icon: Icons.kitchen,
                    color: Colors.red,
                                         onTap: () {
                       final userService = Provider.of<UserService?>(context, listen: false);
                       final currentUser = userService?.currentUser;
                       if (currentUser != null) {
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (context) => KitchenScreen(user: currentUser),
                           ),
                         );
                       }
                     },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}




