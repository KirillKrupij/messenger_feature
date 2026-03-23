import 'package:equatable/equatable.dart';

class MessageReaction extends Equatable {
  final String id;
  final String messageId;
  final String userId;
  final String reaction;
  final DateTime createdAt;

  const MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reaction,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, messageId, userId, reaction, createdAt];
}
