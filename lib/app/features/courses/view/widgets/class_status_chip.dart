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

    // No roaster record — lesson not yet registered, show nothing (matches web)
    if (roaster == null) return const SizedBox.shrink();

    switch (roaster.status) {
      case '1':
        return Chip(
          label: Text("Registered", style: context.textTheme.bodySmall),
        );
      case '2':
        return Chip(
          label: Text("Started", style: context.textTheme.bodySmall),
          backgroundColor: Colors.amber.withAlpha(60),
        );
      case '3':
        return Chip(
          label: Text("Completed", style: context.textTheme.bodySmall),
          backgroundColor: context.appColorScheme.success.withAlpha(50),
        );
      default:
        return Chip(
          label: Text("Registered", style: context.textTheme.bodySmall),
        );
    }
  }
}
