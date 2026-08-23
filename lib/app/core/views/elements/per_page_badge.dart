import 'package:flutter/material.dart';
import 'package:lms/app/core/design/figma_tokens.dart';

const _perPageColor = FigmaTokens.primaryPurple;

/// Small outlined pill showing the per_page value actually used for a
/// list's fetch request — matches the website's "N Per Page" indicator.
class PerPageBadge extends StatelessWidget {
  const PerPageBadge({super.key, required this.perPage});
  final int perPage;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: _perPageColor),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '$perPage Per Page',
          style: const TextStyle(
            color: _perPageColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
