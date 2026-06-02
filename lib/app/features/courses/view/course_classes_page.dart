import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/core/views/elements/offline_banner.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/class_status_chip.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
import 'package:lms/app/features/courses/view/widgets/link_button.dart';
import 'package:lms/app/features/courses/viewmodel/course_class_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';

class CourseClassesPage extends ConsumerWidget {
  const CourseClassesPage({super.key, this.courseId});
  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The Course object is passed as route argument from CoursesPage so we can
    // display course-level documents without an extra API call.
    final course = Modular.args.data is Course
        ? Modular.args.data as Course
        : null;

    final pgUrl = course?.participantGuideFile?.toString();
    final wmUrl = course?.wrapMethodologyFile?.toString();
    final wmLink = course?.wrapMethodologyLink?.toString();

    final hasPg = pgUrl != null && pgUrl.trim().isNotEmpty;
    final hasWmFile = wmUrl != null && wmUrl.trim().isNotEmpty;
    final hasWmLink = wmLink != null && wmLink.trim().isNotEmpty;
    final hasDocs = hasPg || hasWmFile || hasWmLink;

    return Scaffold(
      appBar: FlatAppBar(title: "Course Details"),
      body: Column(
        children: [
          // ── Offline / re-sync banner (replaces old orange strip) ──────────
          const OfflineBanner(),

          // ── Course-level documents header ─────────────────────────────────
          if (hasDocs)
            Container(
              width: double.infinity,
              color: context.appColorScheme.primary.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Course Documents",
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.appColorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // Participant Guide — downloadable PDF
                      if (hasPg)
                        _DocRow(
                          icon: Icons.menu_book_rounded,
                          label: "Participant Guide",
                          child: DownloadButton(
                            icon: Icons.picture_as_pdf,
                            label: "Participant Guide",
                            url: pgUrl,
                            courseClass: null,
                            builder: (ctx, file) => PdfContentViewer(file: file),
                          ),
                        ),

                      // Wrap Methodology — downloadable file
                      if (hasWmFile)
                        _DocRow(
                          icon: Icons.wrap_text_rounded,
                          label: "Wrap Methodology",
                          child: DownloadButton(
                            icon: Icons.picture_as_pdf,
                            label: "Wrap Methodology",
                            url: wmUrl,
                            courseClass: null,
                            builder: (ctx, file) => PdfContentViewer(file: file),
                          ),
                        ),

                      // Wrap Methodology — external link fallback
                      if (!hasWmFile && hasWmLink)
                        _DocRow(
                          icon: Icons.wrap_text_rounded,
                          label: "Wrap Methodology",
                          child: LinkButton(
                            icon: Icons.open_in_new_rounded,
                            label: "Wrap Methodology",
                            url: wmLink,
                            courseClass: null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Lesson list ───────────────────────────────────────────────────
          Expanded(
            child: ConnectionAwareWidget(
              offlineChild: _OfflineCourseClassesList(courseId: courseId),
              onlineChild: _OnlineCourseClassesList(courseId: courseId),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small helper: icon + label + action widget in a row ──────────────────────
class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.icon,
    required this.label,
    required this.child,
  });
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.appColorScheme.primary),
        const SizedBox(width: 6),
        Text(label, style: context.textTheme.bodySmall),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Online lesson list — fetches from network, paginated
// ─────────────────────────────────────────────────────────────────────────────
class _OnlineCourseClassesList extends ConsumerWidget {
  const _OnlineCourseClassesList({this.courseId});
  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(CourseClassViewModel.provider(courseId));
    final viewmodel =
        ref.watch(CourseClassViewModel.provider(courseId).notifier);

    return Column(
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
                  return _LessonListView(lessons: data);
                },
              ),
            ),
          ),
        ),
        PaginationWidget(
          pageInfo: state.pageInfo ?? PageInfo(),
          onPageChange: (value) => viewmodel.fetch(value),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline lesson list — loads from Hive (downloaded classes)
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineCourseClassesList extends ConsumerWidget {
  const _OfflineCourseClassesList({this.courseId});
  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineVM = ref.watch(OfflineViewModel.provider);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.smallSpace),
            child: PrimaryCard(
              child: FutureBuilder<List<CourseClass>>(
                future: courseId != null
                    ? offlineVM.getCachedClasses(courseId!)
                    : Future.value([]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data ?? [];
                  if (data.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            "No offline content found.\nConnect to the internet or download this course first.",
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return _LessonListView(lessons: data);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared lesson list — used by both online and offline paths
// ─────────────────────────────────────────────────────────────────────────────
class _LessonListView extends StatelessWidget {
  const _LessonListView({required this.lessons});
  final List<CourseClass> lessons;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: lessons.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _CourseClassTile(
          index: index,
          courseClass: lessons[index],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single lesson tile
// ─────────────────────────────────────────────────────────────────────────────
class _CourseClassTile extends StatelessWidget {
  const _CourseClassTile({required this.index, required this.courseClass});

  final int index;
  final CourseClass courseClass;

  @override
  Widget build(BuildContext context) {
    final info = courseClass.classInfo;
    final name = (info?.name ?? '').stripHtml;

    String nextSession = '';
    if (info?.startDate != null && info!.startDate.toString().isNotEmpty) {
      nextSession = info.startDate.toString();
    }

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
                    Text(name, style: context.textTheme.bodyMedium),
                    if (nextSession.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Next session: $nextSession',
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // All action buttons + status chip together so they wrap and align uniformly.
          // Left-indented 40px to align under the lesson name (past the 32px number column).
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ClassStatusChip(courseClass: courseClass),
                ...actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
