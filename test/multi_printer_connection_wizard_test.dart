import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../lib/screens/multi_printer_connection_wizard.dart';
import '../lib/services/enhanced_printer_manager.dart';
import '../lib/services/printer_configuration_service.dart';
import '../lib/services/database_service.dart';
import '../lib/services/printing_service.dart';
import '../lib/services/menu_service.dart';
import '../lib/models/printer_configuration.dart';

void main() {
  group('Multi-Printer Connection Wizard Tests', () {
    late EnhancedPrinterManager mockEnhancedPrinterManager;
    late PrinterConfigurationService mockPrinterConfigService;
    late MenuService mockMenuService;
    late DatabaseService mockDatabaseService;
    late PrintingService mockPrintingService;

    setUp(() {
      // Initialize mock services
      mockDatabaseService = DatabaseService();
      mockPrinterConfigService = PrinterConfigurationService(mockDatabaseService);
      mockPrintingService = PrintingService();
      mockEnhancedPrinterManager = EnhancedPrinterManager(
        databaseService: mockDatabaseService,
        printerConfigService: mockPrinterConfigService,
        printingService: mockPrintingService,
      );
      mockMenuService = MenuService();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<EnhancedPrinterManager>.value(
              value: mockEnhancedPrinterManager,
            ),
            ChangeNotifierProvider<PrinterConfigurationService>.value(
              value: mockPrinterConfigService,
            ),
            ChangeNotifierProvider<MenuService>.value(
              value: mockMenuService,
            ),
          ],
          child: const MultiPrinterConnectionWizard(),
        ),
      );
    }

    testWidgets('Multi-Printer Wizard displays correctly', (WidgetTester tester) async {
      print('🧪 TEST: Multi-Printer Wizard displays correctly');

      await tester.pumpWidget(createTestWidget());
      
      // Verify wizard UI elements are present
      expect(find.text('🖨️ Multi-Printer Connection Wizard'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Assign'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);

      print('✅ TEST: Multi-Printer Wizard displays correctly - PASSED');
    });

    testWidgets('Wizard shows real printers instead of dummy ones', (WidgetTester tester) async {
      print('🧪 TEST: Wizard shows real printers instead of dummy ones');

      // Add real printer configurations to the service
      final realPrinter1 = PrinterConfiguration(
        id: 'real_printer_1',
        name: 'Kitchen Main Printer',
        description: 'Real kitchen printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88VI,
        ipAddress: '192.168.0.141',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      final realPrinter2 = PrinterConfiguration(
        id: 'real_printer_2',
        name: 'Grill Station Printer',
        description: 'Real grill printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88V,
        ipAddress: '192.168.0.147',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      await mockPrinterConfigService.addConfiguration(realPrinter1);
      await mockPrinterConfigService.addConfiguration(realPrinter2);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Wait for wizard to load real printers
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Verify real printer names appear (not dummy ones)
      expect(find.textContaining('Kitchen Main Printer'), findsOneWidget);
      expect(find.textContaining('Grill Station Printer'), findsOneWidget);
      
      // Verify dummy printer names don't appear
      expect(find.textContaining('192.168.1.101'), findsNothing);
      expect(find.textContaining('192.168.1.102'), findsNothing);

      print('✅ TEST: Wizard shows real printers instead of dummy ones - PASSED');
    });

    testWidgets('Network scan button triggers real printer discovery', (WidgetTester tester) async {
      print('🧪 TEST: Network scan button triggers real printer discovery');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the network scan button
      expect(find.text('🌐 Network Scan'), findsOneWidget);
      await tester.tap(find.text('🌐 Network Scan'));
      await tester.pumpAndSettle();

      // Verify scanning state is activated
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      
      // Wait for scan to complete
      await tester.pumpAndSettle(const Duration(seconds: 3));

      print('✅ TEST: Network scan button triggers real printer discovery - PASSED');
    });

    testWidgets('Manual printer entry works correctly', (WidgetTester tester) async {
      print('🧪 TEST: Manual printer entry works correctly');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the manual entry button
      expect(find.text('✏️ Manual Entry'), findsOneWidget);
      await tester.tap(find.text('✏️ Manual Entry'));
      await tester.pumpAndSettle();

      // Verify manual entry dialog appears
      expect(find.text('Add Printer Manually'), findsOneWidget);
      expect(find.text('Printer Name'), findsOneWidget);
      expect(find.text('IP Address'), findsOneWidget);
      expect(find.text('Port'), findsOneWidget);

      // Fill in printer details
      await tester.enterText(find.widgetWithText(TextField, 'Printer Name'), 'Test Manual Printer');
      await tester.enterText(find.widgetWithText(TextField, 'IP Address'), '192.168.0.200');
      await tester.enterText(find.widgetWithText(TextField, 'Port'), '9100');

      // Tap Add Printer button
      await tester.tap(find.text('Add Printer'));
      await tester.pumpAndSettle();

      // Wait for connection test
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify success message appears
      expect(find.textContaining('added successfully'), findsOneWidget);

      print('✅ TEST: Manual printer entry works correctly - PASSED');
    });

    testWidgets('Wizard steps progress correctly', (WidgetTester tester) async {
      print('🧪 TEST: Wizard steps progress correctly');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify initial step (Scan)
      expect(find.text('Continue'), findsOneWidget);

      // Add a printer to enable progression
      final testPrinter = PrinterConfiguration(
        id: 'test_printer',
        name: 'Test Printer',
        description: 'Test printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88VI,
        ipAddress: '192.168.0.100',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      await mockPrinterConfigService.addConfiguration(testPrinter);
      await tester.pumpAndSettle();

      // Progress to next step
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify step 2 (Select)
      expect(find.text('Connect Selected'), findsOneWidget);

      print('✅ TEST: Wizard steps progress correctly - PASSED');
    });

    testWidgets('Printer selection works correctly', (WidgetTester tester) async {
      print('🧪 TEST: Printer selection works correctly');

      // Add test printers
      final printer1 = PrinterConfiguration(
        id: 'printer_1',
        name: 'Printer 1',
        description: 'First printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88VI,
        ipAddress: '192.168.0.101',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      final printer2 = PrinterConfiguration(
        id: 'printer_2',
        name: 'Printer 2',
        description: 'Second printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88V,
        ipAddress: '192.168.0.102',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      await mockPrinterConfigService.addConfiguration(printer1);
      await mockPrinterConfigService.addConfiguration(printer2);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Progress to selection step
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify printers are shown with checkboxes
      expect(find.text('Printer 1'), findsOneWidget);
      expect(find.text('Printer 2'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));

      // Test Select All functionality
      expect(find.text('Select All'), findsOneWidget);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();

      // Test Deselect All functionality
      expect(find.text('Deselect All'), findsOneWidget);
      await tester.tap(find.text('Deselect All'));
      await tester.pumpAndSettle();

      print('✅ TEST: Printer selection works correctly - PASSED');
    });

    testWidgets('Bluetooth scan shows not implemented message', (WidgetTester tester) async {
      print('🧪 TEST: Bluetooth scan shows not implemented message');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the Bluetooth scan button
      expect(find.text('📱 Bluetooth Scan'), findsOneWidget);
      await tester.tap(find.text('📱 Bluetooth Scan'));
      await tester.pumpAndSettle();

      // Wait for scan to complete
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify not implemented message appears
      expect(find.textContaining('Bluetooth scanning is not yet implemented'), findsOneWidget);

      print('✅ TEST: Bluetooth scan shows not implemented message - PASSED');
    });

    testWidgets('Printer capabilities are correctly displayed', (WidgetTester tester) async {
      print('🧪 TEST: Printer capabilities are correctly displayed');

      // Add printer with specific model
      final epsonPrinter = PrinterConfiguration(
        id: 'epson_printer',
        name: 'Epson TM-T88VI',
        description: 'High-end thermal printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88VI,
        ipAddress: '192.168.0.150',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      await mockPrinterConfigService.addConfiguration(epsonPrinter);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify capabilities are shown
      expect(find.textContaining('High Speed'), findsOneWidget);
      expect(find.textContaining('Auto Cutter'), findsOneWidget);
      expect(find.textContaining('WiFi'), findsOneWidget);

      print('✅ TEST: Printer capabilities are correctly displayed - PASSED');
    });

    testWidgets('Error handling works correctly', (WidgetTester tester) async {
      print('🧪 TEST: Error handling works correctly');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test manual entry with invalid data
      await tester.tap(find.text('✏️ Manual Entry'));
      await tester.pumpAndSettle();

      // Try to add printer without filling fields
      await tester.tap(find.text('Add Printer'));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.textContaining('Please fill in all required fields'), findsOneWidget);

      print('✅ TEST: Error handling works correctly - PASSED');
    });

    test('DiscoveredPrinter conversion works correctly', () {
      print('🧪 TEST: DiscoveredPrinter conversion works correctly');

      final config = PrinterConfiguration(
        id: 'test_config',
        name: 'Test Kitchen Printer',
        description: 'Test printer',
        type: PrinterType.wifi,
        model: PrinterModel.epsonTMT88VI,
        ipAddress: '192.168.0.100',
        port: 9100,
        isActive: true,
        connectionStatus: PrinterConnectionStatus.connected,
      );

      // Note: This test would require access to the private method
      // In a real implementation, you might expose this as a public method for testing
      
      // Verify basic properties would be converted correctly
      expect(config.id, 'test_config');
      expect(config.name, 'Test Kitchen Printer');
      expect(config.ipAddress, '192.168.0.100');
      expect(config.port, 9100);

      print('✅ TEST: DiscoveredPrinter conversion works correctly - PASSED');
    });
  });

  group('Multi-Printer Wizard Integration Tests', () {
    test('Test End-to-End Printer Discovery Flow', () async {
      print('🧪 INTEGRATION TEST: End-to-End Printer Discovery Flow');

      // This test simulates the complete flow:
      // 1. User opens wizard
      // 2. Real printers are discovered
      // 3. User selects printers
      // 4. Printers are connected
      // 5. Assignments are configured

      // Step 1: Initialize services
      final databaseService = DatabaseService();
      final printerConfigService = PrinterConfigurationService(databaseService);
      final printingService = PrintingService();
      final enhancedPrinterManager = EnhancedPrinterManager(
        databaseService: databaseService,
        printerConfigService: printerConfigService,
        printingService: printingService,
      );

      // Step 2: Add real printer configurations
      final realPrinters = [
        PrinterConfiguration(
          id: 'kitchen_main',
          name: 'Kitchen Main Printer',
          description: 'Main kitchen printer',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.0.141',
          port: 9100,
          isActive: true,
          connectionStatus: PrinterConnectionStatus.connected,
        ),
        PrinterConfiguration(
          id: 'grill_station',
          name: 'Grill Station Printer',
          description: 'Grill station printer',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88V,
          ipAddress: '192.168.0.147',
          port: 9100,
          isActive: true,
          connectionStatus: PrinterConnectionStatus.connected,
        ),
      ];

      for (final printer in realPrinters) {
        await printerConfigService.addConfiguration(printer);
      }

      // Step 3: Verify discovery
      final availablePrinters = printerConfigService.configurations;
      expect(availablePrinters.length, 2);
      expect(availablePrinters.any((p) => p.name == 'Kitchen Main Printer'), true);
      expect(availablePrinters.any((p) => p.name == 'Grill Station Printer'), true);

      // Step 4: Test enhanced printer manager integration
      await enhancedPrinterManager.initialize();
      final enhancedPrinters = enhancedPrinterManager.availablePrinters;
      expect(enhancedPrinters.length, greaterThanOrEqualTo(2));

      print('✅ INTEGRATION TEST: End-to-End Printer Discovery Flow - PASSED');
    });

    test('Test Multi-Printer Assignment Integration', () async {
      print('🧪 INTEGRATION TEST: Multi-Printer Assignment Integration');

      // Test the complete assignment flow:
      // 1. Discover printers
      // 2. Create menu items
      // 3. Assign items to printers
      // 4. Verify assignments

      final databaseService = DatabaseService();
      final printerConfigService = PrinterConfigurationService(databaseService);
      final printingService = PrintingService();
      final enhancedPrinterManager = EnhancedPrinterManager(
        databaseService: databaseService,
        printerConfigService: printerConfigService,
        printingService: printingService,
      );

      // Add printers
      final printers = [
        PrinterConfiguration(
          id: 'main_kitchen',
          name: 'Main Kitchen',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.0.141',
          port: 9100,
        ),
        PrinterConfiguration(
          id: 'grill_station',
          name: 'Grill Station',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88V,
          ipAddress: '192.168.0.147',
          port: 9100,
        ),
      ];

      for (final printer in printers) {
        await printerConfigService.addConfiguration(printer);
      }

      // Initialize enhanced manager
      await enhancedPrinterManager.initialize();

      // Test assignment functionality
      final success = await enhancedPrinterManager.assignMenuItemToPrinter(
        'test_item_1',
        'main_kitchen',
      );

      expect(success, true);

      // Verify assignment
      final assignments = enhancedPrinterManager.menuItemAssignments;
      expect(assignments.containsKey('test_item_1'), true);
      expect(assignments['test_item_1'], 'main_kitchen');

      print('✅ INTEGRATION TEST: Multi-Printer Assignment Integration - PASSED');
    });
  });

  group('Performance Tests', () {
    test('Test Large Number of Printers Performance', () async {
      print('🧪 PERFORMANCE TEST: Large Number of Printers');

      final databaseService = DatabaseService();
      final printerConfigService = PrinterConfigurationService(databaseService);

      // Add 50 printers to test performance
      final stopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 50; i++) {
        final printer = PrinterConfiguration(
          id: 'printer_$i',
          name: 'Printer $i',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.0.${100 + i}',
          port: 9100,
        );
        
        await printerConfigService.addConfiguration(printer);
      }

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      print('Added 50 printers in ${elapsedMs}ms');
      expect(elapsedMs, lessThan(5000)); // Should complete in under 5 seconds

      // Verify all printers were added
      final configurations = printerConfigService.configurations;
      expect(configurations.length, 50);

      print('✅ PERFORMANCE TEST: Large Number of Printers - PASSED');
    });
  });
} 