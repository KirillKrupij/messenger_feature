import '../../domain/entities/message_reaction.dart';

class MessageReactionModel extends MessageReaction {
  const MessageReactionModel({
    required super.id,
    required super.messageId,
    required super.userId,
    required super.reaction,
    required super.createdAt,
  });

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) {
    return MessageReactionModel(
      id: json['id']?.toString() ?? '',
      messageId: json['message_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      reaction: json['reaction']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'reaction': reaction,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
