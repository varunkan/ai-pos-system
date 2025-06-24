import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/order.dart';
import '../models/app_settings.dart';

/// Enum for printer connection types
enum PrinterType {
  wifi,
  bluetooth,
}

/// Model for discovered printer devices
class PrinterDevice {
  final String id;
  final String name;
  final String address;
  final PrinterType type;
  final String model;
  final int signalStrength;
  final bool isConnected;

  PrinterDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    this.model = '',
    this.signalStrength = 0,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'type': type.toString(),
    'model': model,
    'signalStrength': signalStrength,
    'isConnected': isConnected,
  };

  factory PrinterDevice.fromJson(Map<String, dynamic> json) => PrinterDevice(
    id: json['id'],
    name: json['name'],
    address: json['address'],
    type: PrinterType.values.firstWhere((e) => e.toString() == json['type']),
    model: json['model'] ?? '',
    signalStrength: json['signalStrength'] ?? 0,
    isConnected: json['isConnected'] ?? false,
  );

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? address,
    PrinterType? type,
    String? model,
    int? signalStrength,
    bool? isConnected,
  }) => PrinterDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    type: type ?? this.type,
    model: model ?? this.model,
    signalStrength: signalStrength ?? this.signalStrength,
    isConnected: isConnected ?? this.isConnected,
  );
}

/// Comprehensive printing service with WiFi and Bluetooth support
class PrintingService with ChangeNotifier {
  final SharedPreferences _prefs;
  final NetworkInfo _networkInfo;
  AppSettings _settings;
  
  // Connection management
  PrinterDevice? _connectedPrinter;
  Socket? _wifiSocket;
  BluetoothConnection? _bluetoothConnection;
  
  // Manual scanning control
  bool _isManualScanningEnabled = false;
  bool _isCurrentlyScanning = false;
  
  // Settings keys
  static const String _connectedPrinterKey = 'connected_printer';
  static const String _settingsKey = 'printing_settings';
  
  // Print settings
  int _paperWidth = 80; // mm
  String _printQuality = 'High';
  String _printSpeed = 'Normal';
  bool _enableHeaderLogo = true;
  String _footerMessage = 'Thank you for dining with us!';
  bool _printOrderDetails = true;
  bool _autoPrintOrders = false;
  bool _printKitchenCopy = true;

  PrintingService(this._prefs, this._networkInfo) : _settings = AppSettings() {
    _loadSettings();
    _loadConnectedPrinter();
  }

  // Getters
  PrinterDevice? get connectedPrinter => _connectedPrinter;
  bool get isConnected => _connectedPrinter != null;
  bool get isManualScanningEnabled => _isManualScanningEnabled;
  bool get isCurrentlyScanning => _isCurrentlyScanning;
  int get paperWidth => _paperWidth;
  String get printQuality => _printQuality;
  String get printSpeed => _printSpeed;
  bool get enableHeaderLogo => _enableHeaderLogo;
  String get footerMessage => _footerMessage;
  bool get printOrderDetails => _printOrderDetails;
  bool get autoPrintOrders => _autoPrintOrders;
  bool get printKitchenCopy => _printKitchenCopy;

