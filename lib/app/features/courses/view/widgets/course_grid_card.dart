import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';

/// Unified course card used across Course Catalog and all My Courses screens.
///
/// Layout (top → bottom):
///  1. Image area — the course thumbnail with the title overlaid at the
///     bottom in a semi-transparent purple bar.
///  2. Info section (optional) — white area showing next-session date,
///     status badge, progress, etc.
///  3. Purple footer — title text + full-width "View Course" button.
class CourseGridCard extends StatelessWidget {
  const CourseGridCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
    this.offlineCourse,
    this.infoSection,
  });

  final String? imageUrl;
  final String title;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final Course? offlineCourse;

  /// Optional white middle section (next session, progress, rating, etc.).
  final Widget? infoSection;

  // Purple matching the reference: #5457C1
  static const _cardPurple = Color(0xFF5457C1);

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Image with title overlay ──────────────────────────────
          SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11)),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImgFallback(),
                        )
                      : const _ImgFallback(),
                ),
                // Offline save button
                if (offlineCourse != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: OfflineCourseButton(course: offlineCourse!),
                  ),
                // Title overlay bar at bottom of image
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    decoration: BoxDecoration(
                      color: _cardPurple.withValues(alpha: 0.85),
                    ),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2. Optional info section (next session / progress etc.) ──
          if (infoSection != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: infoSection!,
            ),

          // ── 3. Purple footer ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            color: _cardPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 5),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      textStyle: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1EFFB),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined,
          size: 54, color: Color(0xFF5457C1)),
    );
  }
}
