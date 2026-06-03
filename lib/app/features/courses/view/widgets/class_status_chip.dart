import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/utils/utils.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';

class ClassStatusChip extends ConsumerWidget {
  const ClassStatusChip({super.key, required this.courseClass});
  final CourseClass courseClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ = ref.watch(RoasterViewModel.provider(courseClass.courseId));
    final viewModel = ref.watch(
      RoasterViewModel.provider(courseClass.courseId).notifier,
    );

    final roaster = viewModel.getForClass(courseClass);

    if (roaster == null) return const SizedBox.shrink();

    late final String label;
    late final Color bg;
    late final Color fg;

    switch (roaster.status) {
      case '1':
        label = 'Registered';
        bg    = const Color(0xFFEDE9F8);
        fg    = const Color(0xFF6B4FBB);
      case '2':
        label = 'Started';
        bg    = const Color(0xFFFFF3CD);
        fg    = const Color(0xFF856404);
      case '3':
        label = 'Completed';
        bg    = const Color(0xFFD4EDDA);
        fg    = const Color(0xFF276036);
      default:
        label = 'Registered';
        bg    = const Color(0xFFEDE9F8);
        fg    = const Color(0xFF6B4FBB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
