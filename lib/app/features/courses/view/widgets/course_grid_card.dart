import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';

/// Same card design as the Course Catalog screen's course cards: a
/// fixed-height image, an optional white info block underneath it, and a
/// purple (#603D92) footer with the title and an outlined action button
/// pinned to the bottom-left. Shared across the "My Courses" grid screens
/// (Enrolled/Completed/Required/Development Plan) instead of each having
/// its own copy-pasted card.
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

  /// Omit to hide the save-offline button (e.g. a custom development-plan
  /// entry with no real course behind it).
  final Course? offlineCourse;

  /// Rendered in the white block between the image and the purple footer
  /// (e.g. star rating / progress bar / completed badge). Omitted entirely
  /// when null, same as the catalog card without a next-session block.
  final Widget? infoSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
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
                if (offlineCourse != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: OfflineCourseButton(course: offlineCourse!),
                  ),
              ],
            ),
          ),
          if (infoSection != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              child: infoSection!,
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(color: Color(0xFF603D92)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Up to 3 lines before truncating - the grid row height
                  // (set by each page) is sized generously enough that
                  // realistic titles fit in full; this is just a safety net
                  // against an unexpectedly long one overflowing the card.
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      height: 27 / 22,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        height: 21 / 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
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
      child: const Icon(Icons.school_outlined, size: 54, color: Color(0xFF603D92)),
    );
  }
}
