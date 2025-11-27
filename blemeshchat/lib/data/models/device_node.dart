class DeviceNode {
  final String id;              // Unique device identifier
  final String name;            // User-friendly name
  final String address;         // BLE MAC address
  final int rssi;              // Signal strength
  final DateTime lastSeen;     // Last contact timestamp
  final bool isConnected;      // Connection status
  final int hopCount;          // Hops away from this device

  DeviceNode({
    required this.id,
    required this.name,
    required this.address,
    required this.rssi,
    required this.lastSeen,
    required this.isConnected,
    this.hopCount = 0,
  });

  // Create from JSON
  factory DeviceNode.fromJson(Map<String, dynamic> json) {
    return DeviceNode(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      rssi: json['rssi'] as int,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      isConnected: json['isConnected'] as bool,
      hopCount: json['hopCount'] as int? ?? 0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'rssi': rssi,
      'lastSeen': lastSeen.toIso8601String(),
      'isConnected': isConnected,
      'hopCount': hopCount,
    };
  }

  // Create a copy with modified fields
  DeviceNode copyWith({
    String? id,
    String? name,
    String? address,
    int? rssi,
    DateTime? lastSeen,
    bool? isConnected,
    int? hopCount,
  }) {
    return DeviceNode(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
      hopCount: hopCount ?? this.hopCount,
    );
  }

  // For database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'last_seen': lastSeen.millisecondsSinceEpoch,
      'hop_count': hopCount,
    };
  }

  // Create from database map
  factory DeviceNode.fromMap(Map<String, dynamic> map) {
    return DeviceNode(
      id: map['id'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      rssi: -100, // Default RSSI when loading from DB
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int),
      isConnected: false, // Connection status is runtime only
      hopCount: map['hop_count'] as int? ?? 0,
    );
  }

  // Check if device is considered stale (not seen recently)
  bool isStale({Duration threshold = const Duration(minutes: 5)}) {
    return DateTime.now().difference(lastSeen) > threshold;
  }

  // Get signal strength quality
  SignalStrength getSignalQuality() {
    if (rssi >= -50) return SignalStrength.excellent;
    if (rssi >= -60) return SignalStrength.good;
    if (rssi >= -70) return SignalStrength.fair;
    if (rssi >= -80) return SignalStrength.poor;
    return SignalStrength.veryPoor;
  }

  @override
  String toString() {
    return 'DeviceNode(id: $id, name: $name, rssi: $rssi, connected: $isConnected, hops: $hopCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceNode && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum SignalStrength {
  excellent,
  good,
  fair,
  poor,
  veryPoor,
}