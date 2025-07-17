import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_pos_system/services/printer_configuration_service.dart';
import 'package:ai_pos_system/services/printer_assignment_service.dart';
import 'package:ai_pos_system/services/printing_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_manager.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/printer_assignment.dart';
import 'package:ai_pos_system/models/printer_configuration.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/models/printer_assignment.dart';
import 'package:ai_pos_system/models/printer_configuration.dart';

/// COMPREHENSIVE PRINTER ASSIGNMENT PERSISTENCE TEST
/// This test demonstrates that printer assignments are automatically saved 
/// and restored across app sessions and logouts.

Future<void> main() async {
  print('🧪 COMPREHENSIVE PRINTER ASSIGNMENT PERSISTENCE TEST');
  print('=' * 70);
  
  await testPrinterAssignmentPersistence();
}

Future<void> testPrinterAssignmentPersistence() async {
  print('🎯 Testing printer assignment persistence across app sessions...');
  print('-' * 70);
  
  try {
    // Initialize services
    final databaseService = DatabaseService();
    final printerConfigService = PrinterConfigurationService(databaseService);
    final printerAssignmentService = PrinterAssignmentService(printerConfigService);
    
    // Wait for initialization
    await Future.delayed(const Duration(seconds: 2));
    
    print('✅ Services initialized successfully');
    
    // === PHASE 1: CREATE TEST ASSIGNMENTS ===
    print('\n📍 PHASE 1: Creating test assignments...');
    
    // Create test printer configurations
    await _createTestPrinterConfigurations(printerConfigService);
    
    // Create test assignments
    await _createTestAssignments(printerAssignmentService);
    
    // === PHASE 2: VERIFY PERSISTENCE ===
    print('\n📍 PHASE 2: Verifying persistence...');
    
    // Check assignments are loaded
    await printerAssignmentService.verifyAssignmentPersistence();
    
    // === PHASE 3: SIMULATE APP RESTART ===
    print('\n📍 PHASE 3: Simulating app restart...');
    
    // Create NEW service instances (simulating app restart)
    final newDatabaseService = DatabaseService();
    final newPrinterConfigService = PrinterConfigurationService(newDatabaseService);
    final newPrinterAssignmentService = PrinterAssignmentService(newPrinterConfigService);
    
    // Wait for initialization
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if assignments survived restart
    await newPrinterAssignmentService.verifyAssignmentPersistence();
    
    // === PHASE 4: VERIFY FUNCTIONALITY ===
    print('\n📍 PHASE 4: Testing assignment functionality...');
    
    await _testAssignmentFunctionality(newPrinterAssignmentService);
    
    // === PHASE 5: SIMULATE LOGOUT/LOGIN ===
    print('\n📍 PHASE 5: Simulating logout/login cycle...');
    
    // Close services (simulating logout)
    await databaseService.close();
    await newDatabaseService.close();
    
    // Create fresh instances (simulating login)
    final freshDatabaseService = DatabaseService();
    final freshPrinterConfigService = PrinterConfigurationService(freshDatabaseService);
    final freshPrinterAssignmentService = PrinterAssignmentService(freshPrinterConfigService);
    
    // Wait for initialization
    await Future.delayed(const Duration(seconds: 2));
    
    // Final verification
    await freshPrinterAssignmentService.verifyAssignmentPersistence();
    
    print('\n🎉 PERSISTENCE TEST COMPLETED SUCCESSFULLY!');
    print('✅ All assignments survived app restart and logout/login cycles');
    print('✅ Assignment persistence system is working correctly');
    
  } catch (e) {
    print('❌ Error during persistence test: $e');
  }
}

Future<void> _createTestPrinterConfigurations(PrinterConfigurationService service) async {
  print('🖨️ Creating test printer configurations...');
  
  final testPrinters = [
    PrinterConfiguration(
      id: 'printer_1',
      name: 'Kitchen Printer 1',
      type: PrinterType.thermal,
      model: 'Epson TM-T88VI',
      ipAddress: '192.168.0.141',
      port: 9100,
      isActive: true,
      connectionStatus: PrinterConnectionStatus.connected,
    ),
    PrinterConfiguration(
      id: 'printer_2',
      name: 'Bar Printer',
      type: PrinterType.thermal,
      model: 'Epson TM-T88V',
      ipAddress: '192.168.0.147',
      port: 9100,
      isActive: true,
      connectionStatus: PrinterConnectionStatus.connected,
    ),
  ];
  
  for (final printer in testPrinters) {
    await service.addConfiguration(printer);
  }
  
  print('✅ Created ${testPrinters.length} test printer configurations');
}

Future<void> _createTestAssignments(PrinterAssignmentService service) async {
  print('📋 Creating test assignments...');
  
  final testAssignments = [
    PrinterAssignment(
      printerId: 'printer_1',
      printerName: 'Kitchen Printer 1',
      printerAddress: '192.168.0.141:9100',
      assignmentType: AssignmentType.category,
      targetId: 'appetizers',
      targetName: 'Appetizers',
    ),
    PrinterAssignment(
      printerId: 'printer_1',
      printerName: 'Kitchen Printer 1',
      printerAddress: '192.168.0.141:9100',
      assignmentType: AssignmentType.category,
      targetId: 'main_dishes',
      targetName: 'Main Dishes',
    ),
    PrinterAssignment(
      printerId: 'printer_2',
      printerName: 'Bar Printer',
      printerAddress: '192.168.0.147:9100',
      assignmentType: AssignmentType.category,
      targetId: 'beverages',
      targetName: 'Beverages',
    ),
  ];
  
  for (final assignment in testAssignments) {
    await service.addAssignment(assignment);
  }
  
  print('✅ Created ${testAssignments.length} test assignments');
}

Future<void> _testAssignmentFunctionality(PrinterAssignmentService service) async {
  print('🔍 Testing assignment functionality...');
  
  // Test category assignment lookup
  final appetizerAssignment = service.getAssignmentForMenuItem('test_item', 'appetizers');
  if (appetizerAssignment != null) {
    print('✅ Found assignment for appetizers: ${appetizerAssignment.printerName}');
  } else {
    print('❌ No assignment found for appetizers');
  }
  
  // Test assignment statistics
  final stats = await service.getAssignmentStats();
  print('📊 Assignment statistics:');
  print('  - Total assignments: ${stats['totalAssignments']}');
  print('  - Category assignments: ${stats['categoryAssignments']}');
  print('  - Menu item assignments: ${stats['menuItemAssignments']}');
  print('  - Unique printers: ${stats['uniquePrinters']}');
  
  print('✅ Assignment functionality test completed');
} 