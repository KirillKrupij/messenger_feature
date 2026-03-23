import '../../domain/entities/message.dart';

import 'file_item_model.dart';
import 'message_reaction_model.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.text,
    required super.createdAt,
    super.updatedAt,
    super.isDeleted = false,
    super.isEdited = false,
    super.deletedAt,
    super.status,
    super.senderName,
    super.senderAvatarId,
    super.forwardedFromUserId,
    super.forwardedFromChatId,
    super.forwardedFromName,
    super.originalMessageId,
    super.replyToMessageId,
    super.replyToMessage,
    super.attachments,
    super.reactions,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
      isDeleted: json['is_deleted'] == true,
      isEdited: json['is_edited'] == true,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'].toString())
          : null,
      status: json['status']?.toString(),
      senderName: json['sender_name']?.toString(),
      senderAvatarId: json['sender_avatar_id']?.toString(),
      forwardedFromUserId: json['forwarded_from_user_id']?.toString(),
      forwardedFromChatId: json['forwarded_from_chat_id']?.toString(),
      forwardedFromName: json['forwarded_from_name']?.toString(),
      originalMessageId: json['original_message_id']?.toString(),
      replyToMessageId: json['reply_to_message_id']?.toString(),
      replyToMessage: json['reply_to_message'] != null
          ? MessageModel.fromJson(
              json['reply_to_message'] as Map<String, dynamic>)
          : null,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((item) =>
                  FileItemModel.fromJson(item as Map<String, dynamic>))
              .toList()
              .toList()
          : [],
      reactions: json['reactions'] != null
          ? (json['reactions'] as List)
              .map((item) =>
                  MessageReactionModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_deleted': isDeleted,
      'is_edited': isEdited,
      'deleted_at': deletedAt?.toIso8601String(),
      'status': status,
      'sender_name': senderName,
      'sender_avatar_id': senderAvatarId,
      'forwarded_from_user_id': forwardedFromUserId,
      'forwarded_from_chat_id': forwardedFromChatId,
      'forwarded_from_name': forwardedFromName,
      'original_message_id': originalMessageId,
      'reply_to_message_id': replyToMessageId,
      if (replyToMessage != null)
        'reply_to_message': (replyToMessage as MessageModel).toJson(),
      'attachments':
          attachments.map((e) => (e as FileItemModel).toJson()).toList(),
      'reactions':
          reactions.map((e) => (e as MessageReactionModel).toJson()).toList(),
    };
  }
}
