import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';

/// Unified course card — exact CSS spec from reference website.
///
/// Structure:
///  • Outer card: padding 0 15px
///  • Image block (div.team-img.text-center): padding 20px 0 15px, 185px tall
///      - Image with title overlay bar at bottom (purple + course name 22px)
///  • Info section (div.center-content): padding 15px
///      - h6 "The next available…": 12px #767676, margin-bottom 8px
///      - h5 date: 14px #484848 bold, margin-bottom 8px
///  • Footer (div.bottom-content): padding 15px, bg primaryPurple
///      - h2 title: 22px white, margin-bottom 8px
///      - p > a "View Course": padding 5px 20px, white, 16px Roboto
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
      // Outer card
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 15),
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
        children: [
          // ── div.team-img.text-center: padding 20px 0 15px ────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 15),
            child: SizedBox(
              height: 185,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _ImgFallback(),
                          )
                        : const _ImgFallback(),
                  ),
                  // Offline button
                  if (offlineCourse != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: OfflineCourseButton(course: offlineCourse!),
                    ),
                  // Title overlay bar at bottom of image
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(6)),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        color: FigmaTokens.primaryPurple.withValues(alpha: 0.85),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── div.center-content: padding 15px ─────────────────────────
          if (infoSection != null)
            Padding(
              padding: const EdgeInsets.all(15),
              child: infoSection!,
            ),

          // ── div.bottom-content: padding 15px, bg primaryPurple ───────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: FigmaTokens.primaryPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // h2: 22px white, margin-bottom 8px
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                // p > a: padding 5px 20px, 16px white
                OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 5),
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
