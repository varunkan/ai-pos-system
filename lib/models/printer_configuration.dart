import 'package:uuid/uuid.dart';

/// Enum for printer types
enum PrinterType {
  wifi,
  ethernet,
  bluetooth,
  usb,
}

/// Enum for printer connection status
enum PrinterConnectionStatus {
  connected,
  disconnected,
  connecting,
  error,
  unknown,
}

/// Enum for printer models
enum PrinterModel {
  epsonTMT88VI('Epson TM-T88VI'),
  epsonTMT88V('Epson TM-T88V'),
  epsonTMT20III('Epson TM-T20III'),
  epsonTMT82III('Epson TM-T82III'),
  epsonTMm30('Epson TM-m30'),
  epsonTMm50('Epson TM-m50'),
  epsonTMP20('Epson TM-P20'),
  epsonTMP60II('Epson TM-P60II'),
  custom('Custom/Other');

  const PrinterModel(this.displayName);
  final String displayName;
}

/// Represents a printer configuration with all connection details
class PrinterConfiguration {
  final String id;
  final String name;
  final String description;
  final PrinterType type;
  final PrinterModel model;
  final String ipAddress;
  final int port;
  final String macAddress;
  final String bluetoothAddress;
  final bool isActive;
  final bool isDefault;
  final PrinterConnectionStatus connectionStatus;
  final DateTime lastConnected;
  final DateTime lastTestPrint;
  final Map<String, dynamic> customSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrinterConfiguration({
    String? id,
    required this.name,
    this.description = '',
    required this.type,
    this.model = PrinterModel.epsonTMT88VI,
    this.ipAddress = '',
    this.port = 9100,
    this.macAddress = '',
    this.bluetoothAddress = '',
    this.isActive = true,
    this.isDefault = false,
    this.connectionStatus = PrinterConnectionStatus.unknown,
    DateTime? lastConnected,
    DateTime? lastTestPrint,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    lastConnected = lastConnected ?? DateTime.fromMillisecondsSinceEpoch(0),
    lastTestPrint = lastTestPrint ?? DateTime.fromMillisecondsSinceEpoch(0),
    customSettings = customSettings ?? {},
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Creates a [PrinterConfiguration] from JSON
  factory PrinterConfiguration.fromJson(Map<String, dynamic> json) {
    return PrinterConfiguration(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: PrinterType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['type'] as String? ?? 'wifi'),
        orElse: () => PrinterType.wifi,
      ),
      model: PrinterModel.values.firstWhere(
        (e) => e.toString().split('.').last == (json['model'] as String? ?? 'epsonTMT88VI'),
        orElse: () => PrinterModel.epsonTMT88VI,
      ),
      ipAddress: json['ip_address'] as String? ?? '',
      port: json['port'] as int? ?? 9100,
      macAddress: json['mac_address'] as String? ?? '',
      bluetoothAddress: json['bluetooth_address'] as String? ?? '',
      isActive: (json['is_active'] as int?) == 1,
      isDefault: (json['is_default'] as int?) == 1,
      connectionStatus: PrinterConnectionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['connection_status'] as String? ?? 'unknown'),
        orElse: () => PrinterConnectionStatus.unknown,
      ),
      lastConnected: json['last_connected'] != null 
          ? DateTime.parse(json['last_connected'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      lastTestPrint: json['last_test_print'] != null 
          ? DateTime.parse(json['last_test_print'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      customSettings: json['custom_settings'] != null 
          ? Map<String, dynamic>.from(json['custom_settings'] as Map)
          : {},
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this [PrinterConfiguration] to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'model': model.toString().split('.').last,
      'ip_address': ipAddress,
      'port': port,
      'mac_address': macAddress,
      'bluetooth_address': bluetoothAddress,
      'is_active': isActive ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
      'connection_status': connectionStatus.toString().split('.').last,
      'last_connected': lastConnected.toIso8601String(),
      'last_test_print': lastTestPrint.toIso8601String(),
      'custom_settings': customSettings,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [PrinterConfiguration] with updated fields
  PrinterConfiguration copyWith({
    String? id,
    String? name,
    String? description,
    PrinterType? type,
    PrinterModel? model,
    String? ipAddress,
    int? port,
    String? macAddress,
    String? bluetoothAddress,
    bool? isActive,
    bool? isDefault,
    PrinterConnectionStatus? connectionStatus,
    DateTime? lastConnected,
    DateTime? lastTestPrint,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrinterConfiguration(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      model: model ?? this.model,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      macAddress: macAddress ?? this.macAddress,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      isActive: isActive ?? this.isActive,
      isDefault: isDefault ?? this.isDefault,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastConnected: lastConnected ?? this.lastConnected,
      lastTestPrint: lastTestPrint ?? this.lastTestPrint,
      customSettings: customSettings ?? this.customSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get the full address for network printers
  String get fullAddress {
    if (type == PrinterType.wifi || type == PrinterType.ethernet) {
      return '$ipAddress:$port';
    }
    return ipAddress;
  }

  /// Check if printer is network-based
  bool get isNetworkPrinter {
    return type == PrinterType.wifi || type == PrinterType.ethernet;
  }

  /// Check if printer is wireless
  bool get isWirelessPrinter {
    return type == PrinterType.wifi || type == PrinterType.bluetooth;
  }

  /// Get connection display text
  String get connectionDisplayText {
    switch (connectionStatus) {
      case PrinterConnectionStatus.connected:
        return 'Connected';
      case PrinterConnectionStatus.disconnected:
        return 'Disconnected';
      case PrinterConnectionStatus.connecting:
        return 'Connecting...';
      case PrinterConnectionStatus.error:
        return 'Error';
      case PrinterConnectionStatus.unknown:
        return 'Unknown';
    }
  }

  /// Get time since last connection
  String get timeSinceLastConnection {
    if (lastConnected.millisecondsSinceEpoch == 0) {
      return 'Never connected';
    }
    
    final now = DateTime.now();
    final difference = now.difference(lastConnected);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterConfiguration && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PrinterConfiguration(id: $id, name: $name, type: $type, address: $fullAddress)';
  }
} 