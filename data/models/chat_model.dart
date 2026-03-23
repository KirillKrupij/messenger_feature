import '../../domain/entities/chat.dart';
import 'user_status_model.dart';

class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.name,
    required super.isGroup,
    required super.createdAt,
    super.lastMessageText,
    super.lastMessageCreatedAt,
    super.lastMessageSenderId,
    super.lastMessageStatus,
    super.unreadCount,
    super.unseenReactionsCount,
    super.participants,
    super.interlocutorStatus,
    super.ownerId,
    super.description,
    super.avatarFileId,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isGroup: json['is_group'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      lastMessageText: json['last_message_text']?.toString(),
      lastMessageCreatedAt: json['last_message_created_at'] != null
          ? DateTime.parse(json['last_message_created_at'].toString())
          : null,
      lastMessageSenderId: json['last_message_sender_id']?.toString(),
      lastMessageStatus: json['last_message_status']?.toString(),
      unreadCount: (json['unread_count'] is num)
          ? (json['unread_count'] as num).toInt()
          : 0,
      unseenReactionsCount: (json['unseen_reactions_count'] is num)
          ? (json['unseen_reactions_count'] as num).toInt()
          : 0,
      participants: json['participants'] != null
          ? (json['participants'] as List).map((e) => e.toString()).toList()
          : [],
      interlocutorStatus: json['interlocutor_status'] != null
          ? UserStatusModel.fromJson(
              Map<String, dynamic>.from(json['interlocutor_status'] as Map))
          : null,
      ownerId: json['owner_id']?.toString(),
      description: json['description']?.toString(),
      avatarFileId: json['avatar_file_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_group': isGroup,
      'created_at': createdAt.toIso8601String(),
      'participants': participants,
      'owner_id': ownerId,
      'description': description,
      'avatar_file_id': avatarFileId,
    };
  }
}
