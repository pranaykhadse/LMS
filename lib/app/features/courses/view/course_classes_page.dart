import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/class_status_chip.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
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
                    return SingleChildScrollView(
                      child: SizedBox(
                        width: double.maxFinite,
                        child: DataTable(
                          headingTextStyle: context.textTheme.labelLarge
                              ?.copyWith(color: context.appColorScheme.primary),
                          columns: [
                            DataColumn(label: Text("")),
                            DataColumn(label: Text("Course Detail")),
                            DataColumn(label: Text("Next session")),
                            DataColumn(label: Text("Status")),
                            DataColumn(label: Text("Action")),
                          ],
                          rows: [
                            // for (CourseClass item in (data ?? []))
                            ...List.generate(data?.length ?? 0, (index) {
                              final item = data![index];
                              return DataRow(
                                cells: [
                                  DataCell(Text("${index + 1}")),
                                  DataCell(Text(item.classInfo?.name ?? "")),
                                  DataCell(Text("")),
                                  DataCell(ClassStatusChip(courseClass: item)),
                                  DataCell(
                                    Row(
                                      children: [
                                        // if (item.classInfo?.videoUploadUrl !=
                                        //     null)
                                        // Text(
                                        //   item.classInfo?.videoUploadUrl ??
                                        //       "",
                                        // ),
                                        DownloadButton(
                                          icon: Icons.videocam,
                                          label: "Video",
                                          url: item.classInfo?.videoUploadUrl,
                                          courseClass: item,
                                          builder:
                                              (context, file) =>
                                                  VideoContentViewer(
                                                    file: file,
                                                  ),
                                        ),
                                        DownloadButton(
                                          icon: Icons.picture_as_pdf,
                                          label: "PDF",
                                          url: item.classInfo?.articleFile,
                                          courseClass: item,
                                          builder:
                                              (context, file) =>
                                                  PdfContentViewer(file: file),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
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
