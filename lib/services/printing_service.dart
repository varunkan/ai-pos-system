import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table.dart' as restaurant_table;
import '../models/order.dart';
import '../models/user.dart';
import '../models/app_settings.dart';
import '../screens/print_preview_screen.dart';

class DiscoveredPrinter {
  final String ip;
  final String name;
  DiscoveredPrinter({required this.ip, this.name = 'Thermal Printer'});
}

class PrintingService with ChangeNotifier {
  final SharedPreferences _prefs;
  AppSettings _settings;
  static const String _printerIpKey = 'printer_ip_address';
  static const String _settingsKey = 'printing_settings';
  final NetworkInfo _networkInfo;
  String? _selectedPrinter;
  List<String> _availablePrinters = [];
  bool _isScanning = false;
  String? _error;

  PrintingService(this._prefs, this._networkInfo) : _settings = AppSettings() {
    _loadSettings();
  }

  String? get selectedPrinter => _selectedPrinter;
  List<String> get availablePrinters => _availablePrinters;
  bool get isScanning => _isScanning;
  String? get error => _error;

  Future<void> _loadSettings() async {
    final String? settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        _settings = AppSettings.fromJson(settingsMap);
        
        // Safely notify listeners
        try {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            try {
              notifyListeners();
            } catch (e) {
              debugPrint('Error notifying listeners during load settings: $e');
            }
          });
        } catch (e) {
          debugPrint('Error scheduling notification during load settings: $e');
        }
      } catch (e) {
        debugPrint('Error loading printing settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final String settingsJson = jsonEncode(_settings.toJson());
    await _prefs.setString(_settingsKey, settingsJson);
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await _saveSettings();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during update settings: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during update settings: $e');
    }
  }

  Future<void> savePrinterIp(String ipAddress) async {
    await _prefs.setString(_printerIpKey, ipAddress);
  }

  String? getSavedPrinterIp() {
    return _prefs.getString(_printerIpKey);
  }

  Future<void> scanForPrinters() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      debugPrint('Starting printer scan...');
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) {
        throw Exception('Could not get WiFi IP address');
      }

      // Extract subnet from IP (e.g., 192.168.1.100 -> 192.168.1.*)
      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      debugPrint('Scanning subnet: $subnet.* on port 9100');

      final List<String> foundPrinters = [];
      
      // Scan common printer ports
      for (int i = 1; i <= 254; i++) {
        final ip = '$subnet.$i';
        try {
          final socket = await Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 100));
          await socket.close();
          foundPrinters.add('$ip:9100');
        } catch (e) {
          // Connection failed, continue scanning
        }
      }

      setState(() {
        _availablePrinters = foundPrinters;
        _isScanning = false;
      });

      debugPrint('Printer discovery finished.');
    } catch (e) {
      setState(() {
        _error = 'Failed to scan for printers: $e';
        _isScanning = false;
      });
    }
  }

  void selectPrinter(String printer) {
    _selectedPrinter = printer;
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during select printer: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during select printer: $e');
    }
  }

  Future<bool> printReceipt(Order order) async {
    if (_selectedPrinter == null) {
      _error = 'No printer selected';
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during print receipt error: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during print receipt error: $e');
      }
      return false;
    }

    try {
      final receipt = _generateReceipt(order);
      await _sendToPrinter(receipt);
      return true;
    } catch (e) {
      _error = 'Failed to print receipt: $e';
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during print receipt error: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during print receipt error: $e');
      }
      return false;
    }
  }

  Future<bool> printKitchenTicket(Order order) async {
    if (_selectedPrinter == null) {
      _error = 'No printer selected';
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during print kitchen ticket error: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during print kitchen ticket error: $e');
      }
      return false;
    }

    try {
      final ticket = _generateKitchenTicket(order);
      await _sendToPrinter(ticket);
      return true;
    } catch (e) {
      _error = 'Failed to print kitchen ticket: $e';
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during print kitchen ticket error: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during print kitchen ticket error: $e');
      }
      return false;
    }
  }

  /// Returns the formatted receipt content for preview
  String getReceiptPreview(Order order) {
    return _generateReceipt(order);
  }

  /// Returns the formatted kitchen ticket content for preview
  String getKitchenTicketPreview(Order order) {
    return _generateKitchenTicket(order);
  }

  /// Shows print preview dialog and returns true if user wants to print
  Future<bool> showPrintPreview(BuildContext context, Order order, {bool isKitchenTicket = false}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => PrintPreviewScreen(
          order: order,
          user: _getCurrentUser(), // You'll need to implement this
          table: _getTableForOrder(order), // You'll need to implement this
          orderType: order.type.toString().split('.').last,
          isKitchenTicket: isKitchenTicket,
        ),
      ),
    );
    
    return result ?? false;
  }

  /// Helper method to get current user (you'll need to implement this based on your user management)
  User _getCurrentUser() {
    // TODO: Implement based on your user management system
    return User(
      id: 'current_user',
      name: 'Server',
      role: UserRole.server,
      pin: '0000',
    );
  }

  /// Helper method to get table for order (you'll need to implement this based on your table management)
  restaurant_table.Table? _getTableForOrder(Order order) {
    // TODO: Implement based on your table management system
    if (order.tableId != null) {
      return restaurant_table.Table(
        id: order.tableId!,
        number: int.tryParse(order.tableId!) ?? 1,
        capacity: 4,
        status: restaurant_table.TableStatus.occupied,
      );
    }
    return null;
  }

  String _generateReceipt(Order order) {
    final buffer = StringBuffer();
    
    // Header
    if (_settings.enableReceiptHeader) {
      buffer.writeln(_settings.businessName);
      if (_settings.businessAddress.isNotEmpty) {
        buffer.writeln(_settings.businessAddress);
      }
      if (_settings.businessPhone.isNotEmpty) {
        buffer.writeln(_settings.businessPhone);
      }
      buffer.writeln('');
    }

    // Order details
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Date: ${_formatDateTime(order.orderTime)}');
    buffer.writeln('Type: ${order.type.toString().split('.').last}');
    if (order.tableId != null) {
      buffer.writeln('Table: ${order.tableId}');
    }
    buffer.writeln('');

    // Items
    buffer.writeln('ITEMS:');
    buffer.writeln('${'Item'.padRight(30)} ${'Qty'.padLeft(5)} ${'Price'.padLeft(10)}');
    buffer.writeln('-' * 50);

    for (final item in order.items) {
      final itemName = item.menuItem.name;
      final quantity = item.quantity.toString();
      final price = '${_settings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}';
      
      buffer.writeln('${itemName.padRight(30)} ${quantity.padLeft(5)} ${price.padLeft(10)}');
      
      if (item.selectedVariant != null) {
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
    }

    buffer.writeln('-' * 50);

    // Totals
    buffer.writeln('${'Subtotal:'.padLeft(35)} ${_settings.currencySymbol}${order.subtotal.toStringAsFixed(2)}');
    
    if (_settings.enableTax && order.taxAmount > 0) {
      buffer.writeln('${_settings.taxName}:'.padLeft(35) + ' ${_settings.currencySymbol}${order.taxAmount.toStringAsFixed(2)}');
    }
    
    if (_settings.enableTips && order.tipAmount > 0) {
      buffer.writeln('${'Tip:'.padLeft(35)} ${_settings.currencySymbol}${order.tipAmount.toStringAsFixed(2)}');
    }
    
    buffer.writeln('${'TOTAL:'.padLeft(35)} ${_settings.currencySymbol}${order.totalAmount.toStringAsFixed(2)}');

    // Footer
    if (_settings.enableReceiptFooter) {
      buffer.writeln('');
      buffer.writeln(_settings.receiptFooterText);
    }

    return buffer.toString();
  }

  String _generateKitchenTicket(Order order) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('KITCHEN TICKET');
    buffer.writeln('Order #: ${order.orderNumber}');
    buffer.writeln('Time: ${_formatTime(order.orderTime)}');
    buffer.writeln('Type: ${order.type.toString().split('.').last}');
    if (order.tableId != null) {
      buffer.writeln('Table: ${order.tableId}');
    }
    if (order.isUrgent) {
      buffer.writeln('*** URGENT ***');
    }
    buffer.writeln('');

    // Items
    for (final item in order.items) {
      buffer.writeln('${item.quantity}x ${item.menuItem.name}');
      
      if (item.selectedVariant != null) {
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
      
      buffer.writeln('');
    }

    // Special instructions
    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) {
      buffer.writeln('SPECIAL INSTRUCTIONS:');
      buffer.writeln(order.specialInstructions);
      buffer.writeln('');
    }

    // Allergen warnings
    final allergens = <String>{};
    for (final item in order.items) {
      allergens.addAll(item.menuItem.getAllergenList());
    }
    
    if (allergens.isNotEmpty) {
      buffer.writeln('ALLERGEN WARNINGS:');
      buffer.writeln(allergens.join(', '));
    }

    return buffer.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year} ${_formatTime(dateTime)}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _sendToPrinter(String content) async {
    if (_selectedPrinter == null) return;
    
    debugPrint('Printing to $_selectedPrinter');
    debugPrint(content);
    
    // TODO: Implement actual printer communication
    // For now, just log the content
  }

  // Test printing
  Future<void> testPrint() async {
    final testOrder = Order(
      items: [],
      orderNumber: 'TEST001',
      customerName: 'Test Customer',
      tableId: '1',
    );
    
    await printReceipt(testOrder);
  }

  void setState(VoidCallback fn) {
    fn();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during setState: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during setState: $e');
    }
  }
} 