import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/class_status_chip.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
import 'package:lms/app/features/courses/view/widgets/link_button.dart';
import 'package:lms/app/features/courses/viewmodel/course_class_view_model.dart';

class CourseClassesPage extends ConsumerWidget {
  const CourseClassesPage({super.key, this.courseId});
  final String? courseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(CourseClassViewModel.provider(courseId));
    final viewmodel = ref.watch(
      CourseClassViewModel.provider(courseId).notifier,
    );
    return Scaffold(
      appBar: FlatAppBar(title: "Course Details"),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(context.smallSpace),
              child: PrimaryCard(
                child: DataStateBuilder(
                  dataState: state.data,
                  builder: (context, data) {
                    if (data == null || data.isEmpty) {
                      return const Center(child: Text("No lessons available."));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: data.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = data[index];
                        return _CourseClassTile(
                          index: index,
                          courseClass: item,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          PaginationWidget(
            pageInfo: state.pageInfo ?? PageInfo(),
            onPageChange: (value) {
              viewmodel.fetch(value);
            },
          ),
        ],
      ),
    );
  }
}

class _CourseClassTile extends StatelessWidget {
  const _CourseClassTile({required this.index, required this.courseClass});

  final int index;
  final CourseClass courseClass;

  @override
  Widget build(BuildContext context) {
    final info = courseClass.classInfo;
    final name = (info?.name ?? '').stripHtml;

    // Determine next session label from start date/time when available.
    String nextSession = '';
    if (info?.startDate != null && info!.startDate.toString().isNotEmpty) {
      nextSession = info.startDate.toString();
    }

    // Build the list of content action buttons for every available content type.
    final actions = <Widget>[
      DownloadButton(
        icon: Icons.videocam,
        label: "Video",
        url: info?.videoUploadUrl,
        courseClass: courseClass,
        builder: (context, file) => VideoContentViewer(file: file),
      ),
      DownloadButton(
        icon: Icons.picture_as_pdf,
        label: "PDF",
        url: info?.articleFile,
        courseClass: courseClass,
        builder: (context, file) => PdfContentViewer(file: file),
      ),
      LinkButton(
        icon: Icons.play_circle_outline,
        label: "Watch Video",
        url: info?.watchVideoLink,
        courseClass: courseClass,
      ),
      LinkButton(
        icon: Icons.article_outlined,
        label: "Read Article",
        url: info?.readArticleLink,
        courseClass: courseClass,
      ),
      LinkButton(
        icon: Icons.language,
        label: "Read Webpage",
        url: info?.readWebpageLink,
        courseClass: courseClass,
      ),
      LinkButton(
        icon: Icons.video_call_outlined,
        label: "Virtual Class",
        url: info?.virtualClassLink,
        courseClass: courseClass,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index number
              SizedBox(
                width: 32,
                child: Text(
                  '${index + 1}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.appColorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lesson name
                    Text(
                      name,
                      style: context.textTheme.bodyMedium,
                    ),
                    if (nextSession.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Next session: $nextSession',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Status chip
                    ClassStatusChip(courseClass: courseClass),
                  ],
                ),
              ),
            ],
          ),
          // Content action buttons — only renders buttons that have a URL
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: actions,
          ),
        ],
      ),
    );
  }
}
