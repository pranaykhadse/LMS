import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/view/content_view_page.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';

class DownloadButton extends ConsumerWidget {
  const DownloadButton({
    super.key,
    required this.icon,
    this.url,
    required this.label,
    required this.builder,
    required this.courseClass,
  });
  final String? url;
  final String label;
  final IconData icon;
  final CourseClass courseClass;
  final Widget Function(BuildContext context, FileCacheState file) builder;
  @override
  Widget build(BuildContext context, ref) {
    if (url == null || url!.isEmpty) return SizedBox();
    final viewModel = ref.watch(FileCacheViewModel.provider);
    return FutureBuilder(
      future: viewModel.getFor(url!),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Row(
          spacing: context.minorSpace,
          children: [
            OutlinedButton(
              onPressed: () async {
                if (data != null) {
                  ref
                      .read(
                        RoasterViewModel.provider(
                          courseClass.courseId,
                        ).notifier,
                      )
                      .markAsRead(courseClass);
                  ContentViewPage.show(
                    context: context,
                    courseClass: courseClass,
                    child: builder(context, data),
                  );
                }
                // await viewModel.downloadFile(url!);
              },
              child: Row(
                spacing: context.minorSpace,
                children: [Icon(icon), Text("View $label")],
              ),
            ),
            if (data?.file != null) ...{
              Chip(
                label: Text(
                  "Available Offline",
                  style: context.textTheme.bodySmall,
                ),
                backgroundColor: context.appColorScheme.success.withAlpha(50),
              ),
              InkWell(
                onTap: () {
                  viewModel.delete(data!.url);
                },
                child: Icon(
                  Icons.delete,
                  color: context.appColorScheme.primary,
                ),
              ),
            } else if (data?.progress != null) ...{
              Row(
                spacing: context.minorSpace,
                children: [
                  StreamBuilder<double>(
                    stream: data?.progress ?? Stream.value(0.5),
                    builder: (context, snapshot) {
                      return SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          value: snapshot.data?.clamp(0, 1),
                        ),
                      );
                    },
                  ),
                  Text("Downloading"),
                ],
              ),
            } else
              InkWell(
                onTap: () async {
                  await viewModel.downloadFile(url!);
                },
                child: Container(
                  color: Colors.grey.shade300,
                  padding: EdgeInsets.symmetric(
                    vertical: context.minorSpace / 2,
                    horizontal: context.minorSpace,
                  ),
                  child: Row(
                    spacing: context.minorSpace,
                    children: [
                      Icon(Icons.cloud_download_outlined, color: Colors.grey),

                      Text("Save Offline", style: context.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
