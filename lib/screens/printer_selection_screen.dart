import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printing_service.dart';
import '../widgets/back_button.dart';

class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  List<String> _discoveredPrinters = [];
  bool _isScanning = false;
  String? _selectedPrinter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSelectedPrinter();
  }

  void _loadSelectedPrinter() {
    final printingService = Provider.of<PrintingService>(context, listen: false);
    setState(() {
      _selectedPrinter = printingService.selectedPrinter;
    });
  }

  Future<void> _startScan() async {
    debugPrint("Starting printer scan...");
    setState(() {
      _isScanning = true;
      _discoveredPrinters = [];
      _error = null;
    });

    final printingService = Provider.of<PrintingService>(context, listen: false);
    
    try {
      await printingService.scanForPrinters();
      setState(() {
        _discoveredPrinters = printingService.availablePrinters;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Discovery Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectPrinter(String printerAddress) {
    final printingService = Provider.of<PrintingService>(context, listen: false);
    printingService.selectPrinter(printerAddress);
    setState(() {
      _selectedPrinter = printerAddress;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Printer selected: $printerAddress'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildBody() {
    if (_isScanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Scanning for printers on the network...'),
          ],
        ),
      );
    } else if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    } else if (_discoveredPrinters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No printers found. Ensure you are on the same Wi-Fi network as the printer and tap "Scan".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: _discoveredPrinters.length,
        itemBuilder: (context, index) {
          final printer = _discoveredPrinters[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text('Printer ${index + 1}'),
              subtitle: Text(printer),
              onTap: () => _selectPrinter(printer),
              trailing: _selectedPrinter == printer
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.print_outlined),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Printer'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          const SizedBox(width: 8),
          const CustomBackButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildBody(),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(_isScanning ? 'Scanning...' : 'Scan for Printers'),
              onPressed: _isScanning ? null : _startScan,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}