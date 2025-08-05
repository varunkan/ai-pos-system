import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cloud synchronization service for real-time updates across multiple devices
/// This service ensures that changes made on one device are immediately reflected
/// on all other devices connected to the same restaurant tenant
class CloudSyncService extends ChangeNotifier {
  static CloudSyncService? _instance;
  static final _lock = Object();
  
  // WebSocket connection for real-time updates
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _syncTimer;
  
  // Connection state
  bool _isConnected = false;
  bool _isReconnecting = false;
  bool _isOnline = false;
  int _reconnectAttempts = 0;
  
  // Device and restaurant info
  String? _deviceId;
  String? _restaurantId;
  String? _userId;
  
  // Configuration
  static const String _defaultServerUrl = 'wss://ai-pos-sync.herokuapp.com/ws';
  static const String _defaultApiUrl = 'https://ai-pos-sync.herokuapp.com/api';
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _syncInterval = Duration(seconds: 10);
  static const int _maxReconnectAttempts = 10;
  
  String _serverUrl = _defaultServerUrl;
  String _apiUrl = _defaultApiUrl;
  
  // Event streams for different data types
  final StreamController<Map<String, dynamic>> _orderUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _menuUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _inventoryUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _tableUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _printerUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Pending changes queue
  final List<Map<String, dynamic>> _pendingChanges = [];
  final Set<String> _processedChanges = {};
  
  // Connectivity subscription
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  bool get isOnline => _isOnline;
  Stream<Map<String, dynamic>> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get menuUpdates => _menuUpdatesController.stream;
  Stream<Map<String, dynamic>> get inventoryUpdates => _inventoryUpdatesController.stream;
  Stream<Map<String, dynamic>> get tableUpdates => _tableUpdatesController.stream;
  Stream<Map<String, dynamic>> get userUpdates => _userUpdatesController.stream;
  Stream<Map<String, dynamic>> get printerUpdates => _printerUpdatesController.stream;
  
  factory CloudSyncService() {
    synchronized(_lock, () {
      _instance ??= CloudSyncService._internal();
    });
    return _instance!;
  }
  
  CloudSyncService._internal();
  
  /// Initialize the cloud sync service
  Future<void> initialize({
    required String restaurantId,
    String? deviceId,
    String? userId,
    String? serverUrl,
    String? apiUrl,
  }) async {
    _restaurantId = restaurantId;
    _deviceId = deviceId ?? await _generateDeviceId();
    _userId = userId;
    _serverUrl = serverUrl ?? _defaultServerUrl;
    _apiUrl = apiUrl ?? _defaultApiUrl;
    
    debugPrint('☁️ CloudSyncService: Initializing for restaurant: $restaurantId');
    debugPrint('☁️ CloudSyncService: Device ID: $_deviceId');
    
    // Initialize connectivity monitoring
    await _initializeConnectivity();
    
    // Initialize local storage
    await _initializeLocalStorage();
    
    // Connect to real-time server
    await connect();
    
    // Start background sync
    _startBackgroundSync();
    
    debugPrint('☁️ CloudSyncService: Initialized successfully');
  }
  
  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      
      _connectivitySubscription = connectivity.onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;
        
        debugPrint('☁️ CloudSyncService: Connectivity changed - Online: $_isOnline');
        
