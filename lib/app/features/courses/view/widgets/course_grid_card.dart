import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/core/utils/dev_image_proxy.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
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
        // Design ref: --card-radius: 16px, --card-shadow: 0 10px 25px rgba(0,0,0,0.05)
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
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
                      devProxiedImageUrl(imageUrl!),
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
                  Positioned(top: 10, right: 10, child: overlayButtons!),
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
                      // Design ref: --card-title: #1E2939
                      color: const Color(0xFF1E2939),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  // Spacer pushes button to 15px from bottom
                  const Spacer(),
                  // Full-width outlined View Course button
                  ViewCourseButton(label: buttonLabel, onPressed: onPressed),
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
      width: 28,
      height: 28,
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
            valueColor: const AlwaysStoppedAnimation<Color>(
              FigmaTokens.primaryPurple,
            ),
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

class _ImgFallback extends ConsumerWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CSS ref, confirmed against `origin/staging`: the real fallback for
    // a course with no logo is a dedicated "no course image" graphic
    // (`/dist/images/course-bg.svg`) served from the backend — not
    // `assets/images/login-bg.png` (a LOGIN page background), which this
    // was using apparently by copy/paste.
    final origin = Uri.parse(ref.watch(ServerProvider.serverUrl)).origin;
    final fallbackUrl = '$origin/backend/web/dist/images/course-bg.svg';
    return Image.network(
      devProxiedImageUrl(fallbackUrl),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF1F5F9)),
    );
  }
}

// ── Shared View Course button ─────────────────────────────────────────────
//
// Figma spec:
//   • Default  — bg #F8FAFC, border 0.65px #693D94 (radius 14px),
//                text Inter 12px SemiBold #693D94, height 40px
//   • Hover    — bg #693D94, text white
//   • Disabled — 50 % opacity of default
//
// Used by CourseGridCard and every other "View Course" surface in the app.
class ViewCourseButton extends StatelessWidget {
  const ViewCourseButton({
    super.key,
    this.label = 'View Course',
    this.onPressed,
    this.width = double.infinity,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Defaults to full-width; pass a fixed value for inline/narrow contexts.
  final double width;

  static const _purple = FigmaTokens.primaryPurple;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return HoverBuilder(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hovering) {
        final bg =
            disabled
                ? const Color(0xFFF8FAFC).withValues(alpha: 0.5)
                : hovering
                ? _purple
                : const Color(0xFFF8FAFC);
        final textColor =
            disabled
                ? _purple.withValues(alpha: 0.4)
                : hovering
                ? Colors.white
                : _purple;
        final borderColor = disabled ? _purple.withValues(alpha: 0.3) : _purple;

        return SizedBox(
          width: width,
          height: 40,
          child: GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 0.65),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
