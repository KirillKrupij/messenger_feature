import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import 'chat_list_widget.dart';
import 'chat_view_widget.dart';
import 'chat_user_selection_widget.dart';

import 'create_group_dialog.dart';

/// Главный виджет мессенджера, который управляет отображением:
/// - Списка чатов
/// - Выбора пользователя для нового чата
/// - Просмотра конкретного чата
/// - Создания группы
class MessengerWidget extends ConsumerStatefulWidget {
  const MessengerWidget({super.key});

  @override
  ConsumerState<MessengerWidget> createState() => _MessengerWidgetState();
}

class _MessengerWidgetState extends ConsumerState<MessengerWidget> {
  bool _isSelectingUser = false;

  void _showCreateGroupDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    if (_isSelectingUser) {
      return ChatUserSelectionWidget(
        onBack: () => setState(() => _isSelectingUser = false),
      );
    }

    if (chatState.activeChatId != null) {
      return ChatViewWidget(chatId: chatState.activeChatId!);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Сообщения',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  )),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF415BE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_comment_rounded,
                          color: Color(0xFF415BE7), size: 20),
                      onPressed: () => setState(() => _isSelectingUser = true),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Написать сообщение',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF415BE7).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.group_add,
                          color: Color(0xFF415BE7), size: 20),
                      onPressed: () => _showCreateGroupDialog(context),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Создать группу',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: Colors.black.withOpacity(0.05), height: 1),
        const Expanded(
          child: ChatListWidget(),
        ),
      ],
    );
  }
}
