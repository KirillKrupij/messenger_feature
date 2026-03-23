import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dems_frontend/features/users/presentation/providers/users_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:dems_frontend/config/app_config.dart';
import 'package:dems_frontend/core/constants/api_constants.dart';

class UserPickerDialog extends ConsumerStatefulWidget {
  final List<String> excludedUserIds;
  final bool multiSelection;

  const UserPickerDialog({
    super.key,
    this.excludedUserIds = const [],
    this.multiSelection = true,
  });

  @override
  ConsumerState<UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends ConsumerState<UserPickerDialog> {
  final Set<String> _selectedUserIds = {};
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load all users ideally. For now, paginated default.
      ref.read(usersProvider.notifier).loadUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final usersState = ref.watch(usersProvider);
    final currentUserId = authState.user?.id;

    final users = usersState.users
        .where((u) =>
            !widget.excludedUserIds.contains(u.id) && u.id != currentUserId)
        .toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.multiSelection
                      ? 'Выберите участников'
                      : 'Выберите пользователя',
                  style: const TextStyle(
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
            TextField(
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF415BE7)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                _searchQuery = value.isEmpty ? null : value;
                ref
                    .read(usersProvider.notifier)
                    .loadUsers(search: _searchQuery);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: usersState.isLoading && users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : users.isEmpty
                      ? const Center(
                          child: Text(
                            "Пользователи не найдены",
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: users.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final isSelected =
                                _selectedUserIds.contains(user.id);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                                    : Text(
                                        user.login.isNotEmpty
                                            ? user.login[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Color(0xFF1E293B),
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                              title: Text(
                                user.login,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              trailing: widget.multiSelection
                                  ? (isSelected
                                      ? const Icon(Icons.check_circle,
                                          color: Color(0xFF415BE7))
                                      : const Icon(Icons.circle_outlined,
                                          color: Color(0xFFCBD5E1)))
                                  : null,
                              onTap: () {
                                if (widget.multiSelection) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedUserIds.remove(user.id);
                                    } else {
                                      _selectedUserIds.add(user.id);
                                    }
                                  });
                                } else {
                                  Navigator.pop(context, [user]);
                                }
                              },
                            );
                          },
                        ),
            ),
            if (widget.multiSelection && _selectedUserIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final selectedUsers = usersState.users
                        .where((u) => _selectedUserIds.contains(u.id))
                        .toList();
                    Navigator.pop(context, selectedUsers);
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
                    'Добавить (${_selectedUserIds.length})',
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