  Future<void> _loadSettings() async {
    final String? settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        _settings = AppSettings.fromJson(settingsMap);
        
        // Load print settings
        _paperWidth = settingsMap['paperWidth'] ?? 80;
        _printQuality = settingsMap['printQuality'] ?? 'High';
        _printSpeed = settingsMap['printSpeed'] ?? 'Normal';
        _enableHeaderLogo = settingsMap['enableHeaderLogo'] ?? true;
        _footerMessage = settingsMap['footerMessage'] ?? 'Thank you for dining with us!';
        _printOrderDetails = settingsMap['printOrderDetails'] ?? true;
        _autoPrintOrders = settingsMap['autoPrintOrders'] ?? false;
        _printKitchenCopy = settingsMap['printKitchenCopy'] ?? true;
        
        _safeNotifyListeners();
      } catch (e) {
        debugPrint('Error loading printing settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final settingsMap = _settings.toJson();
    settingsMap.addAll({
      'paperWidth': _paperWidth,
      'printQuality': _printQuality,
      'printSpeed': _printSpeed,
      'enableHeaderLogo': _enableHeaderLogo,
      'footerMessage': _footerMessage,
      'printOrderDetails': _printOrderDetails,
      'autoPrintOrders': _autoPrintOrders,
      'printKitchenCopy': _printKitchenCopy,
    });
    
    final String settingsJson = jsonEncode(settingsMap);
    await _prefs.setString(_settingsKey, settingsJson);
  }

  Future<void> _loadConnectedPrinter() async {
    final String? printerJson = _prefs.getString(_connectedPrinterKey);
    if (printerJson != null) {
      try {
        final Map<String, dynamic> printerMap = jsonDecode(printerJson);
        _connectedPrinter = PrinterDevice.fromJson(printerMap);
        _safeNotifyListeners();
      } catch (e) {
        debugPrint('Error loading connected printer: $e');
      }
    }
  }

  Future<void> _saveConnectedPrinter() async {
    if (_connectedPrinter != null) {
      final String printerJson = jsonEncode(_connectedPrinter!.toJson());
      await _prefs.setString(_connectedPrinterKey, printerJson);
    } else {
      await _prefs.remove(_connectedPrinterKey);
    }
  }

  /// Scan for available printers by type
  Future<List<PrinterDevice>> scanForPrinters(PrinterType type) async {
    if (!_isManualScanningEnabled) {
      debugPrint('Manual scanning not enabled. Call enableManualScanning() first.');
      return [];
    }
    
    if (_isCurrentlyScanning) {
      debugPrint('Already scanning for printers. Please wait...');
      return [];
    }
    
    _isCurrentlyScanning = true;
    _safeNotifyListeners();
    
    try {
      switch (type) {
        case PrinterType.wifi:
          return await _scanWiFiPrinters();
        case PrinterType.bluetooth:
          return await _scanBluetoothPrinters();
      }
    } finally {
      _isCurrentlyScanning = false;
      _safeNotifyListeners();
    }
  }

  /// Scan for WiFi printers on the network
  Future<List<PrinterDevice>> _scanWiFiPrinters() async {
    final List<PrinterDevice> printers = [];
    
    try {
      debugPrint('Starting comprehensive WiFi printer scan...');
      
      // Double check that manual scanning is enabled
      if (!_isManualScanningEnabled) {
        debugPrint('WiFi scanning aborted - manual scanning not enabled');
        return printers;
      }
      
      // Get current WiFi network info
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) {
        debugPrint('No WiFi connection detected');
        return printers;
      }
      
      // Extract network subnet (e.g., 192.168.1.x from 192.168.1.50)
      final parts = wifiIP.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
        debugPrint('Scanning WiFi subnet: $subnet.* on multiple ports (comprehensive scan)');
        
        // Common printer ports
        final printerPorts = [9100, 515, 631, 9101, 9102];
        
        // More comprehensive IP ranges for printers
        final commonPrinterIPs = <String>[];
        
        // Add common printer IP ranges
        for (int i = 1; i <= 254; i++) {
          // Skip broadcast and network addresses
          if (i == 0 || i == 255) continue;
          
          // Priority IPs (common printer ranges)
          if ((i >= 100 && i <= 120) ||  // 192.168.x.100-120
              (i >= 200 && i <= 220) ||  // 192.168.x.200-220
              (i >= 50 && i <= 70) ||    // 192.168.x.50-70
              (i >= 150 && i <= 170) ||  // 192.168.x.150-170
              (i >= 10 && i <= 30)) {    // 192.168.x.10-30
            commonPrinterIPs.insert(0, '$subnet.$i'); // Insert at beginning for priority
          } else {
            commonPrinterIPs.add('$subnet.$i'); // Add at end for full scan
          }
        }
        
        // Skip your own IP to avoid self-connection
        final yourIP = parts[3];
        commonPrinterIPs.removeWhere((ip) => ip.endsWith('.$yourIP'));
        
        debugPrint('Scanning ${commonPrinterIPs.length} IPs on ${printerPorts.length} ports...');
        
        // Process IPs in small batches to avoid network overload
        for (int i = 0; i < commonPrinterIPs.length; i += 5) {
          // Check if scanning is still enabled
          if (!_isManualScanningEnabled) {
            debugPrint('WiFi scanning stopped - manual scanning disabled during scan');
            break;
          }
          
          final batch = commonPrinterIPs.skip(i).take(5);
          final futures = <Future<PrinterDevice?>>[];
          
          // Test each IP on each port
          for (final ip in batch) {
            for (final port in printerPorts) {
              futures.add(_testAndCreatePrinterDevice(ip, port));
            }
          }
          
          // Wait for this batch to complete
          final batchResults = await Future.wait(futures);
          
          for (final printer in batchResults) {
            if (printer != null) {
              // Avoid duplicates (same IP, different port)
              final existingPrinter = printers.where((p) => 
                p.address.split(':')[0] == printer.address.split(':')[0]
              ).firstOrNull;
              
              if (existingPrinter == null) {
                printers.add(printer);
                debugPrint('Found WiFi printer: ${printer.name} at ${printer.address}');
              }
            }
          }
          
          // Progress update every 25 IPs
          if ((i + 5) % 25 == 0) {
            debugPrint('Scanned ${i + 5}/${commonPrinterIPs.length} IPs... Found ${printers.length} printers so far');
          }
          
          // Small delay between batches to be network-friendly
          if (i + 5 < commonPrinterIPs.length) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
      }
      
      debugPrint('Comprehensive WiFi scan completed - found ${printers.length} WiFi printers');
      
    } catch (e) {
      debugPrint('Error in comprehensive WiFi printer scan: $e');
    }

    return printers;
  }

  /// Test a specific IP and port for printer connectivity
  Future<PrinterDevice?> _testAndCreatePrinterDevice(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip, 
        port, 
        timeout: const Duration(milliseconds: 300) // Slightly longer timeout for better detection
      );
      
      // Try to identify printer type by sending a simple ESC/POS command
      String printerModel = 'Network Printer';
      String printerType = 'ESC/POS Compatible';
      
