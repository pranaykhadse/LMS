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
  // Nullable: participant-guide content has no associated lesson class.
  final CourseClass? courseClass;
  final Widget view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(appBar: FlatAppBar(title: ""), body: view);
  }

  static void show({
    required BuildContext context,
    CourseClass? courseClass,
    required Widget child,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ContentViewPage(courseClass: courseClass, view: child),
      ),
    );
  }
}
