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
    // Status '1' = Registered. Any other status (including '3') = Completed.
    final isCompleted = roaster != null && roaster.status != '1';

    debugPrint(
      '[ClassStatusChip] classId=${courseClass.classId} '
      'status=${roaster?.status ?? "no-record"} '
      'isCompleted=$isCompleted',
    );

    if (isCompleted) {
      return Chip(
        label: Text("Completed", style: context.textTheme.bodySmall),
        backgroundColor: context.appColorScheme.success.withAlpha(50),
      );
    }
    return Chip(label: Text("Registered", style: context.textTheme.bodySmall));
  }
}
