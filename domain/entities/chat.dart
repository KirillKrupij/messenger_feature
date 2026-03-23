import 'package:equatable/equatable.dart';
import 'user_status.dart';

class Chat extends Equatable {
  final String id;
  final String name;
  final bool isGroup;
  final DateTime createdAt;

  final String? lastMessageText;
  final DateTime? lastMessageCreatedAt;
  final String? lastMessageSenderId;
  final String? lastMessageStatus;
  final int unreadCount;
  final int unseenReactionsCount;
  final List<String> participants;
  final UserStatus? interlocutorStatus;

  final String? ownerId;
  final String? description;
  final String? avatarFileId;

  const Chat({
    required this.id,
    required this.name,
    required this.isGroup,
    required this.createdAt,
    this.lastMessageText,
    this.lastMessageCreatedAt,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    this.unreadCount = 0,
    this.unseenReactionsCount = 0,
    this.participants = const [],
    this.interlocutorStatus,
    this.ownerId,
    this.description,
    this.avatarFileId,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        isGroup,
        createdAt,
        lastMessageText,
        lastMessageCreatedAt,
        lastMessageSenderId,
        lastMessageStatus,
        unreadCount,
        unseenReactionsCount,
        participants,
        interlocutorStatus,
        ownerId,
        description,
        avatarFileId,
      ];
}
