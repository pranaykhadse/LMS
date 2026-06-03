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
    final t   = (info?.customTypeName ?? info?.type ?? '').toLowerCase().trim();
    final alt = info?.alternativeLearningEvent;

    // DEBUG — remove once type values are confirmed
    debugPrint(
      '[Tile] #${courseClass.classId} name="$name" '
      'customTypeName="${info?.customTypeName}" '
      'type="${info?.type}" '
      't="$t" '
      'alt=${alt?.isNotEmpty == true ? "✓" : "null"} '
      'videoUrl=${info?.videoUploadUrl?.isNotEmpty == true ? "✓" : "null"} '
      'watchVideoLink=${info?.watchVideoLink?.isNotEmpty == true ? "✓" : "null"} '
      'readWebpageLink=${info?.readWebpageLink?.isNotEmpty == true ? "✓" : "null"} '
      'virtualClassLink=${info?.virtualClassLink?.isNotEmpty == true ? "✓" : "null"} '
      'discussionForumLink=${info?.discussionForumLink != null ? "✓" : "null"} '
      'discussionGuruLink=${info?.discussionGuruLink?.isNotEmpty == true ? "✓" : "null"} '
      'peerCoachingLink=${info?.peerCoachingLink?.isNotEmpty == true ? "✓" : "null"} '
      'onePagerPro=${info?.onePagerPro?.isNotEmpty == true ? "✓" : "null"} '
      'customPrompt=${info?.customPrompt?.isNotEmpty == true ? "✓" : "null"} '
      'storyLineFile=${info?.storyLineFile?.isNotEmpty == true ? "✓" : "null"} '
      's3ClassLink=${info?.s3ClassLink != null ? "✓" : "null"} '
      'classLink=${info?.classLink != null ? "✓" : "null"}',
    );

    // Always-present offline-capable downloads (hidden by DownloadButton when
    // the URL is null/empty, so safe to add unconditionally).
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

    // One primary-action block per type.
    if (t.contains('virtual class')) {
      // Attend Class (live link) + Watch Recording (S3/class recording)
      actions.add(LinkButton(icon: Icons.video_call_outlined, label: "Attend Class",      url: alt,                                                                    courseClass: courseClass));
      actions.add(LinkButton(icon: Icons.play_circle_filled_rounded, label: "Watch Recording", url: info?.s3ClassLink?.toString() ?? info?.classLink?.toString(), courseClass: courseClass));
    } else if (t.contains('elearning') || t.contains('e-learning') || t.contains('e learning')) {
      actions.add(LinkButton(icon: Icons.rocket_launch_rounded,  label: "Launch",         url: alt ?? info?.storyLineFile,                                            courseClass: courseClass));
    } else if (t.contains('in person')) {
      actions.add(LinkButton(icon: Icons.person_add_outlined,    label: "Register",       url: alt,                                                                    courseClass: courseClass));
    } else if (t.contains('watch video')) {
      actions.add(LinkButton(icon: Icons.play_circle_outline,    label: "Watch Video",    url: info?.watchVideoLink ?? alt,                                           courseClass: courseClass));
    } else if (t.contains('read article')) {
      actions.add(LinkButton(icon: Icons.article_outlined,       label: "Read Article",   url: info?.readArticleLink ?? alt,                                          courseClass: courseClass));
    } else if (t.contains('read webpage')) {
      actions.add(LinkButton(icon: Icons.language,               label: "Read Webpage",   url: info?.readWebpageLink ?? alt,                                          courseClass: courseClass));
    } else if (t.contains('discussion board')) {
      actions.add(LinkButton(icon: Icons.forum_outlined,         label: "Discussion Board", url: info?.discussionForumLink?.toString() ?? alt,                       courseClass: courseClass));
    } else if (t.contains('perform') && t.contains('task')) {
      actions.add(LinkButton(icon: Icons.task_alt,               label: "Tasks",          url: alt,                                                                    courseClass: courseClass));
    } else if (t.contains('peer coaching')) {
      // Peer Coaching: no action button (matches web — Details only)
    } else if (t.contains('receive coaching') || t.contains('coaching')) {
      actions.add(LinkButton(icon: Icons.people_outline_rounded, label: "Coaches",        url: alt,                                                                    courseClass: courseClass));
    } else if (t.contains('insight')) {
      actions.add(LinkButton(icon: Icons.bar_chart_rounded,      label: "Insights",       url: alt,                                                                    courseClass: courseClass));
    } else if (t.contains('linkedin')) {
      actions.add(LinkButton(icon: Icons.verified_outlined,      label: "Certification",  url: info?.readWebpageLink ?? alt,                                          courseClass: courseClass));
    } else if (t.contains('certificate')) {
      // Certificate: no action button (matches web)
    } else if (t.contains('discussion guru')) {
      actions.add(LinkButton(icon: Icons.school_outlined,        label: "Discussion Guru", url: info?.discussionGuruLink ?? alt,                                      courseClass: courseClass));
    } else if (t.contains('one page') || t.contains('onepage')) {
      actions.add(LinkButton(icon: Icons.description_outlined,   label: "OnePage Pro",    url: info?.onePagerPro ?? alt,                                              courseClass: courseClass));
    } else if (t.contains('simulation') || t.contains('custom prompt')) {
      actions.add(LinkButton(icon: Icons.link_rounded,           label: "Bridgework Link", url: info?.customPrompt ?? alt,                                            courseClass: courseClass));
    } else if (t.contains('agreement')) {
      actions.add(LinkButton(icon: Icons.assignment_outlined,    label: "Agreement",      url: alt,                                                                    courseClass: courseClass));
    } else if (t.contains('test out') || t.contains('assessment')) {
      // Test Out Assessment: no action button (matches web — Started status only)
    } else if (t.contains('web application')) {
      actions.add(LinkButton(icon: Icons.open_in_browser_rounded, label: "Launch Web Application", url: alt,                                                         courseClass: courseClass));
    } else if (t.contains('text message')) {
      // Text Message: no action button
    } else if (alt != null && alt.trim().isNotEmpty) {
      // Unknown type — show generic Launch so nothing is lost
      actions.add(LinkButton(icon: Icons.open_in_browser_rounded, label: "Launch",        url: alt,                                                                    courseClass: courseClass));
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
