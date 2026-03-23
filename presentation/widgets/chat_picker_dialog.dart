import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../../../../config/app_config.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class ChatPickerDialog extends ConsumerStatefulWidget {
  const ChatPickerDialog({super.key});

  @override
  ConsumerState<ChatPickerDialog> createState() => _ChatPickerDialogState();
}

class _ChatPickerDialogState extends ConsumerState<ChatPickerDialog> {
  final Set<String> _selectedChatIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(chatProvider).chats.isEmpty) {
        ref.read(chatProvider.notifier).loadChats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final chats = chatState.chats;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Переслать сообщение',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: chatState.isLoading && chats.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final isSelected = _selectedChatIds.contains(chat.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFE2E8F0),
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
                                    : Icon(
                                        chat.isGroup
                                            ? Icons.groups
                                            : Icons.person,
                                        size: 24,
                                        color: const Color(0xFF64748B),
                                      ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF415BE7),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            chat.name.isEmpty ? 'Без названия' : chat.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Color(0xFF415BE7))
                              : const Icon(Icons.circle_outlined,
                                  color: Color(0xFFCBD5E1)),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedChatIds.remove(chat.id);
                              } else {
                                _selectedChatIds.add(chat.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            if (_selectedChatIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _selectedChatIds.toList());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF415BE7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Переслать (${_selectedChatIds.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
