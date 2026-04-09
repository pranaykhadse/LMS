import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/courses/model/course_class.dart';

class ContentViewPage extends ConsumerWidget {
  const ContentViewPage({
    super.key,
    required this.courseClass,
    // required this.file,
    required this.view,
  });
  final CourseClass courseClass;
  // final FileCacheState file;
  final Widget view;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(appBar: FlatAppBar(title: ""), body: view);
  }

  static void show({
    required BuildContext context,
    required CourseClass courseClass,
    required Widget child,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return ContentViewPage(courseClass: courseClass, view: child);
      },
    );
  }
}
