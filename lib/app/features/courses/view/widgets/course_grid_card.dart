import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';

class CourseGridCard extends StatefulWidget {
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
  final Widget? infoSection;

  /// Extra buttons (e.g. +/- dev plan) shown only on hover, positioned
  /// top-right of the image area. Pass null to omit.
  final Widget? overlayButtons;

  @override
  State<CourseGridCard> createState() => _CourseGridCardState();
}

class _CourseGridCardState extends State<CourseGridCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
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
            // ── Image area ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 20, 15, 0),
              child: SizedBox(
                height: 210,
                child: Stack(
                  children: [
                    // Background: Leadership Edge Live logo centered
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          color: FigmaTokens.primaryPurple
                              .withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            width: 140,
                            opacity:
                                const AlwaysStoppedAnimation(0.18),
                          ),
                        ),
                      ),
                    ),
                    // Foreground: actual course image as a rectangle
                    // centered/slightly left, not full bleed
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: widget.imageUrl != null
                            ? Image.network(
                                widget.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    // Leadership Edge Live logo — top-right corner
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 26,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Offline save button — only on hover, top-left
                    if (_hovering && widget.offlineCourse != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: OfflineCourseButton(
                            course: widget.offlineCourse!),
                      ),
                    // Extra overlay buttons (dev plan +/-) — only on hover
                    if (_hovering && widget.overlayButtons != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: widget.overlayButtons!,
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
                            widget.title,
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

            // ── Info section ──────────────────────────────────────────
            if (widget.infoSection != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
                child: widget.infoSection!,
              ),

            // Spacer pushes footer to bottom
            const Spacer(),

            // ── Purple footer — always at bottom ──────────────────────
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(15),
              color: FigmaTokens.primaryPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      widget.title,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: widget.onPressed,
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
                    child: Text(widget.buttonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
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
