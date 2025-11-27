import 'package:blemeshchat/data/models/mesh_message.dart';

class Conversation {
  final String id;              // Conversation ID
  final String peerId;          // Other device ID
  final String peerName;        // Other device name
  final List<MeshMessage> messages;
  final DateTime lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    this.messages = const [],
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  // Create from JSON
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      peerId: json['peerId'] as String,
      peerName: json['peerName'] as String,
      messages: (json['messages'] as List<dynamic>?)
          ?.map((m) => MeshMessage.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peerId': peerId,
      'peerName': peerName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  // Create a copy with modified fields
  Conversation copyWith({
    String? id,
    String? peerId,
    String? peerName,
    List<MeshMessage>? messages,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      peerName: peerName ?? this.peerName,
      messages: messages ?? this.messages,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  // For database storage (conversation metadata only)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peer_id': peerId,
      'peer_name': peerName,
      'last_message_time': lastMessageTime.millisecondsSinceEpoch,
      'unread_count': unreadCount,
    };
  }

  // Create from database map
  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      peerId: map['peer_id'] as String,
      peerName: map['peer_name'] as String,
      messages: [], // Messages loaded separately
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(
        map['last_message_time'] as int,
      ),
      unreadCount: map['unread_count'] as int? ?? 0,
    );
  }

  // Get last message
  MeshMessage? get lastMessage {
    if (messages.isEmpty) return null;
    return messages.last;
  }

  // Get last message preview text
  String get lastMessagePreview {
    if (messages.isEmpty) return 'No messages yet';
    final lastMsg = messages.last;
    
    if (lastMsg.type != MessageType.text) {
      return '[System message]';
    }
    
    if (lastMsg.content.length > 50) {
      return '${lastMsg.content.substring(0, 50)}...';
    }
    
    return lastMsg.content;
  }

  // Get display time for last message
  String get lastMessageTimeDisplay {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${lastMessageTime.month}/${lastMessageTime.day}';
    }
  }

  // Add a new message to the conversation
  Conversation addMessage(MeshMessage message) {
    final updatedMessages = [...messages, message];
    return copyWith(
      messages: updatedMessages,
      lastMessageTime: message.timestamp,
    );
  }

  // Update a specific message (e.g., delivery status)
  Conversation updateMessage(String messageId, MeshMessage updatedMessage) {
    final updatedMessages = messages.map((msg) {
      return msg.id == messageId ? updatedMessage : msg;
    }).toList();
    
    return copyWith(messages: updatedMessages);
  }

  // Mark all messages as read
  Conversation markAsRead() {
    return copyWith(unreadCount: 0);
  }

  // Increment unread count
  Conversation incrementUnread() {
    return copyWith(unreadCount: unreadCount + 1);
  }

  // Get messages grouped by date
  Map<DateTime, List<MeshMessage>> get messagesGroupedByDate {
    final grouped = <DateTime, List<MeshMessage>>{};
    
    for (final message in messages) {
      final date = DateTime(
        message.timestamp.year,
        message.timestamp.month,
        message.timestamp.day,
      );
      
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(message);
    }
    
    return grouped;
  }

  // Get sent messages count
  int get sentMessagesCount {
    return messages.where((m) => 
      m.type == MessageType.text && 
      m.senderId != peerId
    ).length;
  }

  // Get received messages count
  int get receivedMessagesCount {
    return messages.where((m) => 
      m.type == MessageType.text && 
      m.senderId == peerId
    ).length;
  }

  // Check if conversation has any undelivered messages
  bool get hasUndeliveredMessages {
    return messages.any((m) => 
      m.status == DeliveryStatus.pending || 
      m.status == DeliveryStatus.failed
    );
  }

  // Get date header text for grouping
  static String getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  String toString() {
    return 'Conversation(peer: $peerName, messages: ${messages.length}, unread: $unreadCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}