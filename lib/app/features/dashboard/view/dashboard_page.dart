import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/courses/model/calendar_event.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/model/learning_progress_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_progress_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _border = FigmaTokens.cardBorders;

bool _anyCourse(Course course) => true;

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _redirectingUnauthorized = false;

  void _refetchAll() {
    ref.read(LearningProgressViewModel.provider.notifier).fetch();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(AuthStateNotifier.provider);

    // Dashboard's own fetch has no offline fallback (it always needs live
    // data - banner, resources, etc.), so it used to fail outright with a
    // generic error screen whenever the manual Offline Mode toggle was on,
    // even for a course the learner had explicitly saved for offline
    // access. Show the offline-saved courses instead of ever attempting -
    // and failing - that live fetch.
    if (isEffectivelyOffline(ref)) {
      return AppScaffold(
        backgroundColor: _bg,
        title: 'Dashboard',
        selectedLabel: 'Dashboard',
        hideBack: true,
        body: const OfflineCoursesSection(
          matches: _anyCourse,
          emptyMessage:
              'No offline courses found.\nConnect to the internet and save a course first.',
        ),
      );
    }

    final state = ref.watch(LearningProgressViewModel.provider);

    if (!_redirectingUnauthorized &&
        state.state == DataProviderState.error &&
        isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Dashboard',
      selectedLabel: 'Dashboard',
      hideBack: true,
      onRefresh: _refetchAll,
      body: _redirectingUnauthorized
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _DashboardBody(auth: auth, state: state, onRefetchAll: _refetchAll),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.auth,
    required this.state,
    required this.onRefetchAll,
  });
  final AuthState? auth;
  final DataState<LearningProgressData> state;
  final VoidCallback onRefetchAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: state.error ?? 'Unable to load dashboard.',
          onRetry: onRefetchAll,
        );
      case DataProviderState.data:
        final data = state.data;
        if (data == null) {
          return const _ErrorView(message: 'No dashboard data found.');
        }

        return RefreshIndicator(
          color: _purple,
          onRefresh: () async => onRefetchAll(),
          child: Builder(
            builder: (context) {
              final isWide = Responsive.isDesktop(context);
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _BannerSection(auth: auth),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                    child: _StatRow(
                      isWide: isWide,
                      enrolled: data.summary.enrolledCourses,
                      required: data.summary.requiredCourses,
                      completed: data.summary.completedCourses,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: isWide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _ContinueLearningCard(
                                    courses: _continueLearningCourses(data),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _UpcomingSessionsCard(
                                    sessions: data.upcomingSessions,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _ContinueLearningCard(
                                courses: _continueLearningCourses(data),
                              ),
                              const SizedBox(height: 12),
                              _UpcomingSessionsCard(sessions: data.upcomingSessions),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: isWide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _CourseProgressCard(
                                    courses: _progressCourses(data),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _OverallProgressCard(
                                    overallProgress: data.summary.overallProgress,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _CourseProgressCard(courses: _progressCourses(data)),
                              const SizedBox(height: 12),
                              _OverallProgressCard(
                                overallProgress: data.summary.overallProgress,
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: isWide
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _DiscussionBoardsCard(
                                    boards: data.extras.discussionBoards,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _RewardsPointsCard(
                                    rewards: data.extras.rewards,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _DiscussionBoardsCard(
                                  boards: data.extras.discussionBoards),
                              const SizedBox(height: 12),
                              _RewardsPointsCard(
                                  rewards: data.extras.rewards),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    child: _RequiredForYouCard(required: data.requiredForYou),
                  ),
                  const AppFooter(),
                ],
              );
            },
          ),
        );
    }
  }
}

// ─── Adapters ─────────────────────────────────────────────────────────────────
//
// The learning-progress endpoint's "dashboard.continue_learning" entries
// carry description/logo/class info but no numeric progress of their own -
// cross-referenced against progress_status (keyed by course_id) below,
// since that's the only place the API actually reports it.

List<DashboardCourse> _continueLearningCourses(LearningProgressData data) {
  final progressByCourseId = {
    for (final p in data.progressStatus) p.courseId: p.progress,
  };
  return data.extras.continueLearning
      .map(
        (item) => DashboardCourse(
          id: int.tryParse(item.courseId) ?? 0,
          name: item.courseName,
          logo: item.logoLink,
          progress: progressByCourseId[item.courseId] ?? 0,
          displayRating: false,
          averageRating: 0,
          ratingCount: 0,
          description: item.description.isNotEmpty ? item.description : null,
          category: item.className.isNotEmpty ? item.className : null,
          dueDate: item.formattedDueDate,
        ),
      )
      .toList();
}

List<DashboardCourse> _progressCourses(LearningProgressData data) {
  return data.progressStatus
      .map(
        (item) => DashboardCourse(
          id: int.tryParse(item.courseId) ?? 0,
          name: item.courseName,
          logo: null,
          progress: item.progress,
          displayRating: false,
          averageRating: 0,
          ratingCount: 0,
        ),
      )
      .toList();
}

// ─── Banner ───────────────────────────────────────────────────────────────────

class _BannerSection extends StatelessWidget {
  const _BannerSection({required this.auth});
  final AuthState? auth;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  String _userName() {
    final p = auth?.userProfile;
    final first = p?.firstname?.trim() ?? '';
    final last = p?.lastname?.trim() ?? '';
    final name = [first, last].where((s) => s.isNotEmpty).join(' ');
    return name.isNotEmpty ? name : auth?.user?.username ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Figma: width Fill, height 160px, radius 14px
      height: 160,
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login-bg.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FigmaTokens.primaryPurple.withValues(alpha: 0.85),
                  FigmaTokens.gradientEnd.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          // Figma content: padding top 16 / right 12 / bottom 8 / left 12
          // vertical flow, gap 8px between text children
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Greeting: Inter 500, 16px, line-height 20px, ls -0.75
                Text(
                  'Good ${_greeting()}, ${_userName()}!',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 20 / 16,
                    letterSpacing: -0.75,
                  ),
                ),
                const SizedBox(height: 8),
                // Quote body: Inter 400, 11px, line-height 18px
                Text(
                  'A leader is best when people barely know he exists...when his '
                  'work is done, his aim fulfilled, they will all say: We did it ourselves."',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 18 / 11,
                  ),
                ),
                const SizedBox(height: 8),
                // Attribution: Inter 500, 12px, line-height 20px, ls 0.35
                Text(
                  '- Lao-Tzu',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 20 / 12,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat cards ───────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.isWide,
    required this.enrolled,
    required this.required,
    required this.completed,
  });
  final bool isWide;
  final int enrolled;
  final int required;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book_rounded,
            iconColor: _purple,
            label: 'ENROLLED',
            value: enrolled,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.error_outline_rounded,
            iconColor: const Color(0xFFD97706),
            label: 'REQUIRED',
            value: required,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF16A34A),
            label: 'COMPLETED',
            value: completed,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    // Design ref: bg-white rounded-lg border border-gray-200 px-5 py-4
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF), // gray-400
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    height: 18 / 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: const Color(0xFF1F2937), // gray-800
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared card chrome ─────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  const _DashCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FigmaTokens.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.large = false,
    this.trailing,
    this.actionLabelStyle,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Per-card override for the "View All" text style - cards measured so
  /// far don't share one spec (Continue Learning is 16px/24px, Course
  /// Progress is 12px/16px), so default to the former and let callers
  /// override.
  final TextStyle? actionLabelStyle;

  /// h4.section-title-main (16.8px, #1E2939, title case) instead of the
  /// default h4.section-title-sm (12px, #6A7282, uppercase) - the
  /// reference site uses the larger style for Upcoming Virtual Classes.
  final bool large;

  /// Optional trailing control (e.g. the Upcoming Sessions expand/collapse
  /// chevron) shown after the actionLabel, if any.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            large ? title : title.toUpperCase(),
            style: GoogleFonts.inter(
              color: large ? const Color(0xFF364153) : const Color(0xFF6A7282),
              fontSize: large ? 16 : 12,
              fontWeight: large ? FontWeight.w600 : FontWeight.w700,
              letterSpacing: large ? 0 : .3,
              height: large ? 24 / 16 : null,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: actionLabelStyle ??
                    GoogleFonts.inter(
                      color: _purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                    ),
              ),
            ),
          ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── Continue Learning ────────────────────────────────────────────────────────

