import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dems_frontend/features/chat/domain/entities/chat.dart';
import 'package:dems_frontend/features/chat/domain/entities/message.dart';
import 'package:dems_frontend/features/chat/domain/repositories/chat_repository.dart';
import 'package:dems_frontend/core/network/websocket_client.dart';
import 'package:dems_frontend/core/services/push_notification_service.dart';
import 'package:dems_frontend/features/chat/presentation/providers/chat_provider.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockWebSocketClient extends Mock implements WebSocketClient {}

class MockPushNotificationService extends Mock
    implements PushNotificationService {}

void main() {
  late ChatNotifier notifier;
  late MockChatRepository mockRepository;
  late MockWebSocketClient mockWebSocketClient;
  late MockPushNotificationService mockPushNotificationService;
  const currentUserId = 'user123';

  setUp(() {
    mockRepository = MockChatRepository();
    mockWebSocketClient = MockWebSocketClient();
    mockPushNotificationService = MockPushNotificationService();
    // Мокаем stream, чтобы избежать ошибки типа Null
    when(() => mockWebSocketClient.stream).thenAnswer((_) => Stream.empty());
    // Мокаем getChats, который вызывается в _init
    when(() => mockRepository.getChats(
          query: any(named: 'query'),
          offset: 0,
          limit: 20,
        )).thenAnswer((_) async => Right([]));
    notifier = ChatNotifier(
      mockRepository,
      mockWebSocketClient,
      currentUserId,
      mockPushNotificationService,
    );
  });

  group('ChatNotifier', () {
    test('начальное состояние должно быть корректным', () {
      expect(notifier.state.chats, isEmpty);
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNull);
      expect(notifier.state.activeChatId, isNull);
      expect(notifier.state.currentUserId, currentUserId);
    });

    test('loadChats должен загружать чаты и обновлять состояние', () async {
      // Arrange
      final chats = [
        Chat(
          id: 'chat1',
          name: 'Chat 1',
          isGroup: false,
          createdAt: DateTime.now(),
          lastMessageText: 'Hello',
          lastMessageCreatedAt: DateTime.now(),
          lastMessageSenderId: 'user1',
          lastMessageStatus: 'read',
          unreadCount: 0,
          unseenReactionsCount: 0,
          participants: ['user1', 'user123'],
        ),
      ];
      when(() => mockRepository.getChats(
          query: any(named: 'query'),
          offset: 0,
          limit: 20)).thenAnswer((_) async => Right(chats));

      // Act
      await notifier.loadChats();

      // Assert
      expect(notifier.state.chats, hasLength(1));
      expect(notifier.state.chats.first.id, 'chat1');
      expect(notifier.state.isLoading, false);
      verify(() => mockRepository.getChats(query: null, offset: 0, limit: 20))
          .called(2);
    });

    test('selectChat должен устанавливать активный чат', () async {
      // Arrange
      const chatId = 'chat123';
      when(() => mockPushNotificationService.setActiveChat(chatId))
          .thenAnswer((_) async {});
      when(() => mockRepository.getChatMessages(chatId, offset: 0, limit: 50))
          .thenAnswer((_) async => Right([]));

      // Act
      await notifier.selectChat(chatId);

      // Assert
      expect(notifier.state.activeChatId, chatId);
      verify(() => mockPushNotificationService.setActiveChat(chatId)).called(1);
      verify(() => mockRepository.getChatMessages(chatId, offset: 0, limit: 50))
          .called(1);
    });

    test('sendMessage должен отправлять сообщение через WebSocket', () {
      // Arrange
      notifier.state = notifier.state.copyWith(activeChatId: 'chat123');
      const text = 'Hello world';
      when(() => mockWebSocketClient.sendMessage('chat:send', any()))
          .thenReturn(null);

      // Act
      notifier.sendMessage(text);

      // Assert
      verify(() => mockWebSocketClient.sendMessage('chat:send', {
            'chat_id': 'chat123',
            'text': text,
          })).called(1);
    });

    test('sendMessage с вложениями должен включать attachment_ids', () {
      // Arrange
      notifier.state = notifier.state.copyWith(activeChatId: 'chat123');
      const text = 'Check this';
      final attachmentIds = ['file1', 'file2'];
      when(() => mockWebSocketClient.sendMessage('chat:send', any()))
          .thenReturn(null);

      // Act
      notifier.sendMessage(text, attachmentIds: attachmentIds);

      // Assert
      verify(() => mockWebSocketClient.sendMessage('chat:send', {
            'chat_id': 'chat123',
            'text': text,
            'attachment_ids': attachmentIds,
          })).called(1);
    });

    test('sendMessage без активного чата не должен отправлять', () {
      // Arrange
      notifier.state = notifier.state.copyWith(activeChatId: null);
      const text = 'Hello';
      when(() => mockWebSocketClient.sendMessage('chat:send', any()))
          .thenReturn(null);

      // Act
      notifier.sendMessage(text);

      // Assert
      verifyNever(() => mockWebSocketClient.sendMessage('chat:send', any()));
    });

    test('toggleSelection должен добавлять/удалять ID сообщения', () {
      // Arrange
      const messageId = 'msg1';
      expect(notifier.state.selectedMessageIds, isEmpty);

      // Act - добавить
      notifier.toggleSelection(messageId);

      // Assert
      expect(notifier.state.selectedMessageIds, contains(messageId));

      // Act - удалить
      notifier.toggleSelection(messageId);

      // Assert
      expect(notifier.state.selectedMessageIds, isEmpty);
    });
  });
}
