import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/printing_service.dart';
import '../widgets/universal_navigation.dart';

class PrinterSelectionScreen extends StatefulWidget {
  final User? user;

  const PrinterSelectionScreen({
    super.key,
    this.user,
  });

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isScanning = false;
  List<PrinterDevice> _wifiPrinters = [];
  List<PrinterDevice> _bluetoothPrinters = [];
  PrinterDevice? _connectedPrinter;
  String _connectionStatus = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConnectedPrinter();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConnectedPrinter() async {
    final printingService = Provider.of<PrintingService>(context, listen: false);
    final connected = await printingService.getConnectedPrinter();
    if (mounted) {
      setState(() {
        _connectedPrinter = connected;
        _connectionStatus = connected != null ? 'Connected' : 'Disconnected';
      });
    }
  }

  Future<void> _scanForPrinters(PrinterType type) async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      if (type == PrinterType.wifi) {
        _wifiPrinters.clear();
      } else {
        _bluetoothPrinters.clear();
      }
    });

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      // Enable manual scanning before attempting to scan
      printingService.enableManualScanning();
      
      final printers = await printingService.scanForPrinters(type);
      
      if (mounted) {
        setState(() {
          if (type == PrinterType.wifi) {
            _wifiPrinters = printers;
          } else {
            _bluetoothPrinters = printers;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to scan for printers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectToPrinter(PrinterDevice printer) async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final success = await printingService.connectToPrinter(printer);
      
      if (mounted) {
        if (success) {
          setState(() {
            _connectedPrinter = printer;
            _connectionStatus = 'Connected';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${printer.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.disconnectPrinter();
      
      if (mounted) {
        setState(() {
          _connectedPrinter = null;
          _connectionStatus = 'Disconnected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer disconnected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    if (_connectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer connected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.printTestReceipt();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test receipt printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print test failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showManualIPDialog() async {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '9100');
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Printer by IP Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Port (optional)',
                  hintText: '9100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text(
                'Common printer ports:\n• 9100 (RAW/ESC-POS)\n• 515 (LPR/LPD)\n• 631 (IPP)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 9100;
                
                if (ip.isNotEmpty) {
                  Navigator.of(context).pop();
                  await _addPrinterByIP(ip, port);
                }
              },
              child: const Text('Add Printer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addPrinterByIP(String ipAddress, int port) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Testing connection to $ipAddress:$port...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printer = await printingService.addPrinterByIP(ipAddress, port: port);
      
      if (mounted && printer != null) {
        setState(() {
          // Add to WiFi printers list if not already present
          if (!_wifiPrinters.any((p) => p.address == printer.address)) {
            _wifiPrinters.insert(0, printer);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printer found: ${printer.name}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Connect',
              textColor: Colors.white,
              onPressed: () => _connectToPrinter(printer),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add printer: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UniversalAppBar(
        currentUser: widget.user,
        title: 'Printer Settings',
        showQuickActions: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'WiFi Printers'),
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWiFiTab(),
                _buildBluetoothTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _connectedPrinter != null ? Colors.green.shade50 : Colors.red.shade50,
      child: Row(
        children: [
          Icon(
            _connectedPrinter != null ? Icons.check_circle : Icons.error,
            color: _connectedPrinter != null ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Printer Status: $_connectionStatus',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _connectedPrinter != null ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                if (_connectedPrinter != null)
                  Text(
                    'Connected to: ${_connectedPrinter!.name}',
                    style: TextStyle(color: Colors.green.shade600),
                  ),
              ],
            ),
          ),
          if (_connectedPrinter != null) ...[
            ElevatedButton.icon(
              onPressed: _testPrint,
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Test Print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _disconnectPrinter,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWiFiTab() {
    return Column(
      children: [
        _buildWiFiScanHeader(),
        _buildManualIPSection(),
        Expanded(
          child: _wifiPrinters.isEmpty
              ? _buildEmptyState(PrinterType.wifi)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _wifiPrinters.length,
                  itemBuilder: (context, index) {
                    final printer = _wifiPrinters[index];
                    return _buildPrinterCard(printer);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWiFiScanHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'WiFi Printer Discovery',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : () => _scanForPrinters(PrinterType.wifi),
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(_isScanning ? 'Scanning Network...' : 'Auto Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualIPSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.router, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Add Printer by IP Address',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'If you know your printer\'s IP address, you can add it directly:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showManualIPDialog,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add by IP Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Column(
      children: [
        _buildScanHeader(PrinterType.bluetooth),
        Expanded(
          child: _bluetoothPrinters.isEmpty
              ? _buildEmptyState(PrinterType.bluetooth)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bluetoothPrinters.length,
                  itemBuilder: (context, index) {
                    final printer = _bluetoothPrinters[index];
                    return _buildPrinterCard(printer);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScanHeader(PrinterType type) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Scan for ${type == PrinterType.wifi ? 'WiFi' : 'Bluetooth'} printers',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : () => _scanForPrinters(type),
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(type == PrinterType.wifi ? Icons.wifi_find : Icons.bluetooth_searching),
            label: Text(_isScanning ? 'Scanning...' : 'Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PrinterType type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == PrinterType.wifi ? Icons.wifi_off : Icons.bluetooth_disabled,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${type == PrinterType.wifi ? 'WiFi' : 'Bluetooth'} printers found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Scan" to search for available printers',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard(PrinterDevice printer) {
    final isConnected = _connectedPrinter?.id == printer.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isConnected ? 4 : 1,
      color: isConnected ? Colors.green.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected ? Colors.green : Colors.blue,
          child: Icon(
            printer.type == PrinterType.wifi ? Icons.wifi : Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(
          printer.name,
          style: TextStyle(
            fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${printer.address}'),
            if (printer.model.isNotEmpty)
              Text('Model: ${printer.model}'),
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_alt,
                  size: 16,
                  color: _getSignalColor(printer.signalStrength),
                ),
                const SizedBox(width: 4),
                Text(
                  'Signal: ${printer.signalStrength}%',
                  style: TextStyle(
                    color: _getSignalColor(printer.signalStrength),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: isConnected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: () => _connectToPrinter(printer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Connect'),
              ),
        isThreeLine: true,
      ),
    );
  }

  Color _getSignalColor(int strength) {
    if (strength >= 70) return Colors.green;
    if (strength >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsSection(
          'Print Settings',
          [
            _buildSettingsTile(
              'Paper Width',
              '80mm (Standard)',
              Icons.straighten,
              onTap: () => _showPaperWidthDialog(),
            ),
            _buildSettingsTile(
              'Print Quality',
              'High',
              Icons.high_quality,
              onTap: () => _showPrintQualityDialog(),
            ),
            _buildSettingsTile(
              'Print Speed',
              'Normal',
              Icons.speed,
              onTap: () => _showPrintSpeedDialog(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSettingsSection(
          'Receipt Format',
          [
            _buildSettingsTile(
              'Header Logo',
              'Enabled',
              Icons.image,
              onTap: () => _showHeaderLogoDialog(),
            ),
            _buildSettingsTile(
              'Footer Message',
              'Thank you for dining with us!',
              Icons.message,
              onTap: () => _showFooterMessageDialog(),
            ),
            _buildSettingsTile(
              'Print Order Details',
              'Enabled',
              Icons.list_alt,
              onTap: () => _toggleOrderDetails(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSettingsSection(
          'Advanced',
          [
            _buildSettingsTile(
              'Auto-Print Orders',
              'Disabled',
              Icons.auto_mode,
              onTap: () => _toggleAutoPrint(),
            ),
            _buildSettingsTile(
              'Print Kitchen Copy',
              'Enabled',
              Icons.kitchen,
              onTap: () => _toggleKitchenCopy(),
            ),
            _buildSettingsTile(
              'Reset Settings',
              'Restore defaults',
              Icons.restore,
              onTap: () => _showResetDialog(),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _connectedPrinter != null ? _printSampleReceipt : null,
          icon: const Icon(Icons.receipt),
          label: const Text('Print Sample Receipt'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showPaperWidthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paper Width'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('58mm'),
              value: '58mm',
              groupValue: '80mm',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('80mm (Standard)'),
              value: '80mm',
              groupValue: '80mm',
              onChanged: (value) => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPrintQualityDialog() {
    // Implementation for print quality dialog
  }

  void _showPrintSpeedDialog() {
    // Implementation for print speed dialog
  }

  void _showHeaderLogoDialog() {
    // Implementation for header logo dialog
  }

  void _showFooterMessageDialog() {
    // Implementation for footer message dialog
  }

  void _toggleOrderDetails() {
    // Implementation for toggling order details
  }

  void _toggleAutoPrint() {
    // Implementation for toggling auto-print
  }

  void _toggleKitchenCopy() {
    // Implementation for toggling kitchen copy
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all printer settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printer settings reset to defaults'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _printSampleReceipt() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.printSampleReceipt();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample receipt printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print sample: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}