class _ContinueLearningCard extends StatefulWidget {
  const _ContinueLearningCard({required this.courses});
  final List<DashboardCourse> courses;

  @override
  State<_ContinueLearningCard> createState() => _ContinueLearningCardState();
}

class _ContinueLearningCardState extends State<_ContinueLearningCard> {
  final _controller = PageController();
  int _index = 0;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void didUpdateWidget(_ContinueLearningCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courses.length != widget.courses.length) {
      _startAutoAdvance();
    }
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (widget.courses.length <= 1) return;
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.courses.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool _isOverdue(DashboardCourse course) {
    if (course.dueDate == null) return false;
    final parsed = DateTime.tryParse(course.dueDate!);
    if (parsed == null) return false;
    return parsed.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.courses.isEmpty ? null : widget.courses[_index];
    final overdue = current != null && _isOverdue(current);
    final accentColor = overdue ? const Color(0xFFDC2626) : _purple;
    final borderColor = overdue ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB);
    final headerBg = overdue ? const Color(0xFFFEF2F2) : Colors.white;
    final headerBorder = overdue ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: headerBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'CONTINUE LEARNING',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (overdue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'OVERDUE',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.courses.isNotEmpty)
                  GestureDetector(
                    onTap: () => Modular.to.pushNamed(
                      CoursesModule.construct(CoursesModule.inProgressCourses),
                    ),
                    child: Text(
                      'View All',
                      style: GoogleFonts.inter(
                        color: _purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Course card (PageView) ───────────────────────────────────
          if (widget.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No courses in progress.',
                style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else
            SizedBox(
              // Thumbnail 144px wide; content needs ~220px for title +
              // description + due date + Resume button comfortably.
              height: 220,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.courses.length,
                itemBuilder: (context, i) => _ContinueLearningItem(
                  course: widget.courses[i],
                  accentColor: accentColor,
                ),
              ),
            ),

          // ── Dot indicators ───────────────────────────────────────────
          if (widget.courses.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.courses.length, (i) {
                  final dotOverdue = _isOverdue(widget.courses[i]);
                  final dotColor = dotOverdue
                      ? const Color(0xFFEF4444)
                      : _purple;
                  return GestureDetector(
                    onTap: () {
                      _startAutoAdvance();
                      _controller.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index ? dotColor : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinueLearningItem extends ConsumerWidget {
  const _ContinueLearningItem({
    required this.course,
    required this.accentColor,
  });
  final DashboardCourse course;
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled = isViewCourseDisabled(ref, course.id);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Thumbnail (left) ───────────────────────────────────────────
        SizedBox(
          width: 144,
          child: Stack(
            fit: StackFit.expand,
            children: [
              course.logo != null
                  ? Image.network(
                      course.logo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImgFallback(),
                    )
                  : const _ImgFallback(),
              Positioned(
                top: 4,
                left: 4,
                child: OfflineCourseButton(
                  course: Course(
                    id: course.id,
                    name: course.name,
                    logoLink: course.logo,
                    averageRating: course.averageRating,
                    ratingCount: course.ratingCount,
                    displayRating: course.displayRating ? 1 : 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Text content (right) ──────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category label
                if (course.category != null)
                  Text(
                    course.category!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 2),

                // Course title
                Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1F2937),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),

                // Description
                if (course.description != null) ...[
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      course.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),

                // Due date
                if (course.dueDate != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        '${accentColor == const Color(0xFFDC2626) ? "Overdue: " : "Due: "}${course.dueDate}',
                        style: GoogleFonts.inter(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),

                // Resume button
                _BrandButton(
                  label: 'Resume Lesson →',
                  onPressed: viewDisabled
                      ? null
                      : () => Modular.to.pushNamed(
                            CoursesModule.construct(
                              '${CoursesModule.detail}/${course.id}',
                            ),
                          ),
                  borderRadius: 6,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  textStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Upcoming Sessions ────────────────────────────────────────────────────────

CalendarEvent? _toCalendarEvent(UpcomingSession session) {
  final rawDate = session.startDate;
  if (rawDate == null) return null;
  final startDate = DateTime.tryParse(rawDate);
  if (startDate == null) return null;
  return CalendarEvent(
    courseId: int.tryParse(session.courseId) ?? 0,
    courseName: session.courseName,
    classId: int.tryParse(session.classId) ?? 0,
    className: '',
    learningEventClassId: int.tryParse(session.classId) ?? 0,
    title: session.courseName,
    startDate: startDate,
    startTime: session.startTime,
    endTime: session.endTime,
    registrationStatus: '',
    description: '',
    instructor: session.instructor,
  );
}

class _UpcomingSessionsCard extends StatefulWidget {
  const _UpcomingSessionsCard({required this.sessions});
  final List<UpcomingSession> sessions;

  @override
  State<_UpcomingSessionsCard> createState() => _UpcomingSessionsCardState();
}

class _UpcomingSessionsCardState extends State<_UpcomingSessionsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = widget.sessions
        .map(_toCalendarEvent)
        .whereType<CalendarEvent>()
        .where((e) => e.startDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    final shown = upcoming.take(8).toList();
    const collapsedCount = 3;
    final visible = _expanded ? shown : shown.take(collapsedCount).toList();
    final hasMore = shown.length > collapsedCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — "Upcoming Sessions" plain title, no action
          Text(
            'Upcoming Sessions',
            style: GoogleFonts.inter(
              color: const Color(0xFF374151), // gray-700
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No upcoming sessions.',
                style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else ...[
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _SessionRow(event: visible[i]),
            ],
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.event});
  final CalendarEvent event;

  String _formatDate(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    return '$weekday, $month ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    // Design ref: rounded-lg border border-gray-100 bg-gray-50 p-3
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // gray-50
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)), // gray-100
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Join button row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.courseName.isNotEmpty ? event.courseName : event.title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Join button with live pulse dot
              GestureDetector(
                onTap: () => Modular.to.pushNamed(
                  CoursesModule.construct(
                      '${CoursesModule.detail}/${event.courseId}'),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _purple,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulse dot (static red dot — Flutter has no CSS
                      // animate-pulse; a simple dot conveys the same intent)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF87171), // red-400
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Join',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Date • time
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 10, color: _purple),
              const SizedBox(width: 4),
              Text(
                _formatDate(event.startDateTime),
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              if (event.startTime != null && event.startTime!.isNotEmpty) ...[
                Text(
                  ' • ',
                  style: GoogleFonts.inter(
                      color: const Color(0xFFD1D5DB), fontSize: 12),
                ),
                Text(
                  _formatTime(event.startDateTime),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
          // Hosted by
          if (event.instructor != null && event.instructor!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: 'Hosted by ',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF9CA3AF), fontSize: 12),
                ),
                TextSpan(
                  text: event.instructor,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Course Progress ────────────────────────────────────────────────────────

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.courses});
  final List<DashboardCourse> courses;

  @override
  Widget build(BuildContext context) {
    final shown = courses.take(2).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Course Progress',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF374151), // gray-700
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (shown.isNotEmpty)
                GestureDetector(
                  onTap: () => Modular.to.pushNamed(
                    CoursesModule.construct(CoursesModule.allCourseProgress),
                  ),
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      color: _purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No enrolled courses yet.',
                style: GoogleFonts.inter(
                    color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _CourseProgressRow(course: shown[i]),
            ],
        ],
      ),
    );
  }
}

class _CourseProgressRow extends StatelessWidget {
  const _CourseProgressRow({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context) {
    final pct = (course.progress.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // BookOpen icon matching design ref
            const Icon(Icons.menu_book_rounded, size: 13, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF4B5563), // gray-600
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${course.progress}%',
              style: GoogleFonts.inter(
                color: const Color(0xFF9CA3AF), // gray-400
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Design ref: h-1.5 rounded-full bg-gray-100 → fill bg-[#5b5bd6]
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: const AlwaysStoppedAnimation<Color>(_purple),
          ),
        ),
      ],
    );
  }
}

// ─── Overall Learning Progress ────────────────────────────────────────────────

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.overallProgress});
  final int overallProgress;

  @override
  Widget build(BuildContext context) {
    // Design ref: gradient from #5865f2 → #7c3aed, rounded-xl p-5
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF5865F2), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row: star icon + "OVERALL LEARNING PROGRESS"
          Row(
            children: [
              const Icon(Icons.star_border_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Text(
                'OVERALL LEARNING PROGRESS',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Big percentage number
          Text(
            '$overallProgress%',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar: white semi-transparent track + fill
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: overallProgress / 100,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Discussion Boards ──────────────────────────────────────────────────────

class _DiscussionBoardsCard extends StatelessWidget {
  const _DiscussionBoardsCard({required this.boards});
  final List<DashboardDiscussionBoardItem> boards;

  @override
  Widget build(BuildContext context) {
    final shown = boards.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Discussion Boards',
            style: GoogleFonts.inter(
              color: const Color(0xFF374151),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No discussion threads yet.',
                style: GoogleFonts.inter(
                    color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 24, color: Color(0xFFE5E7EB)),
              _DiscussionBoardRow(item: shown[i]),
            ],
        ],
      ),
    );
  }
}

class _DiscussionBoardRow extends StatelessWidget {
  const _DiscussionBoardRow({required this.item});
  final DashboardDiscussionBoardItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1F2937),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (item.lastRepliedBy.isNotEmpty) item.lastRepliedBy,
                  if (item.lastReply.isNotEmpty) item.lastReply,
                  '${item.replyCount} ${item.replyCount == 1 ? 'reply' : 'replies'}',
                ].join(' • '),
                style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _ViewButton(
          onPressed: () => Modular.to.pushNamed(
            CoursesModule.construct(
                '${CoursesModule.detail}/${item.courseId}'),
          ),
        ),
      ],
    );
  }
}

// ─── Rewards & Points ───────────────────────────────────────────────────────

class _RewardsPointsCard extends ConsumerWidget {
  const _RewardsPointsCard({required this.rewards});
  final DashboardRewards? rewards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final points = rewards?.totalPoints ?? profile?.points ?? 0;
    final firstName = profile?.firstname?.trim();
    final activity = rewards?.activity ?? const <DashboardRewardActivity>[];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + "This Month" action
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rewards & Points',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF374151),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Modular.to.pushNamed(
                  CoursesModule.construct(CoursesModule.redeemPoints),
                ),
                child: Text(
                  'This Month',
                  style: GoogleFonts.inter(
                    color: _purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),

          // Points circle + name/description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: _purple,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$points',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      'pts',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Great progress${firstName != null && firstName.isNotEmpty ? ', $firstName' : ''}!',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1F2937),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've earned points by completing courses and attending virtual classes.",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Activity list or empty state
          if (activity.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No reward points earned this month yet.',
                style: GoogleFonts.inter(
                    color: const Color(0xFF6B7280), fontSize: 13),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in activity)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.label,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF1F2937),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '+${a.points} pts',
                            style: GoogleFonts.inter(
                              color: _purple,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Required For You ────────────────────────────────────────────────────────

class _RequiredForYouCard extends StatelessWidget {
  const _RequiredForYouCard({required this.required});
  final List<RequiredCourseItem> required;

  @override
  Widget build(BuildContext context) {
    final shown = required.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required For You',
            style: GoogleFonts.inter(
              color: const Color(0xFF374151),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No required courses.',
                style: GoogleFonts.inter(
                    color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else ...[
            // Numbered list with dividers
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _RequiredRow(index: i + 1, item: shown[i]),
              ),
            ],
            const SizedBox(height: 20),
            // "View All Required Courses" centered purple button
            Center(
              child: _BrandButton(
                label: 'View All Required Courses',
                onPressed: () => Modular.to.pushNamed(
                  CoursesModule.construct(CoursesModule.requiredCourses),
                ),
                borderRadius: 6,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                textStyle: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequiredRow extends ConsumerWidget {
  const _RequiredRow({required this.index, required this.item});
  final int index;
  final RequiredCourseItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseId = int.tryParse(item.courseId) ?? 0;
    final viewDisabled = isViewCourseDisabled(ref, courseId);
    return Row(
      children: [
        // Number
        SizedBox(
          width: 20,
          child: Text(
            '$index',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Course name
        Expanded(
          child: Text(
            item.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF374151),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // View button — outlined purple, fills on hover
        _ViewButton(
          onPressed: viewDisabled
              ? null
              : () => Modular.to.pushNamed(
                    CoursesModule.construct(
                        '${CoursesModule.detail}/$courseId'),
                  ),
        ),
      ],
    );
  }
}

// Outlined purple "View" button — fills solid on hover, matching design ref:
// border border-[#5b5bd6] text-[#5b5bd6] hover:bg-[#5b5bd6] hover:text-white
class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) {
        final filled = hovering && onPressed != null;
        const borderRadius = BorderRadius.all(Radius.circular(4));
        return Material(
          color: filled ? _purple : Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _purple),
                borderRadius: borderRadius,
              ),
              child: Text(
                'View',
                style: GoogleFonts.inter(
                  color: filled ? Colors.white : _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
// ─── Brand-colored button with an explicit hover state ─────────────────────
//
// ElevatedButton's built-in hover handling is driven by InkResponse
// internally, and didn't reliably repaint the background color when tested
// on macOS desktop - tracking hover state directly with a MouseRegion
// guarantees the swap between primaryPurple and purpleHover actually shows.

class _BrandButton extends StatefulWidget {
  const _BrandButton({
    required this.label,
    required this.onPressed,
    required this.borderRadius,
    required this.padding,
    required this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;

  @override
  State<_BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<_BrandButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: !enabled
            ? _purple.withOpacity(0.5)
            : _hovering
                ? FigmaTokens.purpleHover
                : _purple,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          onTap: widget.onPressed,
          child: Padding(
            padding: widget.padding,
            child: Text(
              widget.label,
              style: widget.textStyle,
              textAlign: TextAlign.center,
              // Without this, the explicit line-height on these styles
              // puts all the extra leading above the glyphs instead of
              // splitting it evenly, so the text sits visibly above
              // vertical-center inside a container that hugs it tightly.
              textHeightBehavior: const TextHeightBehavior(
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Image fallback ───────────────────────────────────────────────────────────

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FigmaTokens.badgeBackground,
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _purple, size: 40),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _muted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
