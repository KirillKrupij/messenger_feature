import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/websocket_client.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_total_unread_count_usecase.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// State management for global unread count
class UnreadCounterState {
  final int count;
  final bool isLoading;
  final String? error;

  UnreadCounterState({
    this.count = 0,
    this.isLoading = false,
    this.error,
  });

  UnreadCounterState copyWith({
    int? count,
    bool? isLoading,
    String? error,
  }) {
    return UnreadCounterState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class UnreadCounterNotifier extends StateNotifier<UnreadCounterState> {
  final GetTotalUnreadCountUseCase _getUnreadCount;
  final WebSocketClient _wsClient;
  final String? _currentUserId;

  UnreadCounterNotifier(
      this._getUnreadCount, this._wsClient, this._currentUserId)
      : super(UnreadCounterState()) {
    _init();
  }

  Future<void> _init() async {
    // 1. Fetch initial count
    state = state.copyWith(isLoading: true);
    final result = await _getUnreadCount(NoParams());
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (count) => state = state.copyWith(isLoading: false, count: count),
    );

    // 2. Listen to WebSocket events
    _wsClient.stream.listen((data) {
      final type = data['type'] as String?;
      final payload = data['payload'];

      if (type == 'chat:message' && payload != null && payload is Map) {
        _handleNewMessage(payload);
      } else if (type == 'chat:status' && payload != null && payload is Map) {
        _handleMessageStatus(payload);
      }
    });
  }

  void _handleNewMessage(Map<dynamic, dynamic> payload) {
    final senderId = payload['sender_id'] as String?;

    // If message is NOT from me, increment count
    // NOTE: This is a simplified check. Ideally we also check if we are currently viewing this chat.
    // However, the provider doesn't know about UI state (active chat).
    // But since the backend updates unread count, we should ideally re-fetch or trust our local increment.
    // If we are in the chat, the ChatNotifier will mark it as read immediately, sending a 'chat:read'.
    // Which might decrement it back?
    // Let's increment for now, and rely on eventual consistency or subsequent read event.
    // Actually, checking activeChatId from ChatProvider might be cleaner if possible,
    // but avoid circular dependency.

    if (senderId != _currentUserId) {
      state = state.copyWith(count: state.count + 1);
    }
  }

  void _handleMessageStatus(Map<dynamic, dynamic> payload) {
    // If status is 'read', and we are the user who read it (implied if we receive this event for our own message? No.)
    // Wait. creating the backend logic:
    // "ALSO send to the current user (other devices) to sync unread count"
    // So if I read a message on another device, I get a 'chat:status' with status='read'.
    // Who is the 'user_id' in payload? The one who read it?
    // chat_handler.go: "user_id": c.UserID (the reader).

    final status = payload['status'] as String?;
    final userId = payload['user_id']
        as String?; // The one who performed the action (read)

    if (status == 'read' && userId == _currentUserId) {
      // We read a message (possibly on another device, or this one).
      // Decrement count.
      // But how many?
      // A 'chat:status' is per message. So decrement by 1.
      // We ensure count doesn't go below 0.
      if (state.count > 0) {
        state = state.copyWith(count: state.count - 1);
      }
    }
  }
}

final unreadCounterProvider =
    StateNotifierProvider<UnreadCounterNotifier, UnreadCounterState>((ref) {
  final getUnreadCount = ref.watch(getTotalUnreadCountUseCaseProvider);
  final wsClient = ref.watch(webSocketClientProvider);
  final authState = ref.watch(authProvider);
  final currentUserId = authState.user?.id;

  return UnreadCounterNotifier(getUnreadCount, wsClient, currentUserId);
});
