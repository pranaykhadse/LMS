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
    this.progress,
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

  /// Course completion percentage (0-100). When set and > 0, a small
  /// circular progress ring is overlaid on the bottom-right of the image.
  final int? progress;

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
        mainAxisSize: MainAxisSize.max,
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
                // Progress ring — bottom-right
                if (progress != null && progress! > 0)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: _ProgressRing(progress: progress!),
                  ),
              ],
            ),
          ),

          // ── White content area — title + button pinned to bottom ────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info section (next session date, rating, etc.)
                  if (infoSection != null) ...[
                    infoSection!,
                    const SizedBox(height: 6),
                  ],
                  // Course title — pushed down a bit
                  const SizedBox(height: 8),
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
                  // Spacer pushes button to 15px from bottom
                  const Spacer(),
                  // Full-width filled button
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress / 100,
            strokeWidth: 2.5,
            backgroundColor: const Color(0xFFE8E7F8),
            valueColor: const AlwaysStoppedAnimation<Color>(FigmaTokens.primaryPurple),
          ),
          Text(
            '$progress',
            style: const TextStyle(
              color: FigmaTokens.primaryPurple,
              fontSize: 7,
              fontWeight: FontWeight.w700,
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
