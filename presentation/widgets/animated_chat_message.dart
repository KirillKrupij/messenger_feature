import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';
import 'chat_message_bubble.dart';

class AnimatedChatMessage extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool isHighlighted;
  final bool isGroup;
  final void Function(String) onReplyTap;
  final VoidCallback? onAnimationComplete;

  const AnimatedChatMessage({
    super.key,
    required this.message,
    required this.isMe,
    required this.isHighlighted,
    this.isGroup = false,
    required this.onReplyTap,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedChatMessage> createState() => _AnimatedChatMessageState();
}

class _AnimatedChatMessageState extends State<AnimatedChatMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    if (!widget.message.isDeleted) {
      _controller.value = 1.0;
    } else {
      _controller.reverse().then((_) {
        widget.onAnimationComplete?.call();
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedChatMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.isDeleted && !oldWidget.message.isDeleted) {
      _controller.reverse().then((_) {
        widget.onAnimationComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: 0.0,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ChatMessageBubble(
          message: widget.message,
          isMe: widget.isMe,
          isHighlighted: widget.isHighlighted,
          isGroup: widget.isGroup,
          onReplyTap: widget.onReplyTap,
        ),
      ),
    );
  }
}
