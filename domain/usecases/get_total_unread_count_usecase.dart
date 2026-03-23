import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';
import '../../presentation/providers/chat_provider.dart';

class GetTotalUnreadCountUseCase implements UseCase<int, NoParams> {
  final ChatRepository repository;

  GetTotalUnreadCountUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(NoParams params) async {
    return await repository.getTotalUnreadCount();
  }
}

final getTotalUnreadCountUseCaseProvider =
    Provider<GetTotalUnreadCountUseCase>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return GetTotalUnreadCountUseCase(repository);
});
