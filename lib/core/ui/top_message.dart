import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _currentEntry;
Timer? _currentTimer;

void _dismissCurrent() {
  _currentTimer?.cancel();
  _currentTimer = null;
  _currentEntry?.remove();
  _currentEntry = null;
}

/// Shows a message banner at the top of the screen.
///
/// Unlike a SnackBar, it is inserted into the root overlay, so it is always
/// drawn above dialogs, bottom sheets and navigation bars.
void showTopMessage(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) return;

  _dismissCurrent();

  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _TopMessage(
      message: message,
      isError: isError,
      actionLabel: actionLabel,
      onAction: onAction,
      onClose: () {
        if (_currentEntry == entry) _dismissCurrent();
      },
    ),
  );

  _currentEntry = entry;
  overlay.insert(entry);

  _currentTimer = Timer(
    duration ??
        (actionLabel != null
            ? const Duration(seconds: 6)
            : const Duration(seconds: 4)),
    () {
      if (_currentEntry == entry) _dismissCurrent();
    },
  );
}

class _TopMessage extends StatefulWidget {
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _TopMessage({
    required this.message,
    required this.isError,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_TopMessage> createState() => _TopMessageState();
}

class _TopMessageState extends State<_TopMessage>
    with SingleTickerProviderStateMixin {
  final _dismissKey = UniqueKey();
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final background = widget.isError
        ? scheme.errorContainer
        : scheme.inverseSurface;
    final foreground = widget.isError
        ? scheme.onErrorContainer
        : scheme.onInverseSurface;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _controller,
                  child: Dismissible(
                    key: _dismissKey,
                    direction: DismissDirection.up,
                    onDismissed: (_) => widget.onClose(),
                    child: Material(
                      color: background,
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.onClose,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.isError
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: foreground,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  style: TextStyle(color: foreground),
                                ),
                              ),
                              if (widget.actionLabel != null) ...[
                                const SizedBox(width: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: widget.isError
                                        ? scheme.error
                                        : scheme.inversePrimary,
                                  ),
                                  onPressed: () {
                                    widget.onClose();
                                    widget.onAction?.call();
                                  },
                                  child: Text(widget.actionLabel!),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
