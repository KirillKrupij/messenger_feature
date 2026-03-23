import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:dems_frontend/config/app_config.dart';
import 'package:dems_frontend/core/constants/api_constants.dart';
import 'package:dems_frontend/core/notifications/index.dart';
import 'package:dems_frontend/features/chat/domain/entities/chat.dart';
import 'package:dems_frontend/features/chat/presentation/providers/chat_provider.dart';
import 'package:dems_frontend/features/users/domain/entities/user_entity.dart';
import 'package:dems_frontend/features/users/presentation/providers/users_provider.dart';
import 'package:dems_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'user_picker_dialog.dart';

class ChatInfoDialog extends ConsumerStatefulWidget {
  final Chat chat;

  const ChatInfoDialog({super.key, required this.chat});

  @override
  ConsumerState<ChatInfoDialog> createState() => _ChatInfoDialogState();
}

class _ChatInfoDialogState extends ConsumerState<ChatInfoDialog> {
  late TextEditingController _nameController;
  List<UserEntity>? _participants;
  PlatformFile? _avatarFile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chat.name);
    _loadParticipants();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants([Chat? chat]) async {
    final targetChat = chat ?? widget.chat;
    try {
      if (targetChat.participants.isEmpty) {
        setState(() {
          _participants = [];
          _isLoading = false;
        });
        return;
      }

      final repo = ref.read(usersRepositoryProvider);
      final futures = targetChat.participants.map((id) => repo.getUser(id));
      final results = await Future.wait(futures);

      final loadedUsers = <UserEntity>[];
      for (final result in results) {
        result.fold(
          (l) => print('Failed to load user: ${l.message}'),
          (user) => loadedUsers.add(user),
        );
      }

      if (mounted) {
        setState(() {
          _participants = loadedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _avatarFile = result.files.first;
      });
    }
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final notifier = ref.read(chatProvider.notifier);

      if (newName != widget.chat.name || _avatarFile != null) {
        await notifier.updateGroupWithAvatar(
            widget.chat.id, newName, _avatarFile,
            currentAvatarFileId: widget.chat.avatarFileId);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ref.read(notificationServiceProvider.notifier).error(
              'Ошибка при сохранении',
              '$e',
            );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    // Use cast<Chat>() to handle covariance if list is actually List<ChatModel>
    final chat = chatState.chats.cast<Chat>().firstWhere(
          (c) => c.id == widget.chat.id,
          orElse: () => widget.chat,
        );

    // Check if we need to reload participants (e.g. count changed)
    // Ideally we diff the lists, but length check + deep check is safer.
    // To avoid build-cycle, we should use a listener or check in a way that doesn't trigger setstate loops.
    // Simpler: Just rely on _loadParticipants being called when we detect change?
    // Use ref.listen is better.

    ref.listen(chatProvider, (previous, next) {
      final prevChat = previous?.chats
          .cast<Chat>()
          .firstWhere((c) => c.id == widget.chat.id, orElse: () => widget.chat);
      final nextChat = next.chats
          .cast<Chat>()
          .firstWhere((c) => c.id == widget.chat.id, orElse: () => widget.chat);

      if (prevChat != null &&
          !listEquals(prevChat.participants, nextChat.participants)) {
        _loadParticipants(nextChat);
      }
    });

    final currentUserId = ref.read(authProvider).user?.id;
    final isOwner = chat.ownerId == currentUserId;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Редактирование группы',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: isOwner ? _pickAvatar : null,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFE2E8F0), width: 2),
                          image: _avatarFile != null
                              ? DecorationImage(
                                  image: kIsWeb
                                      ? MemoryImage(_avatarFile!.bytes!)
                                      : FileImage(File(_avatarFile!.path!))
                                          as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : (chat.avatarFileId != null)
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        '${AppConfig.apiBaseUrl}${ApiConstants.fileContent(chat.avatarFileId!)}',
                                        headers: {
                                          'Authorization':
                                              'Bearer ${ref.read(authLocalDataSourceProvider).getTokenSync()}',
                                        },
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child:
                            (_avatarFile == null && chat.avatarFileId == null)
                                ? Center(
                                    child: Text(
                                    chat.name.isNotEmpty
                                        ? chat.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8)),
                                  ))
                                : null,
                      ),
                      if (isOwner)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF415BE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              if (isOwner)
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Название группы',
                    hintText: 'Введите название',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF415BE7)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                )
              else
                Center(
                  child: Text(
                    chat.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Participants Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Участники (${_participants?.length ?? 0})',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (true) // All users can add? Or only owner? Usually all in casual chats, but let's stick to previous logic. Previous logic allowed all.
                    TextButton.icon(
                      onPressed: () => _addParticipant(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF415BE7),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Participants List
              SizedBox(
                height: 200, // Fixed height for list
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Ошибка: $_error'))
                        : _participants == null || _participants!.isEmpty
                            ? const Center(child: Text("Нет участников"))
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _participants!.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final user = _participants![index];
                                  final isMe = user.id == currentUserId;
                                  final isUserOwner = user.id == chat.ownerId;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFF1F5F9),
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
                                    title: Row(
                                      children: [
                                        Text(
                                          user.login,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        if (isUserOwner)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: const Text('Владелец',
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Color(0xFFD97706))),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: (isOwner && !isMe)
                                        ? IconButton(
                                            icon: const Icon(Icons.close,
                                                size: 18),
                                            color: const Color(0xFF94A3B8),
                                            onPressed: () =>
                                                _removeConfirm(context, user),
                                          )
                                        : null,
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isOwner) ...[
          TextButton(
            onPressed: _isSaving ? null : () => _deleteGroup(context),
            child: const Text('Удалить группу',
                style: TextStyle(color: Colors.red)),
          ),
        ] else ...[
          TextButton(
            onPressed:
                _isSaving ? null : () => _leaveGroup(context, currentUserId!),
            child: const Text('Покинуть группу',
                style: TextStyle(color: Colors.red)),
          ),
        ],
        const Spacer(), // Push buttons to sides or just space them? Default actions align end.
        // Let's keep Save/Cancel for edits.

        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child:
              const Text('Закрыть', style: TextStyle(color: Color(0xFF64748B))),
        ),
        if (isOwner)
          ElevatedButton(
            onPressed: _isSaving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF415BE7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Сохранить'),
          ),
      ],
      actionsAlignment: MainAxisAlignment.end, // Default
    );
  }

  void _addParticipant(BuildContext context) async {
    final chatState = ref.read(chatProvider);
    final chat = chatState.chats.firstWhere(
      (c) => c.id == widget.chat.id,
      orElse: () => widget.chat,
    );

    final users = await showDialog<List<UserEntity>>(
      context: context,
      builder: (context) =>
          UserPickerDialog(excludedUserIds: chat.participants),
    );

    if (users != null && users.isNotEmpty) {
      for (final user in users) {
        await ref.read(chatProvider.notifier).addParticipant(chat.id, user.id);
      }
      // Listener will trigger reload
    }
  }

  void _removeConfirm(BuildContext context, UserEntity user) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Удалить ${user.login}?',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              content: const Text(
                'Этот пользователь будет удален из группы.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(chatProvider.notifier)
                        .removeParticipant(widget.chat.id, user.id);
                    // Listener will trigger reload
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Удалить'),
                ),
              ],
            ));
  }

  void _deleteGroup(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Удалить группу?',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              content: const Text(
                'Вся переписка будет удалена для всех участников. Это действие нельзя отменить.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final success = await ref
                        .read(chatProvider.notifier)
                        .deleteChat(widget.chat.id);
                    if (success && mounted) {
                      Navigator.pop(context); // Close details
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Удалить'),
                ),
              ],
            ));
  }

  void _leaveGroup(BuildContext context, String userId) async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Покинуть группу?',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              content: const Text(
                'Вы больше не сможете писать сообщения в эту группу, пока вас снова не добавят.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final success = await ref
                        .read(chatProvider.notifier)
                        .removeParticipant(widget.chat.id, userId);
                    if (success && mounted) {
                      Navigator.pop(context); // Close details
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Покинуть'),
                ),
              ],
            ));
  }
}
