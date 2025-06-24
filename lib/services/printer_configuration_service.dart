import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/printer_configuration.dart';
import 'database_service.dart';

class PrinterConfigurationService with ChangeNotifier {
  final DatabaseService _databaseService;
  List<PrinterConfiguration> _configurations = [];
  bool _isLoading = false;

  PrinterConfigurationService(this._databaseService) {
    _initializeDatabase();
    _loadConfigurations();
  }

  // Getters
  List<PrinterConfiguration> get configurations => _configurations;
  List<PrinterConfiguration> get activeConfigurations => 
      _configurations.where((config) => config.isActive).toList();
  List<PrinterConfiguration> get networkPrinters => 
      _configurations.where((config) => config.isNetworkPrinter && config.isActive).toList();
  bool get isLoading => _isLoading;

  /// Initialize the printer configurations table
  Future<void> _initializeDatabase() async {
    try {
      final db = await _databaseService.database;
      
      // Create printer_configurations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS printer_configurations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT DEFAULT '',
          type TEXT NOT NULL,
          model TEXT DEFAULT 'epsonTMT88VI',
          ip_address TEXT DEFAULT '',
          port INTEGER DEFAULT 9100,
          mac_address TEXT DEFAULT '',
          bluetooth_address TEXT DEFAULT '',
          is_active INTEGER NOT NULL DEFAULT 1,
          is_default INTEGER NOT NULL DEFAULT 0,
          connection_status TEXT DEFAULT 'unknown',
          last_connected TEXT DEFAULT '1970-01-01T00:00:00.000Z',
          last_test_print TEXT DEFAULT '1970-01-01T00:00:00.000Z',
          custom_settings TEXT DEFAULT '{}',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // Create default printer configurations if none exist
      await _createDefaultConfigurations();

      debugPrint('Printer configurations table initialized successfully');
    } catch (e) {
      debugPrint('Error initializing printer configurations table: $e');
    }
  }

  /// Create default printer configurations for restaurant stations
  Future<void> _createDefaultConfigurations() async {
    try {
      final db = await _databaseService.database;
      
      // Check if any configurations exist
      final existing = await db.query('printer_configurations', limit: 1);
      if (existing.isNotEmpty) {
        return; // Don't create defaults if configurations already exist
      }

      final defaultConfigs = [
        PrinterConfiguration(
          name: 'Main Kitchen Printer',
          description: 'Central coordination & receipts',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.100',
          port: 9100,
          isDefault: true,
        ),
        PrinterConfiguration(
          name: 'Tandoor Station',
          description: 'Naan, kebabs, tandoori items',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.101',
          port: 9100,
        ),
        PrinterConfiguration(
          name: 'Curry Station',
          description: 'Curries, dal, gravies',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.102',
          port: 9100,
        ),
        PrinterConfiguration(
          name: 'Appetizer Station',
          description: 'Starters, salads, cold items',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.103',
          port: 9100,
        ),
        PrinterConfiguration(
          name: 'Grill Station',
          description: 'Grilled items, BBQ',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.104',
          port: 9100,
        ),
        PrinterConfiguration(
          name: 'Bar/Beverage Station',
          description: 'Drinks, beverages',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.105',
          port: 9100,
        ),
      ];

      for (final config in defaultConfigs) {
        await db.insert('printer_configurations', _configToDbMap(config));
      }

      debugPrint('Created ${defaultConfigs.length} default printer configurations');
    } catch (e) {
      debugPrint('Error creating default printer configurations: $e');
    }
  }

  /// Convert PrinterConfiguration to database map
  Map<String, dynamic> _configToDbMap(PrinterConfiguration config) {
    final json = config.toJson();
    // Convert custom_settings to JSON string for database storage
    json['custom_settings'] = jsonEncode(config.customSettings);
    return json;
  }

  /// Convert database map to PrinterConfiguration
  PrinterConfiguration _dbMapToConfig(Map<String, dynamic> map) {
    // Parse custom_settings from JSON string
    if (map['custom_settings'] is String) {
      try {
        map['custom_settings'] = jsonDecode(map['custom_settings'] as String);
      } catch (e) {
        map['custom_settings'] = <String, dynamic>{};
      }
    }
    return PrinterConfiguration.fromJson(map);
  }

