import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../domain/entities/message.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ChatInput extends StatefulWidget {
  final void Function(String text, List<PlatformFile> attachments) onSend;
  final void Function(String id, String text)? onEdit;
  final void Function(bool)? onTyping;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onCancelReply;
  final bool isLoading;
  final Message? editingMessage;
  final Message? replyingToMessage;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onEdit,
    this.onTyping,
    this.onCancelEdit,
    this.onCancelReply,
    this.isLoading = false,
    this.editingMessage,
    this.replyingToMessage,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isTextEmpty = true;
  bool _showEmojiPicker = false;
  Timer? _typingTimer;
  final List<PlatformFile> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    if (widget.editingMessage != null) {
      _controller.text = widget.editingMessage!.text;
      _isTextEmpty = false;
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != oldWidget.editingMessage) {
      if (widget.editingMessage != null) {
        _controller.text = widget.editingMessage!.text;
        _focusNode.requestFocus();
      } else {
        _controller.clear();
        _focusNode.unfocus();
      }
    }
  }

  void _handleTextChanged() {
    final isEmpty = _controller.text.trim().isEmpty;
    if (isEmpty != _isTextEmpty) {
      setState(() {
        _isTextEmpty = isEmpty;
      });
    }

    if (!isEmpty && !widget.isLoading && widget.editingMessage == null) {
      widget.onTyping?.call(true);

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        widget.onTyping?.call(false);
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true, // Needed for web
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
        _focusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  void _removeFile(PlatformFile file) {
    setState(() {
      _selectedFiles.remove(file);
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if ((text.isNotEmpty || _selectedFiles.isNotEmpty) && !widget.isLoading) {
      if (widget.editingMessage != null) {
        // Editing messages with attachments not supported yet via this input
        widget.onEdit?.call(widget.editingMessage!.id, text);
      } else {
        widget.onSend(text, List.from(_selectedFiles));
      }
      widget.onTyping?.call(false);
      _typingTimer?.cancel();
      _controller.clear();
      setState(() {
        _showEmojiPicker = false;
        _selectedFiles.clear();
      });
      if (widget.editingMessage == null) {
        _focusNode.requestFocus();
      }
    }
  }

  void _cancelEdit() {
    widget.onCancelEdit?.call();
    _controller.clear();
    _focusNode.unfocus();
  }

  void _cancelReply() {
    widget.onCancelReply?.call();
    _focusNode.requestFocus();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

// ... (existing helper methods)

  Future<void> _handlePaste() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;

    final reader = await clipboard.read();

    // 1. Check for Files
    if (reader.canProvide(Formats.fileUri)) {
      final uri = await reader.readValue(Formats.fileUri);
      if (uri != null && uri.scheme == 'file') {
        try {
          final path = uri.toFilePath();
          final file = XFile(path);
          final bytes = await file.readAsBytes();
          final length = await file.length();

          final platformFile = PlatformFile(
            name: file.name,
            size: length,
            bytes: bytes,
            path: path,
          );

          setState(() {
            _selectedFiles.add(platformFile);
          });

          _focusNode.requestFocus();
          return;
        } catch (e) {
          debugPrint('Error pasting file from URI $uri: $e');
        }
      }
    }

    // 2. Check for Images (Images that are not files, e.g. copied from browser canvas or screenshot)
    if (reader.canProvide(Formats.png) || reader.canProvide(Formats.jpeg)) {
      final format =
          reader.canProvide(Formats.png) ? Formats.png : Formats.jpeg;
      reader.getFile(
        format,
        (file) async {
          final bytes = await file.readAll();
          final ext = format == Formats.png ? 'png' : 'jpg';
          // Generate unique name
          final name =
              'pasted_image_${DateTime.now().millisecondsSinceEpoch}.$ext';

          final platformFile = PlatformFile(
            name: name,
            size: bytes.length,
            bytes: bytes,
            readStream: null,
          );

          setState(() {
            _selectedFiles.add(platformFile);
          });
          _focusNode.requestFocus();
        },
        onError: (err) => debugPrint('Error pasting image: $err'),
      );
      return;
    }

    // 3. Fallback to Text
    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        final selection = _controller.selection;
        if (selection.isValid && selection.start >= 0) {
          final newText = _controller.text
              .replaceRange(selection.start, selection.end, text);
          _controller.value = TextEditingValue(
            text: newText,
            selection:
                TextSelection.collapsed(offset: selection.start + text.length),
          );
        } else {
          // If no selection/cursor, append? Or set text?
          // Usually insert at end if no cursor, but focusNode requestFocus handled
          _controller.text += text;
          _controller.selection =
              TextSelection.collapsed(offset: _controller.text.length);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editingMessage != null;

    return DropTarget(
      onDragDone: (detail) async {
        final List<PlatformFile> droppedFiles = [];
        for (final XFile file in detail.files) {
          final bytes = await file.readAsBytes();
          droppedFiles.add(PlatformFile(
            name: file.name,
            size: await file.length(),
            bytes: bytes,
            readStream: null, // Read stream not needed if we have bytes
          ));
        }

        if (droppedFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(droppedFiles);
          });
          _focusNode.requestFocus();
        }
      },
      onDragEntered: (detail) {
        // Optional: show drag overlay
      },
      onDragExited: (detail) {
        // Optional: hide drag overlay
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.black.withOpacity(0.05)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEditing)
                  // ... (Editing preview logic remains same)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.edit,
                            size: 16, color: Color(0xFF415BE7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Редактирование',
                                style: TextStyle(
                                  color: Color(0xFF415BE7),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.editingMessage!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _cancelEdit,
                          child: Icon(Icons.close,
                              size: 20, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                if (widget.replyingToMessage != null && !isEditing)
                  // ... (Reply preview logic remains same)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.reply,
                            size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.replyingToMessage!.senderName ?? 'Ответ',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                widget.replyingToMessage!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _cancelReply,
                          child: Icon(Icons.close,
                              size: 20, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                if (_selectedFiles.isNotEmpty)
                  Container(
                    height: 60,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedFiles.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        // Use cached_network_image or Image.memory depending on platform?
                        // For file picker, we have bytes (web) or path (native).
                        // Just showing icon and name for now to be safe.
                        return Container(
                          width: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined,
                                  color: Color(0xFF64748B), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      '${(file.size / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _removeFile(file),
                                child: const Icon(Icons.close,
                                    size: 16, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                // Removing IntrinsicHeight and changing alignment to start
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Attachment Button
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 8.0), // Align with text field top
                      child: IconButton(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.attach_file_rounded),
                        color: const Color(0xFF64748B),
                        splashRadius: 20,
                        tooltip: 'Прикрепить файл',
                      ),
                    ),
                    const SizedBox(width: 4),

                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.only(left: 16, right: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CallbackShortcuts(
                                bindings: {
                                  const SingleActivator(
                                      LogicalKeyboardKey.enter,
                                      shift: false): _handleSend,
                                  const SingleActivator(LogicalKeyboardKey.keyV,
                                          control: true):
                                      _handlePaste, // Windows/Linux
                                  const SingleActivator(LogicalKeyboardKey.keyV,
                                      meta: true): _handlePaste, // MacOS
                                },
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  onTap: () {
                                    if (_showEmojiPicker) {
                                      setState(() {
                                        _showEmojiPicker = false;
                                      });
                                    }
                                  },
                                  contextMenuBuilder:
                                      (context, editableTextState) {
                                    final List<ContextMenuButtonItem>
                                        buttonItems = editableTextState
                                            .contextMenuButtonItems;

                                    // Override paste button
                                    final pasteItemIndex =
                                        buttonItems.indexWhere((item) =>
                                            item.type ==
                                            ContextMenuButtonType.paste);

                                    if (pasteItemIndex != -1) {
                                      buttonItems[pasteItemIndex] =
                                          ContextMenuButtonItem(
                                        type: ContextMenuButtonType.paste,
                                        onPressed: () {
                                          _handlePaste();
                                          // Hide menu after paste
                                          editableTextState.hideToolbar();
                                        },
                                      );
                                    }

                                    return AdaptiveTextSelectionToolbar
                                        .buttonItems(
                                      anchors:
                                          editableTextState.contextMenuAnchors,
                                      buttonItems: buttonItems,
                                    );
                                  },
                                  maxLines: 5,
                                  minLines: 1,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF1E293B),
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Сообщение...',
                                    hintStyle: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                            // Emoji Button moved here for top alignment
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4.0), // Adjust alignment
                              child: IconButton(
                                iconSize: 24,
                                onPressed: _toggleEmojiPicker,
                                icon: Icon(
                                  _showEmojiPicker
                                      ? Icons.keyboard
                                      : Icons.emoji_emotions_outlined,
                                  color: _showEmojiPicker
                                      ? const Color(0xFF415BE7)
                                      : const Color(0xFF64748B),
                                ),
                                splashRadius: 14,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                alignment: Alignment.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSendButton(isEditing),
                  ],
                ),
              ],
            ),
          ),
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  // Not using onEmojiSelected to modify controller manually recommended by docs
                },
                textEditingController: _controller,
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 32 *
                        (foundation.defaultTargetPlatform == TargetPlatform.iOS
                            ? 1.30
                            : 1.0),
                    backgroundColor: Colors.white,
                  ),
                  viewOrderConfig: const ViewOrderConfig(
                    top: EmojiPickerItem.categoryBar,
                    middle: EmojiPickerItem.emojiView,
                    bottom: EmojiPickerItem.searchBar,
                  ),
                  skinToneConfig: const SkinToneConfig(
                    indicatorColor: Color(0xFF415BE7),
                    dialogBackgroundColor: Colors.white,
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    tabIndicatorAnimDuration: kTabScrollDuration,
                    initCategory: Category.RECENT,
                    backgroundColor: Colors.white,
                    iconColor: Color(0xFF64748B),
                    iconColorSelected: Color(0xFF415BE7),
                    indicatorColor: Color(0xFF415BE7),
                    dividerColor: Color(0xFFE2E8F0),
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: const SearchViewConfig(
                    backgroundColor: Colors.white,
                    buttonIconColor: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool isEditing) {
    final bool canSend =
        (!_isTextEmpty || _selectedFiles.isNotEmpty) && !widget.isLoading;

    return GestureDetector(
      onTap: canSend ? _handleSend : null,
      child: Container(
        width: 50,
        height: 50, // Fixed height
        decoration: BoxDecoration(
          gradient: !canSend
              ? LinearGradient(colors: [
                  Colors.grey.shade300,
                  Colors.grey.shade400,
                ])
              : const LinearGradient(
                  colors: [Color(0xFF415BE7), Color(0xFF6C86FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  isEditing ? Icons.check_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
        ),
      ),
    );
  }
}
