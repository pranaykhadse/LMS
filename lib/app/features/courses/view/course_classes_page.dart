import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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

          // ── Course-level documents ────────────────────────────────────────
          if (hasDocs)
            Container(
              width: double.infinity,
              color: context.appColorScheme.primary.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: defaultTargetPlatform == TargetPlatform.macOS
                  // macOS: label + buttons all on one horizontal line
                  ? Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: _docChildren(context, pgUrl, wmUrl, wmLink,
                          hasPg, hasWmFile, hasWmLink, inline: true),
                    )
                  // iOS: original vertical layout (label on top, buttons below)
                  : Column(
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
                          children: _docChildren(context, pgUrl, wmUrl, wmLink,
                              hasPg, hasWmFile, hasWmLink, inline: false),
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

List<Widget> _docChildren(
  BuildContext context,
  String? pgUrl,
  String? wmUrl,
  String? wmLink,
  bool hasPg,
  bool hasWmFile,
  bool hasWmLink, {
  required bool inline,
}) {
  return [
    if (inline)
      Text(
        "Course Documents",
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.appColorScheme.primary,
        ),
      ),
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
  ];
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

    // ── Type-aware action buttons ─────────────────────────────────────────
    // API returns type as a numeric string (e.g. "3") in ClassInfo.type.
    // customTypeName is always "" so we use type directly.
    final t   = (info?.type?.isNotEmpty == true
            ? info!.type!
            : (info?.customTypeName ?? ''))
        .trim();
    final alt = info?.alternativeLearningEvent;

    // Always-present offline-capable downloads (hidden by DownloadButton
    // when the URL is null/empty, so safe to add unconditionally).
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
      DownloadButton(
        icon: Icons.assignment_outlined,
        label: "Agreement",
        url: courseClass.scannedPdf,
        courseClass: courseClass,
        builder: (context, file) => PdfContentViewer(file: file),
      ),
    ];

    // Numeric type codes confirmed from API:
    //  1=eLearning  2=In Person  3=Virtual Class  4=Watch Video
    //  5=Read Article  6=Read Webpage  7=Discussion Board
    //  8=Task w/ Obs  9=Task w/o Obs  10=Coaching  11=Insight
    //  12=Certificate  13=LinkedIn Cert  14=Discussion Guru
    //  15=Peer Coaching  16=OnePage Pro  17=Simulation
    //  18=Agreement  19=Test Out  20=Text Message  21=Web App
    switch (t) {
      case '3': // Virtual Class
        actions.add(LinkButton(icon: Icons.video_call_outlined,        label: "Attend Class",           url: alt,                                                    courseClass: courseClass));
        actions.add(LinkButton(icon: Icons.play_circle_filled_rounded, label: "Watch Recording",        url: info?.s3ClassLink?.toString() ?? info?.classLink?.toString(), courseClass: courseClass));
      case '1': // eLearning Module
        actions.add(LinkButton(icon: Icons.rocket_launch_rounded,      label: "Launch",                 url: alt ?? info?.storyLineFile,                            courseClass: courseClass));
      case '2': // In Person
        actions.add(LinkButton(icon: Icons.person_add_outlined,        label: "Register",               url: alt,                                                    courseClass: courseClass));
      case '4': // Watch Video — DownloadButton already handles this
        break;
      case '5': // Read Article — DownloadButton already handles this
        break;
      case '6': // Read Webpage
        actions.add(LinkButton(icon: Icons.language,                   label: "Read Webpage",           url: info?.readWebpageLink ?? alt,                          courseClass: courseClass));
      case '7': // Discussion Board
        actions.add(LinkButton(icon: Icons.forum_outlined,             label: "Discussion Board",       url: info?.discussionForumLink?.toString() ?? alt,          courseClass: courseClass));
      case '8': // Perform a Task with Observation
      case '9': // Perform a Task without Observation
        actions.add(LinkButton(icon: Icons.task_alt,                   label: "Tasks",                  url: alt,                                                    courseClass: courseClass));
      case '10': // Receive Coaching
        actions.add(LinkButton(icon: Icons.people_outline_rounded,     label: "Coaches",                url: alt,                                                    courseClass: courseClass));
      case '11': // Insight Report
        actions.add(LinkButton(icon: Icons.bar_chart_rounded,          label: "Insights",               url: alt,                                                    courseClass: courseClass));
      case '12': // Certificate — no button
        break;
      case '13': // LinkedIn Certification
        actions.add(LinkButton(icon: Icons.verified_outlined,          label: "Certification",          url: info?.readWebpageLink ?? alt,                          courseClass: courseClass));
      case '14': // Discussion Guru
        actions.add(LinkButton(icon: Icons.school_outlined,            label: "Discussion Guru",        url: info?.discussionGuruLink ?? alt,                       courseClass: courseClass));
      case '15': // Peer Coaching — no button
        break;
      case '16': // One Page Form / OnePage Pro
        actions.add(LinkButton(icon: Icons.description_outlined,       label: "OnePage Pro",            url: info?.onePagerPro ?? alt,                              courseClass: courseClass));
      case '17': // Simulation / Custom Prompt
        actions.add(LinkButton(icon: Icons.link_rounded,               label: "Bridgework Link",        url: info?.customPrompt ?? alt,                             courseClass: courseClass));
      case '18': // Agreement
        actions.add(LinkButton(icon: Icons.assignment_outlined,        label: "Agreement",              url: alt,                                                    courseClass: courseClass));
      case '19': // Test Out Assessment — no button
        break;
      case '20': // Text Message — no button
        break;
      case '21': // Web Application
        actions.add(LinkButton(icon: Icons.open_in_browser_rounded,    label: "Launch Web Application", url: alt,                                                   courseClass: courseClass));
      default:
        if (alt != null && alt.trim().isNotEmpty) {
          actions.add(LinkButton(icon: Icons.open_in_browser_rounded,  label: "Launch",                 url: alt,                                                    courseClass: courseClass));
        }
    }

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
