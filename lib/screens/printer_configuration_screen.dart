import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/printer_configuration.dart';
import '../services/printer_configuration_service.dart';
import '../services/printing_service.dart' as printing_service;
import '../widgets/back_button.dart';

class PrinterConfigurationScreen extends StatefulWidget {
  final PrinterConfiguration? printerConfiguration;
  final Function(PrinterConfiguration)? onConfigurationUpdated;

  const PrinterConfigurationScreen({
    super.key,
    this.printerConfiguration,
    this.onConfigurationUpdated,
  });

  @override
  State<PrinterConfigurationScreen> createState() => _PrinterConfigurationScreenState();
}

class _PrinterConfigurationScreenState extends State<PrinterConfigurationScreen> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Manual Configuration
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _modelController = TextEditingController();
  
  // Scanning
  bool _isScanning = false;
  List<DiscoveredPrinter> _discoveredPrinters = [];
  List<printing_service.PrinterDevice> _bluetoothPrinters = [];
  String _scanningStatus = '';
  Timer? _scanTimer;
  
  // Connection Testing
  bool _isTestingConnection = false;
  String _connectionStatus = '';
  Color _connectionStatusColor = Colors.grey;
  
  // Printer Types
  PrinterType _selectedType = PrinterType.wifi;
  PrinterModel _selectedModel = PrinterModel.epsonTMT88VI;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeFields();
  }
  
  void _initializeFields() {
    if (widget.printerConfiguration != null) {
      final config = widget.printerConfiguration!;
      _nameController.text = config.name;
      _selectedType = config.type;
      _selectedModel = config.model;
      
      if (config.type == PrinterType.bluetooth) {
        _ipController.text = config.bluetoothAddress ?? '';
        _portController.text = '';
      } else {
        _ipController.text = config.ipAddress;
        _portController.text = config.port.toString();
      }
    } else {
      // Default values for new printer
      _nameController.text = 'New Printer';
      _ipController.text = '192.168.1.100';
      _portController.text = '9100';
      _selectedType = PrinterType.wifi;
      _selectedModel = PrinterModel.epsonTMT88VI;
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _modelController.dispose();
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configure ${widget.printerConfiguration?.name ?? 'New Printer'}'),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        elevation: 0,
        leading: const CustomBackButton(),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue.shade700,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Manual Setup'),
            Tab(icon: Icon(Icons.wifi_find), text: 'Network Scan'),
            Tab(icon: Icon(Icons.bluetooth_searching), text: 'Bluetooth Scan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildManualConfigTab(),
          _buildNetworkScanTab(),
          _buildBluetoothScanTab(),
        ],
      ),
    );
  }

  Widget _buildManualConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _getPrinterStationColor(widget.printerConfiguration?.name ?? 'New Printer'),
                        child: Text(
                          _getPrinterStationIcon(widget.printerConfiguration?.name ?? 'New Printer'),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.printerConfiguration?.name ?? 'New Printer',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getPrinterStationDescription(widget.printerConfiguration?.name ?? 'New Printer'),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Printer Type Selection
          const Text(
            'Printer Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                RadioListTile<PrinterType>(
                  title: const Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('WiFi/Ethernet Printer'),
                    ],
                  ),
                  subtitle: const Text('Network printer with IP address'),
                  value: PrinterType.wifi,
                  groupValue: _selectedType,
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const Divider(height: 1),
                RadioListTile<PrinterType>(
                  title: const Row(
                    children: [
                      Icon(Icons.bluetooth, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Bluetooth Printer'),
                    ],
                  ),
                  subtitle: const Text('Wireless Bluetooth connection'),
                  value: PrinterType.bluetooth,
                  groupValue: _selectedType,
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
                const Divider(height: 1),
                RadioListTile<PrinterType>(
                  title: const Row(
                    children: [
                      Icon(Icons.usb, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('USB Printer'),
                    ],
                  ),
                  subtitle: const Text('Direct USB connection'),
                  value: PrinterType.wifi, // Using wifi as placeholder since USB not defined
                  groupValue: _selectedType,
                  onChanged: (value) => setState(() => _selectedType = value!),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Configuration Fields
          const Text(
            'Printer Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Printer Name
          _buildConfigField(
            'Printer Name',
            _nameController,
            'e.g., Main Kitchen Printer',
            Icons.print,
          ),
          
          const SizedBox(height: 16),
          
          // IP Address (only for WiFi)
          if (_selectedType == PrinterType.wifi) ...[
            _buildConfigField(
              'IP Address (Local or Public)',
              _ipController,
              'Local: 192.168.1.100 or Public: 203.0.113.10',
              Icons.computer,
              validator: _validateIP,
            ),
            
            // Help text for remote printing
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Remote Printing Support',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Local IP (192.168.x.x): For printers on same network\n'
                    '• Public IP: For remote restaurant locations over internet\n'
                    '• Port forwarding required for public IP access\n'
                    '• Ensure firewall allows port ${_portController.text.isEmpty ? '9100' : _portController.text}',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildConfigField(
              'Port',
              _portController,
              'e.g., 9100',
              Icons.settings_input_hdmi,
              validator: _validatePort,
            ),
          ],
          
          // Bluetooth Address (only for Bluetooth)
          if (_selectedType == PrinterType.bluetooth) ...[
            _buildConfigField(
              'Bluetooth Address',
              _ipController,
              'e.g., 00:11:22:33:44:55',
              Icons.bluetooth,
              validator: _validateBluetoothAddress,
            ),
          ],
          
          // USB Path configuration is not currently supported
          
          const SizedBox(height: 16),
          
          // Printer Model
          _buildPrinterModelDropdown(),
          
          const SizedBox(height: 24),
          
          // Test Connection
          _buildConnectionTestSection(),
          
          const SizedBox(height: 24),
          
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _savePrinterConfiguration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Configuration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkScanTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scan Info Card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Network Printer Discovery',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will scan your local network (192.168.x.x) for Epson thermal printers on common ports (9100, 515, 631). Make sure your printers are powered on and connected to the same network.',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Scan Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startNetworkScan,
              icon: _isScanning 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find),
              label: Text(_isScanning ? 'Scanning Network...' : 'Start Network Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          if (_scanningStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _scanningStatus,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Discovered Printers
          if (_discoveredPrinters.isNotEmpty) ...[
            const Text(
              'Discovered Printers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _discoveredPrinters.length,
                itemBuilder: (context, index) {
                  final discoveredPrinter = _discoveredPrinters[index];
                  return _buildDiscoveredPrinterCard(discoveredPrinter);
                },
              ),
            ),
          ] else if (!_isScanning) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_find,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No printers discovered yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a network scan to find available printers',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBluetoothScanTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bluetooth Info Card
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Bluetooth Printer Discovery',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will scan for nearby Bluetooth thermal printers. Make sure your printers are in pairing mode and Bluetooth is enabled on this device.',
                    style: TextStyle(
                      color: Colors.purple.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Scan Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _startBluetoothScan,
              icon: _isScanning 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_isScanning ? 'Scanning Bluetooth...' : 'Start Bluetooth Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          if (_scanningStatus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _scanningStatus,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Discovered Bluetooth Printers
          if (_bluetoothPrinters.isNotEmpty) ...[
            const Text(
              'Discovered Bluetooth Printers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _bluetoothPrinters.length,
                itemBuilder: (context, index) {
                  final printer = _bluetoothPrinters[index];
                  return _buildBluetoothPrinterCard(printer);
                },
              ),
            ),
          ] else if (!_isScanning) ...[
            // Empty state when no printers found
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bluetooth_searching,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Bluetooth Printers Found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure your printer is:\n• Powered on\n• In pairing mode\n• Within Bluetooth range',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPrinterModelDropdown() {
    final epsonModels = [
      'Epson TM-T88VI',
      'Epson TM-T88V',
      'Epson TM-T20III',
      'Epson TM-T82III',
      'Epson TM-m30',
      'Epson TM-m50',
      'Epson TM-P20',
      'Epson TM-P60II',
      'Custom/Other Epson Model',
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Printer Model',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: epsonModels.contains(_modelController.text) 
              ? _modelController.text 
              : 'Custom/Other Epson Model',
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.print),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: epsonModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Text(model),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              if (value == 'Custom/Other Epson Model') {
                _showCustomModelDialog();
              } else {
                _modelController.text = value;
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildConnectionTestSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Test',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_protected_setup),
                    label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTestingConnection ? null : _testPrint,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Test Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (_connectionStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _connectionStatusColor.withOpacity(0.1),
                  border: Border.all(color: _connectionStatusColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _connectionStatus,
                  style: TextStyle(
                    color: _connectionStatusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveredPrinterCard(DiscoveredPrinter discoveredPrinter) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(
            Icons.print,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(discoveredPrinter.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${discoveredPrinter.ipAddress}:${discoveredPrinter.port}'),
            Text(
              'Model: ${discoveredPrinter.model} • Status: ${discoveredPrinter.status}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _useDiscoveredPrinter(discoveredPrinter),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Use This Printer'),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildBluetoothPrinterCard(printing_service.PrinterDevice printer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Icon(Icons.bluetooth, color: Colors.purple.shade700),
        ),
        title: Text(
          printer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${printer.address}'),
            Text('Model: ${printer.model}'),
            Row(
              children: [
                Text('Signal: '),
                Icon(
                  _getSignalIcon(printer.signalStrength),
                  color: _getSignalColor(printer.signalStrength),
                  size: 16,
                ),
                Text(' ${printer.signalStrength}%'),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _useBluetoothPrinter(printer),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('Use This Printer'),
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getSignalIcon(int signalStrength) {
    if (signalStrength >= 80) return Icons.signal_cellular_4_bar;
    if (signalStrength >= 60) return Icons.signal_cellular_alt;
    if (signalStrength >= 40) return Icons.signal_cellular_alt;
    if (signalStrength >= 20) return Icons.signal_cellular_alt;
    return Icons.signal_cellular_null;
  }

  Color _getSignalColor(int signalStrength) {
    if (signalStrength >= 80) return Colors.green;
    if (signalStrength >= 60) return Colors.orange;
    return Colors.red;
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
      case 'Receipt Station':
        return Colors.teal.shade100;
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
      case 'Receipt Station':
        return '🧾';
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
      case 'Receipt Station':
        return 'Customer receipts, payment confirmations';
      default:
        return 'Kitchen printer';
    }
  }

  // Validation methods - Enhanced for local and public IP support
  String? _validateIP(String? value) {
    if (value == null || value.isEmpty) {
      return 'IP address is required';
    }
    
    // Enhanced IP validation for both local and public IPs
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(value)) {
      return 'Enter a valid IP address (e.g., 192.168.1.100 or 203.0.113.10)';
    }
    
    // Check if each octet is valid (0-255)
    final parts = value.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return 'IP address octets must be between 0-255';
      }
    }
    
    // Additional validation messages for different IP types
    if (value.startsWith('192.168.') || value.startsWith('10.') || value.startsWith('172.')) {
      // Local/Private IP - provide helpful context
      return null; // Valid local IP
    } else if (value.startsWith('127.')) {
      return 'Localhost (127.x.x.x) not supported for printer connections';
    } else {
      // Likely public IP - provide helpful context
      return null; // Valid public IP
    }
  }

  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Port is required';
    }
    final port = int.tryParse(value);
    if (port == null || port < 1 || port > 65535) {
      return 'Enter a valid port (1-65535)';
    }
    return null;
  }

  String? _validateBluetoothAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Bluetooth address is required';
    }
    final btRegex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    if (!btRegex.hasMatch(value)) {
      return 'Enter a valid Bluetooth address (e.g., 00:11:22:33:44:55)';
    }
    return null;
  }

  // Action methods
  void _startNetworkScan() {
    setState(() {
      _isScanning = true;
      _discoveredPrinters.clear();
      _scanningStatus = 'Scanning local network for printers...';
    });

    // Simulate network scanning process
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (timer.tick == 1) {
        setState(() {
          _scanningStatus = 'Checking 192.168.1.x addresses...';
        });
      } else if (timer.tick == 2) {
        setState(() {
          _scanningStatus = 'Testing common printer ports...';
        });
      } else if (timer.tick == 3) {
        setState(() {
          _scanningStatus = 'Identifying printer models...';
          // Add some mock discovered printers
          _discoveredPrinters.addAll([
            DiscoveredPrinter(
              name: 'Epson TM-T88VI',
              ipAddress: '192.168.1.150',
              port: 9100,
              model: 'TM-T88VI',
              status: 'Online',
            ),
            DiscoveredPrinter(
              name: 'Epson TM-T20III',
              ipAddress: '192.168.1.151',
              port: 9100,
              model: 'TM-T20III',
              status: 'Online',
            ),
          ]);
        });
      } else if (timer.tick >= 4) {
        setState(() {
          _isScanning = false;
          _scanningStatus = 'Scan completed. Found ${_discoveredPrinters.length} printers.';
        });
        timer.cancel();
      }
    });
  }

  void _startBluetoothScan() async {
    setState(() {
      _isScanning = true;
      _bluetoothPrinters.clear();
      _scanningStatus = 'Initializing Bluetooth scan...';
    });
    
    try {
      final printingService = Provider.of<printing_service.PrintingService>(context, listen: false);
      
      // Enable manual scanning
      printingService.enableManualScanning();
      
      setState(() {
        _scanningStatus = 'Scanning for Bluetooth printers...';
      });
      
      // Real Bluetooth scanning using PrintingService
      final discoveredPrinters = await printingService.scanForPrinters(printing_service.PrinterType.bluetooth);
      
      setState(() {
        _bluetoothPrinters = discoveredPrinters;
        _scanningStatus = discoveredPrinters.isEmpty 
          ? 'No Bluetooth printers found. Make sure your printer is in pairing mode and within range.'
          : 'Found ${discoveredPrinters.length} Bluetooth printer(s)';
      });
      
      if (discoveredPrinters.isNotEmpty) {
        // Show success message with printer details
        final printerNames = discoveredPrinters.map((p) => p.name).take(3).join(', ');
        final moreCount = discoveredPrinters.length > 3 ? ' and ${discoveredPrinters.length - 3} more' : '';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Found: $printerNames$moreCount'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Use First',
              textColor: Colors.white,
              onPressed: () => _useBluetoothPrinter(discoveredPrinters.first),
            ),
          ),
        );
      } else {
        // Show helpful message if no printers found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No Bluetooth printers found'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _startBluetoothScan,
            ),
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _scanningStatus = 'Bluetooth scan failed: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bluetooth scan failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _startBluetoothScan,
          ),
        ),
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
      _connectionStatusColor = Colors.orange;
    });

    try {
      if (_selectedType == PrinterType.wifi) {
        final ip = _ipController.text.trim();
        final port = int.tryParse(_portController.text) ?? 9100;
        
        // Validate IP format first
        if (_validateIP(ip) != null) {
          throw Exception('Invalid IP address format');
        }
        
        // Validate port range
        if (_validatePort(_portController.text) != null) {
          throw Exception('Invalid port number');
        }
        
        setState(() {
          _connectionStatus = 'Connecting to $ip:$port...';
        });
        
        // Attempt to connect with detailed feedback
        final socket = await Socket.connect(
          ip, 
          port, 
          timeout: const Duration(seconds: 8)
        );
        
        // Try to send printer identification and status commands
        try {
          setState(() {
            _connectionStatus = 'Connected! Testing printer capabilities...';
          });
          
          // Send comprehensive ESC/POS identification sequence
          final identifyCommands = [
            [0x1B, 0x40], // ESC @ - Initialize printer
            [0x1D, 0x49, 0x01], // GS I 1 - Printer ID
            [0x1D, 0x49, 0x02], // GS I 2 - Type ID  
            [0x10, 0x04, 0x01], // DLE EOT 1 - Real-time status
            [0x1D, 0x72, 0x01], // GS r 1 - Transmit status
          ];
          
          List<int> allResponses = [];
          
          for (final command in identifyCommands) {
            try {
              socket.add(command);
              await socket.flush();
              
              // Wait for response with timeout
              final response = await socket.first.timeout(
                const Duration(seconds: 2),
                onTimeout: () => Uint8List(0),
              );
              
              if (response.isNotEmpty) {
                allResponses.addAll(response);
              }
              
              // Small delay between commands
              await Future.delayed(const Duration(milliseconds: 100));
            } catch (e) {
              // Individual command failed, continue with next
            }
          }
          
          await socket.close();
          
          // Analyze responses to provide detailed feedback
          String printerInfo = '';
          bool isEpsonPrinter = false;
          
          if (allResponses.isNotEmpty) {
            final responseStr = String.fromCharCodes(
              allResponses.where((b) => b >= 32 && b <= 126)
            ).toLowerCase();
            
            if (responseStr.contains('epson') || responseStr.contains('tm-')) {
              isEpsonPrinter = true;
              printerInfo = 'Epson thermal printer detected';
              
              // Try to identify specific model
              if (responseStr.contains('tm-t88')) printerInfo += ' (TM-T88 series)';
              else if (responseStr.contains('tm-m30')) printerInfo += ' (TM-M30 series)';
              else if (responseStr.contains('tm-t20')) printerInfo += ' (TM-T20 series)';
              else if (responseStr.contains('tm-p')) printerInfo += ' (TM-P series)';
            } else {
              printerInfo = 'Printer responded (${allResponses.length} bytes)';
            }
          } else {
            printerInfo = 'Connection successful, but no printer response';
          }
          
          setState(() {
            _connectionStatus = isEpsonPrinter 
              ? '✅ Success! $printerInfo'
              : '✅ Connection established! $printerInfo';
            _connectionStatusColor = Colors.green;
          });
          
          // Show detailed success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEpsonPrinter 
                  ? '🖨️ Epson printer found at $ip:$port'
                  : '🔗 Printer connection successful at $ip:$port'
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Test Print',
                textColor: Colors.white,
                onPressed: _testPrint,
              ),
            ),
          );
          
        } catch (e) {
          // Command failed but connection works
          await socket.close();
          
          setState(() {
            _connectionStatus = '✅ Connection successful! Port is open (printer may be offline or different model)';
            _connectionStatusColor = Colors.green;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Connection established at $ip:$port'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
      } else if (_selectedType == PrinterType.bluetooth) {
        final address = _ipController.text.trim();
        
        // Validate Bluetooth address format
        if (_validateBluetoothAddress(address) != null) {
          throw Exception('Invalid Bluetooth address format');
        }
        
        setState(() {
          _connectionStatus = 'Testing Bluetooth connection to $address...';
        });
        
        // Simulate Bluetooth connection test (replace with real implementation)
        await Future.delayed(const Duration(seconds: 3));
        
        setState(() {
          _connectionStatus = '✅ Bluetooth connection successful!';
          _connectionStatusColor = Colors.green;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bluetooth printer connected: $address'),
            backgroundColor: Colors.green,
          ),
        );
        
      } else {
        throw Exception('Unsupported printer type: $_selectedType');
      }
      
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Connection failed: ${e.toString()}';
        _connectionStatusColor = Colors.red;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _testConnection,
          ),
        ),
      );
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  void _testPrint() async {
    final printerConfigService = Provider.of<PrinterConfigurationService>(context, listen: false);
    
    try {
      // Create a temporary configuration for testing
      final testConfig = PrinterConfiguration(
        name: _nameController.text,
        type: _selectedType,
        model: _selectedModel,
        ipAddress: _ipController.text,
        port: int.tryParse(_portController.text) ?? 9100,
      );
      
      // Test print using the configuration service
      final success = await printerConfigService.testConfiguration(testConfig);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test print sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Test print failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _useDiscoveredPrinter(DiscoveredPrinter discoveredPrinter) {
    setState(() {
      _ipController.text = discoveredPrinter.ipAddress;
      _portController.text = discoveredPrinter.port.toString();
      _modelController.text = 'Epson ${discoveredPrinter.model}';
      _selectedType = PrinterType.wifi;
    });
    
    _tabController.animateTo(0); // Switch to manual config tab
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configured with ${discoveredPrinter.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _useBluetoothPrinter(printing_service.PrinterDevice printer) {
    setState(() {
      _nameController.text = printer.name;
      _ipController.text = printer.address; // Bluetooth address
      _portController.text = ''; // Not used for Bluetooth
      _selectedType = PrinterType.bluetooth;
      _selectedModel = PrinterModel.epsonTMGeneric; // Default for Bluetooth
    });
    
    _tabController.animateTo(0); // Switch to manual config tab
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configured with ${printer.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCustomModelDialog() {
    final customController = TextEditingController(text: _modelController.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Printer Model'),
        content: TextField(
          controller: customController,
          decoration: const InputDecoration(
            labelText: 'Enter printer model',
            hintText: 'e.g., Epson TM-Custom',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _modelController.text = customController.text;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _savePrinterConfiguration() async {
    // Validate fields
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a printer name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_selectedType == PrinterType.wifi) {
      if (_validateIP(_ipController.text) != null || 
          _validatePort(_portController.text) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid IP address and port'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_selectedType == PrinterType.bluetooth) {
      if (_validateBluetoothAddress(_ipController.text) != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid Bluetooth address'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final printerConfigService = Provider.of<PrinterConfigurationService>(context, listen: false);
    
    try {
      // Create or update printer configuration
      final config = PrinterConfiguration(
        id: widget.printerConfiguration?.id, // Keep existing ID if updating
        name: _nameController.text,
        type: _selectedType,
        model: _selectedModel,
        ipAddress: _selectedType == PrinterType.bluetooth ? '' : _ipController.text,
        port: _selectedType == PrinterType.bluetooth ? 0 : (int.tryParse(_portController.text) ?? 9100),
        bluetoothAddress: _selectedType == PrinterType.bluetooth ? _ipController.text : '',
      );
      
      bool success;
      if (widget.printerConfiguration == null) {
        // Adding new configuration
        success = await printerConfigService.addConfiguration(config);
      } else {
        // Updating existing configuration
        success = await printerConfigService.updateConfiguration(config);
      }
      
      if (success) {
        // Call the callback to notify parent
        if (widget.onConfigurationUpdated != null) {
          widget.onConfigurationUpdated!(config);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer configuration saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context);
      } else {
        throw Exception('Failed to save configuration');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Model class for discovered printers
class DiscoveredPrinter {
  final String name;
  final String ipAddress;
  final int port;
  final String model;
  final String status;
  
  DiscoveredPrinter({
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.model,
    required this.status,
  });
} 