      try {
        // Send status request to identify printer
        socket.add([0x10, 0x04, 0x01]); // ESC/POS: Transmit printer status
        await socket.flush();
        
        // Wait for response (with timeout)
        final response = await socket.timeout(const Duration(milliseconds: 100)).first;
        if (response.isNotEmpty) {
          printerModel = 'ESC/POS Printer';
          printerType = _identifyPrinterType(port);
        }
      } catch (e) {
        // Printer might not support status requests, but connection worked
        printerType = _identifyPrinterType(port);
      }
      
      await socket.close();
      
      // Create printer device if connection successful
      final signalStrength = _calculateSignalStrength(ip);
      return PrinterDevice(
        id: 'wifi_${ip.replaceAll('.', '_')}_$port',
        name: '$printerModel ($ip:$port)',
        address: '$ip:$port',
        type: PrinterType.wifi,
        model: printerType,
        signalStrength: signalStrength,
      );
      
    } catch (e) {
      // Connection failed - not a printer or not available
      return null;
    }
  }

  /// Identify printer type based on port
  String _identifyPrinterType(int port) {
    switch (port) {
      case 9100:
        return 'RAW/ESC-POS Printer';
      case 515:
        return 'LPR/LPD Printer';
      case 631:
        return 'IPP Printer';
      case 9101:
        return 'Parallel Port Printer';
      case 9102:
        return 'Serial Port Printer';
      default:
        return 'Network Printer';
    }
  }
  
  /// Manually add a printer by IP address
  Future<PrinterDevice?> addPrinterByIP(String ipAddress, {int port = 9100}) async {
    try {
      debugPrint('Testing manual IP: $ipAddress:$port');
      
      // Validate IP format
      final parts = ipAddress.split('.');
      if (parts.length != 4) {
        throw Exception('Invalid IP address format');
      }
      
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          throw Exception('Invalid IP address range');
        }
      }
      
      // Test connection to the specific IP and port
      final printer = await _testAndCreatePrinterDevice(ipAddress, port);
      if (printer != null) {
        debugPrint('Successfully connected to manual IP: ${printer.address}');
        return printer;
      } else {
        throw Exception('No printer found at $ipAddress:$port');
      }
    } catch (e) {
      debugPrint('Error testing manual IP $ipAddress:$port - $e');
      throw Exception('Failed to connect to $ipAddress:$port - $e');
    }
  }

  /// Scan for Bluetooth printers
  Future<List<PrinterDevice>> _scanBluetoothPrinters() async {
    final List<PrinterDevice> printers = [];
    
    try {
      debugPrint('Scanning for Bluetooth printers...');
      
      // Check if Bluetooth is enabled
      final isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (isEnabled != true) {
        debugPrint('Bluetooth is not enabled');
        return printers;
      }
      
      // Get bonded devices first (previously paired printers)
      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      
      for (final device in bondedDevices) {
        if (_isPrinterDevice(device.name ?? '')) {
          printers.add(PrinterDevice(
            id: 'bt_bonded_${device.address.replaceAll(':', '_')}',
            name: device.name ?? 'Unknown Printer',
            address: device.address,
            type: PrinterType.bluetooth,
            model: 'Bluetooth Printer',
            signalStrength: 90, // Bonded devices typically have good signal
          ));
        }
      }
      
      // Discover new devices
      try {
        final discoveryResults = await FlutterBluetoothSerial.instance.startDiscovery();
        
        await for (final result in discoveryResults) {
          final device = result.device;
          final deviceName = device.name ?? '';
          
          // Check if this looks like a printer and isn't already in our list
          if (_isPrinterDevice(deviceName) && 
              !printers.any((p) => p.address == device.address)) {
            
            final signalStrength = (result.rssi + 100).clamp(0, 100); // Convert RSSI to percentage
            
            printers.add(PrinterDevice(
              id: 'bt_discovered_${device.address.replaceAll(':', '_')}',
              name: deviceName,
              address: device.address,
              type: PrinterType.bluetooth,
              model: 'Bluetooth Printer',
              signalStrength: signalStrength,
            ));
          }
        }
      } catch (discoveryError) {
        debugPrint('Bluetooth discovery error (using bonded devices only): $discoveryError');
      }
      
      debugPrint('Found ${printers.length} Bluetooth printers');
      
    } catch (e) {
      debugPrint('Error scanning Bluetooth printers: $e');
    }

    return printers;
  }

  /// Test if a network printer is available at the given IP and port
  Future<bool> _testPrinterConnection(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 200));
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Calculate signal strength based on IP (simplified)
  int _calculateSignalStrength(String ip) {
    // Simple calculation based on last octet (closer to router = stronger signal)
    final parts = ip.split('.');
    final lastOctet = int.tryParse(parts.last) ?? 100;
    return (255 - lastOctet).clamp(30, 100);
  }

  /// Check if a Bluetooth device is likely a printer
  bool _isPrinterDevice(String deviceName) {
    final printerKeywords = ['printer', 'print', 'pos', 'thermal', 'receipt', 'epson', 'star', 'zebra'];
    final lowerName = deviceName.toLowerCase();
    return printerKeywords.any((keyword) => lowerName.contains(keyword));
  }

  /// Connect to a printer device
  Future<bool> connectToPrinter(PrinterDevice printer) async {
    try {
      // Disconnect existing connection
      await disconnectPrinter();

      debugPrint('Connecting to ${printer.name} at ${printer.address}...');
      
      // Connect to real printer based on type
      switch (printer.type) {
        case PrinterType.wifi:
          return await _connectToWiFiPrinter(printer);
        case PrinterType.bluetooth:
          return await _connectToBluetoothPrinter(printer);
      }
    } catch (e) {
      debugPrint('Error connecting to printer: $e');
      return false;
    }
  }

  /// Connect to WiFi printer
  Future<bool> _connectToWiFiPrinter(PrinterDevice printer) async {
    try {
      final parts = printer.address.split(':');
      final ip = parts[0];
      final port = int.parse(parts[1]);

      _wifiSocket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _connectedPrinter = printer.copyWith(isConnected: true);
      await _saveConnectedPrinter();
      _safeNotifyListeners();
      
      debugPrint('Connected to WiFi printer: ${printer.address}');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to WiFi printer: $e');
      return false;
    }
  }

  /// Connect to Bluetooth printer
  Future<bool> _connectToBluetoothPrinter(PrinterDevice printer) async {
    try {
      _bluetoothConnection = await BluetoothConnection.toAddress(printer.address);
      _connectedPrinter = printer.copyWith(isConnected: true);
      await _saveConnectedPrinter();
      _safeNotifyListeners();
      
      debugPrint('Connected to Bluetooth printer: ${printer.address}');
      return true;
    } catch (e) {
      debugPrint('Failed to connect to Bluetooth printer: $e');
      return false;
    }
  }

  /// Disconnect from current printer
  Future<void> disconnectPrinter() async {
    try {
      if (_wifiSocket != null) {
        await _wifiSocket!.close();
        _wifiSocket = null;
      }
      
      if (_bluetoothConnection != null) {
        await _bluetoothConnection!.close();
        _bluetoothConnection = null;
      }

      _connectedPrinter = null;
      await _saveConnectedPrinter();
      _safeNotifyListeners();
      
      debugPrint('Disconnected from printer');
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
    }
  }

  /// Get currently connected printer
  Future<PrinterDevice?> getConnectedPrinter() async {
    return _connectedPrinter;
  }

  /// Print a test receipt
  Future<void> printTestReceipt() async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    final testContent = _generateTestReceipt();
    await _sendToPrinter(testContent);
  }

  /// Print a sample receipt with realistic data
  Future<void> printSampleReceipt() async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    final sampleContent = _generateSampleReceipt();
    await _sendToPrinter(sampleContent);
  }

  /// Print customer receipt
  Future<bool> printReceipt(Order order) async {
    try {
      final receipt = _generateReceipt(order);
      
      // Check if printer is connected
      if (_connectedPrinter == null) {
        debugPrint('No printer connected - cannot print receipt for order: ${order.orderNumber}');
        return false;
      }
      
      // Send to connected printer
      await _sendToPrinter(receipt);
      debugPrint('Customer receipt printed successfully for order: ${order.orderNumber}');
      return true;
    } catch (e) {
      debugPrint('Failed to print receipt: $e');
      return false;
    }
  }

  /// Print kitchen ticket
  Future<bool> printKitchenTicket(Order order) async {
    try {
      final ticket = _generateKitchenTicket(order);
      
      // Check if printer is connected
      if (_connectedPrinter == null) {
        debugPrint('No printer connected - cannot print kitchen ticket for order: ${order.orderNumber}');
        return false;
      }
      
      // Send to connected printer
      await _sendToPrinter(ticket);
      debugPrint('Kitchen ticket printed successfully for order: ${order.orderNumber}');
      return true;
    } catch (e) {
      debugPrint('Failed to print kitchen ticket: $e');
      return false;
    }
  }

  /// Generate test receipt content
  String _generateTestReceipt() {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    buffer.writeln('TEST RECEIPT');
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment
    buffer.writeln('Printer: ${_connectedPrinter!.name}');
    buffer.writeln('Address: ${_connectedPrinter!.address}');
    buffer.writeln('Type: ${_connectedPrinter!.type.toString().split('.').last}');
    buffer.writeln('Paper Width: ${_paperWidth}mm');
    buffer.writeln('Print Quality: $_printQuality');
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('');
    buffer.writeln('If you can read this clearly,');
    buffer.writeln('your printer is working correctly!');
    buffer.writeln('');
    
    // Cut paper
    buffer.write('\x1D\x56\x41\x10');
    
    return buffer.toString();
  }

  /// Generate sample receipt with realistic data
  String _generateSampleReceipt() {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    if (_enableHeaderLogo) {
      buffer.writeln('RESTAURANT POS SYSTEM');
      buffer.writeln('123 Main Street');
      buffer.writeln('City, State 12345');
      buffer.writeln('Phone: (555) 123-4567');
    }
    
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment
    
    // Order details
    buffer.writeln('Order #: SAMPLE-001');
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 19)}');
    buffer.writeln('Type: Dine-In');
    buffer.writeln('Table: 5');
    buffer.writeln('Server: John Doe');
    buffer.writeln('');
    
    // Items
    buffer.writeln('ITEMS:');
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    buffer.writeln('2x Burger Deluxe          \$24.00');
    buffer.writeln('1x Caesar Salad           \$12.00');
    buffer.writeln('2x Soft Drink             \$6.00');
    buffer.writeln('1x Chocolate Cake         \$8.00');
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    
    // Totals
    buffer.writeln('Subtotal:                 \$50.00');
    buffer.writeln('Tax (13%):                \$6.50');
    buffer.writeln('Tip (18%):                \$9.00');
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    buffer.writeln('TOTAL:                    \$65.50');
    buffer.writeln('');
    
    if (_footerMessage.isNotEmpty) {
      buffer.write('\x1B\x61\x01'); // Center alignment
      buffer.writeln(_footerMessage);
    }
    
    buffer.writeln('');
    
    // Cut paper
    buffer.write('\x1D\x56\x41\x10');
    
    return buffer.toString();
  }

  /// Generate receipt content for an order
  String _generateReceipt(Order order) {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    // Header
    if (_enableHeaderLogo && _settings.enableReceiptHeader) {
      buffer.writeln(_settings.businessName);
      if (_settings.businessAddress.isNotEmpty) {
        buffer.writeln(_settings.businessAddress);
      }
      if (_settings.businessPhone.isNotEmpty) {
        buffer.writeln(_settings.businessPhone);
      }
    }
    
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment

    // Order details
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Date: ${_formatDateTime(order.orderTime)}');
    buffer.writeln('Type: ${order.type.toString().split('.').last}');
    if (order.tableId != null) {
      buffer.writeln('Table: ${order.tableId}');
    }
    buffer.writeln('');

    // Items
    if (_printOrderDetails) {
      buffer.writeln('ITEMS:');
      buffer.writeln('${'-' * (_paperWidth ~/ 2)}');

      for (final item in order.items) {
        final itemName = item.menuItem.name;
        final quantity = item.quantity.toString();
        final price = '${_settings.currencySymbol}${item.totalPrice.toStringAsFixed(2)}';
        
        buffer.writeln('${quantity}x $itemName');
        buffer.writeln('${' ' * 25}$price');
        
        if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
          buffer.writeln('  ${item.selectedVariant}');
        }
        
        if (item.selectedModifiers.isNotEmpty) {
          for (final modifier in item.selectedModifiers) {
            buffer.writeln('  + $modifier');
          }
        }
        
        if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
          buffer.writeln('  Note: ${item.specialInstructions}');
        }
        
        if (item.notes != null && item.notes!.isNotEmpty) {
          buffer.writeln('  Chef: ${item.notes}');
        }
        
        buffer.writeln('');
      }

      buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    }

    // Totals
    buffer.writeln('Subtotal: ${_settings.currencySymbol}${order.subtotal.toStringAsFixed(2)}');
    
    if (order.discountAmount != null && order.discountAmount! > 0) {
      buffer.writeln('Discount: -${_settings.currencySymbol}${order.discountAmount!.toStringAsFixed(2)}');
    }
    
    if (_settings.enableTax && order.taxAmount > 0) {
      buffer.writeln('${_settings.taxName}: ${_settings.currencySymbol}${order.taxAmount.toStringAsFixed(2)}');
    }
    
    if (order.gratuityAmount != null && order.gratuityAmount! > 0) {
      buffer.writeln('Gratuity: ${_settings.currencySymbol}${order.gratuityAmount!.toStringAsFixed(2)}');
    }
    
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    buffer.writeln('TOTAL: ${_settings.currencySymbol}${order.totalAmount.toStringAsFixed(2)}');

    // Footer
    if (_footerMessage.isNotEmpty) {
      buffer.writeln('');
      buffer.write('\x1B\x61\x01'); // Center alignment
      buffer.writeln(_footerMessage);
    }

    buffer.writeln('');
    
    // Cut paper
    buffer.write('\x1D\x56\x41\x10');

    return buffer.toString();
  }

  /// Generate kitchen ticket content
  String _generateKitchenTicket(Order order) {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    // Header
    buffer.writeln('KITCHEN TICKET');
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment
    
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Time: ${_formatTime(order.orderTime)}');
    buffer.writeln('Type: ${order.type.toString().split('.').last}');
    if (order.tableId != null) {
      buffer.writeln('Table: ${order.tableId}');
    }
    if (order.isUrgent) {
      buffer.write('\x1B\x61\x01'); // Center alignment
      buffer.writeln('*** URGENT ***');
      buffer.write('\x1B\x61\x00'); // Left alignment
    }
    buffer.writeln('');

    // Items
    for (final item in order.items) {
      buffer.writeln('${item.quantity}x ${item.menuItem.name}');
      
      if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
        buffer.writeln('  ${item.selectedVariant}');
      }
      
      if (item.selectedModifiers.isNotEmpty) {
        for (final modifier in item.selectedModifiers) {
          buffer.writeln('  + $modifier');
        }
      }
      
      if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
        buffer.writeln('  Note: ${item.specialInstructions}');
      }
      
      if (item.notes != null && item.notes!.isNotEmpty) {
        buffer.writeln('  Chef: ${item.notes}');
      }
      
      buffer.writeln('');
    }

    // Special instructions
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      buffer.writeln('SPECIAL INSTRUCTIONS:');
      buffer.writeln(order.specialInstructions);
      buffer.writeln('');
    }

    // Chef notes
    if (order.notes.isNotEmpty) {
      buffer.writeln('CHEF NOTES:');
      for (final note in order.notes) {
        if (note.isInternal) {
          buffer.writeln('- ${note.note}');
        }
      }
      buffer.writeln('');
    }

    // Cut paper
    buffer.write('\x1D\x56\x41\x10');

    return buffer.toString();
  }

  /// Send content to printer
  Future<void> _sendToPrinter(String content) async {
    if (_connectedPrinter == null) {
      throw Exception('No printer connected');
    }

    try {
      debugPrint('Sending ${content.length} characters to ${_connectedPrinter!.name}');
      
      // Send to actual hardware printer
      final data = Uint8List.fromList(content.codeUnits);
      
      switch (_connectedPrinter!.type) {
        case PrinterType.wifi:
          if (_wifiSocket != null) {
            _wifiSocket!.add(data);
            await _wifiSocket!.flush();
          } else {
            throw Exception('WiFi printer connection not established');
          }
          break;
        case PrinterType.bluetooth:
          if (_bluetoothConnection != null) {
            _bluetoothConnection!.output.add(data);
            await _bluetoothConnection!.output.allSent;
          } else {
            throw Exception('Bluetooth printer connection not established');
          }
          break;
      }
      
      debugPrint('Content sent to printer successfully');
    } catch (e) {
      debugPrint('Error sending to printer: $e');
      throw Exception('Failed to send to printer: $e');
    }
  }

  /// Update print settings
  Future<void> updatePrintSettings({
    int? paperWidth,
    String? printQuality,
    String? printSpeed,
    bool? enableHeaderLogo,
    String? footerMessage,
    bool? printOrderDetails,
    bool? autoPrintOrders,
    bool? printKitchenCopy,
  }) async {
    if (paperWidth != null) _paperWidth = paperWidth;
    if (printQuality != null) _printQuality = printQuality;
    if (printSpeed != null) _printSpeed = printSpeed;
    if (enableHeaderLogo != null) _enableHeaderLogo = enableHeaderLogo;
    if (footerMessage != null) _footerMessage = footerMessage;
    if (printOrderDetails != null) _printOrderDetails = printOrderDetails;
    if (autoPrintOrders != null) _autoPrintOrders = autoPrintOrders;
    if (printKitchenCopy != null) _printKitchenCopy = printKitchenCopy;
    
    await _saveSettings();
    _safeNotifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetSettings() async {
    _paperWidth = 80;
    _printQuality = 'High';
    _printSpeed = 'Normal';
    _enableHeaderLogo = true;
    _footerMessage = 'Thank you for dining with us!';
    _printOrderDetails = true;
    _autoPrintOrders = false;
    _printKitchenCopy = true;
    
    await _saveSettings();
    _safeNotifyListeners();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  void _safeNotifyListeners() {
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Legacy methods for backward compatibility
  String? get selectedPrinter => _connectedPrinter?.address;
  List<String> get availablePrinters => [];
  bool get isScanning => false;
  String? get error => null;

  void selectPrinter(String printer) {
    // Legacy method - no longer used
  }

  Future<void> scanForPrintersLegacy() async {
    // Legacy method - use scanForPrinters(PrinterType) instead
  }

  /// Enable manual scanning for WiFi printers
  void enableManualScanning() {
    _isManualScanningEnabled = true;
    debugPrint('Manual printer scanning enabled');
    _safeNotifyListeners();
  }

  /// Disable manual scanning (default state)
  void disableManualScanning() {
    _isManualScanningEnabled = false;
    debugPrint('Manual printer scanning disabled');
    _safeNotifyListeners();
  }

  /// Print order with segregated items based on printer assignments
  Future<void> printOrderSegregated(Order order, Map<String, List<OrderItem>> itemsByPrinter) async {
    try {
      debugPrint('Starting segregated printing for order: ${order.orderNumber}');
      
      // Print to each assigned printer
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        if (items.isEmpty) continue;
        
        debugPrint('Printing ${items.length} items to printer: $printerId');
        
        // Create a partial order with only the items for this printer
        final partialOrder = Order(
          id: order.id,
          orderNumber: order.orderNumber,
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          customerEmail: order.customerEmail,
          items: items,
          subtotal: items.fold<double>(0.0, (sum, item) => sum + item.totalPrice),
          taxAmount: 0.0, // Don't duplicate tax on partial orders
          discountAmount: 0.0, // Don't duplicate discount on partial orders
          gratuityAmount: 0.0, // Don't duplicate gratuity on partial orders
          totalAmount: items.fold<double>(0.0, (sum, item) => sum + item.totalPrice),
          status: order.status,
          type: order.type,
          orderTime: order.orderTime,
          tableId: order.tableId,
          isUrgent: order.isUrgent,
          specialInstructions: order.specialInstructions,
          notes: order.notes,
          paymentMethod: order.paymentMethod,
          createdAt: order.createdAt,
          updatedAt: order.updatedAt,
        );
        
        // Print kitchen ticket for this printer
        await _printToSpecificPrinter(partialOrder, printerId, true);
      }
      
      debugPrint('Segregated printing completed for order: ${order.orderNumber}');
    } catch (e) {
      debugPrint('Error in segregated printing: $e');
      throw Exception('Failed to print segregated order: $e');
    }
  }

  /// Print to a specific printer by ID
  Future<void> _printToSpecificPrinter(Order order, String printerId, bool isKitchenTicket) async {
    try {
      // Find the printer by ID
      PrinterDevice? targetPrinter;
      
      // Restaurant printer stations - configure with actual IP addresses
      final mockPrinters = [
        PrinterDevice(id: 'printer_1', name: 'Main Kitchen Printer', address: '192.168.1.100:9100', type: PrinterType.wifi),
        PrinterDevice(id: 'printer_2', name: 'Tandoor Station', address: '192.168.1.101:9100', type: PrinterType.wifi),
        PrinterDevice(id: 'printer_3', name: 'Curry Station', address: '192.168.1.102:9100', type: PrinterType.wifi),
        PrinterDevice(id: 'printer_4', name: 'Appetizer Station', address: '192.168.1.103:9100', type: PrinterType.wifi),
        PrinterDevice(id: 'printer_5', name: 'Grill Station', address: '192.168.1.104:9100', type: PrinterType.wifi),
        PrinterDevice(id: 'printer_6', name: 'Bar/Beverage Station', address: '192.168.1.105:9100', type: PrinterType.wifi),
      ];
      
      targetPrinter = mockPrinters.firstWhere(
        (printer) => printer.id == printerId,
        orElse: () => throw Exception('Printer not found: $printerId'),
      );
      
      debugPrint('Connecting to printer: ${targetPrinter.name} (${targetPrinter.address})');
      
      // Connect to the specific printer
      await _connectToSpecificPrinter(targetPrinter);
      
      // Generate and send the content
      final content = isKitchenTicket 
          ? _generateKitchenTicketSegregated(order, targetPrinter.name)
          : _generateReceipt(order);
      
      await _sendToPrinter(content);
      
      debugPrint('Successfully printed to ${targetPrinter.name}');
      
    } catch (e) {
      debugPrint('Error printing to specific printer: $e');
      throw Exception('Failed to print to printer $printerId: $e');
    }
  }

  /// Connect to a specific printer for segregated printing
  Future<void> _connectToSpecificPrinter(PrinterDevice printer) async {
    try {
      if (printer.type == PrinterType.wifi) {
        // Close existing connection if different printer
        if (_wifiSocket != null && _connectedPrinter?.id != printer.id) {
          await _wifiSocket!.close();
          _wifiSocket = null;
        }
        
        // Connect to the specific printer
        if (_wifiSocket == null || _connectedPrinter?.id != printer.id) {
          final addressParts = printer.address.split(':');
          final ip = addressParts[0];
          final port = addressParts.length > 1 ? int.tryParse(addressParts[1]) ?? 9100 : 9100;
          
          _wifiSocket = await Socket.connect(
            ip,
            port,
            timeout: const Duration(seconds: 5),
          );
          
          debugPrint('Connected to WiFi printer: ${printer.address}');
        }
      }
      // Add Bluetooth support if needed
      
    } catch (e) {
      debugPrint('Error connecting to printer ${printer.name}: $e');
      throw Exception('Failed to connect to printer: $e');
    }
  }

  /// Generate kitchen ticket with printer-specific header
  String _generateKitchenTicketSegregated(Order order, String printerName) {
    final buffer = StringBuffer();
    
    // ESC/POS commands for 80mm paper
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment
    
    // Header with printer name
    buffer.writeln('KITCHEN TICKET');
    buffer.writeln('Station: $printerName');
    buffer.writeln('');
    buffer.write('\x1B\x61\x00'); // Left alignment
    
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Customer: ${order.customerName ?? 'Guest'}');
    buffer.writeln('Time: ${_formatTime(order.orderTime)}');
    buffer.writeln('Type: ${order.type.toString().split('.').last}');
    if (order.tableId != null) {
      buffer.writeln('Table: ${order.tableId}');
    }
    if (order.isUrgent) {
      buffer.write('\x1B\x61\x01'); // Center alignment
      buffer.writeln('*** URGENT ***');
      buffer.write('\x1B\x61\x00'); // Left alignment
    }
    buffer.writeln('');

    // Items for this station
    for (final item in order.items) {
      buffer.writeln('${item.quantity}x ${item.menuItem.name}');
      
      if (item.selectedVariant != null && item.selectedVariant!.isNotEmpty) {
        buffer.writeln('  ${item.selectedVariant}');
      }
      
      if (item.selectedModifiers.isNotEmpty) {
        for (final modifier in item.selectedModifiers) {
          buffer.writeln('  + $modifier');
        }
      }
      
      if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
        buffer.writeln('  Note: ${item.specialInstructions}');
      }
      
      if (item.notes != null && item.notes!.isNotEmpty) {
        buffer.writeln('  Chef: ${item.notes}');
      }
      
      buffer.writeln('');
    }

    // Special instructions
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      buffer.writeln('SPECIAL INSTRUCTIONS:');
      buffer.writeln(order.specialInstructions);
      buffer.writeln('');
    }

    // Footer
    buffer.writeln('${'-' * (_paperWidth ~/ 2)}');
    buffer.write('\x1B\x61\x01'); // Center alignment
    buffer.writeln('Prepared at: $printerName');
    buffer.write('\x1B\x61\x00'); // Left alignment
    buffer.writeln('');

    // Cut paper
    buffer.write('\x1D\x56\x41\x10');

    return buffer.toString();
  }

  /// Get segregated items by printer assignments
  Future<Map<String, List<OrderItem>>> segregateOrderItems(Order order, dynamic printerAssignmentService) async {
    final Map<String, List<OrderItem>> itemsByPrinter = {};
    
    try {
      for (final item in order.items) {
        // Get printer assignment for this menu item
        final assignment = printerAssignmentService.getAssignmentForMenuItem(
          item.menuItem.id,
          item.menuItem.categoryId,
        );
        
        String printerId;
        if (assignment != null) {
          printerId = assignment.printerId;
          debugPrint('Item ${item.menuItem.name} assigned to printer: ${assignment.printerName}');
        } else {
          // Default printer if no assignment found
          printerId = 'printer_1'; // Kitchen Main Printer
          debugPrint('Item ${item.menuItem.name} using default printer');
        }
        
        if (!itemsByPrinter.containsKey(printerId)) {
          itemsByPrinter[printerId] = [];
        }
        itemsByPrinter[printerId]!.add(item);
      }
      
      debugPrint('Items segregated across ${itemsByPrinter.length} printers');
      return itemsByPrinter;
      
    } catch (e) {
      debugPrint('Error segregating order items: $e');
      // Fallback: send all items to default printer
      return {'printer_1': order.items};
    }
  }

  /// Update printer configuration
  void updatePrinterConfiguration(PrinterDevice updatedPrinter) {
    // Update the connected printer if it matches
    if (_connectedPrinter?.id == updatedPrinter.id) {
      _connectedPrinter = updatedPrinter;
    }
    
    // Close existing connection to force reconnection with new settings
    _wifiSocket?.destroy();
    _wifiSocket = null;
    
    notifyListeners();
    debugPrint('Updated printer configuration for ${updatedPrinter.name}');
  }

  /// Print a test receipt for configuration testing (overloaded version)
  Future<void> printTestReceiptForPrinter(PrinterDevice printer) async {
    const testContent = '''
================================
        TEST RECEIPT
================================
Printer: %PRINTER_NAME%
Address: %PRINTER_ADDRESS%
Model: %PRINTER_MODEL%
Date: %CURRENT_DATE%
Time: %CURRENT_TIME%
================================
This is a test print to verify
your printer configuration.

If you can read this clearly,
your printer is working correctly!
================================
        Configuration Test
        Restaurant POS System
================================


''';
    
    final now = DateTime.now();
    String formattedContent = testContent
        .replaceAll('%PRINTER_NAME%', printer.name)
        .replaceAll('%PRINTER_ADDRESS%', printer.address)
        .replaceAll('%PRINTER_MODEL%', printer.model ?? 'Unknown')
        .replaceAll('%CURRENT_DATE%', '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
        .replaceAll('%CURRENT_TIME%', '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    
    // Add ESC/POS commands for 80mm thermal printing
    final buffer = StringBuffer();
    buffer.write('\x1B\x40'); // Initialize printer
    buffer.write('\x1B\x61\x01'); // Center alignment for header
    buffer.write(formattedContent);
    buffer.write('\x1D\x56\x41\x10'); // Cut paper
    
    await _sendToSpecificPrinter(printer, buffer.toString());
  }
  
  /// Send content to a specific printer (dedicated method for configuration)
  Future<void> _sendToSpecificPrinter(PrinterDevice printer, String content) async {
    try {
      if (printer.type == PrinterType.wifi) {
        final addressParts = printer.address.split(':');
        final ip = addressParts[0];
        final port = addressParts.length > 1 ? int.tryParse(addressParts[1]) ?? 9100 : 9100;
        
        final socket = await Socket.connect(
          ip,
          port,
          timeout: const Duration(seconds: 5),
        );
        
        socket.add(content.codeUnits);
        await socket.flush();
        await socket.close();
        
        debugPrint('Successfully sent test print to ${printer.name}');
      } else {
        throw Exception('Printer type ${printer.type} not yet implemented for test printing');
      }
    } catch (e) {
      debugPrint('Error sending test print to ${printer.name}: $e');
      rethrow;
    }
  }
}