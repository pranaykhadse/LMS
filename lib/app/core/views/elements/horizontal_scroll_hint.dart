import 'package:flutter/material.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';

/// Small "swipe to see more" hint shown above a table that scrolls
/// horizontally below a minimum width - phone-only, since tablet+ always
/// has room to show every column without scrolling.
class HorizontalScrollHint extends StatelessWidget {
  const HorizontalScrollHint({super.key});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isTablet(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swipe_rounded, size: 14, color: FigmaTokens.noteBodyText),
          const SizedBox(width: 6),
          Text(
            'Swipe the table sideways to see more',
            style: TextStyle(color: FigmaTokens.noteBodyText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
