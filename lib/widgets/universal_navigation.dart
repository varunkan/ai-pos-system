import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/printer_assignment.dart';
import '../services/order_service.dart';
import '../services/reservation_service.dart';
import '../services/printing_service.dart';
import '../services/printer_assignment_service.dart';
import '../screens/order_type_selection_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/admin_orders_screen.dart';
import '../screens/daily_bookings_screen.dart';
import '../screens/reservations_screen.dart';
import '../screens/server_selection_screen.dart';
import '../screens/printer_selection_screen.dart';
import '../screens/printer_assignment_screen.dart';
import '../main.dart';

/// Universal navigation widget that provides consistent navigation across all screens
class UniversalNavigation extends StatelessWidget {
  final User? currentUser;
  final String currentScreenTitle;
  final VoidCallback? onBack;
  final List<Widget>? additionalActions;
  final bool showQuickActions;
  final bool isFullscreen;

  const UniversalNavigation({
    super.key,
    this.currentUser,
    required this.currentScreenTitle,
    this.onBack,
    this.additionalActions,
    this.showQuickActions = true,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFullscreen) {
      return _buildFullscreenNavigation(context);
    }

    return AppBar(
      title: Text(currentScreenTitle),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      elevation: 2,
      leading: _buildLeadingWidget(context),
      actions: [
        if (showQuickActions) ..._buildQuickActions(context),
        if (additionalActions != null) ...additionalActions!,
        const SizedBox(width: 8),
        _buildNavigationMenu(context),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget? _buildLeadingWidget(BuildContext context) {
    if (onBack != null) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
        tooltip: 'Back',
      );
    }

    // Check if we can go back
    if (Navigator.of(context).canPop()) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      );
    }

