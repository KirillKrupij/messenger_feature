import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../../domain/entities/chat.dart';
import 'package:intl/intl.dart';

import 'typing_indicator.dart';
import 'package:dems_frontend/config/app_config.dart';
import 'package:dems_frontend/core/constants/api_constants.dart';
import 'package:dems_frontend/features/auth/presentation/providers/auth_provider.dart';

class ChatListWidget extends ConsumerStatefulWidget {
  const ChatListWidget({super.key});

  @override
  ConsumerState<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends ConsumerState<ChatListWidget> {
  final ScrollController _scrollController = ScrollController();
  String? _currentSearchQuery;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when 200px from bottom
      ref.read(chatProvider.notifier).loadMoreChats(query: _currentSearchQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Поиск чатов...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    _currentSearchQuery = value.isEmpty ? null : value;
                    ref
                        .read(chatProvider.notifier)
                        .loadChats(query: _currentSearchQuery);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildContent(context, chatState),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ChatState chatState) {
    if (chatState.isLoading && chatState.chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.error != null && chatState.chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки чатов:\n${chatState.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              TextButton(
                onPressed: () => ref.read(chatProvider.notifier).loadChats(),
                child: const Text('Попробовать снова'),
              ),
            ],
          ),
        ),
      );
    }

    if (chatState.chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_outlined,
                size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Нет чатов',
                style: TextStyle(
                    color: Colors.grey.withOpacity(0.6), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount:
          chatState.chats.length + (chatState.isLoadingMoreChats ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.chats.length) {
          // Loading indicator at bottom
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final chat = chatState.chats[index];
        final isActive = chatState.activeChatId == chat.id;

        // Determine online status
        bool isOnline = false;
        if (!chat.isGroup && chat.participants.isNotEmpty) {
          final otherId = chat.participants.firstWhere(
            (id) => id != chatState.currentUserId,
            orElse: () => '',
          );
          if (otherId.isNotEmpty) {
            isOnline = chatState.userStatuses[otherId]?.isOnline ?? false;
          }
        }

        final isTyping = chatState.typingUsers[chat.id]?.isNotEmpty ?? false;

        return _ChatListItem(
          chat: chat,
          isActive: isActive,
          isOnline: isOnline,
          isTyping: isTyping,
          currentUserId: chatState.currentUserId,
        );
      },
    );
  }
}

class _ChatListItem extends ConsumerStatefulWidget {
  final Chat chat;
  final bool isActive;
  final bool isOnline;
  final bool isTyping;
  final String? currentUserId;

  const _ChatListItem({
    super.key,
    required this.chat,
    required this.isActive,
    required this.isOnline,
    required this.isTyping,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends ConsumerState<_ChatListItem> {
  bool _isHovered = false;

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final localDateTime = dateTime.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck =
        DateTime(localDateTime.year, localDateTime.month, localDateTime.day);

    if (dateToCheck == today) {
      return DateFormat('HH:mm').format(localDateTime);
    } else if (dateToCheck == yesterday) {
      return 'Вчера';
    } else {
      return DateFormat('dd.MM.yy').format(localDateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final isActive = widget.isActive;
    final isOnline = widget.isOnline;
    final isTyping = widget.isTyping;

    // Background color logic
    Color backgroundColor = Colors.transparent;
    if (isActive) {
      backgroundColor = const Color(0xFFF1F5F9);
    } else if (_isHovered) {
      backgroundColor = const Color(0xFFEEF2F6); // Lighter slate for hover
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => ref.read(chatProvider.notifier).selectChat(chat.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              left: BorderSide(
                color: isActive ? const Color(0xFF415BE7) : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: isActive
                        ? const Color(0xFF415BE7)
                        : const Color(0xFFE2E8F0),
                    backgroundImage: chat.avatarFileId != null
                        ? NetworkImage(
                            '${AppConfig.apiBaseUrl}${ApiConstants.fileContent(chat.avatarFileId!)}',
                            headers: {
                              'Authorization':
                                  'Bearer ${ref.read(authLocalDataSourceProvider).getTokenSync()}',
                            },
                          )
                        : null,
                    child: chat.avatarFileId != null
                        ? null
                        : chat.isGroup
                            ? Icon(Icons.group,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF64748B))
                            : Text(
                                chat.name.isNotEmpty
                                    ? chat.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            style: TextStyle(
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 14,
                              color: const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chat.lastMessageCreatedAt != null)
                          Text(
                            _formatTime(chat.lastMessageCreatedAt!),
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: isTyping
                              ? const Row(
                                  children: [
                                    TypingIndicator(
                                      showBubble: false,
                                      dotSize: 4,
                                      dotColor: Color(0xFF415BE7),
                                      padding: EdgeInsets.zero,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Печатает...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF415BE7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  chat.lastMessageText ?? 'Нет сообщений',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive
                                        ? const Color(0xFF475569)
                                        : const Color(0xFF64748B),
                                    fontWeight:
                                        chat.lastMessageStatus != 'read' &&
                                                chat.lastMessageSenderId !=
                                                    widget.currentUserId
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                        // Show unread badge if message is from others and unread
                        // Show status icons if message is from me
                        _buildMessageIndicator(chat),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageIndicator(Chat chat) {
    // If no last message, show nothing
    if (chat.lastMessageSenderId == null) {
      return const SizedBox.shrink();
    }

    // If message is from me, show status ticks
    if (widget.currentUserId != null &&
        chat.lastMessageSenderId == widget.currentUserId) {
      if (chat.lastMessageStatus != null) {
        return Row(
          children: [
            const SizedBox(width: 4),
            _buildStatusIcon(chat.lastMessageStatus!),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    // If message is from others and there are unread messages OR unseen reactions, show badge
    if (chat.unreadCount > 0 || chat.unseenReactionsCount > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chat.unseenReactionsCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              // Circle with heart, no text
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, size: 10, color: Colors.white),
            ),
          if (chat.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF415BE7),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color = const Color(0xFF94A3B8);

    switch (status) {
      case 'sent':
        icon = Icons.check;
        break;
      case 'delivered':
        icon = Icons.done_all;
        break;
      case 'read':
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(icon, size: 14, color: color);
  }
}
