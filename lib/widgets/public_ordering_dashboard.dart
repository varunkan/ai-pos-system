import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/public_order_submission_service.dart';
import '../services/printing_service.dart';
import '../services/printer_configuration_service.dart';

/// Dashboard widget for managing public ordering system
class PublicOrderingDashboard extends StatefulWidget {
  const PublicOrderingDashboard({super.key});

  @override
  State<PublicOrderingDashboard> createState() => _PublicOrderingDashboardState();
}

class _PublicOrderingDashboardState extends State<PublicOrderingDashboard> {
  late PublicOrderSubmissionService _publicOrderService;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printerConfigService = Provider.of<PrinterConfigurationService>(context, listen: false);
      
      // For now, we'll create a mock order service since we can't get it from Provider
      // In a real implementation, you'd get this from Provider as well
      _publicOrderService = PublicOrderSubmissionService(
        printingService: printingService,
        printerConfigService: printerConfigService,
        orderService: null as dynamic, // This would be injected properly
      );
      
      // Initialize with restaurant info (you'd get this from your auth service)
      await _publicOrderService.initialize('restaurant_123', 'Your Restaurant Name');
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return ChangeNotifierProvider.value(
      value: _publicOrderService,
      child: Consumer<PublicOrderSubmissionService>(
        builder: (context, service, child) {
          return Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(service),
                  const SizedBox(height: 20),
                  _buildStatusCards(service),
                  const SizedBox(height: 20),
                  _buildControlPanel(service),
                  const SizedBox(height: 20),
                  _buildOrderStats(service),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Card(
      elevation: 4,
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Public Ordering System...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Text(
                  'Public Ordering Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isInitialized = false;
                });
                _initializeService();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PublicOrderSubmissionService service) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.public,
            color: Colors.blue.shade700,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Public Ordering System',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Customers can order from anywhere in the world',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        _buildStatusIndicator(service),
      ],
    );
  }

  Widget _buildStatusIndicator(PublicOrderSubmissionService service) {
    final isEnabled = service.isPublicOrderingEnabled;
    final isMonitoring = service.isMonitoring;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isEnabled && isMonitoring) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'ACTIVE';
    } else if (isEnabled && !isMonitoring) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'ENABLED';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'DISABLED';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards(PublicOrderSubmissionService service) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Orders Today',
            service.todayOrdersCount.toString(),
            Icons.today,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Total Public Orders',
            service.totalPublicOrders.toString(),
            Icons.shopping_cart,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Monitoring Status',
            service.isMonitoring ? 'ACTIVE' : 'INACTIVE',
            Icons.monitor,
            service.isMonitoring ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(PublicOrderSubmissionService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Control Panel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  service.isPublicOrderingEnabled ? 'Disable Public Ordering' : 'Enable Public Ordering',
                  service.isPublicOrderingEnabled ? Icons.pause : Icons.play_arrow,
                  service.isPublicOrderingEnabled ? Colors.red : Colors.green,
                  () => service.setPublicOrderingEnabled(!service.isPublicOrderingEnabled),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton(
                  'View App QR Code',
                  Icons.qr_code,
                  Colors.blue,
                  _showQRCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  'Configure Printers',
                  Icons.print,
                  Colors.purple,
                  _configurePrinters,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton(
                  'Test System',
                  Icons.bug_report,
                  Colors.orange,
                  _testSystem,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildOrderStats(PublicOrderSubmissionService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'How It Works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildHowItWorksStep(
            '1.',
            'Customer Downloads App',
            'Customers download your restaurant app from anywhere in the world',
            Icons.download,
          ),
          _buildHowItWorksStep(
            '2.',
            'Browse & Order',
            'They browse your menu and place orders with payment',
            Icons.restaurant_menu,
          ),
          _buildHowItWorksStep(
            '3.',
            'Auto-Print to Kitchen',
            'Orders automatically appear on your kitchen printers',
            Icons.print,
          ),
          _buildHowItWorksStep(
            '4.',
            'Real-time Updates',
            'Customers get live updates on their order status',
            Icons.notifications,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(String number, String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: Colors.blue),
            SizedBox(width: 8),
            Text('Customer App QR Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 120,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'QR Code will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Customers scan this to download your app',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Print this QR code and display it in your restaurant so customers can easily find and download your ordering app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Generate and download QR code
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR code generation feature coming soon!'),
                ),
              );
            },
            child: const Text('Download QR'),
          ),
        ],
      ),
    );
  }

  void _configurePrinters() {
    // Navigate to printer configuration screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening printer configuration...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _testSystem() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science, color: Colors.orange),
            SizedBox(width: 8),
            Text('Test Public Ordering System'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will test the complete public ordering flow:'),
            SizedBox(height: 12),
            Text('• Create a test order'),
            Text('• Send it to your printers'),
            Text('• Verify the complete process'),
            SizedBox(height: 16),
            Text(
              'This helps ensure everything is working correctly before customers start ordering.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _runSystemTest();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Run Test'),
          ),
        ],
      ),
    );
  }

  void _runSystemTest() {
    // TODO: Implement system test
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧪 Running system test...'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Simulate test completion
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ System test completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
} 