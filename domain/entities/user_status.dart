class UserStatus {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const UserStatus({
    required this.userId,
    required this.isOnline,
    this.lastSeenAt,
  });
}
