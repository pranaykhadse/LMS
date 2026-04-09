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

    final isActive = viewModel.getForClass(courseClass);
    if (isActive != null && isActive.isActive == '1') {
      return Chip(
        label: Text(
          "Completed",
          style: context.textTheme.bodySmall, //?.copyWith(color: Colors.white),
        ),
        backgroundColor: context.appColorScheme.success.withAlpha(50),
      );
    }
    return Chip(label: Text("Registered", style: context.textTheme.bodySmall));
  }
}
