import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_realtime_sync_service.dart';

/// Widget to display real-time sync status and active devices
class RealtimeSyncStatusWidget extends StatelessWidget {
  const RealtimeSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseRealtimeSyncService>(
      builder: (context, syncService, child) {
        if (!syncService.isInitialized) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    syncService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: syncService.isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    syncService.isConnected ? 'Real-time Sync Active' : 'Real-time Sync Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: syncService.isConnected ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const Spacer(),
                  if (syncService.lastSyncTime != null)
                    Text(
                      'Last sync: ${_formatTime(syncService.lastSyncTime!)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
              if (syncService.isConnected) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.devices, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${syncService.activeDevices.length} active device${syncService.activeDevices.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ],
                ),
                if (syncService.activeDevices.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Devices: ${syncService.activeDevices.take(3).join(', ')}${syncService.activeDevices.length > 3 ? '...' : ''}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Expanded real-time sync status widget with more details
class ExpandedRealtimeSyncStatusWidget extends StatelessWidget {
  const ExpandedRealtimeSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseRealtimeSyncService>(
      builder: (context, syncService, child) {
        if (!syncService.isInitialized) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Firebase Sync: Initializing...'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      syncService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: syncService.isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Real-time Synchronization',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: syncService.isConnected ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        syncService.isConnected ? 'Connected' : 'Disconnected',
                        style: TextStyle(
                          color: syncService.isConnected ? Colors.green[700] : Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Connection details
                _buildDetailRow('Status', syncService.isConnected ? 'Active' : 'Inactive'),
                if (syncService.lastSyncTime != null)
                  _buildDetailRow('Last Sync', _formatDetailedTime(syncService.lastSyncTime!)),
                _buildDetailRow('Active Devices', '${syncService.activeDevices.length}'),
                
                // Active devices list
                if (syncService.activeDevices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Active Devices:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...syncService.activeDevices.map((deviceId) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            deviceId,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                
                // Sync features
                const SizedBox(height: 16),
                const Text(
                  'Sync Features:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildFeatureRow('Orders', Icons.receipt, Colors.orange),
                _buildFeatureRow('Inventory', Icons.inventory, Colors.green),
                _buildFeatureRow('Users', Icons.people, Colors.blue),
                _buildFeatureRow('Menu Items', Icons.restaurant_menu, Colors.purple),
                _buildFeatureRow('Categories', Icons.category, Colors.indigo),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            feature,
            style: const TextStyle(fontSize: 12),
          ),
          const Spacer(),
          const Icon(Icons.sync, size: 14, color: Colors.green),
        ],
      ),
    );
  }

  String _formatDetailedTime(DateTime time) {
    return '${time.day}/${time.month}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
} 