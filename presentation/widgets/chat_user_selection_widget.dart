import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dems_frontend/config/app_config.dart';
import 'package:dems_frontend/core/constants/api_constants.dart';
import 'package:dems_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:dems_frontend/features/users/presentation/providers/users_provider.dart';
import '../providers/chat_provider.dart';

class ChatUserSelectionWidget extends ConsumerWidget {
  final VoidCallback onBack;

  const ChatUserSelectionWidget({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: onBack,
              ),
              const Text(
                'Начать новый чат',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (usersState.isLoading && usersState.users.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (usersState.errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      usersState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (usersState.users.isEmpty) {
                return const Center(
                    child: Text('Нет пользователей для общения'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: usersState.users.length,
                itemBuilder: (context, index) {
                  final user = usersState.users[index];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: user.avatarId != null
                          ? NetworkImage(
                              '${AppConfig.apiBaseUrl}${ApiConstants.fileContent(user.avatarId!)}',
                              headers: {
                                'Authorization':
                                    'Bearer ${ref.read(authLocalDataSourceProvider).getTokenSync()}',
                              },
                            )
                          : null,
                      child: user.avatarId != null
                          ? null
                          : Text(user.login.isNotEmpty
                              ? user.login[0].toUpperCase()
                              : '?'),
                    ),
                    title: Text(
                      user.login,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1E293B)),
                    ),
                    subtitle: Text(
                      user.isSuperuser ? 'Администратор' : 'Сотрудник',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    onTap: () {
                      ref.read(chatProvider.notifier).startPrivateChat(user.id);
                      onBack();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
