import 'package:flutter/material.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/services/user_service.dart';
import '../widgets/back_button.dart';
import '../widgets/universal_navigation.dart';
import 'dine_in_setup_screen.dart';
import 'takeout_setup_screen.dart';
import 'edit_active_order_screen.dart';
import 'server_selection_screen.dart';
import '../services/order_service.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class OrderTypeSelectionScreen extends StatefulWidget {
  final User user;

  const OrderTypeSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  State<OrderTypeSelectionScreen> createState() => _OrderTypeSelectionScreenState();
}

class _OrderTypeSelectionScreenState extends State<OrderTypeSelectionScreen> {
  List<User> _allServers = [];
  bool _loadingServers = true;

  @override
  void initState() {
    super.initState();
    _loadAllServers();
  }

  Future<void> _loadAllServers() async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final allUsers = await userService.getUsers();
      final activeServers = allUsers.where((user) => 
        user.role == UserRole.server && user.isActive
      ).toList();
      
      setState(() {
        _allServers = activeServers;
        _loadingServers = false;
      });
    } catch (e) {
      debugPrint('Error loading servers: $e');
      setState(() {
        _loadingServers = false;
      });
    }
  }

  void _navigateToServerSelection() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ServerSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        // Get real data from OrderService with safety checks
        List<dynamic> activeOrders = [];
        List<dynamic> completedOrders = [];
        double todaysSales = 0.0;
        
        try {
          // Use safe access to OrderService data with null safety
          activeOrders = orderService.activeOrders;
          completedOrders = orderService.completedOrders;
          
          // Calculate today's sales safely
          final now = DateTime.now();
          final todaysCompletedOrders = completedOrders.where((order) {
            try {
              final orderDate = order.createdAt;
              return orderDate.year == now.year &&
                     orderDate.month == now.month &&
                     orderDate.day == now.day;
            } catch (e) {
              debugPrint('Error processing order date: $e');
              return false;
            }
          }).toList();
          
          todaysSales = todaysCompletedOrders.fold(0.0, (sum, order) {
            try {
              return sum + order.totalAmount;
            } catch (e) {
              debugPrint('Error calculating order total: $e');
              return sum;
            }
          });
        } catch (e) {
          debugPrint('Error in OrderTypeSelectionScreen Consumer: $e');
          // Provide fallback empty data
          activeOrders = [];
          completedOrders = [];
          todaysSales = 0.0;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('POS Dashboard'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateToServerSelection,
              tooltip: 'Back to Server Selection',
            ),
            actions: [
              // Add quick actions if needed
              const SizedBox(width: 16),
            ],
          ),
          body: _buildCleanLayout(context, activeOrders, completedOrders, todaysSales),
        );
      },
    );
  }

  Widget _buildCleanLayout(BuildContext context, List<dynamic> activeOrders, 
      List<dynamic> completedOrders, double todaysSales) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Working Servers Section (First 2 rows)
          _buildWorkingServersSection(context),
          const SizedBox(height: 12),
          
          // Welcome Message with Current Server Name
          _buildWelcomeSection(context),
          const SizedBox(height: 16),
          
          // Compact Order Type Tiles
          _buildCompactOrderTypeTiles(context),
          const SizedBox(height: 16),
          
          // Active Orders Section (Main Focus)
          Container(
            height: 400, // Fixed height to prevent overflow
            child: _buildActiveOrdersMainSection(context, activeOrders),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingServersSection(BuildContext context) {
    if (_loadingServers) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    if (_allServers.isEmpty) {
      return Container(
        height: 140,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 32,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'No Active Servers',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All servers are currently offline',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modern Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.groups,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Working Servers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        '${_allServers.length} ${_allServers.length == 1 ? 'server' : 'servers'} currently active',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ONLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
                     // Responsive Server Cards
           Container(
             padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
             child: _buildResponsiveServerGrid(screenWidth),
           ),
        ],
      ),
    );
  }

  Widget _buildResponsiveServerGrid(double screenWidth) {
    // Dynamic calculation based on server count and screen width
    final serverCount = _allServers.length;
    if (serverCount == 0) return const SizedBox();
    
    // Calculate optimal grid dimensions based on server count
    int columnsCount;
    int rowsCount;
    double cardHeight;
    double cardSpacing;
    
    // Determine optimal layout based on server count first, then screen size
    if (serverCount == 1) {
      columnsCount = 1;
      rowsCount = 1;
    } else if (serverCount == 2) {
      columnsCount = 2;
      rowsCount = 1;
    } else if (serverCount == 3) {
      columnsCount = 3;
      rowsCount = 1;
    } else if (serverCount == 4) {
      columnsCount = 2;
      rowsCount = 2;
    } else if (serverCount <= 6) {
      columnsCount = 3;
      rowsCount = 2;
    } else if (serverCount <= 8) {
      columnsCount = 4;
      rowsCount = 2;
    } else if (serverCount <= 9) {
      columnsCount = 3;
      rowsCount = 3;
    } else if (serverCount <= 12) {
      columnsCount = 4;
      rowsCount = 3;
    } else if (serverCount <= 15) {
      columnsCount = 5;
      rowsCount = 3;
    } else {
      // For many servers, limit to 6 columns max
      columnsCount = 6;
      rowsCount = (serverCount / 6).ceil();
    }
    
    // Adjust based on screen width constraints
    final availableWidth = screenWidth - 40; // Account for padding
    final minCardWidth = 120.0;
    final maxPossibleColumns = (availableWidth / minCardWidth).floor();
    
    // Ensure we don't exceed screen width limitations
    if (columnsCount > maxPossibleColumns) {
      columnsCount = math.max(1, maxPossibleColumns);
      rowsCount = (serverCount / columnsCount).ceil();
    }
    
    // Calculate card dimensions based on final layout
    final totalSpacing = (columnsCount - 1) * 8.0; // 8px spacing between cards
    final cardWidth = (availableWidth - totalSpacing) / columnsCount;
    
    // Adaptive card height and spacing based on screen size and card width
    if (screenWidth > 1400) {
      cardHeight = 72;
      cardSpacing = 12;
    } else if (screenWidth > 1200) {
      cardHeight = 76;
      cardSpacing = 10;
    } else if (screenWidth > 900) {
      cardHeight = 80;
      cardSpacing = 10;
    } else if (screenWidth > 700) {
      cardHeight = 84;
      cardSpacing = 8;
    } else if (screenWidth > 500) {
      cardHeight = 88;
      cardSpacing = 8;
    } else {
      cardHeight = 92;
      cardSpacing = 6;
    }
    
    // Ensure minimum card height for very wide layouts
    if (cardWidth > 250) {
      cardHeight = math.max(cardHeight, 76);
    } else if (cardWidth < 140) {
      cardHeight = math.max(cardHeight, 88);
    }
    
    return Column(
      children: [
        // Dynamic grid using Wrap for natural flow
        Consumer<UserService>(
          builder: (context, userService, child) {
            final currentUser = userService.currentUser ?? widget.user;
            
            return Wrap(
              spacing: cardSpacing,
              runSpacing: cardSpacing,
              alignment: WrapAlignment.start,
              children: _allServers.map((server) {
                final isCurrentServer = server.id == currentUser.id;
                
                return SizedBox(
                  width: cardWidth,
                  height: cardHeight,
                  child: _buildModernServerCard(server, isCurrentServer, cardWidth),
                );
              }).toList(),
            );
          },
        ),
        
        // Show server count info for transparency
        if (serverCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              'Showing all $serverCount ${serverCount == 1 ? 'server' : 'servers'} • ${columnsCount}×${rowsCount} grid',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModernServerCard(User server, bool isCurrentServer, double cardWidth) {
    final isDark = isCurrentServer;
    
    return GestureDetector(
      onTap: () => _selectServer(server),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.blue.shade700 : Colors.grey.shade200,
            width: isDark ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isDark ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Modern Avatar
              Container(
                width: cardWidth > 200 ? 40 : 32,
                height: cardWidth > 200 ? 40 : 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)]
                        : [Colors.blue.shade500, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    server.name.isNotEmpty ? server.name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      color: isDark ? Colors.blue.shade700 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: cardWidth > 200 ? 16 : 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Server Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Name with adaptive font size
                    Text(
                      server.name,
                      style: TextStyle(
                        fontSize: cardWidth > 250 ? 14 : cardWidth > 180 ? 13 : 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    
                    // Status row
                    Row(
                      children: [
                        if (isDark) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: cardWidth > 200 ? 10 : 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: cardWidth > 200 ? 10 : 9,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Status indicator
              if (!isDark)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectServer(User server) async {
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      
      // Set the selected server as the current user
      userService.setCurrentUser(server);
      
      // Update the last login time for the selected server
      final updatedServer = User(
        id: server.id,
        name: server.name,
        role: server.role,
        pin: server.pin,
        isActive: server.isActive,
        createdAt: server.createdAt,
        lastLogin: DateTime.now(),
      );
      
      // Update the server in the list
      await userService.updateUser(updatedServer);
      
      // Navigate to a new instance of this screen with the selected user
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTypeSelectionScreen(user: server),
        ),
      );
      
      // Show confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged in as ${server.name}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error selecting server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error switching to ${server.name}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Consumer<UserService>(
      builder: (context, userService, child) {
        // Get the current user, fallback to widget user if none set
        final currentUser = userService.currentUser ?? widget.user;
        
        final now = DateTime.now();
        final hour = now.hour;
        String greeting;
        
        if (hour < 12) {
          greeting = 'Good Morning!';
        } else if (hour < 17) {
          greeting = 'Good Afternoon!';
        } else {
          greeting = 'Good Evening!';
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting ${currentUser.name}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome to your POS System',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Logged in as: ${currentUser.name}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactOrderTypeTiles(BuildContext context) {
    return Container(
      height: 80,
      child: Row(
        children: [
          Expanded(
            child: _buildCompactOrderTypeTile(
              context,
              'Dine-In',
              Icons.restaurant,
              Colors.blue,
              () => _navigateToDineIn(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildCompactOrderTypeTile(
              context,
              'Takeout',
              Icons.takeout_dining,
              Colors.green,
              () => _navigateToTakeout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactOrderTypeTile(BuildContext context, String title, 
      IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Start new order',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrdersMainSection(BuildContext context, List<dynamic> activeOrders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'All Active Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${activeOrders.length} Total',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content - All Orders in Small Tiles
          Expanded(
            child: activeOrders.isEmpty 
              ? _buildEmptyActiveOrders()
              : _buildAllActiveOrdersGrid(context, activeOrders),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new order using the tiles above',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCategoryHeader(BuildContext context, String title, 
      int count, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _showCategoryOrdersDialog(context, title, 
              title.contains('Dine-In') ? OrderType.dineIn : OrderType.takeaway),
          icon: Icon(Icons.visibility, size: 16, color: color),
          label: Text(
            'View All',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAllActiveOrdersGrid(BuildContext context, List<dynamic> activeOrders) {
    // Calculate optimal grid layout based on screen size and number of orders
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Dynamic tile sizing based on screen dimensions
    int crossAxisCount;
    double childAspectRatio;
    double tileSpacing;
    double tilePadding;
    
    if (screenWidth > 1600) {
      // Extra large screens: Bigger tiles, fewer columns for readability
      crossAxisCount = 5;
      childAspectRatio = 1.6;
      tileSpacing = 16;
      tilePadding = 12;
    } else if (screenWidth > 1200) {
      // Large screens: Medium-large tiles
      crossAxisCount = 6;
      childAspectRatio = 1.4;
      tileSpacing = 12;
      tilePadding = 10;
    } else if (screenWidth > 900) {
      // Medium screens: Medium tiles
      crossAxisCount = 7;
      childAspectRatio = 1.3;
      tileSpacing = 10;
      tilePadding = 8;
    } else if (screenWidth > 600) {
      // Small screens: Smaller tiles
      crossAxisCount = 5;
      childAspectRatio = 1.2;
      tileSpacing = 8;
      tilePadding = 6;
    } else {
      // Very small screens: Compact tiles
      crossAxisCount = 4;
      childAspectRatio = 1.1;
      tileSpacing = 6;
      tilePadding = 4;
    }
    
    // Group orders by type for color coding
    final dineInOrders = activeOrders.where((order) => order.type == OrderType.dineIn).toList();
    final takeoutOrders = activeOrders.where((order) => order.type == OrderType.takeaway).toList();
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(tilePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats row
          if (dineInOrders.isNotEmpty || takeoutOrders.isNotEmpty) ...[
            Row(
              children: [
                if (dineInOrders.isNotEmpty) 
                  _buildQuickStat('Dine-In', dineInOrders.length, Colors.blue),
                if (dineInOrders.isNotEmpty && takeoutOrders.isNotEmpty) 
                  SizedBox(width: tileSpacing),
                if (takeoutOrders.isNotEmpty)
                  _buildQuickStat('Takeout', takeoutOrders.length, Colors.green),
              ],
            ),
            SizedBox(height: tileSpacing),
          ],
          
          // All orders grid - dynamically sized tiles
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: tileSpacing,
              mainAxisSpacing: tileSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: activeOrders.length, // Show ALL orders
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              return _buildDynamicOrderTile(context, order, screenWidth);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label == 'Dine-In' ? Icons.restaurant : Icons.takeout_dining,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderGrid(BuildContext context, List<dynamic> orders) {
    // Show orders in a grid layout for better space utilization
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: math.min(orders.length, 6), // Show max 6 orders, rest in "View All"
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildCompactOrderTile(context, order);
      },
    );
  }

  Widget _buildDynamicOrderTile(BuildContext context, dynamic order, double screenWidth) {
    final statusColor = _getStatusColor(order);
    final statusText = _getStatusText(order);
    final typeIcon = _getOrderTypeIcon(order);
    final typeColor = _getOrderTypeColor(order);
    final itemCount = order.items?.length ?? 0;
    final timeAgo = _getTimeAgo(order.createdAt);
    
    // Dynamic sizing based on screen width
    double tilePadding;
    double borderRadius;
    double iconSize;
    double orderNumberFontSize;
    double statusFontSize;
    double itemCountFontSize;
    double priceFontSize;
    double timeFontSize;
    double spacing;
    
    if (screenWidth > 1600) {
      // Extra large screens
      tilePadding = 12;
      borderRadius = 12;
      iconSize = 16;
      orderNumberFontSize = 16;
      statusFontSize = 12;
      itemCountFontSize = 13;
      priceFontSize = 15;
      timeFontSize = 11;
      spacing = 6;
    } else if (screenWidth > 1200) {
      // Large screens
      tilePadding = 10;
      borderRadius = 10;
      iconSize = 14;
      orderNumberFontSize = 14;
      statusFontSize = 11;
      itemCountFontSize = 12;
      priceFontSize = 13;
      timeFontSize = 10;
      spacing = 5;
    } else if (screenWidth > 900) {
      // Medium screens
      tilePadding = 8;
      borderRadius = 9;
      iconSize = 12;
      orderNumberFontSize = 12;
      statusFontSize = 10;
      itemCountFontSize = 11;
      priceFontSize = 12;
      timeFontSize = 9;
      spacing = 4;
    } else if (screenWidth > 600) {
      // Small screens
      tilePadding = 6;
      borderRadius = 8;
      iconSize = 10;
      orderNumberFontSize = 11;
      statusFontSize = 8;
      itemCountFontSize = 9;
      priceFontSize = 11;
      timeFontSize = 8;
      spacing = 3;
    } else {
      // Very small screens
      tilePadding = 4;
      borderRadius = 6;
      iconSize = 8;
      orderNumberFontSize = 10;
      statusFontSize = 7;
      itemCountFontSize = 8;
      priceFontSize = 10;
      timeFontSize = 7;
      spacing = 2;
    }
    
    return GestureDetector(
      onTap: () => _editOrder(context, order),
      child: Container(
        padding: EdgeInsets.all(tilePadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: typeColor.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type icon and order number
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(spacing / 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(spacing),
                  ),
                  child: Icon(typeIcon, size: iconSize, color: typeColor),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Text(
                    order.orderNumber ?? 'N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: orderNumberFontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            
            // Status badge
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing * 1.5, 
                  vertical: spacing / 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(borderRadius / 2),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: statusFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Order details
            Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: TextStyle(
                fontSize: itemCountFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Text(
              '\$${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: priceFontSize,
                color: Colors.black87,
              ),
            ),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallOrderTile(BuildContext context, dynamic order) {
    final statusColor = _getStatusColor(order);
    final statusText = _getStatusText(order);
    final typeIcon = _getOrderTypeIcon(order);
    final typeColor = _getOrderTypeColor(order);
    final itemCount = order.items?.length ?? 0;
    final timeAgo = _getTimeAgo(order.createdAt);
    
    return GestureDetector(
      onTap: () => _editOrder(context, order),
      child: Container(
        padding: const EdgeInsets.all(6), // Increased from 4 to 6 for better text spacing
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8), // Increased from 6 to 8
          border: Border.all(color: typeColor.withOpacity(0.4), width: 1.5), // Slightly thicker border
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08), // Increased opacity for better definition
              blurRadius: 3, // Increased from 2 to 3
              offset: const Offset(0, 1), // Increased shadow
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type icon and order number
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2), // Increased from 1 to 2
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3), // Increased from 2 to 3
                  ),
                  child: Icon(typeIcon, size: 10, color: typeColor), // Increased from 8 to 10
                ),
                const SizedBox(width: 3), // Increased from 2 to 3
                Expanded(
                  child: Text(
                    order.orderNumber ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800, // Made bolder (was bold)
                      fontSize: 11, // Increased from 7 to 11
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3), // Increased from 2 to 3
            
            // Status badge
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), // Increased padding
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6), // Increased from 4 to 6
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 8, // Increased from 6 to 8
                    fontWeight: FontWeight.w700, // Made bolder
                  ),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Order details (improved readability)
            Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                fontSize: 9, // Increased from 6 to 9
                fontWeight: FontWeight.w600, // Made bolder
                color: Colors.grey,
              ),
            ),
            Text(
              '\$${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontWeight: FontWeight.w800, // Made extra bold
                fontSize: 11, // Increased from 7 to 11
                color: Colors.black87,
              ),
            ),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 8, // Increased from 5 to 8
                fontWeight: FontWeight.w500, // Made slightly bolder
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOrderTile(BuildContext context, dynamic order) {
    final statusColor = _getStatusColor(order);
    final statusText = _getStatusText(order);
    final typeIcon = _getOrderTypeIcon(order);
    final itemCount = order.items?.length ?? 0;
    final timeAgo = _getTimeAgo(order.createdAt);
    
    return GestureDetector(
      onTap: () => _editOrder(context, order),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order number and status
            Row(
              children: [
                Icon(typeIcon, size: 16, color: statusColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.orderNumber ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const Spacer(),
            
            // Order details
            Text(
              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            Text(
              '\$${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  IconData _getOrderTypeIcon(dynamic order) {
    return order.type == OrderType.dineIn ? Icons.restaurant : Icons.takeout_dining;
  }

  Color _getOrderTypeColor(dynamic order) {
    return order.type == OrderType.dineIn ? Colors.blue : Colors.green;
  }

  Color _getStatusColor(dynamic order) {
    switch (order.status.toString().split('.').last) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(dynamic order) {
    switch (order.status.toString().split('.').last) {
      case 'pending':
        return 'PENDING';
      case 'preparing':
        return 'PREPARING';
      case 'ready':
        return 'READY';
      default:
        return 'ACTIVE';
    }
  }

  String _formatOrderTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _navigateToDineIn(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DineInSetupScreen(user: widget.user),
      ),
    );
  }

  void _navigateToTakeout(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TakeoutSetupScreen(user: widget.user),
      ),
    );
  }

  void _editOrder(BuildContext context, dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditActiveOrderScreen(
          order: order,
          user: widget.user,
        ),
      ),
    );
  }

  void _showCategoryOrdersDialog(BuildContext context, String category, OrderType orderType) {
    final orderService = Provider.of<OrderService>(context, listen: false);
    final filteredOrders = orderService.activeOrders.where((order) => order.type == orderType).toList();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '$category (${filteredOrders.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredOrders.isEmpty 
                    ? Center(
                        child: Text(
                          'No $category orders',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = filteredOrders[index];
                          return _buildDetailedOrderTile(context, order);
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailedOrderTile(BuildContext context, dynamic order) {
    final statusColor = _getStatusColor(order);
    final statusText = _getStatusText(order);
    final typeIcon = _getOrderTypeIcon(order);
    final itemCount = order.items?.length ?? 0;
    final timeAgo = _getTimeAgo(order.createdAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.of(context).pop();
            _editOrder(context, order);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Order type icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getOrderTypeColor(order).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    typeIcon,
                    size: 20,
                    color: _getOrderTypeColor(order),
                  ),
                ),
                const SizedBox(width: 16),
                // Order details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.orderNumber ?? 'Order',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'} • \$${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 