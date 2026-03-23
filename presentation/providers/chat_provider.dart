import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dems_frontend/core/network/websocket_client.dart';
import 'package:dems_frontend/core/network/network_provider.dart';
import 'package:dems_frontend/core/services/push_notification_service.dart';

import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/models/message_model.dart';
import 'package:dems_frontend/features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/user_status.dart';
import '../../data/models/user_status_model.dart';
import '../../data/models/chat_model.dart';

/// Состояние чата, содержащее все данные, необходимые для отображения и управления мессенджером.
/// Включает списки чатов, сообщений, статусы загрузки, ошибки, активный чат, индикаторы набора текста,
/// выбранные сообщения, статусы пользователей и состояние поиска.
class ChatState {
  /// Список чатов (диалогов) пользователя
  final List<Chat> chats;

  /// Сообщения, сгруппированные по ID чата: chatId -> список сообщений (от старых к новым)
  final Map<String, List<Message>> messages;

  /// Флаг загрузки данных (например, при первоначальной загрузке чатов)
  final bool isLoading;

  /// Текст ошибки, если что-то пошло не так
  final String? error;

  /// ID активного (открытого) чата
  final String? activeChatId;

  /// ID текущего пользователя (для определения своих сообщений)
  final String? currentUserId;

  /// Есть ли ещё чаты для подгрузки (пагинация)
  final bool hasMoreChats;

  /// Идёт ли загрузка дополнительных чатов
  final bool isLoadingMoreChats;

  /// Флаги наличия дополнительных сообщений для каждого чата
  final Map<String, bool> hasMoreMessages;

  /// Флаги загрузки дополнительных сообщений для каждого чата
  final Map<String, bool> isLoadingMoreMessages;

  /// Пользователи, которые в данный момент печатают в каждом чате
  final Map<String, Set<String>> typingUsers;

  /// Сообщение, которое редактируется в данный момент
  final Message? editingMessage;

  /// Сообщение, на которое пользователь отвечает
  final Message? replyingToMessage;

  /// Набор ID выбранных сообщений (для операций массового выделения)
  final Set<String> selectedMessageIds;

  /// Статусы онлайн/офлайн пользователей
  final Map<String, UserStatus> userStatuses;

  /// Режим ручного выбора сообщений (включён ли режим выделения)
  final bool isManualSelectionMode;

  /// Состояние поиска
  final bool isSearching;
  final String? searchQuery;
  final List<Message> searchResults;

  ChatState({
    this.chats = const [],
    this.messages = const {},
    this.isLoading = false,
    this.error,
    this.activeChatId,
    this.currentUserId,
    this.hasMoreChats = true,
    this.isLoadingMoreChats = false,
    this.hasMoreMessages = const {},
    this.isLoadingMoreMessages = const {},
    this.typingUsers = const {},
    this.editingMessage,
    this.replyingToMessage,
    this.selectedMessageIds = const {},
    this.userStatuses = const {},
    this.isManualSelectionMode = false,
    this.isSearching = false,
    this.searchQuery,
    this.searchResults = const [],
  });

  bool get isSelectionMode =>
      selectedMessageIds.isNotEmpty || isManualSelectionMode;

  ChatState copyWith({
    List<Chat>? chats,
    Map<String, List<Message>>? messages,
    bool? isLoading,
    String? error,
    String? activeChatId,
    String? currentUserId,
    bool? hasMoreChats,
    bool? isLoadingMoreChats,
    Map<String, bool>? hasMoreMessages,
    Map<String, bool>? isLoadingMoreMessages,
    bool clearActiveChat = false,
    Map<String, Set<String>>? typingUsers,
    Message? editingMessage,
    bool clearEditingMessage = false,
    Message? replyingToMessage,
    bool clearReplyingToMessage = false,
    Set<String>? selectedMessageIds,
    Map<String, UserStatus>? userStatuses,
    bool? isManualSelectionMode,
    bool? isSearching,
    String? searchQuery,
    List<Message>? searchResults,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Error is allowed to be cleared by passing null
      activeChatId:
          clearActiveChat ? null : (activeChatId ?? this.activeChatId),
      currentUserId: currentUserId ?? this.currentUserId,
      hasMoreChats: hasMoreChats ?? this.hasMoreChats,
      isLoadingMoreChats: isLoadingMoreChats ?? this.isLoadingMoreChats,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isLoadingMoreMessages:
          isLoadingMoreMessages ?? this.isLoadingMoreMessages,
      typingUsers: typingUsers ?? this.typingUsers,
      editingMessage:
          clearEditingMessage ? null : (editingMessage ?? this.editingMessage),
      replyingToMessage: clearReplyingToMessage
          ? null
          : (replyingToMessage ?? this.replyingToMessage),
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      userStatuses: userStatuses ?? this.userStatuses,
      isManualSelectionMode:
          isManualSelectionMode ?? this.isManualSelectionMode,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
    );
  }
}

final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRemoteDataSourceImpl(dio: dio);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remote = ref.watch(chatRemoteDataSourceProvider);
  return ChatRepositoryImpl(remoteDataSource: remote);
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final wsClient = ref.watch(webSocketClientProvider);
  final authState = ref.watch(authProvider);
  final currentUserId = authState.user?.id;
  final pushNotificationService = ref.watch(pushNotificationServiceProvider);
  return ChatNotifier(repo, wsClient, currentUserId, pushNotificationService);
});

