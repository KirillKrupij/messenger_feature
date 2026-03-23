import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatModel>> getChats(
      {String? query, int offset = 0, int limit = 20});
  Future<List<MessageModel>> getChatMessages(String chatId,
      {int offset = 0, int limit = 50});
  Future<ChatModel> getOrCreatePrivateChat(String userId);

  Future<String> uploadFile(PlatformFile file, String chatId);
  Future<void> toggleMessageReaction(String messageId, String reaction);

  Future<ChatModel> createGroupChat(String name,
      {String? description, String? avatarFileId, List<String>? participants});

  Future<ChatModel> updateGroupChat(String chatId, String name,
      {String? description, String? avatarFileId});

  Future<void> deleteChat(String chatId);
  Future<void> addParticipant(String chatId, String userId);
  Future<void> removeParticipant(String chatId, String userId);

  Future<List<MessageModel>> searchMessages(String chatId, String query,
      {int offset = 0, int limit = 50});
  Future<int> getMessageContext(String chatId, String messageId);
  Future<int> getTotalUnreadCount();
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio dio;

  ChatRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<ChatModel>> getChats(
      {String? query, int offset = 0, int limit = 20}) async {
    try {
      final queryParams = <String, dynamic>{
        'offset': offset,
        'limit': limit,
      };
      if (query != null) {
        queryParams['q'] = query;
      }

      final response = await dio.get<Map<String, dynamic>>(
        ApiConstants.chats,
        queryParameters: queryParams,
      );
      final dynamic data = response.data?['data'];
      if (data is! List) return [];

      return data.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
        return ChatModel.fromJson(map);
      }).toList();
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to get chats');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<MessageModel>> getChatMessages(String chatId,
      {int offset = 0, int limit = 50}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiConstants.chatMessages(chatId),
        queryParameters: {
          'offset': offset,
          'limit': limit,
        },
      );
      final dynamic data = response.data?['data'];
      if (data is! List) return [];

      return data.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
        return MessageModel.fromJson(map);
      }).toList();
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to get messages');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ChatModel> getOrCreatePrivateChat(String userId) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiConstants.privateChat,
        data: {'user_id': userId},
      );
      final dynamic data = response.data?['data'];
      if (data == null) {
        throw ServerException(message: 'Empty response from server');
      }

      final Map<String, dynamic> map = Map<String, dynamic>.from(data as Map);
      return ChatModel.fromJson(map);
    } on DioException catch (e) {
      throw ServerException(
          message: e.message ?? 'Failed to get/create private chat');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<String> uploadFile(PlatformFile file, String chatId) async {
    try {
      final String fileName = file.name;
      final String? mimeType = lookupMimeType(fileName);

      MultipartFile multipartFile;

      if (file.bytes != null) {
        // Web or when bytes are available
        multipartFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        );
      } else if (file.path != null) {
        // Mobile/Desktop
        multipartFile = await MultipartFile.fromFile(
          file.path!,
          filename: fileName,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        );
      } else {
        throw ServerException(message: 'File content is empty');
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
        'entity_id': chatId,
        'record_id': chatId,
      });

      final response = await dio.post<Map<String, dynamic>>(
        '/files/upload',
        data: formData,
      );

      final dynamic data = response.data;

      if (data is Map<String, dynamic> && data.containsKey('id')) {
        return data['id'] as String;
      } else {
        throw ServerException(message: 'Invalid upload response');
      }
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to upload file');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> toggleMessageReaction(String messageId, String reaction) async {
    try {
      await dio.post<Map<String, dynamic>>(
        ApiConstants.toggleReaction(messageId),
        data: {'reaction': reaction},
      );
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to toggle reaction');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ChatModel> createGroupChat(String name,
      {String? description,
      String? avatarFileId,
      List<String>? participants}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/chats/group',
        data: {
          'name': name,
          'description': description,
          'avatar_file_id': avatarFileId,
          'participants': participants,
        },
      );
      final dynamic data = response.data?['data'];
      if (data == null) {
        throw ServerException(message: 'Empty response from server');
      }
      return ChatModel.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      throw ServerException(
          message: e.message ?? 'Failed to create group chat');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<ChatModel> updateGroupChat(String chatId, String name,
      {String? description, String? avatarFileId}) async {
    try {
      final response = await dio.put<Map<String, dynamic>>(
        '/chats/$chatId',
        data: {
          'name': name,
          'description': description,
          'avatar_file_id': avatarFileId,
        },
      );
      final dynamic data = response.data?['data'];
      if (data == null) {
        throw ServerException(message: 'Empty response from server');
      }
      return ChatModel.fromJson(Map<String, dynamic>.from(data as Map));
    } on DioException catch (e) {
      throw ServerException(
          message: e.message ?? 'Failed to update group chat');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> deleteChat(String chatId) async {
    try {
      await dio.delete<Map<String, dynamic>>('/chats/$chatId');
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to delete chat');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> addParticipant(String chatId, String userId) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '/chats/$chatId/participants',
        data: {'user_id': userId},
      );
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to add participant');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> removeParticipant(String chatId, String userId) async {
    try {
      await dio.delete<Map<String, dynamic>>(
        '/chats/$chatId/participants/$userId',
      );
    } on DioException catch (e) {
      throw ServerException(
          message: e.message ?? 'Failed to remove participant');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<MessageModel>> searchMessages(String chatId, String query,
      {int offset = 0, int limit = 50}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiConstants.chatMessages(chatId),
        queryParameters: {
          'offset': offset,
          'limit': limit,
          'q': query,
        },
      );
      final dynamic data = response.data?['data'];
      if (data is! List) return [];

      return data.map((item) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(item as Map);
        return MessageModel.fromJson(map);
      }).toList();
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to search messages');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<int> getMessageContext(String chatId, String messageId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '${ApiConstants.chatMessages(chatId)}/$messageId/context',
      );
      final dynamic data = response.data?['data'];
      if (data is Map && data.containsKey('offset')) {
        return data['offset'] as int;
      }
      throw ServerException(message: 'Invalid context response');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<int> getTotalUnreadCount() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/chats/unread-count',
      );
      final dynamic data = response.data?['data'];
      if (data is Map && data.containsKey('count')) {
        return data['count'] as int;
      }
      return 0;
    } on DioException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to get unread count');
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
