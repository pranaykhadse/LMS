import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';

/// Course card matching the reference design:
///  • Full-width image, no padding, rounded top corners only
///  • White content area: "NEXT AVAILABLE" label + date, course title
///  • Full-width primary-color filled "View Course" button (pill shape)
///  • "+" overlay button top-right (dev plan), shown via overlayButtons
class CourseGridCard extends StatelessWidget {
  const CourseGridCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.buttonLabel,
    required this.onPressed,
    this.offlineCourse,
    this.infoSection,
    this.overlayButtons,
  });

  final String? imageUrl;
  final String title;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final Course? offlineCourse;

  /// White info block between image and title
  /// (next-session date, star rating, etc.)
  final Widget? infoSection;

  /// Overlay widget shown top-right of image (e.g. dev plan +/- button).
  final Widget? overlayButtons;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Image — full-width, no side padding ──────────────────────
          SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImgFallback(),
                      )
                    : const _ImgFallback(),
                // Offline save button — top-left
                if (offlineCourse != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: OfflineCourseButton(course: offlineCourse!),
                  ),
                // Dev plan / extra overlay — top-right
                if (overlayButtons != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: overlayButtons!,
                  ),
              ],
            ),
          ),

          // ── White content area ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info section (next session date, rating, etc.)
                if (infoSection != null) ...[
                  infoSection!,
                  const SizedBox(height: 10),
                ],
                // Course title
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: const Color(0xFF1A1A2E),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                // Full-width filled button — pill shape
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FigmaTokens.primaryPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          FigmaTokens.primaryPurple.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
          size: 54, color: FigmaTokens.primaryPurple),
    );
  }
}
