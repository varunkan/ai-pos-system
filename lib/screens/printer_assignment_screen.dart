import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/printer_assignment.dart';
import '../models/printer_configuration.dart';
import '../models/menu_item.dart';
import '../models/category.dart';
import '../services/printer_assignment_service.dart';
import '../services/printer_configuration_service.dart';
import '../services/menu_service.dart';
import '../widgets/back_button.dart';
import 'printer_configuration_screen.dart';

class PrinterAssignmentScreen extends StatefulWidget {
  final bool openIPConfigOnStart;
  
  const PrinterAssignmentScreen({
    super.key, 
    this.openIPConfigOnStart = false,
  });

  @override
  State<PrinterAssignmentScreen> createState() => _PrinterAssignmentScreenState();
}

class _PrinterAssignmentScreenState extends State<PrinterAssignmentScreen> {
  bool _isLoading = false;
  bool _showItems = false; // Toggle between categories and items
  List<PrinterConfiguration> _availablePrinters = [];
  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  Map<String, List<String>> _assignments = {}; // printerId -> [targetIds]

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Auto-open IP configuration if requested
    if (widget.openIPConfigOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIPConfigurationDialog();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final printerConfigService = Provider.of<PrinterConfigurationService>(context, listen: false);
      
      // Load printer configurations from database
      await printerConfigService.refreshConfigurations();
      _availablePrinters = printerConfigService.activeConfigurations;
      
      // Load categories and menu items
      _categories = await menuService.getCategories();
      _menuItems = await menuService.getMenuItems();
      
      // Load existing assignments
      _loadExistingAssignments();
      
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadExistingAssignments() {
    final assignmentService = Provider.of<PrinterAssignmentService>(context, listen: false);
    _assignments.clear();
    
    for (final assignment in assignmentService.assignments) {
      if (!_assignments.containsKey(assignment.printerId)) {
        _assignments[assignment.printerId] = [];
      }
      _assignments[assignment.printerId]!.add(assignment.targetId);
    }
  }

  Future<void> _assignToPrinter(String printerConfigId, String targetId, String targetName, AssignmentType type) async {
    final assignmentService = Provider.of<PrinterAssignmentService>(context, listen: false);
    final printer = _availablePrinters.firstWhere((p) => p.id == printerConfigId);
    
    try {
      // Check if this assignment already exists
      final existingAssignment = assignmentService.assignments
          .where((a) => a.printerId == printerConfigId && a.targetId == targetId)
          .firstOrNull;
      
      if (existingAssignment != null) {
        // Assignment already exists, show info message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$targetName is already assigned to ${printer.name}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Add assignment using printer configuration
      final success = await assignmentService.addAssignmentWithConfig(
        printerConfigId,
        type,
        targetId,
        targetName,
      );
      
      if (success) {
        // Update local state
        if (!_assignments.containsKey(printerConfigId)) {
          _assignments[printerConfigId] = [];
        }
        _assignments[printerConfigId]!.add(targetId);
        
        setState(() {});
        
        // Show success feedback with multiple assignment info
        final totalAssignments = _assignments.values
            .where((list) => list.contains(targetId))
            .length;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$targetName assigned to ${printer.name} (${totalAssignments} printers total)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to add assignment');
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeFromAllPrinters(String targetId) async {
    final assignmentService = Provider.of<PrinterAssignmentService>(context, listen: false);
    
    // Find and remove all assignments for this target
    final assignmentsToRemove = assignmentService.assignments
        .where((a) => a.targetId == targetId)
        .toList();
    
    for (final assignment in assignmentsToRemove) {
      await assignmentService.deleteAssignment(assignment.id);
    }
    
    // Update local state
    for (final printerId in _assignments.keys) {
      _assignments[printerId]!.remove(targetId);
    }
    
    setState(() {});
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed from all printers (${assignmentsToRemove.length} assignments removed)'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeFromSpecificPrinter(String printerId, String targetId) async {
    final assignmentService = Provider.of<PrinterAssignmentService>(context, listen: false);
    final printer = _availablePrinters.firstWhere((p) => p.id == printerId);
    
    // Find and remove specific assignment
    final assignmentToRemove = assignmentService.assignments
        .where((a) => a.printerId == printerId && a.targetId == targetId)
        .firstOrNull;
    
    if (assignmentToRemove != null) {
      await assignmentService.deleteAssignment(assignmentToRemove.id);
      
      // Update local state
      _assignments[printerId]?.remove(targetId);
      
      setState(() {});
      
      // Show feedback
      final targetName = _getTargetName(targetId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $targetName from ${printer.name}'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Assignments'),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        elevation: 0,
        leading: const CustomBackButton(),
        actions: [
          // Toggle between categories and items
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Categories'),
                  icon: Icon(Icons.category),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Items'),
                  icon: Icon(Icons.restaurant_menu),
                ),
              ],
              selected: {_showItems},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _showItems = selection.first;
                });
              },
            ),
          ),
          // Note: Individual printer configuration is now handled by clicking on printer tiles
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Informational Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Multi-Printer Assignment',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Categories and items can be assigned to multiple printers. Drag the same item to different printers to route orders to multiple kitchen stations.',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main drag-drop interface
                Expanded(child: _buildDragDropInterface()),
              ],
            ),
    );
  }

  Widget _buildDragDropInterface() {
    return Row(
      children: [
        // Left side - Printers
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.print, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Kitchen Printers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availablePrinters.length,
                    itemBuilder: (context, index) {
                      return _buildPrinterDropZone(_availablePrinters[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Right side - Categories/Items to drag
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _showItems ? Icons.restaurant_menu : Icons.category,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showItems ? 'Menu Items' : 'Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Drag to assign →',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _showItems ? _buildMenuItemsList() : _buildCategoriesList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterDropZone(PrinterConfiguration printer) {
    final assignedItems = _assignments[printer.id] ?? [];
    final isConnected = printer.connectionStatus == PrinterConnectionStatus.connected;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (details) {
          final data = details.data;
          _assignToPrinter(
            printer.id,
            data['id'],
            data['name'],
            data['type'] == 'category' ? AssignmentType.category : AssignmentType.menuItem,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHovering 
                  ? Colors.green.shade100 
                  : isConnected 
                      ? Colors.white 
                      : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHovering 
                    ? Colors.green.shade400 
                    : isConnected 
                        ? Colors.blue.shade300 
                        : Colors.grey.shade300,
                width: isHovering ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openPrinterConfiguration(printer),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _getPrinterStationColor(printer.name),
                        child: Text(
                          _getPrinterStationIcon(printer.name),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    printer.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.settings,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                            Text(
                              '${_getPrinterStationDescription(printer.name)} • ${printer.model.displayName}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Tap to configure • ${printer.fullAddress}',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected 
                              ? Colors.green.shade100 
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isConnected ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isConnected 
                                ? Colors.green.shade700 
                                : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (assignedItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Assigned:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: assignedItems.map((targetId) {
                      final name = _getTargetName(targetId);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeFromSpecificPrinter(printer.id, targetId),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                if (isHovering) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Drop to assign',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoriesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildDraggableItem(
          id: category.id,
          name: category.name,
          type: 'category',
          icon: Icons.category,
          subtitle: 'Category',
        );
      },
    );
  }

  Widget _buildMenuItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return _buildDraggableItem(
          id: item.id,
          name: item.name,
          type: 'item',
          icon: Icons.restaurant_menu,
          subtitle: '\$${item.price.toStringAsFixed(2)}',
        );
      },
    );
  }

  Widget _buildDraggableItem({
    required String id,
    required String name,
    required String type,
    required IconData icon,
    required String subtitle,
  }) {
    final isAssigned = _isAssigned(id);
    final assignedPrinter = _getAssignedPrinter(id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Draggable<Map<String, dynamic>>(
        data: {
          'id': id,
          'name': name,
          'type': type,
        },
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade300, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: _buildItemCard(id, name, icon, subtitle, isAssigned, assignedPrinter),
        ),
        child: _buildItemCard(id, name, icon, subtitle, isAssigned, assignedPrinter),
      ),
    );
  }

  Widget _buildItemCard(String id, String name, IconData icon, String subtitle, bool isAssigned, String? assignedPrinter) {
    final assignedPrinters = _getAssignedPrinters(id);
    final assignmentCount = assignedPrinters.length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAssigned ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAssigned ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isAssigned ? Colors.green.shade100 : Colors.grey.shade100,
            child: Icon(
              icon,
              size: 16,
              color: isAssigned ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (isAssigned) ...[
                  const SizedBox(height: 4),
                  if (assignmentCount == 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Assigned to ${assignedPrinters.first}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Assigned to $assignmentCount printers',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeFromAllPrinters(id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.clear_all,
                                  size: 10,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Clear All',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
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
              ],
            ),
          ),
          if (isAssigned)
            Stack(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                if (assignmentCount > 1)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        assignmentCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            )
          else
            Icon(
              Icons.drag_handle,
              color: Colors.grey.shade400,
              size: 20,
            ),
        ],
      ),
    );
  }

  String _getTargetName(String targetId) {
    // Try categories first
    final category = _categories.where((c) => c.id == targetId).firstOrNull;
    if (category != null) return category.name;
    
    // Try menu items
    final item = _menuItems.where((i) => i.id == targetId).firstOrNull;
    if (item != null) return item.name;
    
    return 'Unknown';
  }

  bool _isAssigned(String targetId) {
    return _assignments.values.any((list) => list.contains(targetId));
  }

  String? _getAssignedPrinter(String targetId) {
    for (final entry in _assignments.entries) {
      if (entry.value.contains(targetId)) {
        final printer = _availablePrinters.where((p) => p.id == entry.key).firstOrNull;
        return printer?.name;
      }
    }
    return null;
  }

  List<String> _getAssignedPrinters(String targetId) {
    List<String> assignedPrinters = [];
    for (final entry in _assignments.entries) {
      if (entry.value.contains(targetId)) {
        final printer = _availablePrinters.where((p) => p.id == entry.key).firstOrNull;
        if (printer != null) {
          assignedPrinters.add(printer.name);
        }
      }
    }
    return assignedPrinters;
  }

  void _showIPConfigurationDialog() {
    // This method is now deprecated - individual printer configuration is used instead
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Click on individual printer tiles to configure them'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _openPrinterConfiguration(PrinterConfiguration printer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrinterConfigurationScreen(
          printerConfiguration: printer,
          onConfigurationUpdated: (updatedConfig) {
            setState(() {
              final index = _availablePrinters.indexWhere((p) => p.id == updatedConfig.id);
              if (index != -1) {
                _availablePrinters[index] = updatedConfig;
              }
            });
            
            // Refresh the data from database
            _loadData();
          },
        ),
      ),
    );
  }

  // Helper methods for printer station colors and descriptions
  Color _getPrinterStationColor(String printerName) {
    switch (printerName) {
      case 'Main Kitchen Printer':
        return Colors.blue.shade100;
      case 'Tandoor Station':
        return Colors.orange.shade100;
      case 'Curry Station':
        return Colors.amber.shade100;
      case 'Appetizer Station':
        return Colors.green.shade100;
      case 'Grill Station':
        return Colors.red.shade100;
      case 'Bar/Beverage Station':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getPrinterStationIcon(String printerName) {
    switch (printerName) {
      case 'Main Kitchen Printer':
        return '🏠';
      case 'Tandoor Station':
        return '🔥';
      case 'Curry Station':
        return '🍛';
      case 'Appetizer Station':
        return '🥗';
      case 'Grill Station':
        return '🍖';
      case 'Bar/Beverage Station':
        return '🍹';
      default:
        return '🖨️';
    }
  }

  String _getPrinterStationDescription(String printerName) {
    switch (printerName) {
      case 'Main Kitchen Printer':
        return 'Central coordination & receipts';
      case 'Tandoor Station':
        return 'Naan, kebabs, tandoori items';
      case 'Curry Station':
        return 'Curries, dal, gravies';
      case 'Appetizer Station':
        return 'Starters, salads, cold items';
      case 'Grill Station':
        return 'Grilled items, BBQ';
      case 'Bar/Beverage Station':
        return 'Drinks, beverages';
      default:
        return 'Kitchen printer';
    }
  }
} 