    return null;
  }

  Widget _buildFullscreenNavigation(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inversePrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (onBack != null || Navigator.of(context).canPop()) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              currentScreenTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (showQuickActions) ..._buildQuickActions(context),
          if (additionalActions != null) ...additionalActions!,
          const SizedBox(width: 8),
          _buildNavigationMenu(context),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    List<Widget> actions = [];

    // Active Orders Action
    actions.add(
      Consumer<OrderService>(
        builder: (context, orderService, child) {
          final activeOrdersCount = orderService.activeOrders.length;
          return Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: () => _navigateToActiveOrders(context),
                tooltip: 'Active Orders',
              ),
              if (activeOrdersCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$activeOrdersCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    // Reservations Action (for servers and admins)
    if (currentUser?.role == UserRole.admin || 
        currentUser?.role == UserRole.server) {
      actions.add(
        Consumer<ReservationService>(
          builder: (context, reservationService, child) {
            final todaysReservations = reservationService.reservations
                .where((r) => r.reservationDate.day == DateTime.now().day &&
                             r.reservationDate.month == DateTime.now().month &&
                             r.reservationDate.year == DateTime.now().year)
                .toList();
            final pendingCount = todaysReservations
                .where((r) => r.status == 'pending' || r.status == 'confirmed')
                .length;
            
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.event_seat),
                  onPressed: () => _navigateToReservations(context),
                  tooltip: 'Reservations',
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Enhanced Printer Actions with Status and Submenu
    actions.add(
      Consumer2<PrintingService, PrinterAssignmentService>(
        builder: (context, printingService, assignmentService, child) {
          final isConnected = printingService.isConnected;
          final assignmentCount = assignmentService.assignments.length;
          
          return Stack(
            children: [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.print,
                  color: isConnected ? Colors.green : null,
                ),
                tooltip: isConnected 
                    ? 'Printer Connected (${assignmentCount} assignments)' 
                    : 'Printer Settings',
                onSelected: (value) => _handlePrinterAction(context, value),
                itemBuilder: (context) => [
                  // Connection Status Header
                  PopupMenuItem(
                    enabled: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            isConnected ? Icons.check_circle : Icons.error_outline,
                            color: isConnected ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isConnected ? 'Printer Connected' : 'No Printer Connected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isConnected ? Colors.green : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isConnected && printingService.connectedPrinter != null) ...[
                                  Text(
                                    printingService.connectedPrinter!.name,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                                if (assignmentCount > 0) ...[
                                  Text(
                                    '$assignmentCount active assignments',
                                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  
                  // Connection Management
                  const PopupMenuItem(
                    value: 'connection',
                    child: ListTile(
                      leading: Icon(Icons.wifi),
                      title: Text('Printer Connection'),
                      subtitle: Text('Connect to WiFi/Bluetooth printers'),
                      dense: true,
                    ),
                  ),
                  
                  // Assignment Management
                  PopupMenuItem(
                    value: 'assignments',
                    child: ListTile(
                      leading: const Icon(Icons.assignment),
                      title: const Text('Printer Assignments'),
                      subtitle: Text('$assignmentCount category & item routings'),
                      dense: true,
                    ),
                  ),
                  
                  // IP Configuration
                  const PopupMenuItem(
                    value: 'ip_config',
                    child: ListTile(
                      leading: Icon(Icons.settings_ethernet),
                      title: Text('Configure IP Addresses'),
                      subtitle: Text('Set printer network addresses'),
                      dense: true,
                    ),
                  ),
                  
                  const PopupMenuDivider(),
                  
                  // Quick Actions
                  PopupMenuItem(
                    value: 'test_print',
                    enabled: isConnected,
                    child: ListTile(
                      leading: Icon(
                        Icons.print_outlined,
                        color: isConnected ? null : Colors.grey,
                      ),
                      title: Text(
                        'Test Print',
                        style: TextStyle(
                          color: isConnected ? null : Colors.grey,
                        ),
                      ),
                      dense: true,
                    ),
                  ),
                  
                  if (assignmentCount > 0) ...[
                    const PopupMenuItem(
                      value: 'view_assignments',
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('View All Assignments'),
                        dense: true,
                      ),
                    ),
                  ],
                ],
              ),
              
              // Status Indicator Dots
              if (isConnected)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
              
              if (assignmentCount > 0 && !isConnected)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return actions;
  }

  Widget _buildNavigationMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      tooltip: 'Navigation Menu',
      onSelected: (value) => _handleMenuSelection(context, value),
      itemBuilder: (context) => [
        // Core Navigation
        const PopupMenuItem(
          value: 'home',
          child: ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'new_order',
          child: ListTile(
            leading: Icon(Icons.add_circle_outline),
            title: Text('New Order'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'active_orders',
          child: ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Active Orders'),
            dense: true,
          ),
        ),
        
        // Separator
        const PopupMenuDivider(),
        
        // Server Functions
        if (currentUser?.role == UserRole.admin || currentUser?.role == UserRole.server) ...[
          const PopupMenuItem(
            value: 'reservations',
            child: ListTile(
              leading: Icon(Icons.event_seat),
              title: Text('Reservations'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'daily_bookings',
            child: ListTile(
              leading: Icon(Icons.today),
              title: Text('Today\'s Bookings'),
              dense: true,
            ),
          ),
        ],
        
        // Kitchen Functions
        if (currentUser?.role == UserRole.admin || currentUser?.role == UserRole.manager) ...[
          const PopupMenuItem(
            value: 'kitchen',
            child: ListTile(
              leading: Icon(Icons.kitchen),
              title: Text('Kitchen'),
              dense: true,
            ),
          ),
        ],
        
        // Admin Functions
        if (currentUser?.role == UserRole.admin) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'admin_panel',
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Admin Panel'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'reports',
            child: ListTile(
              leading: Icon(Icons.analytics),
              title: Text('Reports & Analytics'),
              dense: true,
            ),
          ),
        ],
        
        // Separator
        const PopupMenuDivider(),
        
        // Enhanced Printer Settings
        const PopupMenuItem(
          value: 'printer_connection',
          child: ListTile(
            leading: Icon(Icons.wifi),
            title: Text('Printer Connection'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'printer_assignments',
          child: ListTile(
            leading: Icon(Icons.assignment),
            title: Text('Printer Assignments'),
            dense: true,
          ),
        ),
        
        // System Functions
        const PopupMenuItem(
          value: 'switch_server',
          child: ListTile(
            leading: Icon(Icons.switch_account),
            title: Text('Switch Server'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    );
  }

  void _handlePrinterAction(BuildContext context, String action) {
    switch (action) {
      case 'connection':
        _navigateToPrinterConnection(context);
        break;
      case 'assignments':
        _navigateToPrinterAssignments(context);
        break;
      case 'ip_config':
        _navigateToPrinterIPConfig(context);
        break;
      case 'view_assignments':
        _showPrinterAssignmentsSummary(context);
        break;
      case 'test_print':
        _performTestPrint(context);
        break;
    }
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'home':
        _navigateToHome(context);
        break;
      case 'new_order':
        _navigateToNewOrder(context);
        break;
      case 'active_orders':
        _navigateToActiveOrders(context);
        break;
      case 'reservations':
        _navigateToReservations(context);
        break;
      case 'daily_bookings':
        _navigateToDailyBookings(context);
        break;
      case 'kitchen':
        _navigateToKitchen(context);
        break;
      case 'admin_panel':
        _navigateToAdminPanel(context);
        break;
      case 'reports':
        _navigateToReports(context);
        break;
      case 'printer_connection':
        _navigateToPrinterConnection(context);
        break;
      case 'printer_assignments':
        _navigateToPrinterAssignments(context);
        break;
      case 'switch_server':
        _navigateToServerSelection(context);
        break;
      case 'logout':
        _performLogout(context);
        break;
    }
  }

  // Navigation methods
  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTypeSelectionScreen(user: currentUser!),
      ),
      (route) => false,
    );
  }

  void _navigateToNewOrder(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTypeSelectionScreen(user: currentUser!),
      ),
      (route) => false,
    );
  }

  void _navigateToActiveOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminOrdersScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToReservations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReservationsScreen(),
      ),
    );
  }

  void _navigateToDailyBookings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DailyBookingsScreen(),
      ),
    );
  }

  void _navigateToKitchen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KitchenScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToAdminPanel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPanelScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToServerSelection(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const ServerSelectionScreen(),
      ),
      (route) => false,
    );
  }

  // Enhanced printer navigation methods
  void _navigateToPrinterConnection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrinterSelectionScreen(user: currentUser),
      ),
    );
  }

  void _navigateToPrinterAssignments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrinterAssignmentScreen(),
      ),
    );
  }

  void _navigateToPrinterIPConfig(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrinterAssignmentScreen(openIPConfigOnStart: true),
      ),
    );
  }

  void _showPrinterAssignmentsSummary(BuildContext context) {
    final assignmentService = Provider.of<PrinterAssignmentService>(context, listen: false);
    final assignments = assignmentService.assignments;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Printer Assignments Summary'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: assignments.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No printer assignments configured'),
                    SizedBox(height: 8),
                    Text(
                      'Use the drag-and-drop interface to assign categories and menu items to printers',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    return ListTile(
                      leading: Icon(
                        assignment.assignmentType == AssignmentType.category
                            ? Icons.category
                            : Icons.restaurant_menu,
                        color: assignment.assignmentType == AssignmentType.category
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text(assignment.targetName),
                      subtitle: Text(
                        'Printer: ${assignment.printerName}\n'
                        'Priority: ${assignment.priority}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: assignment.isActive ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          assignment.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            color: assignment.isActive ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (assignments.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToPrinterAssignments(context);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Manage'),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToPrinterAssignments(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Assignments'),
            ),
          ],
        ],
      ),
    );
  }

  void _performTestPrint(BuildContext context) async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      if (!printingService.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('No printer connected'),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Connect',
              textColor: Colors.white,
              onPressed: () => _navigateToPrinterConnection(context),
            ),
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Printing test receipt...'),
            ],
          ),
        ),
      );

      await printingService.printTestReceipt();
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Test receipt printed to ${printingService.connectedPrinter?.name}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Print test failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _performTestPrint(context),
            ),
          ),
        );
      }
    }
  }

  void _performLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LandingScreen(),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Universal AppBar that delegates to UniversalNavigation
class UniversalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? additionalActions;
  final bool showQuickActions;
  final PreferredSizeWidget? bottom;

  const UniversalAppBar({
    super.key,
    this.currentUser,
    required this.title,
    this.onBack,
    this.additionalActions,
    this.showQuickActions = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final navigation = UniversalNavigation(
      currentUser: currentUser,
      currentScreenTitle: title,
      additionalActions: additionalActions,
      showQuickActions: showQuickActions,
      onBack: onBack,
    );
    
    // Return the AppBar from UniversalNavigation build method
    return AppBar(
      title: Text(title),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      elevation: 2,
      leading: onBack != null 
        ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            tooltip: 'Go Back',
          )
        : Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Go Back',
              )
            : null,
      actions: [
        // Use the same printer actions from the main navigation
        if (showQuickActions) ..._buildSimplifiedQuickActions(context),
        if (additionalActions != null) ...additionalActions!,
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          tooltip: 'Navigation Menu',
          onSelected: (value) => _handleSimpleNavigation(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'printer_connection',
              child: ListTile(
                leading: Icon(Icons.wifi),
                title: Text('Printer Connection'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'printer_assignments',
              child: ListTile(
                leading: Icon(Icons.assignment),
                title: Text('Printer Assignments'),
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
      bottom: bottom,
    );
  }

  List<Widget> _buildSimplifiedQuickActions(BuildContext context) {
    final actions = <Widget>[];

    // Active Orders Count
    actions.add(
      Consumer<OrderService>(
        builder: (context, orderService, child) {
          int activeOrdersCount = 0;
          try {
            activeOrdersCount = orderService.activeOrders.length;
          } catch (e) {
            activeOrdersCount = 0;
          }
          return Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminOrdersScreen(user: currentUser!),
                  ),
                ),
                tooltip: 'Active Orders',
              ),
              if (activeOrdersCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$activeOrdersCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    // Enhanced Printer Actions with Status
    actions.add(
      Consumer2<PrintingService, PrinterAssignmentService>(
        builder: (context, printingService, assignmentService, child) {
          final isConnected = printingService.isConnected;
          return PopupMenuButton<String>(
            icon: Icon(
              Icons.print,
              color: isConnected ? Colors.green : null,
            ),
            tooltip: 'Printer Settings',
            onSelected: (value) => _handlePrinterAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'connection',
                child: ListTile(
                  leading: Icon(Icons.wifi),
                  title: Text('Printer Connection'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'assignments',
                child: ListTile(
                  leading: Icon(Icons.assignment),
                  title: Text('Printer Assignments'),
                  dense: true,
                ),
              ),
            ],
          );
        },
      ),
    );

    return actions;
  }

  void _handleSimpleNavigation(BuildContext context, String value) {
    switch (value) {
      case 'printer_connection':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrinterSelectionScreen(user: currentUser),
          ),
        );
        break;
      case 'printer_assignments':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PrinterAssignmentScreen(),
          ),
        );
        break;
    }
  }

  void _handlePrinterAction(BuildContext context, String action) {
    switch (action) {
      case 'connection':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PrinterSelectionScreen(user: currentUser),
          ),
        );
        break;
      case 'assignments':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PrinterAssignmentScreen(),
          ),
        );
        break;
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
  );
} 