import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/printer_assignment.dart';
import '../models/printer_configuration.dart';
import '../models/menu_item.dart';
import '../models/category.dart';
import '../services/printing_service.dart';
import '../services/printer_configuration_service.dart';
import 'database_service.dart';

class PrinterAssignmentService with ChangeNotifier {
  final DatabaseService _databaseService;
  final PrinterConfigurationService _printerConfigService;
  List<PrinterAssignment> _assignments = [];
  bool _isLoading = false;

  PrinterAssignmentService(this._databaseService, this._printerConfigService) {
    _initializeDatabase();
    _loadAssignments();
  }

  // Getters
  List<PrinterAssignment> get assignments => _assignments;
  bool get isLoading => _isLoading;

  /// Initialize the printer assignments table
  Future<void> _initializeDatabase() async {
    try {
      final db = await _databaseService.database;
      
      // Create printer_assignments table with foreign key to printer_configurations
      await db.execute('''
        CREATE TABLE IF NOT EXISTS printer_assignments (
          id TEXT PRIMARY KEY,
          printer_config_id TEXT NOT NULL,
          printer_name TEXT NOT NULL,
          printer_address TEXT NOT NULL,
          assignment_type TEXT NOT NULL,
          target_id TEXT NOT NULL,
          target_name TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          priority INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (printer_config_id) REFERENCES printer_configurations (id) ON DELETE CASCADE
        )
      ''');

      debugPrint('Printer assignments table initialized successfully');
    } catch (e) {
      debugPrint('Error initializing printer assignments table: $e');
    }
  }

