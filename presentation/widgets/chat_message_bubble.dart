import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/file_item.dart' as entities;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../config/app_config.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/notifications/index.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'full_screen_media_viewer.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'video_attachment_preview.dart';
import 'chat_picker_dialog.dart';

class ChatMessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;
  final bool isHighlighted;
  final bool isGroup;
  final void Function(String)? onReplyTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isHighlighted = false,
    this.isGroup = false,
    this.onReplyTap,
  });

  @override
  ConsumerState<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isSelected = chatState.selectedMessageIds.contains(widget.message.id);
    final isSelectionMode = chatState.isSelectionMode;

    // If deleted, show placeholder text
    final displayText =
        widget.message.isDeleted ? 'Сообщение удалено' : widget.message.text;
    final isDeleted = widget.message.isDeleted;
    final isEdited = widget.message.isEdited && !isDeleted;

    final text = widget.message.text.trim();
    final RegExp emojiRegex = RegExp(
        r'^(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])+$');
    bool isJumbo = false;
    if (!isDeleted &&
        widget.message.replyToMessage == null &&
        emojiRegex.hasMatch(text)) {
      final count = text.characters.length;
      if (count > 0 && count <= 3) {
        isJumbo = true;
      }
    }

    return GestureDetector(
      onTapDown: (details) {
        _tapPosition = details.globalPosition;
      },
      onTap: () {
        if (isSelectionMode) {
          ref.read(chatProvider.notifier).toggleSelection(widget.message.id);
        } else if (!isDeleted) {
          _showContextMenu(context, _tapPosition);
        }
      },
      onDoubleTap: () {
        if (!isDeleted) {
          _handleReply();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        color: (isSelected || widget.isHighlighted)
            ? const Color(0xFFE0E7FF).withOpacity(0.5)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            if (isSelectionMode)
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => ref
                      .read(chatProvider.notifier)
                      .toggleSelection(widget.message.id),
                  activeColor: const Color(0xFF415BE7),
                  shape: const CircleBorder(),
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 2),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: widget.isMe
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!widget.isMe) _buildAvatar(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: (widget.isMe &&
                                    !isDeleted &&
                                    !isSelected &&
                                    !isJumbo)
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF415BE7),
                                      Color(0xFF6C86FF)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: (widget.isMe &&
                                    !isDeleted &&
                                    !isSelected &&
                                    !isJumbo)
                                ? null
                                : (isSelected
                                    ? const Color(0xFFE0E7FF)
                                    : (isJumbo
                                        ? Colors.transparent
                                        : const Color(0xFFF1F5F9))),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                              bottomRight:
                                  Radius.circular(widget.isMe ? 4 : 16),
                            ),
                            boxShadow: isJumbo
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                            border: isSelected
                                ? Border.all(
                                    color: const Color(0xFF415BE7), width: 1.5)
                                : Border.all(
                                    color: Colors.transparent, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isGroup && !widget.isMe && !isDeleted)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    widget.message.senderName ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Color(0xFFE58E00),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (widget.message.forwardedFromUserId != null)
                                Container(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'Переслано от ${widget.message.forwardedFromName ?? 'Unknown'}',
                                    style: TextStyle(
                                      color: (widget.isMe &&
                                              !isDeleted &&
                                              !isSelected)
                                          ? Colors.white.withOpacity(0.9)
                                          : const Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              if (widget.message.replyToMessage != null)
                                GestureDetector(
                                  onTap: () {
                                    if (widget.onReplyTap != null) {
                                      widget.onReplyTap!(
                                          widget.message.replyToMessage!.id);
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (widget.isMe &&
                                              !isDeleted &&
                                              !isSelected)
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(
                                        left: BorderSide(
                                          color: (widget.isMe &&
                                                  !isDeleted &&
                                                  !isSelected)
                                              ? Colors.white.withOpacity(0.5)
                                              : const Color(0xFF10B981),
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.message.replyToMessage!
                                                  .senderName ??
                                              'Ответ',
                                          style: TextStyle(
                                            color: (widget.isMe &&
                                                    !isDeleted &&
                                                    !isSelected)
                                                ? Colors.white.withOpacity(0.9)
                                                : const Color(0xFF10B981),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.message.replyToMessage!.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: (widget.isMe &&
                                                    !isDeleted &&
                                                    !isSelected)
                                                ? Colors.white.withOpacity(0.7)
                                                : const Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (widget.message.attachments.isNotEmpty)
                                _buildAttachments(context),
                              Text(
                                displayText,
                                style: TextStyle(
                                  color: (widget.isMe &&
                                          !isDeleted &&
                                          !isSelected &&
                                          !isJumbo)
                                      ? Colors.white
                                      : (isDeleted
                                          ? Colors.grey
                                          : const Color(0xFF1E293B)),
                                  fontSize: isJumbo
                                      ? (text.characters.length == 1
                                          ? 48
                                          : (text.characters.length == 2
                                              ? 36
                                              : 28))
                                      : 14,
                                  height: isJumbo ? 1.2 : 1.4,
                                  fontStyle: isDeleted
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('HH:mm')
                                        .format(widget.message.createdAt),
                                    style: TextStyle(
                                      color: (widget.isMe &&
                                              !isDeleted &&
                                              !isSelected)
                                          ? Colors.white.withOpacity(0.7)
                                          : const Color(0xFF64748B),
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (isEdited)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Icon(
                                        Icons.edit,
                                        size: 10,
                                        color: (widget.isMe &&
                                                !isDeleted &&
                                                !isSelected)
                                            ? Colors.white.withOpacity(0.7)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  if (widget.isMe && !isDeleted) ...[
                                    const SizedBox(width: 4),
                                    _buildStatusIcon(
                                        widget.isMe && !isSelected),
                                  ],
                                ],
                              ),
                              if (widget.message.reactions.isNotEmpty)
                                _buildReactions(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          globalPosition,
          globalPosition,
        ),
        Offset.zero & overlay.size,
      ),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.4),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['👍', '👎', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _handleReaction(emoji);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 18)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'select',
          child: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 20, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Text(
                'Выбрать',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        if (widget.message.attachments.isNotEmpty) ...[
          if (widget.message.attachments.length > 1) ...[
            const PopupMenuItem<String>(
              value: 'save_all',
              child: Row(
                children: [
                  Icon(Icons.download_for_offline,
                      size: 20, color: Color(0xFF64748B)),
                  SizedBox(width: 12),
                  Text(
                    'Сохранить все', // Save All
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (widget.message.attachments
                .any((f) => f.mimeType.startsWith('image/'))) ...[
              const PopupMenuItem<String>(
                value: 'save_image',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Color(0xFF64748B)),
                    SizedBox(width: 12),
                    Text(
                      'Сохранить в галерею', // Save to gallery
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copy_image',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20, color: Color(0xFF64748B)),
                    SizedBox(width: 12),
                    Text(
                      'Копировать', // Copy
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.message.attachments
                .any((f) => f.mimeType.startsWith('video/'))) ...[
              const PopupMenuItem<String>(
                value: 'save_video',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20, color: Color(0xFF64748B)),
                    SizedBox(width: 12),
                    Text(
                      'Сохранить видео', // Save video
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
        const PopupMenuItem<String>(
          value: 'forward',
          child: Row(
            children: [
              Icon(Icons.forward, size: 20, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Text(
                'Переслать',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(Icons.reply_outlined, size: 20, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Text(
                'Ответить',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        if (widget.isMe)
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 20, color: Color(0xFF64748B)),
                SizedBox(width: 12),
                Text(
                  'Редактировать',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        if (widget.isMe)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Удалить',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'forward') {
        _handleForward();
      } else if (value == 'reply') {
        _handleReply();
      } else if (value == 'edit') {
        _handleEdit();
      } else if (value == 'delete') {
        _confirmDelete(context);
      } else if (value == 'save_all') {
        _handleSaveAll();
      } else if (value == 'save_image') {
        final imageFile = widget.message.attachments
            .firstWhere((f) => f.mimeType.startsWith('image/'));
        _handleSaveAttachment(imageFile, isVideo: false);
      } else if (value == 'save_video') {
        final videoFile = widget.message.attachments
            .firstWhere((f) => f.mimeType.startsWith('video/'));
        _handleSaveAttachment(videoFile, isVideo: true);
      } else if (value == 'copy_image') {
        final imageFile = widget.message.attachments
            .firstWhere((f) => f.mimeType.startsWith('image/'));
        _handleCopyAttachment(imageFile);
      } else if (value == 'select') {
        ref.read(chatProvider.notifier).toggleSelection(widget.message.id);
      }
    });
  }

  Future<void> _handleSaveAttachment(entities.FileItem file,
      {required bool isVideo}) async {
    try {
      final baseUrl =
          kDebugMode ? 'http://localhost:8080/api/v1' : AppConfig.apiBaseUrl;
      final downloadUrl = '$baseUrl${ApiConstants.fileDownload(file.id)}';
      final token = ref.read(authLocalDataSourceProvider).getTokenSync();
      final authenticatedUrl =
          token != null ? '$downloadUrl?token=$token' : downloadUrl;

      if (kIsWeb) {
        final response = await Dio().get<List<int>>(
          authenticatedUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final blob = html.Blob([Uint8List.fromList(response.data!)]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', file.originalName)
          ..click();
        html.Url.revokeObjectUrl(url);
        return;
      }

      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${file.originalName}';

      await Dio().download(authenticatedUrl, savePath);

      if (isVideo) {
        await Gal.putVideo(savePath);
      } else {
        await Gal.putImage(savePath);
      }

      if (mounted) {
        ref.read(notificationServiceProvider.notifier).success(
              isVideo ? 'Видео сохранено' : 'Изображение сохранено',
            );
      }
    } catch (e) {
      debugPrint('Error saving attachment: $e');
      if (mounted) {
        ref.read(notificationServiceProvider.notifier).error(
              'Ошибка при сохранении',
            );
      }
    }
  }

  Future<void> _handleCopyAttachment(entities.FileItem file) async {
    try {
      final baseUrl =
          kDebugMode ? 'http://localhost:8080/api/v1' : AppConfig.apiBaseUrl;
      final downloadUrl = '$baseUrl${ApiConstants.fileDownload(file.id)}';
      final token = ref.read(authLocalDataSourceProvider).getTokenSync();
      final authenticatedUrl =
          token != null ? '$downloadUrl?token=$token' : downloadUrl;

      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        return; // Clipboard not available
      }
      final item = DataWriterItem();

      if (kIsWeb) {
        final response = await Dio().get<List<int>>(
          authenticatedUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        var bytes = Uint8List.fromList(response.data!);

        if (file.mimeType == 'image/jpeg' || file.mimeType == 'image/jpg') {
          // Convert JPEG to PNG for Web Clipboard support
          try {
            final blob = html.Blob([bytes]);
            final url = html.Url.createObjectUrlFromBlob(blob);
            final img = html.ImageElement()..src = url;

            await img.onLoad.first;

            final canvas = html.CanvasElement(
              width: img.naturalWidth,
              height: img.naturalHeight,
            );
            canvas.context2D.drawImage(img, 0, 0);

            final pngBlob = await canvas.toBlob('image/png');
            final reader = html.FileReader();
            reader.readAsArrayBuffer(pngBlob);
            await reader.onLoad.first;

            bytes = (reader.result as Uint8List);
            html.Url.revokeObjectUrl(url); // Cleanup

            // Now it's PNG
            item.add(Formats.png(bytes));
          } catch (e) {
            debugPrint('Error converting JPEG to PNG: $e');
            // Fallback (might fail but worth trying)
            item.add(Formats.jpeg(bytes));
          }
        } else {
          item.add(Formats.png(bytes));
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final savePath = '${tempDir.path}/${file.originalName}';

        await Dio().download(authenticatedUrl, savePath);

        final bytes = File(savePath).readAsBytesSync();

        if (file.mimeType == 'image/jpeg' || file.mimeType == 'image/jpg') {
          item.add(Formats.jpeg(bytes));
        } else {
          item.add(Formats.png(bytes));
        }
      }

      await clipboard.write([item]);

      if (mounted) {
        ref.read(notificationServiceProvider.notifier).success(
              'Скопировано в буфер обмена',
            );
      }
    } catch (e) {
      debugPrint('Error copying attachment: $e');
      if (mounted) {
        ref.read(notificationServiceProvider.notifier).error(
              'Ошибка при копировании',
            );
      }
    }
  }

  Future<void> _handleForward() async {
    final targetChatIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => const ChatPickerDialog(),
    );

    if (targetChatIds != null && targetChatIds.isNotEmpty && mounted) {
      for (final chatId in targetChatIds) {
        await ref
            .read(chatProvider.notifier)
            .forwardMessages([widget.message.id], chatId);
      }

      if (mounted) {
        if (targetChatIds.length == 1) {
          ref.read(chatProvider.notifier).selectChat(targetChatIds.first);
        } else {
          // Go to chat list
          ref.read(chatProvider.notifier).selectChat(null);
        }
      }
    }
  }

  Future<void> _handleSaveAll() async {
    for (final file in widget.message.attachments) {
      final isVideo = file.mimeType.startsWith('video/');
      await _handleSaveAttachment(file, isVideo: isVideo);
      // Small delay on Web to prevent browser blocking multiple downloads
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _handleEdit() {
    ref.read(chatProvider.notifier).setEditingMessage(widget.message);
  }

  void _handleReply() {
    ref.read(chatProvider.notifier).setReplyingToMessage(widget.message);
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Удалить сообщение?',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Это действие нельзя отменить.',
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
            onPressed: () {
              ref.read(chatProvider.notifier).deleteMessage(widget.message.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarId = widget.message.senderAvatarId;
    if (avatarId != null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFFE2E8F0),
        backgroundImage: NetworkImage(
          '${AppConfig.apiBaseUrl}${ApiConstants.fileContent(avatarId)}',
          headers: {
            'Authorization':
                'Bearer ${ref.read(authLocalDataSourceProvider).getTokenSync()}',
          },
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFFE2E8F0),
      child: Text(
        (widget.message.senderName?.isNotEmpty ?? false)
            ? widget.message.senderName![0].toUpperCase()
            : '?',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildAttachments(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.message.attachments.map((file) {
        final isImage = file.mimeType.startsWith('image/');
        final isVideo = file.mimeType.startsWith('video/');
        final baseUrl =
            kDebugMode ? 'http://localhost:8080/api/v1' : AppConfig.apiBaseUrl;

        final contentUrl = '$baseUrl${ApiConstants.fileContent(file.id)}';
        final downloadUrl = '$baseUrl${ApiConstants.fileDownload(file.id)}';

        final token = ref.read(authLocalDataSourceProvider).getTokenSync();
        // Append token for authorized access if available
        final authenticatedContentUrl =
            token != null ? '$contentUrl?token=$token' : contentUrl;

        if (isVideo) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: VideoAttachmentPreview(
              url: authenticatedContentUrl,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => FullScreenMediaViewer(
                      url: authenticatedContentUrl,
                      isVideo: true,
                      fileName: file.originalName,
                    ),
                  ),
                );
              },
            ),
          );
        } else if (isImage) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => FullScreenMediaViewer(
                      url: authenticatedContentUrl,
                      isVideo: false,
                      fileName: file.originalName,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  contentUrl,
                  headers:
                      token != null ? {'Authorization': 'Bearer $token'} : null,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 200,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          );
        } else {
          return InkWell(
            onTap: () async {
              // Append token to query for browser download
              final tokenQuery = token != null ? '?token=$token' : '';
              final fullDownloadUrl = '$downloadUrl$tokenQuery';

              final uri = Uri.parse(fullDownloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                debugPrint('Could not launch $fullDownloadUrl');
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file,
                      size: 24, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.originalName.isNotEmpty
                              ? file.originalName
                              : file.fileName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${(file.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.download_rounded,
                      size: 20, color: Color(0xFF64748B)),
                ],
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildReactions(BuildContext context) {
    // Group reactions by emoji
    final Map<String, int> reactionCounts = {};
    final Map<String, bool> myReactions = {};

    for (var reaction in widget.message.reactions) {
      reactionCounts[reaction.reaction] =
          (reactionCounts[reaction.reaction] ?? 0) + 1;
      if (reaction.userId == ref.read(chatProvider).currentUserId) {
        myReactions[reaction.reaction] = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactionCounts.entries.map((entry) {
          final isMe = myReactions[entry.key] == true;
          return GestureDetector(
            onTap: () => _handleReaction(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFFE0E7FF)
                    : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? const Color(0xFF415BE7) : Colors.transparent,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '${entry.key} ${entry.value}',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF1E293B),
                  fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _handleReaction(String emoji) {
    ref.read(chatProvider.notifier).toggleReaction(widget.message.id, emoji);
  }

  Widget _buildStatusIcon(bool isWhiteColor) {
    IconData icon;
    Color color =
        isWhiteColor ? Colors.white.withOpacity(0.8) : const Color(0xFF64748B);
    switch (widget.message.status) {
      case 'read':
        icon = Icons.done_all;
        color = const Color(0xFF38BDF8); // Sky 400
        break;
      case 'delivered':
        icon = Icons.done_all;
        break;
      default:
        icon = Icons.done;
    }
    return Icon(icon, size: 12, color: color);
  }
}
