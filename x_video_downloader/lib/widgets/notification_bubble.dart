import 'dart:async';
import 'package:flutter/material.dart';
import 'package:x_video_downloader/theme.dart';

/// A floating notification bubble that appears at the top of the screen
/// and auto-dismisses after a duration.
class NotificationBubble {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// Shows a floating bubble notification.
  static void show(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    // Remove any existing bubble
    dismiss();

    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationBubbleWidget(
        message: message,
        duration: duration,
        onDismiss: dismiss,
      ),
    );

    Overlay.of(context).insert(_currentEntry!);

    _dismissTimer = Timer(duration, dismiss);
  }

  /// Dismisses the current notification bubble.
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _NotificationBubbleWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationBubbleWidget({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_NotificationBubbleWidget> createState() => _NotificationBubbleWidgetState();
}

class _NotificationBubbleWidgetState extends State<_NotificationBubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Start dismiss animation before the timer ends
    Future.delayed(widget.duration - const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surfaceContainerHigh,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _controller.reverse().then((_) {
                          widget.onDismiss();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
