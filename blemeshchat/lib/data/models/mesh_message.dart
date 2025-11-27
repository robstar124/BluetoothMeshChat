import 'dart:convert';
import 'dart:typed_data';

class MeshMessage {
  final String id;              // Unique message ID
  final String senderId;        // Original sender device ID
  final String senderName;      // Sender display name
  final String? recipientId;    // null for broadcast, ID for direct
  final String content;         // Message text
  final MessageType type;       // TEXT, DISCOVERY, ACK, ROUTE_REQUEST
  final DateTime timestamp;     // When message was created
  final int ttl;               // Time To Live (hop limit)
  final int sequenceNumber;    // For ordering/deduplication
  final List<String> routePath; // Device IDs message has traversed
  final DeliveryStatus status; // PENDING, SENT, DELIVERED, FAILED

  MeshMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.recipientId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.ttl = 5,
    this.sequenceNumber = 0,
    this.routePath = const [],
    this.status = DeliveryStatus.pending,
  });

  // Create from JSON
  factory MeshMessage.fromJson(Map<String, dynamic> json) {
    return MeshMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      recipientId: json['recipientId'] as String?,
      content: json['content'] as String,
      type: MessageType.values[json['type'] as int],
      timestamp: DateTime.parse(json['timestamp'] as String),
      ttl: json['ttl'] as int? ?? 5,
      sequenceNumber: json['sequenceNumber'] as int? ?? 0,
      routePath: (json['routePath'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      status: DeliveryStatus.values[json['status'] as int? ?? 0],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientId,
      'content': content,
      'type': type.index,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl,
      'sequenceNumber': sequenceNumber,
      'routePath': routePath,
      'status': status.index,
    };
  }

  // Create a copy with modified fields
  MeshMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    int? ttl,
    int? sequenceNumber,
    List<String>? routePath,
    DeliveryStatus? status,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      routePath: routePath ?? this.routePath,
      status: status ?? this.status,
    );
  }

  // For database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'recipient_id': recipientId,
      'content': content,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'ttl': ttl,
      'sequence_number': sequenceNumber,
      'route_path': routePath.join(','),
      'status': status.index,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // Create from database map
  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    return MeshMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      senderName: map['sender_name'] as String,
      recipientId: map['recipient_id'] as String?,
      content: map['content'] as String,
      type: MessageType.values[map['type'] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      ttl: map['ttl'] as int,
      sequenceNumber: map['sequence_number'] as int,
      routePath: (map['route_path'] as String).isEmpty
          ? []
          : (map['route_path'] as String).split(','),
      status: DeliveryStatus.values[map['status'] as int],
    );
  }

  // Serialize to binary format for BLE transmission
  Uint8List toBinary() {
    final buffer = BytesBuilder();
    
    // Header (20 bytes)
    buffer.add(_uuidToBytes(id));                    // 16 bytes
    buffer.add(_uint16ToBytes(type.index));          // 2 bytes
    buffer.add([ttl]);                               // 1 byte
    buffer.add([sequenceNumber]);                    // 1 byte
    
    // Body
    buffer.add(_uuidToBytes(senderId));              // 16 bytes
    buffer.add(_uuidToBytes(recipientId ?? '00000000-0000-0000-0000-000000000000')); // 16 bytes
    buffer.add(_uint32ToBytes(timestamp.millisecondsSinceEpoch ~/ 1000)); // 4 bytes (Unix seconds)
    
    final senderNameBytes = utf8.encode(senderName);
    final contentBytes = utf8.encode(content);
    final routePathString = routePath.join(',');
    final routePathBytes = utf8.encode(routePathString);
    
    buffer.add(_uint16ToBytes(contentBytes.length)); // 2 bytes
    buffer.add([senderNameBytes.length]);            // 1 byte
    buffer.add(senderNameBytes);                     // Variable
    buffer.add(contentBytes);                        // Variable
    buffer.add(routePathBytes);                      // Variable
    
    return buffer.toBytes();
  }

  // Deserialize from binary format
  factory MeshMessage.fromBinary(Uint8List data) {
    int offset = 0;
    
    // Parse header
    final id = _bytesToUuid(data.sublist(offset, offset + 16));
    offset += 16;
    
    final typeIndex = _bytesToUint16(data.sublist(offset, offset + 2));
    offset += 2;
    
    final ttl = data[offset];
    offset += 1;
    
    final sequenceNumber = data[offset];
    offset += 1;
    
    // Parse body
    final senderId = _bytesToUuid(data.sublist(offset, offset + 16));
    offset += 16;
    
    final recipientIdStr = _bytesToUuid(data.sublist(offset, offset + 16));
    final recipientId = recipientIdStr == '00000000-0000-0000-0000-000000000000' 
        ? null 
        : recipientIdStr;
    offset += 16;
    
    final timestampSeconds = _bytesToUint32(data.sublist(offset, offset + 4));
    final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);
    offset += 4;
    
    final contentLength = _bytesToUint16(data.sublist(offset, offset + 2));
    offset += 2;
    
    final senderNameLength = data[offset];
    offset += 1;
    
    final senderName = utf8.decode(data.sublist(offset, offset + senderNameLength));
    offset += senderNameLength;
    
    final content = utf8.decode(data.sublist(offset, offset + contentLength));
    offset += contentLength;
    
    final routePathString = offset < data.length 
        ? utf8.decode(data.sublist(offset)) 
        : '';
    final routePath = routePathString.isEmpty 
        ? <String>[] 
        : routePathString.split(',');
    
    return MeshMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      content: content,
      type: MessageType.values[typeIndex],
      timestamp: timestamp,
      ttl: ttl,
      sequenceNumber: sequenceNumber,
      routePath: routePath,
      status: DeliveryStatus.pending,
    );
  }

  // Helper methods for binary conversion
  static Uint8List _uuidToBytes(String uuid) {
    final cleaned = uuid.replaceAll('-', '');
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static String _bytesToUuid(Uint8List bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Uint8List _uint16ToBytes(int value) {
    return Uint8List(2)
      ..[0] = (value >> 8) & 0xFF
      ..[1] = value & 0xFF;
  }

  static int _bytesToUint16(Uint8List bytes) {
    return (bytes[0] << 8) | bytes[1];
  }

  static Uint8List _uint32ToBytes(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  static int _bytesToUint32(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  // Check if message is a broadcast
  bool get isBroadcast => recipientId == null;

  // Check if message is expired (based on timestamp)
  bool isExpired({Duration maxAge = const Duration(hours: 24)}) {
    return DateTime.now().difference(timestamp) > maxAge;
  }

  // Get display time (e.g., "2m ago", "Yesterday")
  String getDisplayTime() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  // Get hop count from route path
  int get hopCount => routePath.length;

  @override
  String toString() {
    return 'MeshMessage(id: $id, from: $senderName, type: $type, ttl: $ttl, hops: $hopCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MeshMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum MessageType {
  text,           // Chat message
  discovery,      // Network discovery broadcast
  ack,           // Acknowledgment
  routeRequest,  // Ask for route to specific device
  routeReply,    // Response with route info
}

enum DeliveryStatus {
  pending,    // Not yet sent
  sent,       // Sent to at least one peer
  delivered,  // Confirmed received by recipient
  failed,     // Failed to deliver
}