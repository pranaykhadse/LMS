import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';

/// Inline page header showing:
///   ← Back  |  [title]  [optional badge]
///
/// Matches the "← Back | In-Progress Courses  16 courses" pattern used
/// across sub-pages. The back button calls [onBack] if provided, otherwise
/// pops the navigator.
class InlineBackHeader extends StatelessWidget {
  const InlineBackHeader({
    super.key,
    required this.title,
    this.onBack,
    this.badge,
  });

  final String title;
  final VoidCallback? onBack;

  /// Optional pill widget shown after the title (e.g. "16 courses").
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onBack ?? () => safePop(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: FigmaTokens.primaryPurple),
                  const SizedBox(width: 6),
                  Text(
                    'Back',
                    style: GoogleFonts.inter(
                      color: FigmaTokens.primaryPurple,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
              width: 1, height: 16, color: const Color(0xFFD1D5DB)),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            badge!,
          ],
        ],
      ),
    );
  }
}
