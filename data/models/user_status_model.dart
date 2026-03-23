import '../../domain/entities/user_status.dart';

class UserStatusModel extends UserStatus {
  const UserStatusModel({
    required super.userId,
    required super.isOnline,
    super.lastSeenAt,
  });

  factory UserStatusModel.fromJson(Map<String, dynamic> json) {
    return UserStatusModel(
      userId: json['user_id']?.toString() ?? '',
      isOnline: json['is_online'] == true,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_online': isOnline,
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }
}
