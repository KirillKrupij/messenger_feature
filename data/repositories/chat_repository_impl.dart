import 'package:dartz/dartz.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;

  ChatRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Chat>>> getChats(
      {String? query, int offset = 0, int limit = 20}) async {
    try {
      final result = await remoteDataSource.getChats(
          query: query, offset: offset, limit: limit);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Message>>> getChatMessages(String chatId,
      {int offset = 0, int limit = 50}) async {
    try {
      final result = await remoteDataSource.getChatMessages(chatId,
          offset: offset, limit: limit);
      return Right(result.reversed.toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Chat>> getOrCreatePrivateChat(String userId) async {
    try {
      final result = await remoteDataSource.getOrCreatePrivateChat(userId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> uploadFile(
      PlatformFile file, String chatId) async {
    try {
      final result = await remoteDataSource.uploadFile(file, chatId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> toggleMessageReaction(
      String messageId, String reaction) async {
    try {
      await remoteDataSource.toggleMessageReaction(messageId, reaction);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Chat>> createGroupChat(String name,
      {String? description,
      String? avatarFileId,
      List<String>? participants}) async {
    try {
      final result = await remoteDataSource.createGroupChat(name,
          description: description,
          avatarFileId: avatarFileId,
          participants: participants);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Chat>> updateGroupChat(String chatId, String name,
      {String? description, String? avatarFileId}) async {
    try {
      final result = await remoteDataSource.updateGroupChat(chatId, name,
          description: description, avatarFileId: avatarFileId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteChat(String chatId) async {
    try {
      await remoteDataSource.deleteChat(chatId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> addParticipant(
      String chatId, String userId) async {
    try {
      await remoteDataSource.addParticipant(chatId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removeParticipant(
      String chatId, String userId) async {
    try {
      await remoteDataSource.removeParticipant(chatId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Message>>> searchMessages(
      String chatId, String query,
      {int offset = 0, int limit = 50}) async {
    try {
      final result = await remoteDataSource.searchMessages(chatId, query,
          offset: offset, limit: limit);
      // Don't reverse search results usually, as they are a list of matches, not a timeline.
      // But depending on how we display them.
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getMessageContext(
      String chatId, String messageId) async {
    try {
      final result =
          await remoteDataSource.getMessageContext(chatId, messageId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getTotalUnreadCount() async {
    try {
      final result = await remoteDataSource.getTotalUnreadCount();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
