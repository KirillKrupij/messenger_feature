import 'package:equatable/equatable.dart';
import 'file_item.dart';
import 'message_reaction.dart';

/// Сущность сообщения в чате.
/// Содержит все данные сообщения: текст, вложения, реакции, статусы, информацию о пересылке и ответах.
class Message extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? deletedAt;
  final String? status; // 'sent', 'delivered', 'read'
  final String? senderName;
  final String? senderAvatarId;

  final String? forwardedFromUserId;
  final String? forwardedFromChatId;
  final String? forwardedFromName;
  final String? originalMessageId;

  final String? replyToMessageId;
  final Message? replyToMessage;
  final List<FileItem> attachments;
  final List<MessageReaction> reactions;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.isEdited = false,
    this.deletedAt,
    this.status,
    this.senderName,
    this.senderAvatarId,
    this.forwardedFromUserId,
    this.forwardedFromChatId,
    this.forwardedFromName,
    this.originalMessageId,
    this.replyToMessageId,
    this.replyToMessage,
    this.attachments = const [],
    this.reactions = const [],
  });

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        text,
        createdAt,
        updatedAt,
        isDeleted,
        isEdited,
        deletedAt,
        status,
        senderName,
        senderAvatarId,
        forwardedFromUserId,
        forwardedFromChatId,
        forwardedFromName,
        originalMessageId,
        replyToMessageId,
        replyToMessage,
        attachments,
        reactions,
      ];
}
