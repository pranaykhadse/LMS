import 'package:flutter/material.dart';

/// Tracks mouse hover via an explicit MouseRegion and rebuilds [builder]
/// with the current hover state. Used to drive brand-color hover swaps
/// (e.g. FigmaTokens.primaryPurple -> purpleHover) on buttons directly,
/// since ElevatedButton/OutlinedButton's own built-in WidgetState.hovered
/// handling didn't reliably repaint when tested on macOS desktop.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.cursor});

  final Widget Function(BuildContext context, bool hovering) builder;

  /// Mouse cursor to show while hovering. Defaults to `null` (system
  /// default arrow) so existing call sites keep their current behavior;
  /// pass `SystemMouseCursors.click` for anything actually tappable.
  final MouseCursor? cursor;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor ?? MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.builder(context, _hovering),
    );
  }
}
