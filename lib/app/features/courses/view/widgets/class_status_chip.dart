import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';

class ClassStatusChip extends ConsumerWidget {
  const ClassStatusChip({super.key, required this.courseClass, this.fallbackStatus});
  final CourseClass courseClass;

  /// Shown (in the same style _StatusChip used) while RoasterViewModel has
  /// no row yet for this class - e.g. a freshly-enrolled class the roaster
  /// fetch hasn't returned a record for. Once markAsRead (or a future
  /// fetch) produces one, this widget switches to the reactive label
  /// automatically, no caller changes needed.
  final String? fallbackStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(RoasterViewModel.provider(courseClass.courseId));
    final viewModel = ref.watch(
      RoasterViewModel.provider(courseClass.courseId).notifier,
    );

    final roaster = viewModel.getForClass(courseClass);

    late final String label;
    late final Color bg;
    late final Color fg;

    if (roaster == null) {
      final fallback = fallbackStatus;
      if (fallback == null || fallback.isEmpty) return const SizedBox.shrink();
      final isCompleted =
          fallback.toLowerCase() == 'completed' ||
          fallback.toLowerCase() == 'complete';
      label = fallback;
      // CSS ref, joinCourse.php status badges: `.btn-registered` bg #E0E7FF/
      // #4338CA; `.btn-complete` bg #D1FAE5 / #059669.
      bg = isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFE0E7FF);
      fg = isCompleted ? const Color(0xFF059669) : const Color(0xFF4338CA);
    } else {
      switch (roaster.status) {
        case '1':
          label = 'Registered';
          bg    = const Color(0xFFE0E7FF);
          fg    = const Color(0xFF4338CA);
        case '2':
          label = 'Started';
          bg    = const Color(0xFFFEF3C7);
          fg    = const Color(0xFFB45309);
        case '3':
          label = 'Completed';
          bg    = const Color(0xFFD1FAE5);
          fg    = const Color(0xFF059669);
        default:
          label = 'Registered';
          bg    = const Color(0xFFE0E7FF);
          fg    = const Color(0xFF4338CA);
      }
    }

    return Container(
      // CSS ref: `.btn-registered` etc — padding 6px 16px, radius 20px,
      // 12px/weight600, text-transform capitalize, no border/shadow.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
