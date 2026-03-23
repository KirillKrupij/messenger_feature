import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/error/failures.dart';
import '../entities/chat.dart';
import '../entities/message.dart';

/// Абстрактный репозиторий для работы с данными чата.
/// Определяет контракты для получения чатов, сообщений, управления группами,
/// загрузки файлов, реакций, поиска и других операций.
abstract class ChatRepository {
  /// Получить список чатов с поддержкой пагинации и поиска.
  Future<Either<Failure, List<Chat>>> getChats(
      {String? query, int offset = 0, int limit = 20});

  /// Получить сообщения из указанного чата с пагинацией.
  Future<Either<Failure, List<Message>>> getChatMessages(String chatId,
      {int offset = 0, int limit = 50});

  /// Получить или создать приватный чат с указанным пользователем.
  Future<Either<Failure, Chat>> getOrCreatePrivateChat(String userId);

  /// Загрузить файл в указанный чат и получить его ID.
  Future<Either<Failure, String>> uploadFile(PlatformFile file, String chatId);

  /// Добавить или удалить реакцию на сообщение.
  Future<Either<Failure, void>> toggleMessageReaction(
      String messageId, String reaction);

  /// Создать групповой чат.
  Future<Either<Failure, Chat>> createGroupChat(String name,
      {String? description, String? avatarFileId, List<String>? participants});

  /// Обновить информацию группового чата.
  Future<Either<Failure, Chat>> updateGroupChat(String chatId, String name,
      {String? description, String? avatarFileId});

  /// Удалить чат.
  Future<Either<Failure, void>> deleteChat(String chatId);

  /// Добавить участника в групповой чат.
  Future<Either<Failure, void>> addParticipant(String chatId, String userId);

  /// Удалить участника из группового чата.
  Future<Either<Failure, void>> removeParticipant(String chatId, String userId);

  /// Поиск сообщений в чате по тексту.
  Future<Either<Failure, List<Message>>> searchMessages(
      String chatId, String query,
      {int offset = 0, int limit = 50});

  /// Получить контекст сообщения (количество более новых сообщений).
  Future<Either<Failure, int>> getMessageContext(
      String chatId, String messageId);

  /// Получить общее количество непрочитанных сообщений.
  Future<Either<Failure, int>> getTotalUnreadCount();
}
