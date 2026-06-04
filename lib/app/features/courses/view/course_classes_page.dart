import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/core/views/elements/offline_banner.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/class_info.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/class_status_chip.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
import 'package:lms/app/features/courses/view/widgets/link_button.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/features/courses/viewmodel/course_class_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';

// Returns [s] only when it looks like a real http(s) URL (strips HTML first).
// Rejects empty strings, "0", and fields that contain HTML markup instead of a URL.
String? _validUrl(String? s) {
  if (s == null || s.isEmpty || s == '0') return null;
  final plain = s.stripHtml.trim();
  return (plain.startsWith('http://') || plain.startsWith('https://')) ? plain : null;
}

// Maps numeric type code to human-readable label shown as subtitle and dialog badge.
String _typeDisplayName(String? typeCode, String? customTypeName) {
  if (customTypeName != null && customTypeName.trim().isNotEmpty) {
    return customTypeName.trim();
  }
  switch (typeCode) {
    case '1':  return 'eLearning Module';
    case '2':  return 'In Person';
    case '3':  return 'Virtual Class';
    case '4':  return 'Watch Video';
    case '5':  return 'Read Article';
    case '6':  return 'Read Webpage';
    case '7':  return 'Discussion Board';
    case '8':  return 'Perform Task With Observation';
    case '9':  return 'Perform Task Without Observation';
    case '10': return 'Receive Coaching';
    case '11': return 'Insight Report';
    case '12': return 'Certificate';
    case '13': return 'LinkedIn Certification';
    case '14': return 'Discussion Guru';
    case '15': return 'Peer Coaching';
    case '17': return 'OnePage Pro';
    case '18': return 'Custom Prompt';
    case '19': return 'Agreement';
    case '20': return 'Test Out Assessment';
    case '22': return 'Text Message';
    case '23': return 'Web Application';
    default:   return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class CourseClassesPage extends ConsumerWidget {
  const CourseClassesPage({super.key, this.courseId});
  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = Modular.args.data is Course ? Modular.args.data as Course : null;
    final pgUrl   = course?.participantGuideFile?.toString();
    final wmUrl   = course?.wrapMethodologyFile?.toString();
    final wmLink  = course?.wrapMethodologyLink?.toString();
    final hasPg      = pgUrl  != null && pgUrl.trim().isNotEmpty;
    final hasWmFile  = wmUrl  != null && wmUrl.trim().isNotEmpty;
    final hasWmLink  = wmLink != null && wmLink.trim().isNotEmpty;
    final hasDocs    = hasPg || hasWmFile || hasWmLink;

    return Scaffold(
      appBar: FlatAppBar(title: course?.name?.isNotEmpty == true ? course!.name! : "Course Details"),
      body: Column(
        children: [
          const OfflineBanner(),
          if (hasDocs)
            Container(
              width: double.infinity,
              color: context.appColorScheme.primary.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: defaultTargetPlatform == TargetPlatform.macOS
                  ? Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: _docChildren(context, pgUrl, wmUrl, wmLink,
                          hasPg, hasWmFile, hasWmLink, inline: true),
                    )
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

// ─────────────────────────────────────────────────────────────────────────────
// Course-document helpers (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _DocRow extends StatelessWidget {
  const _DocRow({required this.icon, required this.label, required this.child});
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
// Online lesson list
// ─────────────────────────────────────────────────────────────────────────────
class _OnlineCourseClassesList extends ConsumerWidget {
  const _OnlineCourseClassesList({this.courseId});
  final String? courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state     = ref.watch(CourseClassViewModel.provider(courseId));
    final viewmodel = ref.watch(CourseClassViewModel.provider(courseId).notifier);

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
                  return _LessonTableView(lessons: data);
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
// Offline lesson list
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
                  return _LessonTableView(lessons: data);
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
// Lesson table view — "Course Structure" header + column headers + rows
// ─────────────────────────────────────────────────────────────────────────────
class _LessonTableView extends StatelessWidget {
  const _LessonTableView({required this.lessons});
  final List<CourseClass> lessons;

  // Fixed column widths; COURSE DETAILS fills the remaining space via Expanded.
  static const double _colNum     = 40.0;
  static const double _colSession = 90.0;
  static const double _colStatus  = 130.0;
  static const double _colAction  = 280.0;

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF9E9E9E),
      letterSpacing: 0.6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "Course Structure" title ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: context.appColorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Course Structure',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // ── Column headers ────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                SizedBox(width: _colNum,     child: const Text('#',             style: headerStyle)),
                const Expanded(              child: Text('COURSE DETAILS',      style: headerStyle)),
                SizedBox(width: _colSession, child: const Text('NEXT SESSION',  style: headerStyle)),
                const SizedBox(width: 24),
                SizedBox(width: _colStatus,  child: const Text('STATUS',        style: headerStyle)),
                const SizedBox(width: 24),
                SizedBox(width: _colAction,  child: const Text('ACTION',        style: headerStyle)),
              ],
            ),
          ),
        ),

        // ── Rows ──────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) => _CourseClassTile(
              index:       index,
              courseClass: lessons[index],
              colNum:      _colNum,
              colSession:  _colSession,
              colStatus:   _colStatus,
              colAction:   _colAction,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single lesson row
// ─────────────────────────────────────────────────────────────────────────────
class _CourseClassTile extends ConsumerWidget {
  const _CourseClassTile({
    required this.index,
    required this.courseClass,
    required this.colNum,
    required this.colSession,
    required this.colStatus,
    required this.colAction,
  });

  final int index;
  final CourseClass courseClass;
  final double colNum;
  final double colSession;
  final double colStatus;
  final double colAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = courseClass.classInfo;
    final roasterVM = ref.watch(RoasterViewModel.provider(courseClass.courseId).notifier);
    final roaster   = roasterVM.getForClass(courseClass);
    final lec       = roaster?.learningEventClass;
    // Prefer roaster's learningEventClass; fall back to rawLec from allcourse/events
    // when fetch-user-roaster doesn't populate the nested LEC object.
    final effectiveLec = (lec is Map) ? lec : courseClass.rawLec;

    // Derive backend web base URL from the API URL.
    // API:  https://domain/api/web/  →  Web: https://domain/backend/web/
    final serverUrl  = ref.watch(ServerProvider.serverUrl);
    final webBaseUrl = serverUrl.replaceFirst('/api/web/', '/backend/web/');

    final name = (info?.name ?? '').stripHtml;
    final t    = (info?.type?.isNotEmpty == true ? info!.type! : (info?.customTypeName ?? '')).trim();

    // "0" is a falsy sentinel value from the API (not a real URL).  Filter it out.
    final _rawAlt = info?.alternativeLearningEvent;
    final alt = (_rawAlt != null && _rawAlt.isNotEmpty && _rawAlt != '0')
        ? _rawAlt
        : null;

    final typeName = _typeDisplayName(t.isEmpty ? null : t, info?.customTypeName);

    // Next session: prefer LEC dates, then classInfo dates.
    String nextSession = '';
    if (effectiveLec is Map) {
      final s = effectiveLec['start_date']?.toString() ?? '';
      final e = effectiveLec['end_date']?.toString() ?? '';
      if (s.isNotEmpty) nextSession = e.isNotEmpty ? '$s – $e' : s;
    } else if (info?.startDate != null && info!.startDate.toString().isNotEmpty) {
      final s = info.startDate.toString();
      final e = info.endDate?.toString() ?? '';
      nextSession = e.isNotEmpty ? '$s – $e' : s;
    }

    // Types that show a Details button (matches website behaviour).
    const detailsTypes = {
      '1','2','3','4','5','6','7','8','9','10','11','13','15','18','19','20',
    };

    final actions = <Widget>[
      if (detailsTypes.contains(t))
        _DetailsButton(
          info:       info,
          lec:        effectiveLec,
          lessonName: name,
          typeName:   typeName,
          typeCode:   t,
        ),
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

    // Shorthand: begin-class URL for this lesson (universal fallback, same as website).
    final bc = '${webBaseUrl}lmsclass/begin-class?classId=${courseClass.classId}';

    // Numeric type codes from API:
    //  1=eLearning  2=In Person  3=Virtual Class  4=Watch Video
    //  5=Read Article  6=Read Webpage  7=Discussion Board
    //  8=Task w/ Obs  9=Task w/o Obs  10=Coaching  11=Insight
    //  12=Certificate  13=LinkedIn Cert  14=Discussion Guru
    //  15=Peer Coaching  17=OnePage Pro  18=Simulation/Custom Prompt
    //  19=Agreement  20=Test Out  22=Text Message  23=Web Application
    //
    // URL priority per type:
    //   type-specific field  →  alt (already cleaned of "0")  →  begin-class (bc)
    switch (t) {
      case '3': // Virtual Class — Details + Download Recording
        // training_session_recording_link is supplied by the backend in
        // allcourse/events (top-level field alongside id/course_id/class_id).
        // Each LEC row is one session; the button appears only when the URL is set.
        final _lecRecUrl = effectiveLec is Map
            ? _validUrl(effectiveLec['training_session_recording_link']?.toString())
            : null;
        final _recordingUrl = _lecRecUrl ?? _validUrl(_rawAlt);
        actions.add(DownloadButton(
          icon: Icons.download_rounded,
          label: "Recording",
          url: _recordingUrl,   // null → button is hidden automatically
          courseClass: courseClass,
          builder: (context, file) => VideoContentViewer(file: file),
        ));

      case '1': // eLearning Module
        final _elearningUrl = info?.isLaunch == '1'
            ? bc   // begin-class handles SCORM tracking (matches website)
            : (_validUrl(info?.s3ClassLink?.toString()) ?? _validUrl(info?.classLink?.toString()) ?? alt ?? bc);
        actions.add(LinkButton(icon: Icons.rocket_launch_rounded, label: "Launch", url: _elearningUrl, courseClass: courseClass));

      case '2': // In Person — Register
        actions.add(LinkButton(icon: Icons.person_add_outlined,    label: "Register",               url: alt ?? bc, courseClass: courseClass));

      case '4': // Watch Video — DownloadButton (videoUploadUrl) already handles
        break;

      case '5': // Read Article
        // Website opens the read-article page (DownloadButton still provides offline PDF access).
        actions.add(LinkButton(
          icon: Icons.article_outlined,
          label: "Article",
          url: '${webBaseUrl}course/read-article?classId=${courseClass.classId}',
          courseClass: courseClass,
        ));

      case '6': // Read Webpage — URL must be configured; no begin-class fallback
        actions.add(LinkButton(icon: Icons.language,               label: "Webpage",                url: _validUrl(info?.readWebpageLink) ?? alt, courseClass: courseClass));

      case '7': // Discussion Board
        actions.add(LinkButton(icon: Icons.forum_outlined,         label: "Discussion Board",       url: _validUrl(info?.discussionForumLink?.toString()) ?? alt ?? bc, courseClass: courseClass));

      case '8': // Perform a Task with Observation
      case '9': // Perform a Task without Observation
        // Website uses forum/index/observe?id=X  (note: id=, not classId=)
        actions.add(LinkButton(
          icon: Icons.task_alt,
          label: "Tasks",
          url: alt ?? '${webBaseUrl}forum/index/observe?id=${courseClass.classId}',
          courseClass: courseClass,
        ));

      case '10': // Receive Coaching — learning-event-class/coaches?id=X
        actions.add(LinkButton(
          icon: Icons.people_outline_rounded,
          label: "Coaches",
          url: alt ?? '${webBaseUrl}learning-event-class/coaches?id=${courseClass.classId}',
          courseClass: courseClass,
        ));

      case '11': // Insight Report — insight/index?id=X
        actions.add(LinkButton(
          icon: Icons.bar_chart_rounded,
          label: "Insights",
          url: alt ?? '${webBaseUrl}insight/index?id=${courseClass.classId}',
          courseClass: courseClass,
        ));

      case '12': // Certificate — no action button
        break;

      case '13': // LinkedIn Certification — URL must be the LinkedIn add-cert link
        actions.add(LinkButton(icon: Icons.verified_outlined,      label: "Certification",          url: _validUrl(info?.readWebpageLink) ?? alt, courseClass: courseClass));

      case '14': // Discussion Guru
        actions.add(LinkButton(icon: Icons.school_outlined,        label: "Discussion Guru",        url: _validUrl(info?.discussionGuruLink) ?? alt ?? bc, courseClass: courseClass));

      case '15': // Peer Coaching — no action button (just Details)
        break;

      case '16': // OnePage Pro (legacy type code)
      case '17': // One Page Form / OnePage Pro
        // onePagerPro may be empty; customPrompt not applicable here
        actions.add(LinkButton(icon: Icons.description_outlined,   label: "OnePage Pro",            url: _validUrl(info?.onePagerPro) ?? alt ?? bc, courseClass: courseClass));

      case '18': // Simulation / Custom Prompt
        // customPrompt sometimes stores HTML content, not a URL — validate first
        actions.add(LinkButton(icon: Icons.link_rounded,           label: "Bridgework Link",        url: _validUrl(info?.customPrompt) ?? alt ?? bc, courseClass: courseClass));

      case '19': // Agreement — course/agreement-preview?id=X&course_id=Y
        actions.add(LinkButton(
          icon: Icons.assignment_outlined,
          label: "Agreement",
          url: alt ?? '${webBaseUrl}course/agreement-preview?id=${courseClass.classId}&course_id=${courseClass.courseId}',
          courseClass: courseClass,
        ));

      case '20': // Test Out Assessment — no action button (just Details)
        break;

      case '21': // Web Application (legacy type code)
      case '23': // Web Application
        actions.add(LinkButton(icon: Icons.open_in_browser_rounded, label: "Launch Web Application", url: alt ?? bc, courseClass: courseClass));

      case '22': // Text Message — no action button
        break;

      default:
        // Unknown type: open alt URL if real, otherwise fall back to begin-class
        actions.add(LinkButton(icon: Icons.open_in_browser_rounded, label: "Launch", url: alt ?? bc, courseClass: courseClass));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // # column
            SizedBox(
              width: colNum,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appColorScheme.primary,
                ),
              ),
            ),

            // COURSE DETAILS column
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1a1a2e),
                      ),
                    ),
                    if (typeName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '($typeName)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // NEXT SESSION column
            SizedBox(
              width: colSession,
              child: nextSession.isNotEmpty
                  ? Text(
                      nextSession,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(width: 24),

            // STATUS column
            SizedBox(
              width: colStatus,
              child: ClassStatusChip(courseClass: courseClass),
            ),

            const SizedBox(width: 24),

            // ACTION column
            SizedBox(
              width: colAction,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Details button — dark filled, opens centered dialog
// ─────────────────────────────────────────────────────────────────────────────
class _DetailsButton extends StatelessWidget {
  const _DetailsButton({
    required this.info,
    required this.lec,
    required this.lessonName,
    required this.typeName,
    required this.typeCode,
  });

  final ClassInfo? info;
  final dynamic lec;
  final String lessonName;
  final String typeName;
  final String typeCode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: () => _showDetails(context),
        icon: const Icon(Icons.info_outline_rounded, size: 13),
        label: const Text("Details"),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF252535),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    // Prefer LEC data for schedule fields; fall back to ClassInfo.
    String _lecVal(String key, dynamic fallback) {
      if (lec is Map) {
        final v = lec[key]?.toString() ?? '';
        if (v.isNotEmpty) return v;
      }
      return fallback?.toString() ?? '';
    }

    final objective    = (info?.objective   ?? '').stripHtml.trim();
    final description  = (info?.description ?? '').stripHtml.trim();
    final startDate    = _lecVal('start_date',    info?.startDate);
    final endDate      = _lecVal('end_date',      info?.endDate);
    final startTime    = _lecVal('start_time',    info?.startTime);
    final endTime      = _lecVal('end_time',      info?.endTime);
    final instructor   = _lecVal('instructor',    info?.instructor);
    final instructions = _lecVal('instructions',  info?.instruction);
    final location     = _lecVal('location',      info?.location);

    final hasSchedule = [startDate, endDate, startTime, endTime, instructor, instructions, location]
        .any((s) => s.isNotEmpty);

    // Virtual Class-specific session info
    String sessionLink = '';
    String platformLabel = '';
    String vcFilename = '';
    String recordingLink = '';
    if (typeCode == '3') {
      if (lec is Map) {
        final direct = lec['training_session_link']?.toString() ?? '';
        if (direct.startsWith('http')) sessionLink = direct;
        switch (lec['platform']?.toString()) {
          case '1': platformLabel = 'Virtual Platform'; break;
          case '2': platformLabel = 'Rapid Fire / Twilio'; break;
        }
        final rec = lec['training_session_recording_link']?.toString() ?? '';
        if (rec.startsWith('http')) recordingLink = rec;
      }
      if (sessionLink.isEmpty) {
        final vc = info?.virtualClassLink ?? '';
        if (vc.startsWith('http')) sessionLink = vc;
      }
      if (recordingLink.isEmpty) {
        final alt = info?.alternativeLearningEvent ?? '';
        if (alt.isNotEmpty && alt != '0' && alt.startsWith('http')) recordingLink = alt;
      }
      vcFilename = info?.virtualClassFilename?.toString() ?? '';
    }
    final hasVirtualClassInfo =
        sessionLink.isNotEmpty || vcFilename.isNotEmpty || recordingLink.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  color: primary,
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              lessonName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (typeName.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  typeName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                // ── Body ────────────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (objective.isNotEmpty) ...[
                          _sectionLabel('OBJECTIVE'),
                          const SizedBox(height: 6),
                          Text(objective, style: const TextStyle(fontSize: 13)),
                          const Divider(height: 28),
                        ],
                        if (description.isNotEmpty) ...[
                          _sectionLabel('DESCRIPTION'),
                          const SizedBox(height: 6),
                          Text(description, style: const TextStyle(fontSize: 13)),
                          const Divider(height: 28),
                        ],
                        if (hasVirtualClassInfo) ...[
                          _sectionLabel('VIRTUAL CLASS SESSION'),
                          const SizedBox(height: 10),
                          _VirtualClassCard(
                            sessionLink:   sessionLink,
                            platformLabel: platformLabel,
                            filename:      vcFilename,
                            recordingLink: recordingLink,
                          ),
                          const Divider(height: 28),
                        ],
                        if (hasSchedule) ...[
                          _sectionLabel('SCHEDULE'),
                          const SizedBox(height: 10),
                          _ScheduleCard(
                            startDate:    startDate,
                            endDate:      endDate,
                            startTime:    startTime,
                            endTime:      endTime,
                            instructor:   instructor,
                            instructions: instructions,
                            location:     location,
                          ),
                        ],
                        if (!hasVirtualClassInfo && !hasSchedule && objective.isEmpty && description.isEmpty)
                          const Text(
                            'No additional details available.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: Color(0xFF9E9E9E),
      letterSpacing: 0.8,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Virtual Class session card inside Details dialog
// ─────────────────────────────────────────────────────────────────────────────
class _VirtualClassCard extends StatelessWidget {
  const _VirtualClassCard({
    required this.sessionLink,
    required this.platformLabel,
    required this.filename,
    required this.recordingLink,
  });

  final String sessionLink;
  final String platformLabel;
  final String filename;
  final String recordingLink;

  static const _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF9E9E9E),
    letterSpacing: 0.6,
  );
  static const _linkStyle = TextStyle(fontSize: 13, color: Color(0xFF1565C0));
  static const _metaStyle = TextStyle(fontSize: 12, color: Color(0xFF9E9E9E));

  @override
  Widget build(BuildContext context) {
    Widget _divider() => Divider(height: 1, color: Colors.grey.shade200);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SESSION LINK
          if (sessionLink.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SESSION LINK', style: _labelStyle),
                  const SizedBox(height: 6),
                  SelectableText(sessionLink, style: _linkStyle),
                  if (platformLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Platform: $platformLabel', style: _metaStyle),
                  ],
                ],
              ),
            ),
          ],

          // RECORDING LINK
          if (recordingLink.isNotEmpty) ...[
            if (sessionLink.isNotEmpty) _divider(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RECORDING LINK', style: _labelStyle),
                  const SizedBox(height: 6),
                  SelectableText(recordingLink, style: _linkStyle),
                ],
              ),
            ),
          ],

          // ATTACHED FILE
          if (filename.isNotEmpty) ...[
            if (sessionLink.isNotEmpty || recordingLink.isNotEmpty) _divider(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ATTACHED FILE', style: _labelStyle),
                  const SizedBox(height: 4),
                  Text(filename, style: const TextStyle(fontSize: 13, color: Color(0xFF1a1a2e))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedule card inside Details dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.instructor,
    required this.instructions,
    required this.location,
  });

  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;
  final String instructor;
  final String instructions;
  final String location;

  static const _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Color(0xFF9E9E9E),
    letterSpacing: 0.6,
  );
  static const _valueStyle = TextStyle(fontSize: 13, color: Color(0xFF1a1a2e));
  static const _timeStyle  = TextStyle(fontSize: 12, color: Color(0xFF555555));

  @override
  Widget build(BuildContext context) {
    final hasStartEnd    = startDate.isNotEmpty || endDate.isNotEmpty;
    final hasInstructor  = instructor.isNotEmpty;
    final hasInstructions= instructions.isNotEmpty;
    final hasLocation    = location.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Start / End row
          if (hasStartEnd)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('START', style: _labelStyle),
                        const SizedBox(height: 4),
                        if (startDate.isNotEmpty) Text(startDate, style: _valueStyle),
                        if (startTime.isNotEmpty) Text(startTime, style: _timeStyle),
                      ],
                    ),
                  ),
                  if (endDate.isNotEmpty) ...[
                    Container(width: 1, height: 40, color: Colors.grey.shade200),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('END', style: _labelStyle),
                          const SizedBox(height: 4),
                          Text(endDate, style: _valueStyle),
                          if (endTime.isNotEmpty) Text(endTime, style: _timeStyle),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Instructor / Instructions row
          if (hasInstructor || hasInstructions) ...[
            if (hasStartEnd) Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasInstructor)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('INSTRUCTOR', style: _labelStyle),
                          const SizedBox(height: 4),
                          Text(instructor, style: _valueStyle),
                        ],
                      ),
                    ),
                  if (hasInstructions) ...[
                    if (hasInstructor) ...[
                      Container(width: 1, height: 36, color: Colors.grey.shade200),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('INSTRUCTIONS', style: _labelStyle),
                          const SizedBox(height: 4),
                          Text(instructions, style: _valueStyle),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Location row
          if (hasLocation) ...[
            if (hasStartEnd || hasInstructor || hasInstructions)
              Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LOCATION', style: _labelStyle),
                  const SizedBox(height: 4),
                  Text(location, style: _valueStyle),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