/// Основной Notifier для управления состоянием чата.
/// Обрабатывает загрузку чатов и сообщений, подписку на WebSocket-события,
/// отправку сообщений, управление выделением, реакциями, статусами и т.д.
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repo;
  final WebSocketClient _wsClient;
  final String? _currentUserId;
  final PushNotificationService _pushNotificationService;

  ChatNotifier(this._repo, this._wsClient, this._currentUserId,
      this._pushNotificationService)
      : super(ChatState(currentUserId: _currentUserId)) {
    _init();
  }

  void _init() async {
    _wsClient.stream.listen((data) {
      final type = data['type'] as String?;
      final payload = data['payload'];

      if (type == 'chat:message' && payload != null && payload is Map) {
        final message =
            MessageModel.fromJson(Map<String, dynamic>.from(payload));
        _handleNewMessage(message);
      } else if (type == 'chat:status' && payload != null && payload is Map) {
        final Map<String, dynamic> statusMap =
            Map<String, dynamic>.from(payload);
        _handleStatusUpdate(statusMap);
      } else if (type == 'chat:typing' && payload != null && payload is Map) {
        final Map<String, dynamic> typingMap =
            Map<String, dynamic>.from(payload);
        _handleTypingEvent(typingMap);
      } else if (type == 'chat:reaction_update' &&
          payload != null &&
          payload is Map) {
        final message =
            MessageModel.fromJson(Map<String, dynamic>.from(payload));
        _handleReactionUpdate(message);
      } else if (type == 'user:status' && payload != null && payload is Map) {
        final Map<String, dynamic> statusMap =
            Map<String, dynamic>.from(payload);
        _handleUserStatusUpdate(statusMap);
      } else if (type == 'user:status:list' &&
          payload != null &&
          payload is List) {
        final List<dynamic> statusList = List<dynamic>.from(payload);
        _handleUserStatusList(statusList);
      } else if (type == 'chat:messages' && payload != null && payload is Map) {
        final messagesData = payload['messages'];
        if (messagesData is List) {
          final messages = messagesData
              .where((m) => m is Map)
              .map((m) =>
                  MessageModel.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList();
          _handleNewMessages(messages);
        }
      } else if (type == 'chat:created' && payload != null && payload is Map) {
        final chat = ChatModel.fromJson(Map<String, dynamic>.from(payload));
        _handleChatCreated(chat);
      }
    });

    loadChats();
  }

  void _handleUserStatusUpdate(Map<String, dynamic> payload) {
    try {
      final status = UserStatusModel.fromJson(payload);
      final updatedStatuses = Map<String, UserStatus>.from(state.userStatuses);
      updatedStatuses[status.userId] = status;
      state = state.copyWith(userStatuses: updatedStatuses);
    } catch (e) {
      print('[ERROR] Failed to parse user status update: $e');
    }
  }

  void _handleUserStatusList(List<dynamic> payload) {
    try {
      final updatedStatuses = Map<String, UserStatus>.from(state.userStatuses);
      for (var item in payload) {
        if (item is Map) {
          final status =
              UserStatusModel.fromJson(Map<String, dynamic>.from(item));
          updatedStatuses[status.userId] = status;
        }
      }
      state = state.copyWith(userStatuses: updatedStatuses);
    } catch (e) {
      print('[ERROR] Failed to parse user status list: $e');
    }
  }

  void _handleTypingEvent(Map<String, dynamic> payload) {
    final chatId = payload['chat_id'] as String?;
    final userId = payload['user_id'] as String?;
    final isTyping = payload['is_typing'] as bool?;

    if (chatId == null || userId == null || isTyping == null) return;
    if (userId == _currentUserId) return; // Should not happen but good safety

    final currentTyping = state.typingUsers[chatId] ?? {};
    final newTyping = Set<String>.from(currentTyping);

    if (isTyping) {
      newTyping.add(userId);
    } else {
      newTyping.remove(userId);
    }

    final updatedTypingUsers = Map<String, Set<String>>.from(state.typingUsers);
    updatedTypingUsers[chatId] = newTyping;

    state = state.copyWith(typingUsers: updatedTypingUsers);
  }

  void sendTyping(bool isTyping) {
    if (state.activeChatId == null) return;

    _wsClient.sendMessage('chat:typing', {
      'chat_id': state.activeChatId,
      'is_typing': isTyping,
    });
  }

  void setEditingMessage(Message? message) {
    state = state.copyWith(
      editingMessage: message,
      clearEditingMessage: message == null,
      clearReplyingToMessage: message != null, // Clear reply when editing
    );
  }

  void setReplyingToMessage(Message? message) {
    state = state.copyWith(
      replyingToMessage: message,
      clearReplyingToMessage: message == null,
      clearEditingMessage: message != null, // Clear edit when replying
    );
  }

  void editMessage(String messageId, String newText) {
    if (state.activeChatId == null || newText.trim().isEmpty) return;

    _wsClient.sendMessage('chat:edit', {
      'message_id': messageId,
      'text': newText,
    });
    setEditingMessage(null);
  }

  void deleteMessage(String messageId) {
    if (state.activeChatId == null) return;

    _wsClient.sendMessage('chat:delete', {
      'message_id': messageId,
    });
  }

  void toggleSelection(String messageId) {
    final updatedSelection = Set<String>.from(state.selectedMessageIds);
    if (updatedSelection.contains(messageId)) {
      updatedSelection.remove(messageId);
    } else {
      updatedSelection.add(messageId);
      // Cancel editing if entering selection mode
      if (state.editingMessage != null) {
        setEditingMessage(null);
      }
    }
    state = state.copyWith(selectedMessageIds: updatedSelection);
  }

  void enterSelectionMode() {
    state = state.copyWith(isManualSelectionMode: true);
    if (state.editingMessage != null) {
      setEditingMessage(null);
    }
  }

  void clearSelection() {
    state =
        state.copyWith(selectedMessageIds: {}, isManualSelectionMode: false);
  }

  void deleteSelectedMessages() {
    if (state.selectedMessageIds.isEmpty) return;

    for (final messageId in state.selectedMessageIds) {
      deleteMessage(messageId);
    }
    clearSelection();
  }

  Future<void> searchMessages(String query) async {
    if (state.activeChatId == null) return;
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    state = state
        .copyWith(isSearching: true, searchQuery: query, searchResults: []);

    try {
      final result = await _repo.searchMessages(
        state.activeChatId!,
        query,
      );

      result.fold(
        (failure) {
          if (mounted) {
            state = state.copyWith(isSearching: false, error: failure.message);
          }
        },
        (messages) {
          if (mounted) {
            state = state.copyWith(
              isSearching: false,
              searchResults: messages,
            );
          }
        },
      );
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        state = state.copyWith(isSearching: false, error: e.toString());
      }
    }
  }

  void clearSearch() {
    state = state.copyWith(
      isSearching: false,
      searchQuery: null,
      searchResults: [],
    );
  }

  Future<void> forwardMessages(
      List<String> messageIds, String targetChatId) async {
    if (messageIds.isEmpty) return;

    _wsClient.sendMessage('chat:forward', {
      'target_chat_id': targetChatId,
      'message_ids': messageIds,
    });
    // We clear selection after forwarding if we were in selection mode
    if (state.isSelectionMode) {
      clearSelection();
    }
  }

  Future<void> jumpToMessage(String chatId, String messageId) async {
    try {
      final result = await _repo.getMessageContext(chatId, messageId);
      await result.fold((failure) {
        if (mounted) state = state.copyWith(error: failure.message);
      }, (offset) async {
        // Check if we already have this message loaded
        final currentLen = state.messages[chatId]?.length ?? 0;
        if (offset < currentLen) {
          // Message already loaded, UI will handle scrolling
          return;
        }

        // Load enough messages to include the target message
        final needed = offset + 20; // Load extra for context

        final msgsResult =
            await _repo.getChatMessages(chatId, limit: needed, offset: 0);
        msgsResult.fold((failure) {
          if (mounted) state = state.copyWith(error: failure.message);
        }, (messages) {
          final updatedMessages =
              Map<String, List<Message>>.from(state.messages);
          updatedMessages[chatId] = messages;
          if (mounted) {
            state = state.copyWith(messages: updatedMessages);
          }
        });
      });
    } catch (e) {
      print('Jump error: $e');
    }
  }

  void _handleNewMessage(Message message) {
    if (message.isDeleted) {
      _handleMessageDeleted(message);
      return;
    }

    final currentMessages = state.messages[message.chatId] ?? [];
    final updatedMessages = Map<String, List<Message>>.from(state.messages);

    final existingIndex = currentMessages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      // Update existing message
      final updatedList = List<Message>.from(currentMessages);
      updatedList[existingIndex] = message;
      updatedMessages[message.chatId] = updatedList;

      // If we are updating an existing message, we might not need to manage typing users
      // But let's keep the logic consistent
      state = state.copyWith(messages: updatedMessages);

      // If the message is the last one in the chat, update the chat list
      _updateChatList(message, isNew: false);
    } else {
      // Add new message
      updatedMessages[message.chatId] = [...currentMessages, message];

      // Remote user stop typing when message received (only for new messages)
      if (message.senderId != _currentUserId) {
        final currentTyping = state.typingUsers[message.chatId] ?? {};
        if (currentTyping.contains(message.senderId)) {
          final newTyping = Set<String>.from(currentTyping);
          newTyping.remove(message.senderId);
          final updatedTypingUsers =
              Map<String, Set<String>>.from(state.typingUsers);
          updatedTypingUsers[message.chatId] = newTyping;

          state = state.copyWith(
              messages: updatedMessages, typingUsers: updatedTypingUsers);
        } else {
          state = state.copyWith(messages: updatedMessages);
        }
      } else {
        state = state.copyWith(messages: updatedMessages);
      }

      // Update chat list for new message
      _updateChatList(message, isNew: true);
    }

    // Only mark as read/delivered if WE are the recipient
    if (_currentUserId != null && message.senderId != _currentUserId) {
      // If this is the active chat, mark as read
      if (state.activeChatId == message.chatId) {
        markAsRead(message.id);
      } else {
        markAsDelivered(message.id);
      }
    }
  }

  void _handleNewMessages(List<Message> messages) {
    if (messages.isEmpty) return;

    // Group by chatId to batch updates per chat
    final Map<String, List<Message>> messagesByChat = {};
    for (final msg in messages) {
      if (!messagesByChat.containsKey(msg.chatId)) {
        messagesByChat[msg.chatId] = [];
      }
      messagesByChat[msg.chatId]!.add(msg);
    }

    // Process each chat's batch
    final updatedMessagesMap = Map<String, List<Message>>.from(state.messages);
    Map<String, Set<String>> updatedTypingUsers =
        Map<String, Set<String>>.from(state.typingUsers);
    bool stateChanged = false;

    // Filter outdeleted? No, handle them same as new
    // Assuming these are NEW messages (forwarded or bulk sent)

    messagesByChat.forEach((chatId, chatNewMessages) {
      final currentMessages = updatedMessagesMap[chatId] ?? [];

      // Merge
      // For simplicity, just append new ones.
      // In complex cases, we might need to check for duplicates,
      // but forwarded messages usually have new IDs.

      final mergedMessages = [...currentMessages, ...chatNewMessages];
      // Sort in case order is mixed
      mergedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      updatedMessagesMap[chatId] = mergedMessages;
      stateChanged = true;

      // Update typing status (remove sender from typing)
      // Only check the LAST message from a user? Or all?
      // Usually if they sent a message they stopped typing.
      final currentTyping = updatedTypingUsers[chatId] ?? {};
      bool typingChanged = false;
      final newTyping = Set<String>.from(currentTyping);

      for (final msg in chatNewMessages) {
        if (msg.senderId != _currentUserId &&
            newTyping.contains(msg.senderId)) {
          newTyping.remove(msg.senderId);
          typingChanged = true;
        }
      }

      if (typingChanged) {
        updatedTypingUsers[chatId] = newTyping;
      }

      // Update chat list using the Last message of the batch
      final lastMsg = chatNewMessages.last;
      _updateChatList(lastMsg, isNew: true);
    });

    if (stateChanged) {
      state = state.copyWith(
        messages: updatedMessagesMap,
        typingUsers: updatedTypingUsers,
      );
    }

    // Batch read receipts?
    // We can iterate and mark relevant ones.
    for (final msg in messages) {
      if (_currentUserId != null && msg.senderId != _currentUserId) {
        if (state.activeChatId == msg.chatId) {
          markAsRead(msg.id);
        } else {
          markAsDelivered(msg.id);
        }
      }
    }
  }

  void _handleChatCreated(Chat chat) {
    if (state.chats.any((c) => c.id == chat.id)) return;

    final updatedChats = [chat, ...state.chats];
    state = state.copyWith(chats: updatedChats);
  }

  void _handleMessageDeleted(Message message) {
    final currentMessages = state.messages[message.chatId] ?? [];
    final existingIndex = currentMessages.indexWhere((m) => m.id == message.id);

    if (existingIndex == -1) {
      // Message not found locally, but we might need to update chat list if it was the last message
      // and we just don't have the history loaded.
      // Ideally we should check if the deleted message matches the last message of the chat.
      _checkAndUpdateChatListOnDelete(message);
      return;
    }

    // Remove message from local list
    final updatedList = List<Message>.from(currentMessages);
    updatedList.removeAt(existingIndex);

    final updatedMessages = Map<String, List<Message>>.from(state.messages);
    updatedMessages[message.chatId] = updatedList;

    state = state.copyWith(messages: updatedMessages);

    _checkAndUpdateChatListOnDelete(message);
  }

  void _checkAndUpdateChatListOnDelete(Message message) {
    final chatIndex = state.chats.indexWhere((c) => c.id == message.chatId);
    if (chatIndex == -1) return;

    final chat = state.chats[chatIndex];

    // If we can identify that the deleted message was the last one, we need to refresh the chat list
    // or optimistically update it.
    // Since we don't store message ID in chat list item (only text, time, sender),
    // we can try to match by content or just always reload the chat item from server to be safe.
    // reloading is safer to get the correct "new" last message.

    // Using a more robust match check
    final bool isLastMessage = chat.lastMessageCreatedAt == message.createdAt &&
        chat.lastMessageText == message.text;

    if (isLastMessage) {
      // Ideally: fetch updated chat info.
      // Workaround: Trigger a load of chats again or just this chat.
      // Since we don't want to reload everything, let's try to see if we have the previous message in `state.messages`.
      final messages = state.messages[message.chatId];
      if (messages != null && messages.isNotEmpty) {
        final newLast = messages.last; // Assuming ordered by time
        final updatedChat = Chat(
          id: chat.id,
          name: chat.name,
          isGroup: chat.isGroup,
          createdAt: chat.createdAt,
          lastMessageText: newLast.text,
          lastMessageCreatedAt: newLast.createdAt,
          lastMessageSenderId: newLast.senderId,
          lastMessageStatus: newLast.status,
          unreadCount: chat.unreadCount > 0
              ? chat.unreadCount - 1
              : 0, // Decrement unread? heuristic
          unseenReactionsCount: chat.unseenReactionsCount,
          participants: chat.participants,
          avatarFileId: chat.avatarFileId,
          ownerId: chat.ownerId,
          description: chat.description,
          interlocutorStatus: chat.interlocutorStatus,
        );
        final updatedChats = List<Chat>.from(state.chats);
        updatedChats[chatIndex] = updatedChat;
        state = state.copyWith(chats: updatedChats);
      } else {
        // No messages loaded, or empty. Fallback to reload chats to be safe.
        loadChats();
      }
    } else {
      // If it wasn't the last message, but it might have been unread, we should ideally decrement count.
      // But we don't know if the deleted message was read or not easily without more state.
      // Backend handles unread count. So reloading chats is the source of truth.
      // If we want to be correct about unread count, we should reload.
      loadChats();
    }
  }

  void _updateChatList(Message message, {required bool isNew}) {
    if (state.chats.isEmpty) return;

    final chatIndex = state.chats.indexWhere((c) => c.id == message.chatId);
    if (chatIndex == -1) {
      // Chat not found in list, and it's a new message -> reload chats to get it
      if (isNew) loadChats();
      return;
    }

    final chat = state.chats[chatIndex];

    // Determine if we should increment unread count
    // If message is from someone else AND we're not in this chat AND it is NEW, increment
    final isFromMe =
        _currentUserId != null && message.senderId == _currentUserId;
    final isActiveChat = state.activeChatId == message.chatId;
    final shouldIncrementUnread = isNew && !isFromMe && !isActiveChat;

    // Check if we should update the last message preview
    // Update if:
    // 1. It is a NEW message (latest by definition)
    // 2. OR the timestamp is NEWER than current last message (shouldn't happen for updates usually)
    // 3. OR it's an update to the SAME message that is currently the last one (matched by timestamp)
    bool shouldUpdatePreview = false;
    if (isNew) {
      shouldUpdatePreview = true;
    } else {
      final currentLastTime = chat.lastMessageCreatedAt;
      if (currentLastTime != null) {
        // If timestamps match, it's likely the same message being updated (e.g. reaction added)
        // Note: comparing AtMicrosecond might be flaky, but usually ok from same source.
        if (message.createdAt.isAtSameMomentAs(currentLastTime)) {
          shouldUpdatePreview = true;
        }
        // If update is somehow newer (e.g. edit changed timestamp? usually edit updates updated_at, not created_at)
        // We rely on created_at for ordering.
      }
    }

    // Prepare updated chat object
    Chat updatedChat = chat;

    if (shouldUpdatePreview) {
      updatedChat = Chat(
        id: chat.id,
        name: chat.name,
        isGroup: chat.isGroup,
        createdAt: chat.createdAt,
        lastMessageText: _getPreviewText(message),
        lastMessageCreatedAt: message.createdAt,
        lastMessageSenderId: message.senderId,
        lastMessageStatus: message.status,
        unreadCount:
            shouldIncrementUnread ? chat.unreadCount + 1 : chat.unreadCount,
        unseenReactionsCount: chat.unseenReactionsCount,
        participants: chat.participants,
        avatarFileId: chat.avatarFileId,
        ownerId: chat.ownerId,
        description: chat.description,
        interlocutorStatus: chat.interlocutorStatus,
      );
    } else if (shouldIncrementUnread) {
      // Just update unread count if preview didn't change (unlikely for new message, but safe)
      updatedChat = Chat(
        id: chat.id,
        name: chat.name,
        isGroup: chat.isGroup,
        createdAt: chat.createdAt,
        lastMessageText: chat.lastMessageText,
        lastMessageCreatedAt: chat.lastMessageCreatedAt,
        lastMessageSenderId: chat.lastMessageSenderId,
        lastMessageStatus: chat.lastMessageStatus,
        unreadCount: chat.unreadCount + 1,
        unseenReactionsCount: chat.unseenReactionsCount,
        participants: chat.participants,
        avatarFileId: chat.avatarFileId,
        ownerId: chat.ownerId,
        description: chat.description,
        interlocutorStatus: chat.interlocutorStatus,
      );
    } else {
      // If neither preview needs update nor unread count, we might still check unseen reactions
      // But unseen reactions count comes from backend aggregate.
      // We can't easily calculate it here without knowing previous state of reactions.
      // For now, if it's just a reaction update on an old message, we DO NOT change the chat list item
      // unless we want to reflect "someone reacted" indicator?
      // The user wants the indicator.
      // If it's an update and it has reactions from others...
      // We don't have logic here to increment `unseenReactionsCount` reliably because we don't know if it was ALREADY counted.
      // So we rely on a refresh or we just leave it be until next fetch.
      // Given complexity, better to NOT touch it on generic update to avoid "wrong" values.
      return;
    }

    final updatedChats = List<Chat>.from(state.chats);
    updatedChats.removeAt(chatIndex);

    // Only move to top if it's a NEW message
    if (isNew) {
      updatedChats.insert(0, updatedChat);
    } else {
      updatedChats.insert(chatIndex, updatedChat);
    }

    state = state.copyWith(chats: updatedChats);
  }

  void _handleStatusUpdate(Map<String, dynamic> payload) {
    final chatId = payload['chat_id'] as String?;
    final messageId = payload['message_id'] as String?;
    final status = payload['status'] as String?;

    if (chatId == null || messageId == null || status == null) return;

    final chatMessages = state.messages[chatId];
    if (chatMessages == null) return;

    final messageIndex = chatMessages.indexWhere((m) => m.id == messageId);
    if (messageIndex == -1) return;

    final message = chatMessages[messageIndex];

    // Don't downgrade status (e.g., if we get 'delivered' after 'read')
    if (message.status == 'read') return;
    if (message.status == 'delivered' && status == 'delivered') return;

    final updatedMessage = MessageModel(
      id: message.id,
      chatId: message.chatId,
      senderId: message.senderId,
      text: message.text,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      isDeleted: message.isDeleted,
      isEdited: message.isEdited,
      deletedAt: message.deletedAt,
      status: status,
      senderName: message.senderName,
      forwardedFromUserId: message.forwardedFromUserId,
      forwardedFromChatId: message.forwardedFromChatId,
      forwardedFromName: message.forwardedFromName,
      originalMessageId: message.originalMessageId,
      replyToMessageId: message.replyToMessageId,
      replyToMessage: message.replyToMessage,
      attachments: message.attachments,
      reactions: message.reactions,
    );

    final updatedMessages = Map<String, List<Message>>.from(state.messages);
    final updatedChatMessages = List<Message>.from(chatMessages);
    updatedChatMessages[messageIndex] = updatedMessage;
    updatedMessages[chatId] = updatedChatMessages;

    state = state.copyWith(messages: updatedMessages);

    // Also update chat list if this is the last message
    _updateChatListStatus(chatId, messageId, status);
  }

  void _updateChatListStatus(String chatId, String messageId, String status) {
    final chatIndex = state.chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;

    final chat = state.chats[chatIndex];

    // Only update if this status update is for the last message in this chat
    if (chat.lastMessageSenderId == null) return;
    // We don't have message ID in chat list, so we assume if it's the latest, it matches
    // This is a simplification - in production you'd want to track message IDs

    final updatedChat = Chat(
      id: chat.id,
      name: chat.name,
      isGroup: chat.isGroup,
      createdAt: chat.createdAt,
      lastMessageText: chat.lastMessageText,
      lastMessageCreatedAt: chat.lastMessageCreatedAt,
      lastMessageSenderId: chat.lastMessageSenderId,
      lastMessageStatus: status,
      unreadCount: chat.unreadCount,
      participants: chat.participants,
      avatarFileId: chat.avatarFileId,
      ownerId: chat.ownerId,
      description: chat.description,
      interlocutorStatus: chat.interlocutorStatus,
    );

    final updatedChats = List<Chat>.from(state.chats);
    updatedChats[chatIndex] = updatedChat;

    state = state.copyWith(chats: updatedChats);
  }

  void _handleReactionUpdate(Message message) {
    // 1. Update message in active chat view if loaded
    final currentMessages = state.messages[message.chatId];
    if (currentMessages != null) {
      final messageIndex =
          currentMessages.indexWhere((m) => m.id == message.id);
      if (messageIndex != -1) {
        final updatedList = List<Message>.from(currentMessages);
        updatedList[messageIndex] = message;

        final updatedMessages = Map<String, List<Message>>.from(state.messages);
        updatedMessages[message.chatId] = updatedList;
        state = state.copyWith(messages: updatedMessages);
      }
    }

    // 2. Update chat list for Unseen Reactions Indicator
    final chatIndex = state.chats.indexWhere((c) => c.id == message.chatId);
    if (chatIndex == -1) return; // Chat not in list, ignore until reload

    final chat = state.chats[chatIndex];
    // Actually, "Unseen Reaction" depends on WHO reacted.
    // The payload `message` has a list of reactions.
    // We need to know if the reaction is NEW and from SOMEONE ELSE.
    // Ideally we diff the reactions, but that's hard.
    // Heuristic: If we receive a reaction update for a chat we are NOT currently active in,
    // and the message has reactions from others, show the indicator.

    // Better heuristic: If I am NOT the one reacting (which triggers the update usually),
    // or if the event came from WS (meaning someone else triggered it),
    // and I am NOT in the chat, then increment unseen count.

    // Since we don't know who triggered the update easily from just the message payload (unless we check reaction timestamps),
    // let's assume any reaction update when we are not in the chat implies a potential unseen reaction.
    // To be precise: we should validte if there is at least one reaction from NOT ME.

    final bool hasReactionFromOthers =
        message.reactions.any((r) => r.userId != _currentUserId);

    if (state.activeChatId != message.chatId && hasReactionFromOthers) {
      // Increment unseen count to ensure icon shows up.
      // If it was 0, make it 1. If it was >0, keep it or increment.
      // Since we don't track exact number accurately without backend help, just ensuring it is > 0 is enough for the icon.
      // Let's increment it to be safe, or just set to 1 if it was 0.
      int newUnseenCount = chat.unseenReactionsCount;
      if (newUnseenCount == 0) {
        newUnseenCount = 1;
      }

      // Don't update last message text/time.
      final updatedChat = Chat(
        id: chat.id,
        name: chat.name,
        isGroup: chat.isGroup,
        createdAt: chat.createdAt,
        lastMessageText: chat.lastMessageText,
        lastMessageCreatedAt: chat.lastMessageCreatedAt,
        lastMessageSenderId: chat.lastMessageSenderId,
        lastMessageStatus: chat.lastMessageStatus,
        unreadCount: chat.unreadCount, // KEEP SAME
        unseenReactionsCount: newUnseenCount,
        participants: chat.participants,
        avatarFileId: chat.avatarFileId,
        ownerId: chat.ownerId,
        description: chat.description,
        interlocutorStatus: chat.interlocutorStatus,
      );

      final updatedChats = List<Chat>.from(state.chats);
      updatedChats[chatIndex] = updatedChat;
      state = state.copyWith(chats: updatedChats);
    }
  }

  Future<void> loadChats({String? query}) async {
    state = state.copyWith(isLoading: true, hasMoreChats: true);
    final result = await _repo.getChats(query: query, offset: 0, limit: 20);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (chats) {
        final newStatuses = Map<String, UserStatus>.from(state.userStatuses);
        for (final chat in chats) {
          if (chat.interlocutorStatus != null) {
            newStatuses[chat.interlocutorStatus!.userId] =
                chat.interlocutorStatus!;
          }
        }
        state = state.copyWith(
          isLoading: false,
          chats: chats,
          userStatuses: newStatuses,
          hasMoreChats: chats.length >= 20,
        );
      },
    );
  }

  Future<void> loadMoreChats({String? query}) async {
    if (state.isLoadingMoreChats || !state.hasMoreChats) return;

    state = state.copyWith(isLoadingMoreChats: true);
    final result = await _repo.getChats(
      query: query,
      offset: state.chats.length,
      limit: 20,
    );
    result.fold(
      (failure) => state = state.copyWith(
        isLoadingMoreChats: false,
        error: failure.message,
      ),
      (newChats) {
        final newStatuses = Map<String, UserStatus>.from(state.userStatuses);
        for (final chat in newChats) {
          if (chat.interlocutorStatus != null) {
            newStatuses[chat.interlocutorStatus!.userId] =
                chat.interlocutorStatus!;
          }
        }
        final updatedChats = List<Chat>.from(state.chats)..addAll(newChats);
        state = state.copyWith(
          isLoadingMoreChats: false,
          chats: updatedChats,
          userStatuses: newStatuses,
          hasMoreChats: newChats.length >= 20,
        );
      },
    );
  }

  Future<void> selectChat(String? chatId) async {
    // Notify Service Worker about active chat change
    _pushNotificationService.setActiveChat(chatId);

    if (chatId == null) {
      state = state.copyWith(clearActiveChat: true);
      return;
    }
    state = state.copyWith(activeChatId: chatId);

    // Reset unread count for this chat
    _resetUnreadCount(chatId);

    if (!state.messages.containsKey(chatId)) {
      await loadMessages(chatId);
    }

    // Mark latest messages as read
    final unreadMessages = state.messages[chatId]?.where((m) {
          return m.status != 'read' &&
              _currentUserId != null &&
              m.senderId != _currentUserId;
        }) ??
        [];
    for (var m in unreadMessages) {
      markAsRead(m.id);
    }
  }

  void _resetUnreadCount(String chatId) {
    final chatIndex = state.chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;

    final chat = state.chats[chatIndex];
    if (chat.unreadCount == 0 && chat.unseenReactionsCount == 0) {
      return; // Already cleared
    }

    final updatedChat = Chat(
      id: chat.id,
      name: chat.name,
      isGroup: chat.isGroup,
      createdAt: chat.createdAt,
      lastMessageText: chat.lastMessageText,
      lastMessageCreatedAt: chat.lastMessageCreatedAt,
      lastMessageSenderId: chat.lastMessageSenderId,
      lastMessageStatus: chat.lastMessageStatus,
      unreadCount: 0,
      unseenReactionsCount: 0,
      participants: chat.participants,
    );

    final updatedChats = List<Chat>.from(state.chats);
    updatedChats[chatIndex] = updatedChat;

    state = state.copyWith(chats: updatedChats);
  }

  Future<void> loadMessages(String chatId) async {
    final result = await _repo.getChatMessages(chatId, offset: 0, limit: 50);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (messages) {
        // Filter out deleted messages from API result
        final visibleApiMessages = messages.where((m) => !m.isDeleted).toList();

        final currentLocalMessages = state.messages[chatId] ?? [];

        // Merge logic:
        // 1. Create a map of API messages by ID for fast lookup
        final apiMessageIds = visibleApiMessages.map((m) => m.id).toSet();

        // 2. Find messages that are in Local but NOT in API result
        // These might be new messages received via WS while loading
        final localOnlyMessages = currentLocalMessages
            .where((m) => !apiMessageIds.contains(m.id))
            .toList();

        // 3. Combine: LocalOnly + ApiMessages
        // We prioritize API for common IDs (source of truth), but keep unique Local ones
        final combinedMessages = [...localOnlyMessages, ...visibleApiMessages];

        // 4. Sort by createdAt ASC (oldest first) to match ChatViewWidget expectation
        // ChatViewWidget expects messages.last to be the Newest.
        combinedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        final updatedMessages = Map<String, List<Message>>.from(state.messages);
        updatedMessages[chatId] = combinedMessages;

        final updatedHasMore = Map<String, bool>.from(state.hasMoreMessages);
        updatedHasMore[chatId] = messages.length >= 50;

        state = state.copyWith(
          messages: updatedMessages,
          hasMoreMessages: updatedHasMore,
        );
      },
    );
  }

  Future<void> loadMoreMessages(String chatId) async {
    if (state.isLoadingMoreMessages[chatId] == true ||
        state.hasMoreMessages[chatId] == false) {
      return;
    }

    final updatedIsLoading =
        Map<String, bool>.from(state.isLoadingMoreMessages);
    updatedIsLoading[chatId] = true;
    state = state.copyWith(isLoadingMoreMessages: updatedIsLoading);

    final currentMessages = state.messages[chatId] ?? [];
    final result = await _repo.getChatMessages(
      chatId,
      offset: currentMessages.length,
      limit: 50,
    );

    result.fold(
      (failure) {
        final updatedIsLoading =
            Map<String, bool>.from(state.isLoadingMoreMessages);
        updatedIsLoading[chatId] = false;
        state = state.copyWith(
          isLoadingMoreMessages: updatedIsLoading,
          error: failure.message,
        );
      },
      (newMessages) {
        // Filter out deleted messages from new batch
        final visibleNewMessages =
            newMessages.where((m) => !m.isDeleted).toList();

        final updatedMessages = Map<String, List<Message>>.from(state.messages);
        final allMessages = List<Message>.from(currentMessages)
          ..addAll(visibleNewMessages);

        // Sort by createdAt ASC (oldest first) to ensure consistent order
        allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        updatedMessages[chatId] = allMessages;

        final updatedHasMore = Map<String, bool>.from(state.hasMoreMessages);
        updatedHasMore[chatId] = newMessages.length >= 50;

        final updatedIsLoading =
            Map<String, bool>.from(state.isLoadingMoreMessages);
        updatedIsLoading[chatId] = false;

        state = state.copyWith(
          messages: updatedMessages,
          hasMoreMessages: updatedHasMore,
          isLoadingMoreMessages: updatedIsLoading,
        );
      },
    );
  }

  Future<String?> uploadFile(PlatformFile file) async {
    if (state.activeChatId == null) return null;
    try {
      final result = await _repo.uploadFile(file, state.activeChatId!);
      return result.fold(
        (failure) {
          state = state.copyWith(error: failure.message);
          return null;
        },
        (fileId) => fileId,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  void sendMessage(String text, {List<String>? attachmentIds}) {
    if (state.activeChatId == null ||
        (text.trim().isEmpty &&
            (attachmentIds == null || attachmentIds.isEmpty))) {
      return;
    }

    final Map<String, dynamic> payload = {
      'chat_id': state.activeChatId,
      'text': text,
    };

    if (attachmentIds != null && attachmentIds.isNotEmpty) {
      payload['attachment_ids'] = attachmentIds;
    }

    if (state.replyingToMessage != null) {
      payload['reply_to_message_id'] = state.replyingToMessage!.id;
    }

    _wsClient.sendMessage('chat:send', payload);

    // Clear replying state after sending
    if (state.replyingToMessage != null) {
      setReplyingToMessage(null);
    }
  }

  void markAsRead(String messageId) {
    _wsClient.sendMessage('chat:read', {
      'message_id': messageId,
    });
  }

  void markAsDelivered(String messageId) {
    _wsClient.sendMessage('chat:delivered', {
      'message_id': messageId,
    });
  }

  Future<void> startPrivateChat(String userId) async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.getOrCreatePrivateChat(userId);
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (chat) {
        // Update chat list: if exists replace it (to get latest name/status), if not add it.
        final existingIndex = state.chats.indexWhere((c) => c.id == chat.id);
        if (existingIndex != -1) {
          final updatedChats = List<Chat>.from(state.chats);
          updatedChats[existingIndex] = chat;
          state = state.copyWith(chats: updatedChats);
        } else {
          state = state.copyWith(chats: [chat, ...state.chats]);
        }
        state = state.copyWith(isLoading: false);
        selectChat(chat.id);
      },
    );
  }

  String _getPreviewText(Message message) {
    if (message.text.isNotEmpty) {
      return message.text;
    }
    if (message.attachments.isNotEmpty) {
      final file = message.attachments.first;
      if (file.mimeType.startsWith('image/')) {
        return 'photo';
      } else if (file.mimeType.startsWith('video/')) {
        return 'video';
      } else {
        return file.originalName.isNotEmpty ? file.originalName : file.fileName;
      }
    }
    return '';
  }

  Future<void> toggleReaction(String messageId, String reaction) async {
    final result = await _repo.toggleMessageReaction(messageId, reaction);
    result.fold(
      (failure) => state = state.copyWith(error: failure.message),
      (_) {
        // Success. Wait for WS update or do optimistic update here.
        // For now relying on WS.
      },
    );
  }

  Future<void> createGroupWithAvatar(
      String name, List<String> participants, PlatformFile? avatarFile) async {
    state = state.copyWith(isLoading: true);

    final result =
        await _repo.createGroupChat(name, participants: participants);

    await result.fold(
      (failure) async {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (chat) async {
        Chat finalChat = chat;

        if (avatarFile != null) {
          final uploadResult = await _repo.uploadFile(avatarFile, chat.id);
          await uploadResult.fold(
            (failure) {
              state = state.copyWith(
                  error:
                      "Group created, avatar upload failed: ${failure.message}");
            },
            (fileId) async {
              final updateResult = await _repo.updateGroupChat(chat.id, name,
                  avatarFileId: fileId);
              updateResult.fold((f) => null, (updated) {
                finalChat = updated;
              });
            },
          );
        }

        final updatedChats = [finalChat, ...state.chats];
        state = state.copyWith(
          isLoading: false,
          chats: updatedChats,
          activeChatId: finalChat.id,
        );
        _pushNotificationService.setActiveChat(finalChat.id);
        loadMessages(finalChat.id);
      },
    );
  }

  Future<bool> createGroupChat(String name,
      {String? description,
      String? avatarFileId,
      List<String>? participants}) async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.createGroupChat(name,
        description: description,
        avatarFileId: avatarFileId,
        participants: participants);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (chat) {
        final updatedChats = [chat, ...state.chats];
        state = state.copyWith(
          isLoading: false,
          chats: updatedChats,
          activeChatId: chat.id,
        );
        _pushNotificationService.setActiveChat(chat.id);
        loadMessages(chat.id);
        return true;
      },
    );
  }

  Future<bool> updateGroupChat(String chatId, String name,
      {String? description, String? avatarFileId}) async {
    final result = await _repo.updateGroupChat(chatId, name,
        description: description, avatarFileId: avatarFileId);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (chat) {
        final index = state.chats.indexWhere((c) => c.id == chat.id);
        if (index != -1) {
          final updatedChats = List<Chat>.from(state.chats);
          updatedChats[index] = chat;
          state = state.copyWith(chats: updatedChats);
        }
        return true;
      },
    );
  }

  Future<void> updateGroupWithAvatar(
      String chatId, String name, PlatformFile? avatarFile,
      {String? currentAvatarFileId}) async {
    state = state.copyWith(isLoading: true);

    String? newAvatarFileId;

    if (avatarFile != null) {
      final uploadResult = await _repo.uploadFile(avatarFile, chatId);
      await uploadResult.fold(
        (failure) async {
          state =
              state.copyWith(error: "Avatar upload failed: ${failure.message}");
        },
        (fileId) async {
          newAvatarFileId = fileId;
        },
      );
    } else {
      newAvatarFileId = currentAvatarFileId;
    }

    if (state.error != null && avatarFile != null && newAvatarFileId == null) {
      // Upload failed, stop.
      state = state.copyWith(isLoading: false);
      return;
    }

    // Update the group (name and/or avatar)
    await updateGroupChat(chatId, name, avatarFileId: newAvatarFileId);
    state = state.copyWith(isLoading: false);
  }

  Future<bool> deleteChat(String chatId) async {
    final result = await _repo.deleteChat(chatId);
    return result.fold((failure) {
      state = state.copyWith(error: failure.message);
      return false;
    }, (_) {
      final updatedChats = state.chats.where((c) => c.id != chatId).toList();
      state = state.copyWith(chats: updatedChats);
      if (state.activeChatId == chatId) {
        state = state.copyWith(clearActiveChat: true);
        _pushNotificationService.setActiveChat(null);
      }
      return true;
    });
  }

  Future<bool> addParticipant(String chatId, String userId) async {
    final result = await _repo.addParticipant(chatId, userId);
    return result.fold((failure) {
      state = state.copyWith(error: failure.message);
      return false;
    }, (_) {
      // Update local state
      final index = state.chats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        final chat = state.chats[index];
        final updatedParticipants = List<String>.from(chat.participants);
        if (!updatedParticipants.contains(userId)) {
          updatedParticipants.add(userId);
          final updatedChat = Chat(
            id: chat.id,
            name: chat.name,
            isGroup: chat.isGroup,
            createdAt: chat.createdAt,
            lastMessageText: chat.lastMessageText,
            lastMessageCreatedAt: chat.lastMessageCreatedAt,
            lastMessageSenderId: chat.lastMessageSenderId,
            lastMessageStatus: chat.lastMessageStatus,
            unreadCount: chat.unreadCount,
            unseenReactionsCount: chat.unseenReactionsCount,
            participants: updatedParticipants,
            interlocutorStatus: chat.interlocutorStatus,
            ownerId: chat.ownerId,
            description: chat.description,
            avatarFileId: chat.avatarFileId,
          );
          final updatedChats = List<Chat>.from(state.chats);
          updatedChats[index] = updatedChat;
          state = state.copyWith(chats: updatedChats);
        }
      }
      return true;
    });
  }

  Future<bool> removeParticipant(String chatId, String userId) async {
    final result = await _repo.removeParticipant(chatId, userId);
    return result.fold((failure) {
      state = state.copyWith(error: failure.message);
      return false;
    }, (_) {
      if (userId == _currentUserId) {
        // Left group logic
        final updatedChats = state.chats.where((c) => c.id != chatId).toList();
        state = state.copyWith(chats: updatedChats);
        if (state.activeChatId == chatId) {
          state = state.copyWith(clearActiveChat: true);
          _pushNotificationService.setActiveChat(null);
        }
      } else {
        // Someone else removed logic
        final index = state.chats.indexWhere((c) => c.id == chatId);
        if (index != -1) {
          final chat = state.chats[index];
          final updatedParticipants = List<String>.from(chat.participants);
          updatedParticipants.remove(userId);

          final updatedChat = Chat(
            id: chat.id,
            name: chat.name,
            isGroup: chat.isGroup,
            createdAt: chat.createdAt,
            lastMessageText: chat.lastMessageText,
            lastMessageCreatedAt: chat.lastMessageCreatedAt,
            lastMessageSenderId: chat.lastMessageSenderId,
            lastMessageStatus: chat.lastMessageStatus,
            unreadCount: chat.unreadCount,
            unseenReactionsCount: chat.unseenReactionsCount,
            participants: updatedParticipants,
            interlocutorStatus: chat.interlocutorStatus,
            ownerId: chat.ownerId,
            description: chat.description,
            avatarFileId: chat.avatarFileId,
          );
          final updatedChats = List<Chat>.from(state.chats);
          updatedChats[index] = updatedChat;
          state = state.copyWith(chats: updatedChats);
        }
      }
      return true;
    });
  }
}