        if (!wasOnline && _isOnline) {
          debugPrint('☁️ CloudSyncService: Connection restored, reconnecting...');
          connect();
        } else if (wasOnline && !_isOnline) {
          debugPrint('☁️ CloudSyncService: Connection lost, going offline...');
          _isConnected = false;
          notifyListeners();
        }
      });
      
      debugPrint('☁️ CloudSyncService: Connectivity monitoring initialized');
    } catch (e) {
      debugPrint('⚠️ CloudSyncService: Failed to initialize connectivity: $e');
    }
  }
  
  /// Initialize local storage
  Future<void> _initializeLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt('last_cloud_sync_$_restaurantId') ?? 0;
      debugPrint('☁️ CloudSyncService: Last sync timestamp: $lastSync');
    } catch (e) {
      debugPrint('⚠️ CloudSyncService: Failed to initialize local storage: $e');
    }
  }
  
  /// Connect to real-time server
  Future<void> connect() async {
    if (_isConnected || _isReconnecting || !_isOnline) return;
    
    try {
      _isReconnecting = true;
      notifyListeners();
      
      final uri = Uri.parse('$_serverUrl?device_id=$_deviceId&restaurant_id=$_restaurantId');
      _channel = IOWebSocketChannel.connect(uri);
      
      await _channel!.ready;
      
      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0;
      
      debugPrint('☁️ CloudSyncService: Connected to $_serverUrl');
      
      // Start listening for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      
      // Start heartbeat
      _startHeartbeat();
      
      // Send initial registration
      _sendMessage({
        'type': 'register',
        'device_id': _deviceId,
        'restaurant_id': _restaurantId,
        'user_id': _userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('☁️ CloudSyncService: Connection failed: $e');
      _isConnected = false;
      _isReconnecting = false;
      _scheduleReconnect();
      notifyListeners();
    }
  }
  
  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final changeId = data['change_id'] as String?;
      
      // Skip if we processed this change
      if (changeId != null && _processedChanges.contains(changeId)) {
        return;
      }
      
      debugPrint('☁️ CloudSyncService: Received message type: $type');
      
      switch (type) {
        case 'order_update':
          _orderUpdatesController.add(data);
          break;
        case 'menu_update':
          _menuUpdatesController.add(data);
          break;
        case 'inventory_update':
          _inventoryUpdatesController.add(data);
          break;
        case 'table_update':
          _tableUpdatesController.add(data);
          break;
        case 'user_update':
          _userUpdatesController.add(data);
          break;
        case 'printer_update':
          _printerUpdatesController.add(data);
          break;
        case 'heartbeat_response':
          // Heartbeat acknowledged
          break;
        case 'error':
          debugPrint('☁️ CloudSyncService: Server error: ${data['message']}');
          break;
        default:
          debugPrint('☁️ CloudSyncService: Unknown message type: $type');
      }
      
      // Mark as processed
      if (changeId != null) {
        _processedChanges.add(changeId);
      }
      
    } catch (e) {
      debugPrint('☁️ CloudSyncService: Error parsing message: $e');
    }
  }
  
  /// Handle connection errors
  void _handleError(error) {
    debugPrint('☁️ CloudSyncService: WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
    notifyListeners();
  }
  
  /// Handle disconnection
  void _handleDisconnection() {
    debugPrint('☁️ CloudSyncService: WebSocket disconnected');
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
    notifyListeners();
  }
  
  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('☁️ CloudSyncService: Max reconnect attempts reached');
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectDelay.inSeconds * _reconnectAttempts);
    
    debugPrint('☁️ CloudSyncService: Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && _isOnline) {
        connect();
      }
    });
  }
  
  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected) {
        _sendMessage({
          'type': 'heartbeat',
          'device_id': _deviceId,
          'restaurant_id': _restaurantId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }
  
  /// Start background synchronization
  void _startBackgroundSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (_isOnline && _pendingChanges.isNotEmpty) {
        _syncPendingChanges();
      }
    });
  }
  
  /// Send message to server
  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('☁️ CloudSyncService: Error sending message: $e');
      }
    }
  }
  
  /// Queue a change for synchronization
  void queueChange(String dataType, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'data_change',
      'data_type': dataType,
      'action': action,
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
      'change_id': '${DateTime.now().millisecondsSinceEpoch}_${_deviceId}_${(data['id'] ?? '').toString()}',
    };
    
    _pendingChanges.add(change);
    
    // Send immediately if connected
    if (_isConnected) {
      _sendMessage(change);
    }
    
    debugPrint('☁️ CloudSyncService: Queued change: $dataType/$action');
  }
  
  /// Sync pending changes
  Future<void> _syncPendingChanges() async {
    if (_pendingChanges.isEmpty || !_isOnline) return;
    
    try {
      final changes = List<Map<String, dynamic>>.from(_pendingChanges);
      _pendingChanges.clear();
      
      final response = await http.post(
        Uri.parse('$_apiUrl/sync'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'restaurant_id': _restaurantId,
          'device_id': _deviceId,
          'changes': changes,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        debugPrint('☁️ CloudSyncService: Synced ${changes.length} changes');
        
        // Update last sync timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_cloud_sync_$_restaurantId', DateTime.now().millisecondsSinceEpoch);
        
      } else {
        debugPrint('☁️ CloudSyncService: Sync failed: HTTP ${response.statusCode}');
        // Re-queue changes
        _pendingChanges.addAll(changes);
      }
      
    } catch (e) {
      debugPrint('☁️ CloudSyncService: Sync error: $e');
      // Re-queue changes
      _pendingChanges.addAll(_pendingChanges);
    }
  }
  
  /// Broadcast order update to all connected devices
  void broadcastOrderUpdate(String orderId, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'order_update',
      'order_id': orderId,
      'action': action, // 'created', 'updated', 'status_changed', 'completed'
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(change);
    queueChange('orders', action, {'id': orderId, ...data});
  }
  
  /// Broadcast menu update
  void broadcastMenuUpdate(String itemId, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'menu_update',
      'item_id': itemId,
      'action': action, // 'created', 'updated', 'deleted', 'availability_changed'
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(change);
    queueChange('menu_items', action, {'id': itemId, ...data});
  }
  
  /// Broadcast inventory update
  void broadcastInventoryUpdate(String itemId, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'inventory_update',
      'item_id': itemId,
      'action': action, // 'stock_changed', 'item_added', 'item_removed', 'low_stock_alert'
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(change);
    queueChange('inventory', action, {'id': itemId, ...data});
  }
  
  /// Broadcast table update
  void broadcastTableUpdate(String tableId, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'table_update',
      'table_id': tableId,
      'action': action, // 'occupied', 'available', 'reserved', 'cleaning'
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(change);
    queueChange('tables', action, {'id': tableId, ...data});
  }
  
  /// Broadcast user update
  void broadcastUserUpdate(String userId, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'user_update',
      'user_id': userId,
      'action': action, // 'created', 'updated', 'deleted', 'role_changed'
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(change);
    queueChange('users', action, {'id': userId, ...data});
  }
  
  /// Broadcast printer update
  void broadcastPrinterUpdate(String printerId, String action, Map<String, dynamic> data) {
    final change = {
      'type': 'printer_update',
      'printer_id': printerId,
      'action': action, // 'added', 'removed', 'configured', 'assignment_changed'
      'data': data,
      'device_id': _deviceId,
      'restaurant_id': _restaurantId,
      'user_id': _userId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _sendMessage(change);
    queueChange('printers', action, {'id': printerId, ...data});
  }
  
  /// Generate unique device ID
  Future<String> _generateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp % 10000).toString().padLeft(4, '0');
      deviceId = 'pos_device_$random';
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }
  
  /// Update user ID
  void updateUserId(String userId) {
    _userId = userId;
    if (_isConnected) {
      _sendMessage({
        'type': 'user_changed',
        'user_id': userId,
        'device_id': _deviceId,
        'restaurant_id': _restaurantId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
  
  /// Force reconnection
  Future<void> forceReconnect() async {
    _disconnect();
    _reconnectAttempts = 0;
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }
  
  /// Disconnect and cleanup
  void _disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _syncTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _isReconnecting = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _disconnect();
    _connectivitySubscription?.cancel();
    _orderUpdatesController.close();
    _menuUpdatesController.close();
    _inventoryUpdatesController.close();
    _tableUpdatesController.close();
    _userUpdatesController.close();
    _printerUpdatesController.close();
    super.dispose();
  }
}

/// Singleton instance for global access
class CloudSyncManager {
  static CloudSyncService? _instance;
  
  static CloudSyncService get instance {
    _instance ??= CloudSyncService();
    return _instance!;
  }
  
  static Future<void> initialize({
    required String restaurantId,
    String? deviceId,
    String? userId,
    String? serverUrl,
    String? apiUrl,
  }) async {
    _instance = CloudSyncService();
    await _instance!.initialize(
      restaurantId: restaurantId,
      deviceId: deviceId,
      userId: userId,
      serverUrl: serverUrl,
      apiUrl: apiUrl,
    );
  }
} 