  /// Load all printer configurations from database
  Future<void> _loadConfigurations() async {
    try {
      _isLoading = true;
      notifyListeners();

      final db = await _databaseService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'printer_configurations',
        orderBy: 'is_default DESC, name ASC',
      );

      _configurations = maps.map((map) => _dbMapToConfig(map)).toList();
      
      debugPrint('Loaded ${_configurations.length} printer configurations');
    } catch (e) {
      debugPrint('Error loading printer configurations: $e');
      _configurations = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new printer configuration
  Future<bool> addConfiguration(PrinterConfiguration config) async {
    try {
      final db = await _databaseService.database;
      
      // Check for duplicate IP addresses for network printers
      if (config.isNetworkPrinter && config.ipAddress.isNotEmpty) {
        final existing = await db.query(
          'printer_configurations',
          where: 'ip_address = ? AND port = ? AND is_active = 1 AND id != ?',
          whereArgs: [config.ipAddress, config.port, config.id],
        );

        if (existing.isNotEmpty) {
          debugPrint('Printer configuration with IP ${config.ipAddress}:${config.port} already exists');
          return false;
        }
      }

      // If this is set as default, remove default from others
      if (config.isDefault) {
        await _clearDefaultFlags();
      }

      await db.insert('printer_configurations', _configToDbMap(config));
      await _loadConfigurations();
      
      debugPrint('Added printer configuration: ${config.name}');
      return true;
    } catch (e) {
      debugPrint('Error adding printer configuration: $e');
      return false;
    }
  }

  /// Update an existing printer configuration
  Future<bool> updateConfiguration(PrinterConfiguration config) async {
    try {
      final db = await _databaseService.database;
      
      // Check for duplicate IP addresses for network printers
      if (config.isNetworkPrinter && config.ipAddress.isNotEmpty) {
        final existing = await db.query(
          'printer_configurations',
          where: 'ip_address = ? AND port = ? AND is_active = 1 AND id != ?',
          whereArgs: [config.ipAddress, config.port, config.id],
        );

        if (existing.isNotEmpty) {
          debugPrint('Printer configuration with IP ${config.ipAddress}:${config.port} already exists');
          return false;
        }
      }

      // If this is set as default, remove default from others
      if (config.isDefault) {
        await _clearDefaultFlags();
      }

      final updatedConfig = config.copyWith(updatedAt: DateTime.now());

      await db.update(
        'printer_configurations',
        _configToDbMap(updatedConfig),
        where: 'id = ?',
        whereArgs: [config.id],
      );

      await _loadConfigurations();
      
      debugPrint('Updated printer configuration: ${config.name}');
      return true;
    } catch (e) {
      debugPrint('Error updating printer configuration: $e');
      return false;
    }
  }

  /// Delete a printer configuration
  Future<bool> deleteConfiguration(String configId) async {
    try {
      final db = await _databaseService.database;
      
      await db.delete(
        'printer_configurations',
        where: 'id = ?',
        whereArgs: [configId],
      );

      await _loadConfigurations();
      
      debugPrint('Deleted printer configuration: $configId');
      return true;
    } catch (e) {
      debugPrint('Error deleting printer configuration: $e');
      return false;
    }
  }

  /// Get printer configuration by ID
  PrinterConfiguration? getConfigurationById(String id) {
    try {
      return _configurations.firstWhere((config) => config.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get printer configuration by name
  PrinterConfiguration? getConfigurationByName(String name) {
    try {
      return _configurations.firstWhere((config) => config.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get printer configuration by IP address
  PrinterConfiguration? getConfigurationByIP(String ipAddress, int port) {
    try {
      return _configurations.firstWhere(
        (config) => config.ipAddress == ipAddress && config.port == port && config.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get default printer configuration
  PrinterConfiguration? getDefaultConfiguration() {
    try {
      return _configurations.firstWhere((config) => config.isDefault && config.isActive);
    } catch (e) {
      return null;
    }
  }

  /// Set a configuration as default
  Future<bool> setAsDefault(String configId) async {
    try {
      final config = getConfigurationById(configId);
      if (config == null) return false;

      final updatedConfig = config.copyWith(isDefault: true);
      return await updateConfiguration(updatedConfig);
    } catch (e) {
      debugPrint('Error setting configuration as default: $e');
      return false;
    }
  }

  /// Clear default flags from all configurations
  Future<void> _clearDefaultFlags() async {
    try {
      final db = await _databaseService.database;
      await db.update(
        'printer_configurations',
        {'is_default': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'is_default = 1',
      );
    } catch (e) {
      debugPrint('Error clearing default flags: $e');
    }
  }

  /// Toggle configuration active status
  Future<bool> toggleActiveStatus(String configId) async {
    try {
      final config = getConfigurationById(configId);
      if (config == null) return false;

      final updatedConfig = config.copyWith(isActive: !config.isActive);
      return await updateConfiguration(updatedConfig);
    } catch (e) {
      debugPrint('Error toggling configuration active status: $e');
      return false;
    }
  }

  /// Update connection status
  Future<bool> updateConnectionStatus(String configId, PrinterConnectionStatus status) async {
    try {
      final config = getConfigurationById(configId);
      if (config == null) return false;

      final updatedConfig = config.copyWith(
        connectionStatus: status,
        lastConnected: status == PrinterConnectionStatus.connected ? DateTime.now() : config.lastConnected,
      );
      
      return await updateConfiguration(updatedConfig);
    } catch (e) {
      debugPrint('Error updating connection status: $e');
      return false;
    }
  }

  /// Update last test print time
  Future<bool> updateLastTestPrint(String configId) async {
    try {
      final config = getConfigurationById(configId);
      if (config == null) return false;

      final updatedConfig = config.copyWith(lastTestPrint: DateTime.now());
      return await updateConfiguration(updatedConfig);
    } catch (e) {
      debugPrint('Error updating last test print: $e');
      return false;
    }
  }

  /// Test connection to a printer
  Future<bool> testConnection(String configId) async {
    try {
      final config = getConfigurationById(configId);
      if (config == null) return false;

      // Update status to connecting
      await updateConnectionStatus(configId, PrinterConnectionStatus.connecting);

      // Simulate connection test (replace with actual implementation)
      await Future.delayed(const Duration(seconds: 2));
      
      // For now, simulate success for network printers with valid IPs
      bool success = false;
      if (config.isNetworkPrinter && config.ipAddress.isNotEmpty) {
        // Basic IP validation
        final ipParts = config.ipAddress.split('.');
        success = ipParts.length == 4 && 
                 ipParts.every((part) => int.tryParse(part) != null && 
                                       int.parse(part) >= 0 && 
                                       int.parse(part) <= 255);
      }

      final status = success ? PrinterConnectionStatus.connected : PrinterConnectionStatus.error;
      await updateConnectionStatus(configId, status);
      
      debugPrint('Connection test for ${config.name}: ${success ? 'Success' : 'Failed'}');
      return success;
    } catch (e) {
      await updateConnectionStatus(configId, PrinterConnectionStatus.error);
      debugPrint('Error testing connection: $e');
      return false;
    }
  }

  /// Test print to a printer
  Future<bool> testPrint(String configId) async {
    try {
      final config = getConfigurationById(configId);
      if (config == null) return false;

      // Test connection first
      final connected = await testConnection(configId);
      if (!connected) return false;

      // Simulate test print (replace with actual implementation)
      await Future.delayed(const Duration(seconds: 1));
      
      await updateLastTestPrint(configId);
      
      debugPrint('Test print sent to ${config.name}');
      return true;
    } catch (e) {
      debugPrint('Error sending test print: $e');
      return false;
    }
  }

  /// Get configuration statistics
  Map<String, dynamic> getConfigurationStats() {
    final activeConfigs = _configurations.where((c) => c.isActive).toList();
    final connectedConfigs = activeConfigs.where((c) => c.connectionStatus == PrinterConnectionStatus.connected).toList();
    final networkConfigs = activeConfigs.where((c) => c.isNetworkPrinter).toList();
    final bluetoothConfigs = activeConfigs.where((c) => c.type == PrinterType.bluetooth).toList();

    return {
      'totalConfigurations': _configurations.length,
      'activeConfigurations': activeConfigs.length,
      'connectedConfigurations': connectedConfigs.length,
      'networkConfigurations': networkConfigs.length,
      'bluetoothConfigurations': bluetoothConfigs.length,
      'defaultConfiguration': getDefaultConfiguration()?.name ?? 'None',
    };
  }

  /// Scan for network printers
  Future<List<PrinterConfiguration>> scanNetworkPrinters() async {
    try {
      debugPrint('Starting network printer scan...');
      
      // Simulate network scanning (replace with actual implementation)
      await Future.delayed(const Duration(seconds: 3));
      
      final discoveredPrinters = <PrinterConfiguration>[];
      
      // Simulate finding some printers
      for (int i = 110; i <= 115; i++) {
        final config = PrinterConfiguration(
          name: 'Discovered Printer $i',
          description: 'Auto-discovered network printer',
          type: PrinterType.wifi,
          model: PrinterModel.epsonTMT88VI,
          ipAddress: '192.168.1.$i',
          port: 9100,
          connectionStatus: PrinterConnectionStatus.unknown,
        );
        discoveredPrinters.add(config);
      }
      
      debugPrint('Network scan completed. Found ${discoveredPrinters.length} printers');
      return discoveredPrinters;
    } catch (e) {
      debugPrint('Error scanning for network printers: $e');
      return [];
    }
  }

  /// Refresh configurations from database
  Future<void> refreshConfigurations() async {
    await _loadConfigurations();
  }

  /// Export configurations to JSON
  String exportConfigurations() {
    try {
      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'configurations': _configurations.map((config) => config.toJson()).toList(),
      };
      return jsonEncode(exportData);
    } catch (e) {
      debugPrint('Error exporting configurations: $e');
      return '{}';
    }
  }

  /// Import configurations from JSON
  Future<bool> importConfigurations(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      final configsJson = data['configurations'] as List<dynamic>;
      
      int imported = 0;
      for (final configJson in configsJson) {
        final config = PrinterConfiguration.fromJson(configJson as Map<String, dynamic>);
        if (await addConfiguration(config)) {
          imported++;
        }
      }
      
      debugPrint('Imported $imported configurations');
      return imported > 0;
    } catch (e) {
      debugPrint('Error importing configurations: $e');
      return false;
    }
  }
} 