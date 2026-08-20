import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/provider/server_provider.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/model/course_join_detail.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/repository/redirect_login_repository.dart';
import 'package:lms/app/features/courses/view/content_view_page.dart';
import 'package:lms/app/features/courses/view/content_viewer/certificate_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';
import 'package:lms/app/features/courses/view/content_viewer/pdf_content_viewer.dart';
import 'package:lms/app/features/courses/view/content_viewer/video_content_viewer.dart';
import 'package:lms/app/features/courses/view/widgets/class_status_chip.dart';
import 'package:lms/app/features/courses/view/widgets/download_button.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/course_join_detail_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

const _detailPurple = FigmaTokens.primaryPurple;
const _detailPurple2 = FigmaTokens.gradientEnd;
const _detailInk = FigmaTokens.cardTitles;
const _detailMuted = FigmaTokens.noteBodyText;
const _detailBackground = FigmaTokens.pageBackground;

class CourseClassesPage extends ConsumerStatefulWidget {
  const CourseClassesPage({super.key, this.courseId});
  final String? courseId;

  @override
  ConsumerState<CourseClassesPage> createState() => _CourseClassesPageState();
}

class _CourseClassesPageState extends ConsumerState<CourseClassesPage> {
  bool _redirectingUnauthorized = false;

  @override
  Widget build(BuildContext context) {
    final courseId = int.tryParse(widget.courseId ?? '') ?? 0;
    final state = ref.watch(CourseJoinDetailViewModel.provider(courseId));

    if (!_redirectingUnauthorized && isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    return AppScaffold(
      backgroundColor: _detailBackground,
      selectedLabel: 'Course Catalog',
      onBack: () => _goBackToCatalog(context, ref),
      onRefresh: () =>
          ref.read(CourseJoinDetailViewModel.provider(courseId).notifier).fetch(),
      body: _DetailBody(courseId: courseId, state: state),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.courseId, required this.state});

  final int courseId;
  final DataState<CourseJoinDetail> state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(
          child: CircularProgressIndicator(color: _detailPurple),
        );
      case DataProviderState.error:
        if (isUnauthorizedError(state.error)) {
          return const Center(
            child: CircularProgressIndicator(color: _detailPurple),
          );
        }
        return _DetailError(
          message: friendlyErrorMessage(state.error, 'Unable to load course details.'),
          onRetry:
              () =>
                  ref
                      .read(
                        CourseJoinDetailViewModel.provider(courseId).notifier,
                      )
                      .fetch(),
        );
      case DataProviderState.data:
        final detail = state.data;
        if (detail == null) {
          return const _DetailError(message: 'No course detail found.');
        }
        return RefreshIndicator(
          color: _detailPurple,
          onRefresh:
              () =>
                  ref
                      .read(
                        CourseJoinDetailViewModel.provider(courseId).notifier,
                      )
                      .fetch(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 95% of the viewport width, with the remaining 5% split
              // evenly as left/right spacing (via the Center below).
              final maxWidth = constraints.maxWidth * 0.95;
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _CourseHero(detail: detail),
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: _LaunchPanel(detail: detail),
                        ),
                        // Only rendered for enrolled learners, and downloaded
                        // through DownloadButton (encrypted, in-app-only,
                        // never a raw external link) rather than opened via
                        // the system browser/default PDF app.
                        if (detail.participantGuide != null && detail.isEnrolled)
                          _InfoCard(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: DownloadButton(
                                url: detail.participantGuide,
                                label: 'Participant Guide',
                                icon: Icons.picture_as_pdf_rounded,
                                courseClass: null,
                                builder: (ctx, file) => PdfContentViewer(file: file),
                              ),
                            ),
                          ),
                        if (constraints.maxWidth >= 760)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _DescriptionCard(detail: detail)),
                              Expanded(flex: 2, child: _CourseImageCard(url: detail.logo)),
                            ],
                          )
                        else ...[
                          _DescriptionCard(detail: detail),
                          _CourseImageCard(url: detail.logo),
                        ],
                        _SkillsCard(skills: detail.skills),
                        _StructureCard(
                          courseId: detail.id,
                          items: detail.structures,
                          isEnrolled: detail.isEnrolled,
                          courseObjective: detail.objective,
                          courseTitle: detail.title,
                        ),
                        const AppFooter(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

void _goBackToCatalog(BuildContext context, WidgetRef ref) {
  // Belt-and-suspenders: if the catalog already has a search/skill/behavior
  // filter applied, re-fetch it now rather than trusting whatever is
  // already cached in CourseCatalogViewModel.provider - it's a kept-alive
  // provider (see course_catalog_view_model.dart) so this is normally a
  // no-op, but guarantees the filtered results are what's shown instead of
  // whatever got left behind if something else invalidated it while this
  // detail page was open.
  final catalog = ref.read(CourseCatalogViewModel.provider);
  final hasFilter = catalog.search.isNotEmpty ||
      catalog.skillId != null ||
      catalog.behaviorId != null;
  if (hasFilter) {
    ref.read(CourseCatalogViewModel.provider.notifier).fetch();
  }
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  Modular.to.navigate(CoursesModule.construct(CoursesModule.root));
}

class _CourseHero extends StatelessWidget {
  const _CourseHero({required this.detail});
  final CourseJoinDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      padding: const EdgeInsets.fromLTRB(14, 34, 14, 54),
      decoration: const BoxDecoration(color: _detailPurple),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          if (detail.isEnrolled && detail.allowRating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                border: Border.all(color: Colors.white.withValues(alpha: .36)),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Add Rating',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LaunchPanel extends ConsumerStatefulWidget {
  const _LaunchPanel({required this.detail});
  final CourseJoinDetail detail;

  @override
  ConsumerState<_LaunchPanel> createState() => _LaunchPanelState();
}

class _LaunchPanelState extends ConsumerState<_LaunchPanel> {
  Timer? _timer;
  bool _enrolling = false;
  bool _cancelling = false;

  Future<void> _enroll() async {
    // Only show the session-picker dialog for classes that have actual
    // upcoming (not-yet-ended) sessions. If all sessions are past, skip
    // the dialog and enroll directly — classLearningEventSelections
    // auto-selects the latest past session as a fallback.
    final classes = widget.detail.classesWithUpcomingSessions;
    if (classes.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (_) => _MultiClassRegisterDialog(
          courseTitle: widget.detail.title,
          classes: classes,
          onConfirm: _doEnroll,
        ),
      );
    } else {
      await _doEnroll(widget.detail.classLearningEventSelections);
    }
  }

  Future<void> _doEnroll([Map<int, int>? classLearningEvents]) async {
    setState(() => _enrolling = true);
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.detail.id).notifier)
        .enroll(classLearningEvents: classLearningEvents);
    if (!mounted) return;
    setState(() => _enrolling = false);
    if (result.success) {
      Toast.success(context, result.message ?? 'Enrolled successfully.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Unable to enroll in this course.')),
      );
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.detail.id).notifier)
        .cancelRegistration();
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (result.success) {
      Toast.success(context, result.message ?? 'Registration cancelled successfully.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Unable to cancel registration.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Start ticking whenever there's a date to count down to, regardless of
    // enrollment status at mount time - this widget instance is reused (not
    // remounted) when the user enrolls from this same screen, so gating on
    // `isEnrolled` here would freeze the timer forever if it wasn't already
    // true on first build. Visibility of the countdown itself is separately
    // gated by `isEnrolled` in build().
    if (widget.detail.launchDate != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final launchDate = detail.launchDate;
    // Left signed rather than clamped to zero once the target time passes -
    // the session is still open (this is only ever sourced from a still-open,
    // start-through-end session; see nextVirtualClassEvent), so time elapsed
    // since it started is meaningful to show, not just a flat 00:00:00:00.
    Duration? remaining;
    if (launchDate != null) {
      remaining = launchDate.difference(DateTime.now());
    }
    final isPast = (remaining?.isNegative ?? false);
    final remainingAbs = remaining?.abs();

    final hasCountdown = launchDate != null && detail.isEnrolled;
    final countdown = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isPast ? 'STARTED' : 'LAUNCHES IN',
          style: const TextStyle(
            color: _detailMuted,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPast)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Text(
                  '-',
                  style: TextStyle(
                    color: _detailInk,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            _timeEntry(remainingAbs?.inDays ?? 0, 'DAYS'),
            _timeEntry((remainingAbs?.inHours ?? 0) % 24, 'HRS'),
            _timeEntry((remainingAbs?.inMinutes ?? 0) % 60, 'MIN'),
            _timeEntry((remainingAbs?.inSeconds ?? 0) % 60, 'SEC'),
          ],
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EEF7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _InfoCard(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
          // Only show the countdown once the learner is actually enrolled -
          // showing a countdown toward a session they haven't registered
          // for is misleading. On wide screens it sits inline with the
          // primary action button, matching the reference's single header
          // bar instead of stacking them.
          LayoutBuilder(
            builder: (context, constraints) {
              final statusBadge = _statusBadge(detail);
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasCountdown) ...[countdown, const SizedBox(height: 20)],
                    statusBadge,
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: _actionButton()),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasCountdown) countdown,
                  Expanded(child: Center(child: statusBadge)),
                  _actionButton(),
                ],
              );
            },
          ),
          if (detail.learningPath != null) ...[
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F1FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Learning Path: ',
                    style: TextStyle(
                      color: _detailInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F3FF),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      detail.learningPath!,
                      style: const TextStyle(color: _detailPurple),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }

  /// Status pill: a full ring when the course is closed (nothing left to
  /// complete), or the learner's actual completion percentage when it's
  /// still open.
  Widget _statusBadge(CourseJoinDetail detail) {
    final isClosed = detail.launchStatus.toLowerCase().contains('closed');
    final progress = isClosed ? 1.0 : detail.progressPercentage;
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        border: Border.all(color: FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            detail.launchStatus.toUpperCase(),
            style: const TextStyle(
              color: _detailPurple,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: _detailPurple,
                  backgroundColor: Colors.white,
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: _detailPurple,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton() {
    final detail = widget.detail;
    return HoverBuilder(
      builder: (context, hovering) => ElevatedButton.icon(
        onPressed: (_enrolling || _cancelling)
            ? null
            : () {
                if (detail.isEnrolled) {
                  _showCancelConfirmationDialog(context, onConfirm: _cancel);
                } else {
                  _enroll();
                }
              },
        icon: (_enrolling || _cancelling)
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.app_registration_rounded, size: 18),
        label: Text(
          _enrolling
              ? 'Enrolling…'
              : _cancelling
                  ? 'Cancelling…'
                  : detail.primaryAction,
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 47),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor:
              hovering ? FigmaTokens.purpleHover : _detailPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _timeEntry(int value, String label) {
    // Phone: 4 boxes at 5px padding each overflowed the countdown row by
    // 6.1px on a narrow screen; tighten the gap there.
    final hPad = Responsive.isTablet(context) ? 5.0 : 3.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: _TimeBox(value: value, label: label),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.detail});
  final CourseJoinDetail detail;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Course Description'),
          if (detail.description.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              detail.description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _detailMuted,
                height: 1.55,
                fontSize: 16,
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Divider(color: FigmaTokens.cardBorders),
          const SizedBox(height: 16),
          const _SectionTitle('Learning Objectives'),
          if (detail.objective.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              detail.objective,
              style: const TextStyle(
                color: _detailMuted,
                height: 1.55,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseImageCard extends StatelessWidget {
  const _CourseImageCard({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        height: 220,
        child:
            url == null
                ? const _ImageFallback()
                : Image.network(
                  url!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                ),
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.skills});
  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(12, 34, 12, 78),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Skills or Behaviors'),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  skills
                      .map(
                        (skill) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F3FF),
                            border: Border.all(color: FigmaTokens.cardBorders),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              color: _detailPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StructureCard extends StatelessWidget {
  const _StructureCard({
    required this.courseId,
    required this.items,
    required this.isEnrolled,
    required this.courseObjective,
    required this.courseTitle,
  });
  final int courseId;
  final List<CourseStructureItem> items;
  final bool isEnrolled;
  final String courseObjective;
  final String courseTitle;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      padding: items.isEmpty
          ? const EdgeInsets.all(22)
          : const EdgeInsets.fromLTRB(22, 22, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Course Structure'),
          const SizedBox(height: 28),
          if (items.isEmpty)
            const Text(
              'No course structure is available.',
              style: TextStyle(color: _detailMuted),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Full available width - only falls back to a fixed 900px
                // (with horizontal scroll) when the card is narrower than
                // that, e.g. on small screens.
                final tableWidth = constraints.maxWidth;
                final needsScroll = tableWidth < 900;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (needsScroll)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swipe_rounded, size: 14, color: _detailMuted),
                            SizedBox(width: 4),
                            Text(
                              'Swipe to see Next Session, Status & Actions',
                              style: TextStyle(
                                color: _detailMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _StructureTableScroller(
                      width: tableWidth < 900 ? 900 : tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _StructureHeaderRow(),
                          const SizedBox(height: 8),
                          for (var i = 0; i < items.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StructureItemCard(
                                index: i + 1,
                                courseId: courseId,
                                item: items[i],
                                isEnrolled: isEnrolled,
                                courseObjective: courseObjective,
                                courseTitle: courseTitle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Wraps the Course Structure table in a horizontally-scrolling area with
/// an always-visible scrollbar - on a narrow screen the table needs a
/// swipe to reveal Next Session/Status/Action, and without a visible
/// scrollbar that content just looked cut off with no indication more
/// was there.
class _StructureTableScroller extends StatefulWidget {
  const _StructureTableScroller({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  State<_StructureTableScroller> createState() => _StructureTableScrollerState();
}

class _StructureTableScrollerState extends State<_StructureTableScroller> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(width: widget.width, child: widget.child),
      ),
    );
  }
}

class _StructureHeaderRow extends StatelessWidget {
  const _StructureHeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: _detailMuted,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .3,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAF6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 28, child: Text('#', style: style)),
          SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(right: 24),
              child: Text('COURSE DETAILS', style: style),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(right: 24),
              child: Text('NEXT SESSION', style: style),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(right: 24),
              child: Text('STATUS', style: style),
            ),
          ),
          Expanded(flex: 6, child: Text('ACTION', style: style)),
        ],
      ),
    );
  }
}

class _StructureItemCard extends ConsumerStatefulWidget {
  const _StructureItemCard({
    required this.index,
    required this.courseId,
    required this.item,
    required this.isEnrolled,
    required this.courseObjective,
    required this.courseTitle,
  });
  final int index;
  final int courseId;
  final CourseStructureItem item;
  final bool isEnrolled;
  final String courseObjective;
  final String courseTitle;

  @override
  ConsumerState<_StructureItemCard> createState() => _StructureItemCardState();
}

class _StructureItemCardState extends ConsumerState<_StructureItemCard> {
  bool _cancelling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Ticks so "Next Session" and the per-class Register action re-evaluate
    // against the current time without needing a manual refresh - a session
    // that ends while this screen is open should disappear/disable itself
    // live, not just the next time the API is refetched.
    if (widget.item.learningEvents.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelClass() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.courseId).notifier)
        .cancelRegistration(classId: widget.item.classId);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (result.success) {
      Toast.success(context, result.message ?? 'Registration cancelled successfully.');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Unable to cancel registration.')),
      );
    }
  }

  /// Confirms the date/time (matching the website's Register -> Confirm
  /// flow), then registers just this one class/session via
  /// POST lms-screen/register-course in its single-class mode
  /// (class_id + learning_event_class_id) - not the whole-course enroll.
  /// Used by both Virtual Class (typeCode '3') and In Person (typeCode '2')
  /// items - both carry the same learningEvents/session structure.
  Future<void> _registerForSession() async {
    final classId = widget.item.classId;
    if (classId == null) return;
    final event = _earliestUpcomingEvent(widget.item.learningEvents);
    if (event == null) {
      // Every session this class has is already over - registering with no
      // session id just gets rejected by the API ("A session must be
      // selected for this class"), which reads like a bug rather than the
      // simple fact that there's nothing left to register for.
      Toast.error(context, 'No upcoming session is available for this class.');
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => _SessionRegisterDialog(
        courseTitle: widget.courseTitle,
        event: event,
        onConfirm: () => _registerClass(classId, event.learningEventClassId),
      ),
    );
  }

  Future<void> _registerClass(int classId, int? learningEventClassId) async {
    final result = await ref
        .read(CourseJoinDetailViewModel.provider(widget.courseId).notifier)
        .registerClass(classId: classId, learningEventClassId: learningEventClassId);
    if (!mounted) return;
    if (result.success) {
      Toast.success(context, result.message ?? 'Registered successfully.');
    } else {
      Toast.error(context, result.message ?? 'Unable to register.');
    }
  }

  /// Opens the virtual class URL in the in-app WebView, auto-logged in via
  /// redirect-login-link so the learner doesn't see the website login form.
  ///
  /// A class can carry multiple session links (one per learning_event).
  /// Picked fresh at click time - not from a value cached at the last
  /// fetch - so a link that expired while the learner was looking at the
  /// screen doesn't still get sent to redirect-login-link: only a link on
  /// this app's own domain, whose session hasn't ended, and (among those)
  /// the one starting soonest is eligible. If nothing qualifies, this stops
  /// before ever calling redirect-login-link or opening the WebView and
  /// tells the learner why instead.
  Future<void> _attendClass(CourseStructureItem item) async {
    if (!mounted) return;
    final appHost = Uri.parse(ref.read(ServerProvider.serverUrl)).host;
    final event = _selectAttendClassEvent(item.learningEvents, appHost);
    final sessionLink = event?.sessionLink;
    if (sessionLink == null) {
      Toast.error(
        context,
        'No active session link is available for this class right now.',
      );
      return;
    }

    String? loginLink;
    try {
      loginLink = await ref
          .read(RedirectLoginRepository.provider)
          .getLoginLink(sessionLink);
    } catch (e) {
      if (mounted) Toast.error(context, 'Could not get login link: $e');
    }
    if (!mounted) return;
    await InAppWebViewPage.show(
      context,
      url: loginLink ?? sessionLink,
      title: item.title,
    );
  }

  /// Marks this Virtual Class as completed (POST
  /// learning-event/learning-event-completion) when the learner opens its
  /// recording in an external browser - there's no way to track how much
  /// they actually watch there, so open is the only signal available.
  /// Downloading no longer marks it complete on its own; when the
  /// recording is played in the in-app player instead, completion is
  /// driven by actual watch progress (see VideoContentViewer's 30%
  /// threshold) rather than this method.
  void _markRecordingWatched() {
    final classId = widget.item.classId;
    if (classId == null) return;
    ref
        .read(RoasterViewModel.provider(widget.courseId.toString()).notifier)
        .markAsRead(CourseClass(
          courseId: widget.courseId.toString(),
          classId: classId.toString(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isEnrolled = widget.isEnrolled;
    final courseObjective = widget.courseObjective;
    final courseTitle = widget.courseTitle;
    // Recomputed against DateTime.now() on every rebuild (see the ticking
    // _timer above) rather than read from item.nextSession, which is a
    // string baked once at the last fetch - that field only advances when
    // the API is refetched, so it kept showing an already-ended session's
    // date/time until the user manually refreshed.
    //
    // "Next Session" specifically means a session that hasn't started yet -
    // once its start time passes it's no longer "next", so this uses a
    // strictly-future selector rather than the still-open-through-end one
    // Register/Attend use below.
    final upcomingEvent = item.learningEvents.isNotEmpty
        ? _earliestNotYetStartedEvent(item.learningEvents)
        : null;
    final liveNextSession = item.learningEvents.isNotEmpty
        ? (upcomingEvent?.startDateTime != null
            ? _formatFriendlyMoment(upcomingEvent!.startDateTime!)
            : null)
        : (item.nextSession.isNotEmpty ? item.nextSession : null);
    // Registration/attendance stays open for a session's whole duration -
    // from start through end, not just before it starts - matching the
    // website, so this uses the still-open selector rather than
    // upcomingEvent above.
    final liveEvent = item.learningEvents.isNotEmpty
        ? _earliestUpcomingEvent(item.learningEvents)
        : null;
    // A class with learning_events but none still open has nothing left to
    // register for - hide the Register action instead of leaving it
    // clickable only to fail with a toast.
    final hasRegisterableSession =
        item.learningEvents.isEmpty || liveEvent != null;
    // Same set of possible actions as before, just collected into a list so
    // they can be laid out as a compact Wrap in the ACTION column instead of
    // a full-width stacked Column.
    final actions = <Widget>[
      if (item.showDetails)
        OutlinedButton.icon(
          onPressed: () => _showClassDetails(context, courseTitle, courseObjective, item),
          icon: const Icon(Icons.info_rounded, size: 14),
          label: const Text('Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _detailInk,
            side: const BorderSide(color: FigmaTokens.cardBorders),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      // Registered Virtual Class or In Person class: Attend Class
      // (Virtual only, via contentUrl) + optional recordings + Cancel
      if ((item.typeCode == '3' || item.typeCode == '2') && item.isEnrolledInClass) ...[
        // Shown for any enrolled Virtual Class regardless of whether a
        // qualifying session link currently exists - the domain/expiry
        // filtering happens at click time in _attendClass, which tells the
        // learner why via a toast when nothing qualifies, instead of the
        // button just silently disappearing.
        if (item.typeCode == '3')
          _OnlineActionButton(
            icon: Icons.send_rounded,
            label: 'Attend Class',
            onPressed: () => _attendClass(item),
          ),
        // Recordings — Watch (browser) or Download (offline) + play in
        // the in-app player. Watching in the browser has no way to
        // track progress, so that still marks the class completed on
        // open; downloading no longer does - completion for the
        // in-app player instead fires once 30% of the video has
        // actually played (see VideoContentViewer).
        for (final recordingUrl in item.recordingUrls) ...[
          _OnlineActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Watch Recording',
            onPressed: () {
              _openUrl(context, ref, recordingUrl, title: 'Watch Recording');
              _markRecordingWatched();
            },
          ),
          DownloadButton(
            url: recordingUrl,
            label: 'Recording',
            icon: Icons.videocam_rounded,
            courseClass: null,
            builder: (ctx, file) => VideoContentViewer(
              file: file,
              courseId: widget.courseId.toString(),
              classId: item.classId?.toString(),
            ),
          ),
        ],
        _OnlineActionButton(
          icon: Icons.cancel_outlined,
          label: _cancelling ? 'Cancelling…' : 'Cancel Registration',
          onPressed: () => _showCancelConfirmationDialog(context, onConfirm: _cancelClass),
        ),
      ] else if (item.typeCode == '4') ...[
        // Watch Video — the external link (e.g. YouTube, content.
        // watch_video_link) and the actually-uploaded file (content.
        // video_upload_url, handled by the DownloadButton below) are
        // independent - a class can have either, both, or neither.
        if (item.videoLinkUrl != null)
          _OnlineActionButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Watch Video',
            onPressed: () => _openUrl(context, ref, item.videoLinkUrl!, title: item.title),
          ),
      ] else
        // A Virtual Class or In Person class with no live open session left
        // has nothing to register for anymore - hide Register instead of
        // leaving a dead button (see hasRegisterableSession above).
        if (item.showAction &&
            ((item.typeCode != '3' && item.typeCode != '2') || hasRegisterableSession))
          (item.typeCode == '3' || item.typeCode == '2') && isEnrolled
              ? _OnlineActionButton(
                  icon: _actionIcon(item.icon),
                  label: item.actionLabel,
                  onPressed: _registerForSession,
                )
              : _EnrollActionButton(
                  isEnrolled: isEnrolled,
                  icon: _actionIcon(item.icon),
                  label: item.actionLabel,
                  item: item,
                ),
      // downloadUrl is populated straight from the course-structure API
      // response regardless of enrollment, so gate visibility on isEnrolled
      // here too - otherwise non-enrolled learners can see (and use) the
      // Download button for course content.
      if (item.downloadUrl != null && isEnrolled)
        if (item.typeCode == '4')
          DownloadButton(
            url: item.downloadUrl,
            label: _downloadLabel(item.typeCode),
            icon: Icons.videocam_rounded,
            courseClass: null,
            builder: (ctx, file) => VideoContentViewer(
              file: file,
              courseId: widget.courseId.toString(),
              classId: item.classId?.toString(),
            ),
          )
        else
          DownloadButton(
            url: item.downloadUrl,
            label: _downloadLabel(item.typeCode),
            icon: Icons.picture_as_pdf_rounded,
            courseClass: null,
            builder: (ctx, file) => PdfContentViewer(file: file),
          ),
      // Certificate (typeCode '12') has no downloadUrl at all - the API
      // gives back the certificate's raw HTML directly instead of a file
      // URL, so this uses `url` purely as a cache key (the actual save
      // uses rawContent, not a network fetch - see DownloadButton).
      if (item.typeCode == '12' && item.certificateHtml != null && isEnrolled)
        DownloadButton(
          url: 'certificate_class_${item.classId}',
          rawContent: () => utf8.encode(item.certificateHtml!),
          label: 'Certificate',
          icon: Icons.workspace_premium_rounded,
          courseClass: null,
          builder: (ctx, file) => CertificateContentViewer(file: file),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${widget.index}',
              style: const TextStyle(color: _detailMuted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: _detailInk,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(color: Color(0xFF9AA4B5), fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              // Only show a session date once the learner is actually
              // registered for THIS class - showing one for a class they
              // haven't registered for implies a commitment that hasn't
              // been made yet. (isEnrolled is course-level enrollment, not
              // per-class registration - a learner can be enrolled in the
              // course but still unregistered for a given Virtual Class
              // session.)
              child: (liveNextSession != null && item.isEnrolledInClass)
                  // upcomingEvent can be null here even though
                  // liveNextSession isn't - the raw item.nextSession
                  // fallback (classes with no learning_events array) has a
                  // date string but no structured DateTime to count down
                  // to.
                  ? (upcomingEvent != null
                      ? _CompactLaunchCountdown(target: upcomingEvent.startDateTime!)
                      : Text(
                          liveNextSession,
                          style: const TextStyle(color: _detailMuted, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ))
                  : const SizedBox.shrink(),
            ),
          ),
          // Fixed width, not Expanded(flex: 1) - that squeezed down to
          // ~68px within the row's 900px minimum width (shared across 4
          // flex sections), wrapping "Registered"/"Completed" onto two
          // lines. 120px comfortably fits either on one.
          SizedBox(
            width: 120,
            child: item.status.isEmpty
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: item.classId != null
                        ? ClassStatusChip(
                            courseClass: CourseClass(
                              courseId: widget.courseId.toString(),
                              classId: item.classId!.toString(),
                            ),
                            fallbackStatus: item.status,
                          )
                        : _StatusChip(status: item.status),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: actions.isEmpty
                ? const SizedBox.shrink()
                // center, not the default start - Details (an
                // OutlinedButton) and the chip-styled action buttons don't
                // render at quite the same height, so top-aligning them in
                // the Wrap made Details look shifted upward relative to
                // its neighbors.
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  ),
          ),
        ],
      ),
    );
  }
}

/// A compact pill-shaped action button (for the Course Structure table's
/// ACTION column) that disables itself with a "cloud off" state whenever
/// offline, since [onPressed] always performs a network action (opening a
/// link, launching content, etc.).
class _OnlineActionButton extends ConsumerWidget {
  const _OnlineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = _watchIsOnline(ref);
    return HoverBuilder(
      builder: (context, hovering) => SizedBox(
        height: 32,
        child: ElevatedButton.icon(
          onPressed: isOnline ? onPressed : null,
          icon: Icon(isOnline ? icon : Icons.cloud_off_rounded, size: 14),
          label: Text(isOnline ? label : 'Internet required'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: !isOnline
                ? Colors.grey.shade400
                : (hovering ? FigmaTokens.purpleHover : _detailPurple),
            disabledBackgroundColor: Colors.grey.shade400,
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}

/// The generic course-structure action button (e.g. "Agreement", "Launch
/// Web Application"). Unlike [_OnlineActionButton], the not-enrolled path
/// only opens a local dialog, so it stays enabled offline — only the
/// enrolled/network-performing path gets disabled when offline.
class _EnrollActionButton extends ConsumerWidget {
  const _EnrollActionButton({
    required this.isEnrolled,
    required this.icon,
    required this.label,
    required this.item,
  });
  final bool isEnrolled;
  final IconData icon;
  final String label;
  final CourseStructureItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isEnrolled) {
      return HoverBuilder(
        builder: (context, hovering) => SizedBox(
          height: 32,
          child: ElevatedButton.icon(
            onPressed: () => _showNotEnrolledDialog(context),
            icon: Icon(icon, size: 14),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor:
                  hovering ? FigmaTokens.purpleHover : _detailPurple,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      );
    }
    return _OnlineActionButton(
      icon: icon,
      label: label,
      onPressed: () => _handleClassAction(context, ref, item),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 24),
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _detailPurple,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _detailInk,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "LAUNCHES IN" countdown for a single class card - a smaller
/// sibling of _LaunchPanel's course-level countdown, used wherever
/// "Next Session" is shown. Always counts down to a future [target]; the
/// caller only renders this while there's a not-yet-started session to
/// count down to (see upcomingEvent in _StructureItemCardState.build), so
/// unlike the course-level panel this never needs to handle a negative/
/// already-started state - it just gets removed from the tree instead.
/// Compact dash-separated countdown text ("108D - 5H - 30M - 13S") used in
/// the Course Structure table's NEXT SESSION column, instead of
/// [_ClassLaunchCountdown]'s boxed digits.
class _CompactLaunchCountdown extends StatelessWidget {
  const _CompactLaunchCountdown({required this.target});
  final DateTime target;

  @override
  Widget build(BuildContext context) {
    final remaining = target.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox.shrink();
    final text = '${remaining.inDays}D - ${remaining.inHours % 24}H - '
        '${remaining.inMinutes % 60}M - ${remaining.inSeconds % 60}S';
    return Text(
      text,
      style: const TextStyle(
        color: _detailPurple,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}


class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9FF),
        border: Border.all(color: FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: _detailPurple,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _detailMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _detailPurple, size: 78),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _detailMuted, size: 54),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(onRetry: onRetry!, errorMessage: message),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _actionIcon(CourseStructureIcon icon) {
  switch (icon) {
    case CourseStructureIcon.register:       return Icons.how_to_reg_rounded;
    case CourseStructureIcon.video:          return Icons.videocam_rounded;
    case CourseStructureIcon.article:        return Icons.article_rounded;
    case CourseStructureIcon.webpage:        return Icons.language_rounded;
    case CourseStructureIcon.discussionBoard: return Icons.forum_rounded;
    case CourseStructureIcon.tasks:          return Icons.task_alt_rounded;
    case CourseStructureIcon.coaches:        return Icons.people_rounded;
    case CourseStructureIcon.insights:       return Icons.bar_chart_rounded;
    case CourseStructureIcon.certification:  return Icons.workspace_premium_rounded;
    case CourseStructureIcon.discussionGuru: return Icons.chat_rounded;
    case CourseStructureIcon.link:           return Icons.link_rounded;
    case CourseStructureIcon.agreement:      return Icons.edit_rounded;
    case CourseStructureIcon.details:        return Icons.info_rounded;
  }
}

void _handleClassAction(BuildContext context, WidgetRef ref, CourseStructureItem item) {
  final url = item.contentUrl;
  switch (item.typeCode) {
    case '4':
      // Watch Video â€” DownloadButton handles this; action button is hidden for type '4'.
      break;
    case '5': // Read Article
    case '15': // Peer Coaching (PDF)
    case '19': // Agreement (PDF)
      if (url == null) return;
      ContentViewPage.show(
        context: context,
        courseClass: null,
        child: PdfContentViewer(file: FileCacheState(url: url)),
      );
      break;
    default:
      if (url != null) _openUrl(context, ref, url, title: item.title);
  }
}

String _downloadLabel(String typeCode) {
  switch (typeCode) {
    case '4': return 'Video';
    case '5': return 'Article';
    case '15': return 'Guide';
    case '19': return 'Agreement';
    default: return 'File';
  }
}

Future<void> _openUrl(BuildContext context, WidgetRef ref, String url,
    {String? title}) async {
  await InAppWebViewPage.showWithAuth(context, ref, url: url, title: title);
}

// ─── Virtual Class session lookup ──────────────────────────────────────────
//
// The course-level "is there an upcoming Virtual Class session" answer
// lives on CourseJoinDetail.nextVirtualClassEvent (single source of truth
// shared with the LAUNCHES IN countdown). This helper is only for picking
// the earliest upcoming event within one specific structure item's own
// learningEvents list.

LearningEvent? _earliestUpcomingEvent(List<LearningEvent> events) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final start = event.startDateTime;
    if (start == null) continue;
    final end = event.endDateTime;
    // A session stays registerable through its whole duration - from start
    // through end - not just before it starts, matching the website.
    final stillOpen = end == null ? !start.isBefore(now) : now.isBefore(end);
    if (!stillOpen) continue;
    if (earliest == null || start.isBefore(earliest.startDateTime!)) earliest = event;
  }
  return earliest;
}

/// Picks which session Attend Class should open: among this class's
/// learning events, only those whose training_session_link host matches
/// [appHost] (this app's own configured server domain) are eligible at
/// all - any link pointing somewhere else is ignored outright. Of the
/// remaining candidates, an already-ended one (its end time, or start time
/// if it has no end, has passed) is dropped too - there's no fallback to an
/// expired link. Whatever's left, the one starting soonest wins - whether
/// it's already in progress (started but not yet ended) or hasn't started
/// yet. Returns null when nothing qualifies.
LearningEvent? _selectAttendClassEvent(List<LearningEvent> events, String appHost) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final link = event.sessionLink;
    if (link == null) continue;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) continue;
    if (uri.host.toLowerCase() != appHost.toLowerCase()) continue;

    final start = event.startDateTime;
    if (start == null) continue;
    final end = event.endDateTime;
    final stillOpen = end == null ? !start.isBefore(now) : now.isBefore(end);
    if (!stillOpen) continue;

    if (earliest == null || start.isBefore(earliest.startDateTime!)) earliest = event;
  }
  return earliest;
}

/// The earliest event that hasn't started yet - unlike [_earliestUpcomingEvent]
/// (which stays "open" through a session's end for Register/Attend), a
/// session already in progress or finished is no longer "next", so it's
/// excluded here even though it may still be registerable/attendable.
LearningEvent? _earliestNotYetStartedEvent(List<LearningEvent> events) {
  final now = DateTime.now();
  LearningEvent? earliest;
  for (final event in events) {
    final start = event.startDateTime;
    if (start == null || !start.isAfter(now)) continue;
    if (earliest == null || start.isBefore(earliest.startDateTime!)) earliest = event;
  }
  return earliest;
}

// ─── Session Register -> Confirm dialog ────────────────────────────────────
//
// Matches the website's two-step flow: session details + a Register button,
// then a confirm step ("Please confirm the dates and times...") before the
// actual registration call fires.

class _SessionRegisterDialog extends StatefulWidget {
  const _SessionRegisterDialog({
    required this.courseTitle,
    required this.event,
    required this.onConfirm,
  });
  final String courseTitle;
  final LearningEvent event;
  final Future<void> Function() onConfirm;

  @override
  State<_SessionRegisterDialog> createState() => _SessionRegisterDialogState();
}

class _SessionRegisterDialogState extends State<_SessionRegisterDialog> {
  bool _confirming = false;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await widget.onConfirm();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 44),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_detailPurple, _detailPurple2]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.courseTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Positioned(
                    right: -16,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _confirming ? _buildConfirmStep() : _buildDetailsStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sessionCard(),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: HoverBuilder(
            builder: (context, hovering) => ElevatedButton(
              onPressed: () => setState(() => _confirming = true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hovering ? FigmaTokens.purpleHover : _detailPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Please confirm the dates and times for your selections.',
          style: TextStyle(color: _detailInk),
        ),
        const SizedBox(height: 6),
        const Text(
          'You will receive an email with a calendar invitation for each '
          'learning event after confirmation.',
          style: TextStyle(color: _detailMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        _sessionCard(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _submitting ? null : () => setState(() => _confirming = false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _detailInk,
                side: const BorderSide(color: FigmaTokens.cardBorders),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Previous', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            HoverBuilder(
              builder: (context, hovering) => ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hovering ? FigmaTokens.purpleHover : _detailPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sessionCard() {
    final event = widget.event;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sessionField('START', _formatSessionMoment(event.startDateTime)),
              ),
              Expanded(
                child: _sessionField('END', _formatSessionMoment(event.endDateTime)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FigmaTokens.cardBorders),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sessionField(
                  'INSTRUCTOR',
                  event.instructor.isEmpty ? '—' : event.instructor,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        color: _detailMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4EDDA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Available',
                        style: TextStyle(
                          color: Color(0xFF276036),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: _detailInk, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Multi-class Register -> Confirm wizard ────────────────────────────────
//
// Matches the website's step-through flow for whole-course enrollment when
// more than one Virtual/In Person class needs a session picked: one step per
// class (radio-select a session, "Next"), "Register" on the last class's
// step, then a final Confirm step summarizing every selection before the
// actual registration call fires.

class _MultiClassRegisterDialog extends StatefulWidget {
  const _MultiClassRegisterDialog({
    required this.courseTitle,
    required this.classes,
    required this.onConfirm,
  });

  final String courseTitle;
  final List<CourseStructureItem> classes;
  final Future<void> Function(Map<int, int> classLearningEvents) onConfirm;

  @override
  State<_MultiClassRegisterDialog> createState() => _MultiClassRegisterDialogState();
}

class _MultiClassRegisterDialogState extends State<_MultiClassRegisterDialog> {
  late final List<int?> _selectedEventId;
  int _step = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.classes
        .map((item) => _earliestUpcomingEvent(item.learningEvents)?.learningEventClassId)
        .toList();
  }

  bool get _isConfirmStep => _step >= widget.classes.length;

  void _toggleSelection(int index, int? eventId) {
    setState(() {
      _selectedEventId[index] = _selectedEventId[index] == eventId ? null : eventId;
    });
  }

  List<LearningEvent> _upcomingEventsFor(CourseStructureItem item) {
    final now = DateTime.now();
    // A session stays selectable through its whole duration - from start
    // through end, not just before it starts - matching the website.
    final events = item.learningEvents.where((e) {
      final start = e.startDateTime;
      if (start == null) return false;
      final end = e.endDateTime;
      return end == null ? !start.isBefore(now) : now.isBefore(end);
    }).toList();
    events.sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
    return events;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final selections = <int, int>{};
    for (var i = 0; i < widget.classes.length; i++) {
      final classId = widget.classes[i].classId;
      final eventId = _selectedEventId[i];
      if (classId != null && eventId != null) selections[classId] = eventId;
    }
    await widget.onConfirm(selections);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 44),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_detailPurple, _detailPurple2]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.courseTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Positioned(
                    right: -16,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _isConfirmStep ? _buildConfirmStep() : _buildClassStep(_step),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassStep(int index) {
    final item = widget.classes[index];
    final events = _upcomingEventsFor(item);
    final isLastClass = index == widget.classes.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.title,
          style: const TextStyle(color: _detailInk, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          events.isEmpty
              ? 'Select a session'
              : 'Select a session, or tap it again to skip this class',
          style: const TextStyle(color: _detailMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          _sessionCardFor(null)
        else
          // Always shown as a radio - even with a single session - so the
          // learner explicitly confirms their pick, matching the reference
          // design rather than silently auto-selecting the only option.
          // Tapping the already-selected session deselects it - a class
          // left unselected is simply left out of the registration.
          ...events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _toggleSelection(index, event.learningEventClassId),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<int?>(
                      value: event.learningEventClassId,
                      groupValue: _selectedEventId[index],
                      toggleable: true,
                      onChanged: (value) => setState(() => _selectedEventId[index] = value),
                      activeColor: _detailPurple,
                    ),
                    Expanded(child: _sessionCardFor(event)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: HoverBuilder(
            builder: (context, hovering) => ElevatedButton(
              onPressed: () => setState(() => _step = index + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    hovering ? FigmaTokens.purpleHover : _detailPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                isLastClass ? 'Register' : 'Next',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Please confirm the dates and times for your selections.',
          style: TextStyle(color: _detailInk),
        ),
        const SizedBox(height: 6),
        const Text(
          'You will receive an email with a calendar invitation for each '
          'learning event after confirmation.',
          style: TextStyle(color: _detailMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < widget.classes.length; i++) ...[
          Text(
            widget.classes[i].title,
            style: const TextStyle(color: _detailInk, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _selectedEventId[i] == null
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: FigmaTokens.cardBorders),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Skipped - this class will not be registered.',
                    style: TextStyle(color: _detailMuted),
                  ),
                )
              : _sessionCardFor(_selectedEventFor(i)),
          if (i != widget.classes.length - 1) const SizedBox(height: 16),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _step = widget.classes.length - 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: _detailInk,
                side: const BorderSide(color: FigmaTokens.cardBorders),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Previous', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            HoverBuilder(
              builder: (context, hovering) => ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hovering ? FigmaTokens.purpleHover : _detailPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  LearningEvent? _selectedEventFor(int index) {
    final id = _selectedEventId[index];
    if (id == null) return null;
    for (final event in widget.classes[index].learningEvents) {
      if (event.learningEventClassId == id) return event;
    }
    return null;
  }

  Widget _sessionCardFor(LearningEvent? event) {
    if (event == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: FigmaTokens.cardBorders),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'No upcoming session available.',
          style: TextStyle(color: _detailMuted),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _sessionField('START', _formatSessionMoment(event.startDateTime))),
              Expanded(child: _sessionField('END', _formatSessionMoment(event.endDateTime))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: FigmaTokens.cardBorders),
          const SizedBox(height: 12),
          _sessionField('INSTRUCTOR', event.instructor.isEmpty ? '—' : event.instructor),
        ],
      ),
    );
  }

  Widget _sessionField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: _detailInk, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

String _formatSessionMoment(DateTime? dt) {
  if (dt == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]}-${dt.day.toString().padLeft(2, '0')}-${dt.year}\n'
      '$hour12:$minute $ampm';
}

void _showNotEnrolledDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      content: const Text(
        'You are not enrolled for this course. Click the Enroll Now button at the top of this page to continue.',
        style: TextStyle(color: _detailMuted, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: _detailPurple),
          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void _showCancelConfirmationDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Confirm Cancellation',
        style: TextStyle(
          color: _detailInk,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      content: const Text(
        'Would you like to cancel your registration for this course?',
        style: TextStyle(color: _detailMuted, height: 1.5),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _detailInk,
            side: const BorderSide(color: FigmaTokens.cardBorders),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: const Text(
            'No, Keep It',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        HoverBuilder(
          builder: (context, hovering) => ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  hovering ? FigmaTokens.purpleHover : _detailPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );
}

void _showClassDetails(
  BuildContext context,
  String courseTitle,
  String courseObjective,
  CourseStructureItem item,
) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(20),
      child: _ClassDetailsDialog(
        courseTitle: courseTitle,
        courseObjective: courseObjective,
        item: item,
      ),
    ),
  );
}

class _ClassDetailsDialog extends StatelessWidget {
  const _ClassDetailsDialog({
    required this.courseTitle,
    required this.courseObjective,
    required this.item,
  });

  final String courseTitle;
  final String courseObjective;
  final CourseStructureItem item;

  @override
  Widget build(BuildContext context) {
    final typeName = item.subtitle.length > 2
        ? item.subtitle.substring(1, item.subtitle.length - 1)
        : '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 540),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: const BoxDecoration(
              color: _detailPurple,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    courseTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (typeName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .35),
                      ),
                    ),
                    child: Text(
                      typeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (courseObjective.isNotEmpty) ...[
                    const _DialogLabel('OBJECTIVE'),
                    const SizedBox(height: 8),
                    Text(
                      courseObjective,
                      style: const TextStyle(color: _detailMuted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: FigmaTokens.cardBorders),
                    const SizedBox(height: 16),
                  ],
                  if (item.description.isNotEmpty) ...[
                    const _DialogLabel('DESCRIPTION'),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: const TextStyle(color: _detailMuted, height: 1.5),
                    ),
                  ],
                  if (item.learningEvents.isNotEmpty) ...[
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(color: FigmaTokens.cardBorders),
                      const SizedBox(height: 16),
                    ],
                    const _DialogLabel('SCHEDULE'),
                    const SizedBox(height: 12),
                    for (final event in item.learningEvents)
                      _LearningEventCard(event: event),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _detailMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _LearningEventCard extends StatelessWidget {
  const _LearningEventCard({required this.event});
  final LearningEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScheduleField(
                  label: 'START',
                  value: _formatEventMoment(event.startDateTime, event.startTime),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ScheduleField(
                  label: 'END',
                  value: _formatEventMoment(event.endDateTime, event.endTime),
                ),
              ),
            ],
          ),
          if (event.instructor.isNotEmpty || event.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: FigmaTokens.cardBorders),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.instructor.isNotEmpty)
                  Expanded(
                    child: _ScheduleField(
                      label: 'INSTRUCTOR',
                      value: event.instructor,
                    ),
                  ),
                if (event.instructor.isNotEmpty && event.location.isNotEmpty)
                  const SizedBox(width: 16),
                if (event.location.isNotEmpty)
                  Expanded(
                    child: _ScheduleField(
                      label: 'LOCATION',
                      value: event.location,
                    ),
                  ),
              ],
            ),
          ],
          if (event.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: FigmaTokens.cardBorders),
            const SizedBox(height: 12),
            _ScheduleField(label: 'INSTRUCTIONS', value: event.instructions),
          ],
        ],
      ),
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _detailMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? 'â€”' : value,
          style: const TextStyle(
            color: _detailInk,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final isCompleted = status.toLowerCase() == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE8F5E9) : const Color(0xFFEEECFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          color: isCompleted ? const Color(0xFF2E7D32) : _detailPurple,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Formats an already timezone-corrected DateTime (LearningEvent.startDateTime
// / endDateTime, which convert the API's UTC values to local time - see
// course_join_detail.dart's _combineDateAndTime) rather than reparsing the
// raw date/time strings naively. Reparsing them here directly used to skip
// that UTC->local conversion, so this schedule display drifted out of sync
// with the website by exactly the device's UTC offset (5:30 on an IST
// device) even though the register/countdown flow elsewhere was correct.
String _formatEventMoment(DateTime? dateTime, String rawTime) {
  if (dateTime == null) return _formatTime(rawTime);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final month = months[dateTime.month - 1];
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$month ${dateTime.day}\n$hour12:$minute $amPm';
}

// "02 Aug 2026 03:40 PM" - used for the "Next Session" line, which (unlike
// _formatEventMoment's compact two-line schedule-card format) needs the
// full date on one line since it's read out of context of a specific card.
String _formatFriendlyMoment(DateTime dateTime) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = months[dateTime.month - 1];
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final hour12 = (hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour))
      .toString()
      .padLeft(2, '0');
  return '$day $month ${dateTime.year} $hour12:$minute $amPm';
}

String _formatTime(String time) {
  if (time.isEmpty) return '';
  final parts = time.split(':');
  if (parts.length < 2) return time;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = parts[1].padLeft(2, '0');
  final amPm = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$hour12:$minute $amPm';
}