  /// Load all printer assignments from database
  Future<void> _loadAssignments() async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'printer_assignments',
        orderBy: 'priority DESC, target_name ASC',
      );

      _assignments = maps.map((map) => PrinterAssignment.fromJson(map)).toList();
      
      debugPrint('Loaded ${_assignments.length} printer assignments');
    } catch (e) {
      debugPrint('Error loading printer assignments: $e');
      _assignments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new printer assignment using printer configuration
  Future<bool> addAssignmentWithConfig(String printerConfigId, AssignmentType assignmentType, String targetId, String targetName) async {
    try {
      final printerConfig = _printerConfigService.getConfigurationById(printerConfigId);
      if (printerConfig == null) {
        debugPrint('Printer configuration not found: $printerConfigId');
        return false;
      }

      final assignment = PrinterAssignment(
        printerId: printerConfigId,
        printerName: printerConfig.name,
        printerAddress: printerConfig.fullAddress,
        assignmentType: assignmentType,
        targetId: targetId,
        targetName: targetName,
      );

      return await addAssignment(assignment);
    } catch (e) {
      debugPrint('Error adding assignment with config: $e');
      return false;
    }
  }

  /// Add a new printer assignment
  Future<bool> addAssignment(PrinterAssignment assignment) async {
    try {
      final db = await _databaseService.database;
      
      // Check for duplicate assignments
      final existing = await db.query(
        'printer_assignments',
        where: 'target_id = ? AND assignment_type = ? AND is_active = 1',
        whereArgs: [assignment.targetId, assignment.assignmentType.toString().split('.').last],
      );

      if (existing.isNotEmpty) {
        debugPrint('Assignment already exists for target: ${assignment.targetName}');
        return false;
      }

      // Convert assignment to use printer_config_id instead of printer_id
      final assignmentData = assignment.toJson();
      assignmentData['printer_config_id'] = assignment.printerId;
      assignmentData.remove('printer_id');

      await db.insert('printer_assignments', assignmentData);
      await _loadAssignments();
      
      debugPrint('Added printer assignment: ${assignment.targetName} -> ${assignment.printerName}');
      return true;
    } catch (e) {
      debugPrint('Error adding printer assignment: $e');
      return false;
    }
  }

  /// Update an existing printer assignment
  Future<bool> updateAssignment(PrinterAssignment assignment) async {
    try {
      final db = await _databaseService.database;
      
      final updatedAssignment = assignment.copyWith(
        updatedAt: DateTime.now(),
      );

      // Convert assignment to use printer_config_id instead of printer_id
      final assignmentData = updatedAssignment.toJson();
      assignmentData['printer_config_id'] = updatedAssignment.printerId;
      assignmentData.remove('printer_id');

      await db.update(
        'printer_assignments',
        assignmentData,
        where: 'id = ?',
        whereArgs: [assignment.id],
      );

      await _loadAssignments();
      
      debugPrint('Updated printer assignment: ${assignment.targetName}');
      return true;
    } catch (e) {
      debugPrint('Error updating printer assignment: $e');
      return false;
    }
  }

  /// Delete a printer assignment
  Future<bool> deleteAssignment(String assignmentId) async {
    try {
      final db = await _databaseService.database;
      
      await db.delete(
        'printer_assignments',
        where: 'id = ?',
        whereArgs: [assignmentId],
      );

      await _loadAssignments();
      
      debugPrint('Deleted printer assignment: $assignmentId');
      return true;
    } catch (e) {
      debugPrint('Error deleting printer assignment: $e');
      return false;
    }
  }

  /// Get printer assignment for a specific menu item with automatic connection
  PrinterAssignment? getAssignmentForMenuItem(String menuItemId, String categoryId) {
    // First check for specific menu item assignment (higher priority)
    final menuItemAssignment = _assignments
        .where((a) => a.isActive && 
                     a.assignmentType == AssignmentType.menuItem && 
                     a.targetId == menuItemId)
        .fold<PrinterAssignment?>(null, (prev, current) => 
            prev == null || current.priority > prev.priority ? current : prev);

    if (menuItemAssignment != null) {
      _ensurePrinterConnection(menuItemAssignment.printerId);
      return menuItemAssignment;
    }

    // If no specific menu item assignment, check category assignment
    final categoryAssignment = _assignments
        .where((a) => a.isActive && 
                     a.assignmentType == AssignmentType.category && 
                     a.targetId == categoryId)
        .fold<PrinterAssignment?>(null, (prev, current) => 
            prev == null || current.priority > prev.priority ? current : prev);

    if (categoryAssignment != null) {
      _ensurePrinterConnection(categoryAssignment.printerId);
    }

    return categoryAssignment;
  }

  /// Ensure printer connection is established
  Future<void> _ensurePrinterConnection(String printerConfigId) async {
    try {
      final printerConfig = _printerConfigService.getConfigurationById(printerConfigId);
      if (printerConfig == null) return;

      // Check if printer is already connected
      if (printerConfig.connectionStatus == PrinterConnectionStatus.connected) {
        return;
      }

      // Attempt to connect to the printer
      debugPrint('Attempting to connect to printer: ${printerConfig.name}');
      await _printerConfigService.testConnection(printerConfigId);
    } catch (e) {
      debugPrint('Error ensuring printer connection: $e');
    }
  }

  /// Get printer configuration for a printer assignment
  PrinterConfiguration? getPrinterConfigForAssignment(String assignmentId) {
    try {
      final assignment = _assignments.firstWhere((a) => a.id == assignmentId);
      return _printerConfigService.getConfigurationById(assignment.printerId);
    } catch (e) {
      return null;
    }
  }

  /// Get all assignments for a specific printer configuration
  List<PrinterAssignment> getAssignmentsForPrinter(String printerConfigId) {
    return _assignments
        .where((a) => a.isActive && a.printerId == printerConfigId)
        .toList();
  }

  /// Get assignments grouped by printer configuration
  Map<String, List<PrinterAssignment>> getAssignmentsGroupedByPrinter() {
    final Map<String, List<PrinterAssignment>> grouped = {};
    
    for (final assignment in _assignments.where((a) => a.isActive)) {
      if (!grouped.containsKey(assignment.printerId)) {
        grouped[assignment.printerId] = [];
      }
      grouped[assignment.printerId]!.add(assignment);
    }
    
    return grouped;
  }

  /// Get available printer configurations that are not assigned to anything
  List<PrinterConfiguration> getUnassignedPrinters() {
    final assignedPrinterIds = _assignments
        .where((a) => a.isActive)
        .map((a) => a.printerId)
        .toSet();
    
    return _printerConfigService.activeConfigurations
        .where((config) => !assignedPrinterIds.contains(config.id))
        .toList();
  }

  /// Auto-assign printers based on menu categories
  Future<bool> autoAssignPrinters() async {
    try {
      debugPrint('Starting auto-assignment of printers...');
      
      final availablePrinters = _printerConfigService.activeConfigurations;
      if (availablePrinters.isEmpty) {
        debugPrint('No active printers available for auto-assignment');
        return false;
      }

      // Get all categories (this would come from your category service)
      // For now, using common restaurant categories
      final commonCategories = [
        {'id': 'appetizers', 'name': 'Appetizers'},
        {'id': 'tandoor', 'name': 'Tandoor'},
        {'id': 'curry', 'name': 'Curry'},
        {'id': 'grill', 'name': 'Grill'},
        {'id': 'beverages', 'name': 'Beverages'},
        {'id': 'desserts', 'name': 'Desserts'},
      ];

      int assignedCount = 0;
      for (int i = 0; i < commonCategories.length && i < availablePrinters.length; i++) {
        final category = commonCategories[i];
        final printer = availablePrinters[i];

        final success = await addAssignmentWithConfig(
          printer.id,
          AssignmentType.category,
          category['id']!,
          category['name']!,
        );

        if (success) {
          assignedCount++;
        }
      }

      debugPrint('Auto-assigned $assignedCount printer assignments');
      return assignedCount > 0;
    } catch (e) {
      debugPrint('Error during auto-assignment: $e');
      return false;
    }
  }

  /// Print to assigned printer for a menu item
  Future<bool> printToAssignedPrinter(String menuItemId, String categoryId, String content) async {
    try {
      final assignment = getAssignmentForMenuItem(menuItemId, categoryId);
      if (assignment == null) {
        debugPrint('No printer assignment found for menu item: $menuItemId');
        return false;
      }

      final printerConfig = _printerConfigService.getConfigurationById(assignment.printerId);
      if (printerConfig == null) {
        debugPrint('Printer configuration not found: ${assignment.printerId}');
        return false;
      }

      // Ensure connection before printing
      await _ensurePrinterConnection(assignment.printerId);

      // Here you would implement the actual printing logic
      // For now, just simulate printing
      debugPrint('Printing to ${printerConfig.name} (${printerConfig.fullAddress}): $content');
      
      // Update last test print time
      await _printerConfigService.updateLastTestPrint(assignment.printerId);
      
      return true;
    } catch (e) {
      debugPrint('Error printing to assigned printer: $e');
      return false;
    }
  }

  /// Toggle assignment active status
  Future<bool> toggleAssignmentStatus(String assignmentId) async {
    try {
      final assignment = _assignments.firstWhere((a) => a.id == assignmentId);
      final updatedAssignment = assignment.copyWith(
        isActive: !assignment.isActive,
        updatedAt: DateTime.now(),
      );
      
      return await updateAssignment(updatedAssignment);
    } catch (e) {
      debugPrint('Error toggling assignment status: $e');
      return false;
    }
  }

  /// Update assignment priority
  Future<bool> updateAssignmentPriority(String assignmentId, int newPriority) async {
    try {
      final assignment = _assignments.firstWhere((a) => a.id == assignmentId);
      final updatedAssignment = assignment.copyWith(
        priority: newPriority,
        updatedAt: DateTime.now(),
      );
      
      return await updateAssignment(updatedAssignment);
    } catch (e) {
      debugPrint('Error updating assignment priority: $e');
      return false;
    }
  }

  /// Get assignment statistics with printer connection info
  Map<String, dynamic> getAssignmentStats() {
    final activeAssignments = _assignments.where((a) => a.isActive).toList();
    final categoryAssignments = activeAssignments.where((a) => a.assignmentType == AssignmentType.category).length;
    final menuItemAssignments = activeAssignments.where((a) => a.assignmentType == AssignmentType.menuItem).length;
    final uniquePrinters = activeAssignments.map((a) => a.printerId).toSet().length;

    // Get connection status for assigned printers
    final connectedPrinters = activeAssignments
        .map((a) => _printerConfigService.getConfigurationById(a.printerId))
        .where((config) => config?.connectionStatus == PrinterConnectionStatus.connected)
        .length;

    return {
      'totalAssignments': activeAssignments.length,
      'categoryAssignments': categoryAssignments,
      'menuItemAssignments': menuItemAssignments,
      'uniquePrinters': uniquePrinters,
      'connectedPrinters': connectedPrinters,
      'inactiveAssignments': _assignments.where((a) => !a.isActive).length,
    };
  }

  /// Sync assignments with printer configurations (clean up orphaned assignments)
  Future<void> syncWithPrinterConfigurations() async {
    try {
      final validPrinterIds = _printerConfigService.configurations.map((c) => c.id).toSet();
      final orphanedAssignments = _assignments.where((a) => !validPrinterIds.contains(a.printerId)).toList();

      for (final orphaned in orphanedAssignments) {
        await deleteAssignment(orphaned.id);
        debugPrint('Removed orphaned assignment: ${orphaned.targetName}');
      }

      if (orphanedAssignments.isNotEmpty) {
        debugPrint('Cleaned up ${orphanedAssignments.length} orphaned assignments');
      }
    } catch (e) {
      debugPrint('Error syncing with printer configurations: $e');
    }
  }

  /// Refresh assignments from database
  Future<void> refreshAssignments() async {
    await _loadAssignments();
    await syncWithPrinterConfigurations();
  }
} 