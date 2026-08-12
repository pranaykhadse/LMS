import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';

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
  final Widget? infoSection;

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
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // ── Image: padding 15px sides, 20px top, 185px tall ──────────
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 20, 15, 0),
            child: SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail clipped into a right-pointing triangle/arrow
                  ClipPath(
                    clipper: _TriangleImageClipper(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _ImgFallback(),
                            )
                          : const _ImgFallback(),
                    ),
                  ),
                  // Leadership Edge Live logo — top-right
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Offline save button — top-left
                  if (offlineCourse != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: OfflineCourseButton(course: offlineCourse!),
                    ),
                  // Title overlay — bottom-right inside image
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: FigmaTokens.primaryPurple
                              .withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Info section ──────────────────────────────────────────────
          if (infoSection != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: infoSection!,
            ),

          // ── Spacer pushes purple footer to bottom of card ─────────────
          const Spacer(),

          // ── Purple footer — always at bottom, full width ──────────────
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(15),
            color: FigmaTokens.primaryPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Title fills remaining space — longer titles expand, not shrink
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    title,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                // More space between title and button
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

/// Clips the image into a right-pointing triangle/arrow shape, replicating
/// the CSS clip-path polygon used on the reference website's course cards.
/// The shape: top-left corner → top-right → middle-right point →
/// bottom-right → bottom-left corner, creating a right-pointing arrow.
class _TriangleImageClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final midY = size.height * 0.5;
    final tipX = size.width;         // rightmost tip of arrow
    final indentX = size.width * 0.72; // where the arrow indent starts

    path.moveTo(0, 0);                    // top-left
    path.lineTo(indentX, 0);             // top, before the dip
    path.lineTo(tipX, midY);             // right-pointing tip
    path.lineTo(indentX, size.height);   // bottom, after the dip
    path.lineTo(0, size.height);         // bottom-left
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TriangleImageClipper old) => false;
}
