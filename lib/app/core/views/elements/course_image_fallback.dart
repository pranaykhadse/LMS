import 'package:flutter/material.dart';
import 'package:lms/app/core/design/figma_tokens.dart';

/// Shown wherever a course/resource card's own image is missing or fails to
/// load — a plain local placeholder, not a network fetch.
///
/// The real site's own fallback (`dist/images/course-bg.svg`) embeds its
/// artwork via an SVG `<pattern>` fill with a base64 PNG tiled across it —
/// `flutter_svg` has no support for `<pattern>` fills at all (the same
/// limitation already worked around for a couple of nav icons elsewhere in
/// this app), and `Image.network` can't decode SVG in the first place, so
/// that URL renders nothing every time it's hit. Rather than keep pointing
/// at an asset this app can never actually paint, this is a real local
/// placeholder that always renders, works offline, and needs no network
/// round-trip at all.
class CourseImageFallback extends StatelessWidget {
  const CourseImageFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FigmaTokens.badgeBackground, Color(0xFFE0D4F0)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: FigmaTokens.primaryPurple,
        ),
      ),
    );
  }
}
