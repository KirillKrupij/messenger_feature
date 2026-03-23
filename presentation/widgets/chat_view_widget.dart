import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../providers/chat_provider.dart';
import 'animated_chat_message.dart';
import 'chat_input.dart';
import 'package:dems_frontend/core/notifications/index.dart';
import 'package:dems_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'typing_indicator.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import 'chat_picker_dialog.dart';
import 'chat_info_dialog.dart';

import 'package:dems_frontend/config/app_config.dart';
import 'package:dems_frontend/core/constants/api_constants.dart';

class ChatViewWidget extends ConsumerStatefulWidget {
  final String chatId;

  const ChatViewWidget({super.key, required this.chatId});

  @override
  ConsumerState<ChatViewWidget> createState() => _ChatViewWidgetState();
}

class _ChatViewWidgetState extends ConsumerState<ChatViewWidget> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _showScrollButton = false;
  bool _isSearchingMessage = false;
  bool _isSearchBarVisible = false;
  final TextEditingController _searchController = TextEditingController();

  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScroll);
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Determine visibility of "Scroll to Bottom" button
    // In reverse list, index 0 is the bottom.
    // If the first visible item index is > 2, show button.
    final minIndex =
        positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final shouldShowButton = minIndex > 2;

    if (shouldShowButton != _showScrollButton) {
      if (mounted) {
        setState(() {
          _showScrollButton = shouldShowButton;
        });
      }
    }

    // Load more when scrolling near top (end of list in reverse)
    final maxIndex =
        positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final chatState = ref.read(chatProvider);
    final messages = chatState.messages[widget.chatId] ?? [];
    // Approximate total items count
    final totalItems = messages.length;

    if (maxIndex >= totalItems - 5) {
      ref.read(chatProvider.notifier).loadMoreMessages(widget.chatId);
    }
  }

  void _scrollToBottom() {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _scrollToMessage(String messageId) async {
    if (_isSearchingMessage) return;

    setState(() {
      _isSearchingMessage = true;
    });

    try {
      bool found = false;
      int attempts = 0;
      const maxAttempts = 10; // Prevent infinite loop

      while (!found && attempts < maxAttempts) {
        final chatState = ref.read(chatProvider);
        final messages = chatState.messages[widget.chatId] ?? [];
        final msgIndex = messages.indexWhere((m) => m.id == messageId);

        if (msgIndex != -1) {
          found = true;
          final isTyping =
              chatState.typingUsers[widget.chatId]?.isNotEmpty ?? false;
          // Calculate view index
          // messages list: [oldest ... newest]
          // view (reverse): [newest ... oldest]
          // viewIndex = (length - 1 - msgIndex) + (typing ? 1 : 0)
          final viewIndex =
              (messages.length - 1 - msgIndex) + (isTyping ? 1 : 0);

          if (_itemScrollController.isAttached) {
            _itemScrollController.scrollTo(
              index: viewIndex,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.5, // Center the message
            );

            // Highlight the message
            if (mounted) {
              setState(() {
                _highlightedMessageId = messageId;
              });

              // Remove highlight after 2 seconds
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted && _highlightedMessageId == messageId) {
                  setState(() {
                    _highlightedMessageId = null;
                  });
                }
              });
            }
          }
        } else {
          // If not found, check if we can load more
          if (chatState.hasMoreMessages[widget.chatId] == false) {
            if (mounted) {
              ref.read(notificationServiceProvider.notifier).warning(
                'Сообщение не найдено',
                'Удалено или слишком старое',
              );
            }
            break;
          }

          // Load more
          await ref.read(chatProvider.notifier).loadMoreMessages(widget.chatId);
          attempts++;
          // Give a small delay to allow state update if needed, though await should handle it
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingMessage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);
    final messages = chatState.messages[widget.chatId] ?? [];
    final activeChat = chatState.chats.firstWhere((c) => c.id == widget.chatId);

    // Check if anyone else is typing
    final isTyping = chatState.typingUsers[widget.chatId]?.isNotEmpty ?? false;

    ref.listen(chatProvider, (prev, next) {
      final prevCount = prev?.messages[widget.chatId]?.length ?? 0;
      final nextCount = next.messages[widget.chatId]?.length ?? 0;

      final prevTyping = prev?.typingUsers[widget.chatId]?.isNotEmpty ?? false;
      final nextTyping = next.typingUsers[widget.chatId]?.isNotEmpty ?? false;

      if ((prevCount != nextCount || (!prevTyping && nextTyping)) &&
          !_isSearchingMessage) {
        if (nextCount > prevCount &&
            prevCount > 0 &&
            nextCount - prevCount == 1) {
          final positions = _itemPositionsListener.itemPositions.value;
          final isAtBottom = positions.isNotEmpty &&
              positions.map((p) => p.index).reduce((a, b) => a < b ? a : b) <=
                  1;
          if (isAtBottom) {
            _scrollToBottom();
          }
        }
      }
    });

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
          ),
          child: _isSearchBarVisible
              ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF64748B)),
                      onPressed: () {
                        setState(() {
                          _isSearchBarVisible = false;
                          _searchController.clear();
                        });
                        ref.read(chatProvider.notifier).clearSearch();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Поиск...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                        onChanged: (value) {
                          ref.read(chatProvider.notifier).searchMessages(value);
                        },
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(chatProvider.notifier).searchMessages('');
                        },
                      ),
                  ],
                )
              : chatState.isSelectionMode
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () =>
                              ref.read(chatProvider.notifier).clearSelection(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${chatState.selectedMessageIds.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: chatState.selectedMessageIds.isEmpty
                                  ? Colors.grey
                                  : Colors.red),
                          onPressed: chatState.selectedMessageIds.isEmpty
                              ? null
                              : () => _confirmBatchDelete(context, ref),
                        ),
                        IconButton(
                          icon: Icon(Icons.forward,
                              color: chatState.selectedMessageIds.isEmpty
                                  ? Colors.grey
                                  : const Color(0xFF415BE7)),
                          onPressed: chatState.selectedMessageIds.isEmpty
                              ? null
                              : () => _handleBatchForward(context, ref),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18),
                          onPressed: () =>
                              ref.read(chatProvider.notifier).selectChat(null),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _showChatDetails(context, activeChat),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  backgroundImage:
                                      activeChat.avatarFileId != null
                                          ? NetworkImage(
                                              '${AppConfig.apiBaseUrl}${ApiConstants.fileContent(activeChat.avatarFileId!)}',
                                              headers: {
                                                'Authorization':
                                                    'Bearer ${ref.read(authLocalDataSourceProvider).getTokenSync()}',
                                              },
                                            )
                                          : null,
                                  child: activeChat.avatarFileId != null
                                      ? null
                                      : activeChat.isGroup
                                          ? const Icon(Icons.group,
                                              size: 20,
                                              color: Color(0xFF64748B))
                                          : Text(
                                              activeChat.name.isNotEmpty
                                                  ? activeChat.name[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF64748B)),
                                            ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(activeChat.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                      _buildStatusText(activeChat, chatState),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search,
                              color: Color(0xFF64748B)),
                          tooltip: 'Поиск',
                          onPressed: () {
                            setState(() {
                              _isSearchBarVisible = true;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.checklist,
                              color: Color(0xFF64748B)),
                          tooltip: 'Выбрать сообщения',
                          onPressed: () {
                            // We need a way to enter selection mode without selecting a specific message initially.
                            // Or we can just start selection mode?
                            // The provider has selectedMessageIds. defining isSelectionMode as selectedMessageIds.isNotEmpty.
                            // So we might need a dedicated flag or we just don't have empty selection mode supported yet?
                            // Checking ChatState: bool get isSelectionMode => selectedMessageIds.isNotEmpty;
                            // So currently we CANNOT be in selection mode with 0 items.
                            // I should probably update ChatProvider to support empty selection mode OR
                            // effectively I can't trigger "Selection Mode" without selecting something if the getter uses the list.

                            // Wait, the user requirement is "button to enter selection mode".
                            // If I cannot support empty selection, maybe I should select the last message? No that's unexpected.
                            // I should probably refactor ChatState to have an explicit `isSelectionMode` flag,
                            // OR I can just make the UI logic support it.
                            // Let's assume for now I will try to support it by maybe dealing with the provider later?
                            // Actually, looking at ChatState, `isSelectionMode` is a getter.
                            // If I want to support "Choice mode" with 0 items, I need to change the state.
                            // Let's check ChatState again.
                            // Yes: bool get isSelectionMode => selectedMessageIds.isNotEmpty;
                            // I will have to modify ChatState to add `isManualSelectionMode` or similar?
                            // Or I can change the getter.

                            // For this step, I will add the button but it requires a new method in notifier `enterSelectionMode`.
                            ref
                                .read(chatProvider.notifier)
                                .enterSelectionMode();
                          },
                        ),
                      ],
                    ),
        ),

        // Messages or Search Results
        Expanded(
          child: _isSearchBarVisible &&
                  (chatState.searchQuery?.isNotEmpty ?? false)
              ? _buildSearchResults(chatState)
              : Stack(
                  children: [
                    messages.isEmpty && !isTyping
                        ? Center(
                            child: Text(
                              'Нет сообщений. Напишите первым!',
                              style: TextStyle(
                                  color: Colors.grey.withOpacity(0.6),
                                  fontSize: 13),
                            ),
                          )
                        : ScrollablePositionedList.builder(
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                            reverse: true, // Messages scroll from bottom to top
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: messages.length +
                                ((chatState.isLoadingMoreMessages[
                                            widget.chatId] ??
                                        false)
                                    ? 1
                                    : 0) +
                                (isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Display typing indicator at index 0 (bottom visual)
                              if (isTyping && index == 0) {
                                return const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.only(left: 10, bottom: 10),
                                    child: TypingIndicator(),
                                  ),
                                );
                              }

                              // Adjust index to account for typing indicator
                              final adjustedIndex = index - (isTyping ? 1 : 0);

                              // Loading indicator at top (index = last element in reverse list)
                              if (adjustedIndex == messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              // Reverse index for messages (newest at bottom)
                              final msgIndex =
                                  messages.length - 1 - adjustedIndex;
                              final msg = messages[msgIndex];
                              final isMe = msg.senderId == authState.user?.id;

                              // Date Header Logic
                              Widget? dateHeader;
                              if (_shouldShowDateHeader(msgIndex, messages)) {
                                final dateText = _getDateLabel(msg.createdAt);
                                if (dateText != null) {
                                  dateHeader = _buildDateHeader(dateText);
                                }
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (dateHeader != null) dateHeader,
                                  AnimatedChatMessage(
                                    key: ValueKey(
                                        msg.id), // Important for animation
                                    message: msg,
                                    isMe: isMe,
                                    isHighlighted:
                                        msg.id == _highlightedMessageId,
                                    isGroup: activeChat.isGroup,
                                    onReplyTap: _scrollToMessage,
                                  ),
                                ],
                              );
                            },
                          ),

                    // Scroll to bottom button
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        opacity: _showScrollButton ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: !_showScrollButton,
                          child: GestureDetector(
                            onTap: _scrollToBottom,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_isSearchingMessage)
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
        ),

        // Input
        ChatInput(
          onSend: (text, attachments) async {
            // Handle attachments upload and sending here or in ChatInput?
            // Ideally ChatInput should give us files, and we upload them or ChatInput uploaded them.
            // But based on ChatInput plan, ChatInput will handle upload logic internally or returning files.
            // If ChatInput returns `attachments` (List<PlatformFile>), we need to upload them here.

            final notifier = ref.read(chatProvider.notifier);
            final List<String> attachmentIds = [];

            for (var file in attachments) {
              final id = await notifier.uploadFile(file);
              if (id != null) attachmentIds.add(id);
            }

            notifier.sendMessage(text, attachmentIds: attachmentIds);
          },
          onTyping: (isTyping) =>
              ref.read(chatProvider.notifier).sendTyping(isTyping),
          editingMessage: chatState.editingMessage,
          replyingToMessage: chatState.replyingToMessage,
          onEdit: (id, text) =>
              ref.read(chatProvider.notifier).editMessage(id, text),
          onCancelEdit: () =>
              ref.read(chatProvider.notifier).setEditingMessage(null),
          onCancelReply: () =>
              ref.read(chatProvider.notifier).setReplyingToMessage(null),
        ),
      ],
    );
  }

  Future<void> _handleBatchForward(BuildContext context, WidgetRef ref) async {
    final targetChatIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => const ChatPickerDialog(),
    );

    if (targetChatIds != null && targetChatIds.isNotEmpty && context.mounted) {
      final selectedIds = ref.read(chatProvider).selectedMessageIds.toList();

      for (final chatId in targetChatIds) {
        await ref
            .read(chatProvider.notifier)
            .forwardMessages(selectedIds, chatId);
      }

      if (context.mounted) {
        if (targetChatIds.length == 1) {
          ref.read(chatProvider.notifier).selectChat(targetChatIds.first);
        } else {
          // Go to chat list
          ref.read(chatProvider.notifier).selectChat(null);
        }
      }
    }
  }

  void _confirmBatchDelete(BuildContext context, WidgetRef ref) {
    final count = ref.read(chatProvider).selectedMessageIds.length;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить $count ${count == 1 ? 'сообщение' : (count >= 2 && count <= 4) ? 'сообщения' : 'сообщений'}?',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatProvider.notifier).deleteSelectedMessages();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(Chat chat, ChatState chatState) {
    if (chat.isGroup) return const SizedBox.shrink();

    String? statusText;
    Color statusColor = const Color(0xFF64748B);

    if (chat.participants.isNotEmpty) {
      final otherId = chat.participants.firstWhere(
        (String id) => id != chatState.currentUserId,
        orElse: () => '',
      );
      if (otherId.isNotEmpty) {
        final status = chatState.userStatuses[otherId];
        if (status != null) {
          if (status.isOnline) {
            statusText = 'Онлайн';
            statusColor = Colors.green;
          } else if (status.lastSeenAt != null) {
            final now = DateTime.now();
            final diff = now.difference(status.lastSeenAt!.toLocal());
            String timeStr;
            if (diff.inDays == 0) {
              timeStr =
                  DateFormat('HH:mm').format(status.lastSeenAt!.toLocal());
            } else {
              timeStr = DateFormat('dd.MM HH:mm')
                  .format(status.lastSeenAt!.toLocal());
            }
            statusText = 'Был(а) в $timeStr';
          }
        }
      }
    }

    if (statusText == null) return const SizedBox.shrink();

    return Text(
      statusText,
      style: TextStyle(
        color: statusColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _showChatDetails(BuildContext context, Chat chat) {
    if (!chat.isGroup) return; // Only for groups for now, or also for private?
    // For specific users in private chat, we might want to show their profile.
    // For now, let's enable it for groups as requested.

    showDialog(
      context: context,
      builder: (context) => ChatInfoDialog(chat: chat),
    );
  }

  bool _shouldShowDateHeader(int index, List<Message> messages) {
    if (index == 0) return true; // Always check for the first message (oldest)

    final currentMsg = messages[index];
    final prevMsg =
        messages[index - 1]; // Message BEFORE the current one in time

    final currDate = currentMsg.createdAt.toLocal();
    final prevDate = prevMsg.createdAt.toLocal();

    return !_isSameDay(currDate, prevDate);
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String? _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(localDate.year, localDate.month, localDate.day);

    if (msgDate == today) {
      return null; // Don't show header for today
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (msgDate == yesterday) {
      return 'Вчера';
    }

    final beforeYesterday = today.subtract(const Duration(days: 2));
    if (msgDate == beforeYesterday) {
      return 'Позавчера';
    }

    return DateFormat('d MMMM yyyy', 'ru').format(localDate);
  }

  Widget _buildDateHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(ChatState chatState) {
    if (chatState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.searchResults.isEmpty) {
      return const Center(child: Text("Ничего не найдено"));
    }

    return ListView.builder(
      itemCount: chatState.searchResults.length,
      itemBuilder: (context, index) {
        final msg = chatState.searchResults[index];
        return ListTile(
          title: Text(
              (msg.senderName ?? "").isNotEmpty ? msg.senderName! : "User"),
          subtitle: Text(
            msg.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            DateFormat('dd.MM.yy').format(msg.createdAt.toLocal()),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: () async {
            // Close search mode and jump
            setState(() {
              _isSearchBarVisible = false;
              _searchController.clear();
            });
            ref
                .read(chatProvider.notifier)
                .clearSearch(); // Clear search results

            await ref
                .read(chatProvider.notifier)
                .jumpToMessage(widget.chatId, msg.id.toString());

            // After jump, scroll to it
            await _scrollToMessage(msg.id.toString());
          },
        );
      },
    );
  }
}
