import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../lib/services/printer_assignment_service.dart';
import '../lib/services/printer_configuration_service.dart';
import '../lib/services/database_service.dart';
import '../lib/models/printer_assignment.dart';
import '../lib/models/printer_configuration.dart';
import 'package:ai_pos_system/services/enhanced_printer_assignment_service.dart';

void main() {
  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Enhanced Printer Assignment Service Tests', () {
    late DatabaseService databaseService;
    late PrinterConfigurationService printerConfigService;
    late EnhancedPrinterAssignmentService printerAssignmentService;

    setUp(() async {
      // Initialize test database
      databaseService = DatabaseService();
      await databaseService.initialize();
      
      // Initialize printer configuration service
      printerConfigService = PrinterConfigurationService(databaseService);
      await printerConfigService.initialize();
      
      // Initialize enhanced printer assignment service
      printerAssignmentService = EnhancedPrinterAssignmentService(
        databaseService: databaseService,
        printerConfigService: printerConfigService,
      );
      await printerAssignmentService.initialize();
    });

    tearDown(() async {
      await database.close();
    });

    test('Test Assignment Logic Fix', () async {
      print('🧪 TESTING: Assignment Logic Fix');
      
      // Manually create printer configurations table
      await database.execute('''
        CREATE TABLE IF NOT EXISTS printer_configurations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL,
          model TEXT NOT NULL,
          ip_address TEXT,
          port INTEGER,
          mac_address TEXT,
          bluetooth_address TEXT,
          is_active INTEGER DEFAULT 1,
          is_default INTEGER DEFAULT 0,
          connection_status TEXT DEFAULT 'unknown',
          last_connected TEXT,
          last_test_print TEXT,
          custom_settings TEXT,
          created_at TEXT,
          updated_at TEXT,
          remote_config TEXT
        )
      ''');

      // Create test printer configurations
      await database.insert('printer_configurations', {
        'id': 'printer_1',
        'name': 'Main Kitchen Printer',
        'description': 'Main kitchen printer',
        'type': 'wifi',
        'model': 'epsonTMT88VI',
        'ip_address': '192.168.0.141',
        'port': 9100,
        'is_active': 1,
        'connection_status': 'connected',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await database.insert('printer_configurations', {
        'id': 'printer_2',
        'name': 'Grill Station Printer',
        'description': 'Grill station printer',
        'type': 'wifi',
        'model': 'epsonTMT88VI',
        'ip_address': '192.168.0.147',
        'port': 9100,
        'is_active': 1,
        'connection_status': 'connected',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Initialize printer assignment table
      await printerAssignmentService.initializeTable();

      print('✅ Setup complete - printers and tables created');

      // Test 1: Single assignment should work
      final assignment1 = PrinterAssignment(
        printerId: 'printer_1',
        printerName: 'Main Kitchen Printer',
        printerAddress: '192.168.0.141:9100',
        assignmentType: AssignmentType.menuItem,
        targetId: 'item_1',
        targetName: 'Chicken Tikka',
      );

      final success1 = await printerAssignmentService.addAssignment(assignment1);
      expect(success1, true);
      print('✅ Test 1: Single assignment works');

      // Test 2: Multiple assignments to different printers should work
      final assignment2 = PrinterAssignment(
        printerId: 'printer_2',
        printerName: 'Grill Station Printer', 
        printerAddress: '192.168.0.147:9100',
        assignmentType: AssignmentType.menuItem,
        targetId: 'item_1', // Same item
        targetName: 'Chicken Tikka',
      );

      final success2 = await printerAssignmentService.addAssignment(assignment2);
      expect(success2, true);
      print('✅ Test 2: Multiple assignments to different printers works');

      // Test 3: Duplicate assignment to same printer should fail
      final assignment3 = PrinterAssignment(
        printerId: 'printer_1', // Same printer
        printerName: 'Main Kitchen Printer',
        printerAddress: '192.168.0.141:9100',
        assignmentType: AssignmentType.menuItem,
        targetId: 'item_1', // Same item
        targetName: 'Chicken Tikka',
      );

      final success3 = await printerAssignmentService.addAssignment(assignment3);
      expect(success3, false);
      print('✅ Test 3: Duplicate assignment to same printer correctly fails');

      // Test 4: Verify assignments were created
      await printerAssignmentService.loadAssignments();
      final assignments = printerAssignmentService.assignments;
      expect(assignments.length, 2);
      print('✅ Test 4: Correct number of assignments created (${assignments.length})');

      // Test 5: Verify assignments are for correct printers
      final printer1Assignments = assignments.where((a) => a.printerId == 'printer_1').toList();
      final printer2Assignments = assignments.where((a) => a.printerId == 'printer_2').toList();
      expect(printer1Assignments.length, 1);
      expect(printer2Assignments.length, 1);
      print('✅ Test 5: Assignments correctly distributed to different printers');

      // Test 6: Test category assignments
      final categoryAssignment = PrinterAssignment(
        printerId: 'printer_1',
        printerName: 'Main Kitchen Printer',
        printerAddress: '192.168.0.141:9100',
        assignmentType: AssignmentType.category,
        targetId: 'category_1',
        targetName: 'Tandoor Items',
      );

      final success6 = await printerAssignmentService.addAssignment(categoryAssignment);
      expect(success6, true);
      print('✅ Test 6: Category assignment works');

      // Test 7: Test assignment removal
      final assignmentToRemove = assignments.first;
      final success7 = await printerAssignmentService.deleteAssignment(assignmentToRemove.id);
      expect(success7, true);
      print('✅ Test 7: Assignment removal works');

      // Verify assignment was removed
      await printerAssignmentService.loadAssignments();
      final remainingAssignments = printerAssignmentService.assignments;
      expect(remainingAssignments.length, 2); // Should be 2 (was 3, removed 1)
      print('✅ Test 7: Assignment correctly removed');

      print('🎉 ALL TESTS PASSED! Assignment logic is working correctly');
    });

    test('Test addAssignmentWithConfig Method', () async {
      print('🧪 TESTING: addAssignmentWithConfig Method');

      // Create a mock printer configuration
      final printer = PrinterConfiguration(
        id: 'test_printer',
        name: 'Test Printer',
        description: 'Test printer for assignment',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88VI,
        ipAddress: '192.168.0.100',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      // Manually add printer to database
      await database.execute('''
        CREATE TABLE IF NOT EXISTS printer_configurations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          type TEXT NOT NULL,
          model TEXT NOT NULL,
          ip_address TEXT,
          port INTEGER,
          mac_address TEXT,
          bluetooth_address TEXT,
          is_active INTEGER DEFAULT 1,
          is_default INTEGER DEFAULT 0,
          connection_status TEXT DEFAULT 'unknown',
          last_connected TEXT,
          last_test_print TEXT,
          custom_settings TEXT,
          created_at TEXT,
          updated_at TEXT,
          remote_config TEXT
        )
      ''');

      await database.insert('printer_configurations', {
        'id': printer.id,
        'name': printer.name,
        'description': printer.description,
        'type': printer.type.toString().split('.').last,
        'model': printer.model.toString().split('.').last,
        'ip_address': printer.ipAddress,
        'port': printer.port,
        'is_active': printer.isActive ? 1 : 0,
        'connection_status': printer.connectionStatus.toString().split('.').last,
        'created_at': printer.createdAt.toIso8601String(),
        'updated_at': printer.updatedAt.toIso8601String(),
      });

      // Initialize assignment table
      await printerAssignmentService.initializeTable();

      // Test assignment creation
      final success = await printerAssignmentService.addAssignmentWithConfig(
        printer.id,
        AssignmentType.menuItem,
        'test_item',
        'Test Menu Item',
      );

      expect(success, true);
      print('✅ addAssignmentWithConfig method works correctly');

      // Verify assignment was created
      await printerAssignmentService.loadAssignments();
      final assignments = printerAssignmentService.assignments;
      expect(assignments.length, 1);
      expect(assignments.first.printerId, printer.id);
      expect(assignments.first.targetId, 'test_item');
      print('✅ Assignment correctly created and stored');

      print('🎉 addAssignmentWithConfig method test PASSED!');
    });
  });
} 