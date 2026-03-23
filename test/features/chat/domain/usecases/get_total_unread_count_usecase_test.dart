import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dems_frontend/core/error/failures.dart';
import 'package:dems_frontend/core/usecases/usecase.dart';
import 'package:dems_frontend/features/chat/domain/repositories/chat_repository.dart';
import 'package:dems_frontend/features/chat/domain/usecases/get_total_unread_count_usecase.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late GetTotalUnreadCountUseCase useCase;
  late MockChatRepository mockRepository;

  setUp(() {
    mockRepository = MockChatRepository();
    useCase = GetTotalUnreadCountUseCase(mockRepository);
  });

  group('GetTotalUnreadCountUseCase', () {
    test('должен вернуть общее количество непрочитанных сообщений', () async {
      // Arrange
      const expectedCount = 5;
      when(() => mockRepository.getTotalUnreadCount())
          .thenAnswer((_) async => const Right(expectedCount));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, const Right(expectedCount));
      verify(() => mockRepository.getTotalUnreadCount()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('должен вернуть ServerFailure при ошибке сервера', () async {
      // Arrange
      final failure = ServerFailure('Ошибка сервера');
      when(() => mockRepository.getTotalUnreadCount())
          .thenAnswer((_) async => Left(failure));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, Left(failure));
      verify(() => mockRepository.getTotalUnreadCount()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('должен вернуть CacheFailure при ошибке кэша', () async {
      // Arrange
      final failure = CacheFailure('Ошибка кэша');
      when(() => mockRepository.getTotalUnreadCount())
          .thenAnswer((_) async => Left(failure));

      // Act
      final result = await useCase(NoParams());

      // Assert
      expect(result, Left(failure));
      verify(() => mockRepository.getTotalUnreadCount()).called(1);
      verifyNoMoreInteractions(mockRepository);
    });
  });
}
