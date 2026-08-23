import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inline page header showing: [title]  [optional badge]
///
/// The leading "← Back" link previously shown here is gone - back
/// navigation for these pages will get its own logic later, and until
/// then this is just a title row.
class InlineBackHeader extends StatelessWidget {
  const InlineBackHeader({
    super.key,
    required this.title,
    this.onBack,
    this.badge,
  });

  final String title;

  /// No longer used now that the back link is gone - kept so call sites
  /// don't need updating when back navigation is redesigned.
  final VoidCallback? onBack;

  /// Optional pill widget shown after the title (e.g. "16 courses").
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
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
