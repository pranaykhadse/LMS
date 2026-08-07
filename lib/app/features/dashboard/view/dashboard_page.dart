import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _BannerSection(auth: auth),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                    child: Text(
                      "Welcome back! Here's what's happening with your courses.",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF4A5565),
                        fontSize: 15.2,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: _StatRow(
                      isWide: isWide,
                      enrolled: data.summary.enrolledCourses,
                      required: data.summary.requiredCourses,
                      completed: data.summary.completedCourses,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
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
                              const SizedBox(height: 16),
                              _UpcomingSessionsCard(sessions: data.upcomingSessions),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
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
                              const SizedBox(height: 16),
                              _OverallProgressCard(
                                overallProgress: data.summary.overallProgress,
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
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
                                  child: _RewardsPointsCard(rewards: data.extras.rewards),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              _DiscussionBoardsCard(boards: data.extras.discussionBoards),
                              const SizedBox(height: 16),
                              _RewardsPointsCard(rewards: data.extras.rewards),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        gradient: FigmaTokens.heroGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${_greeting()}, ${_userName()}!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '"A leader is best when people barely know he exists; '
            'when his work is done, his aim fulfilled, '
            'they will all say: We did it ourselves."',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '— Lao-Tzu',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: FigmaTokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: GoogleFonts.inter(
              color: _ink,
              fontSize: 35.2,
              fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(12),
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
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

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
              color: large ? const Color(0xFF1E2939) : const Color(0xFF6A7282),
              fontSize: large ? 16.8 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: large ? 0 : .3,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(
                color: _purple,
                fontSize: 13.6,
                fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Continue Learning',
            actionLabel: widget.courses.isEmpty ? null : 'View All',
            onAction: widget.courses.isEmpty
                ? null
                : () => Modular.to.pushNamed(
                      CoursesModule.construct(CoursesModule.myCourses),
                    ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          if (widget.courses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No courses in progress.', style: TextStyle(color: _muted)),
            )
          else ...[
            SizedBox(
              height: 190,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: widget.courses.length,
                itemBuilder: (context, i) =>
                    _ContinueLearningItem(course: widget.courses[i]),
              ),
            ),
            if (widget.courses.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.courses.length, (i) {
                  return GestureDetector(
                    onTap: () {
                      // A manual jump counts as user intent - restart the
                      // auto-advance clock from here instead of firing
                      // mid-interaction.
                      _startAutoAdvance();
                      _controller.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 48 : 21,
                        height: 21,
                        decoration: BoxDecoration(
                          color: i == _index ? _purple : _border,
                          borderRadius: BorderRadius.circular(10.5),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ContinueLearningItem extends ConsumerWidget {
  const _ContinueLearningItem({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled = isViewCourseDisabled(ref, course.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 190,
            height: 210,
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
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              if (course.progress > 0)
                Text(
                  '${course.progress}% complete',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              if (course.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  course.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.35),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _BrandButton(
                  label: 'Resume',
                  onPressed: viewDisabled
                      ? null
                      : () => Modular.to.pushNamed(
                            CoursesModule.construct(
                              '${CoursesModule.detail}/${course.id}',
                            ),
                          ),
                  borderRadius: 8,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Upcoming Sessions ────────────────────────────────────────────────────────

/// Adapts an UpcomingSession into a CalendarEvent so _SessionRow (shared
/// with the Calendar screen's own styling) can render it unchanged.
CalendarEvent? _toCalendarEvent(UpcomingSession session) {
  final rawDate = session.startDate;
  if (rawDate == null) return null;
  final startDate = DateTime.tryParse(rawDate);
  if (startDate == null) return null;
  // Matches CalendarEvent.fromJson's own parsing exactly (raw date parse,
  // no .toLocal() here) - CalendarEvent.startDateTime's _combine getter is
  // what applies the UTC->local conversion, using this startDate + startTime
  // together. Converting here too would double-apply the offset.
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

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: 'Upcoming Sessions', large: true),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No upcoming sessions.', style: TextStyle(color: _muted)),
            )
          else ...[
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
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
                        color: Color(0xFF6A7282),
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final weekday = weekdays[dt.weekday - 1];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$weekday, $month ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      event.courseName.isNotEmpty ? event.courseName : event.title,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 15.2,
                      ),
                    ),
                    if (event.className.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FigmaTokens.badgeBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.className,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF6A7282)),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(event.startDateTime),
                      style: GoogleFonts.inter(color: const Color(0xFF6A7282), fontSize: 12.48),
                    ),
                  ],
                ),
                if (event.instructor != null && event.instructor!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hosted by ',
                          style: GoogleFonts.inter(color: const Color(0xFF6A7282), fontSize: 12.48),
                        ),
                        TextSpan(
                          text: event.instructor,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.48,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _BrandButton(
            label: 'Join',
            onPressed: () => Modular.to.pushNamed(
              CoursesModule.construct('${CoursesModule.detail}/${event.courseId}'),
            ),
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            textStyle: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.8,
            ),
          ),
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
    final shown = courses.take(4).toList();
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Course Progress',
            large: true,
            actionLabel: shown.isEmpty ? null : 'View All',
            onAction: shown.isEmpty
                ? null
                : () => Modular.to.pushNamed(
                      CoursesModule.construct(CoursesModule.enrolledCourses),
                    ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No enrolled courses yet.', style: TextStyle(color: _muted)),
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
            const Icon(Icons.menu_book_rounded, size: 15, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1E2939),
                  fontSize: 14.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${course.progress}%',
              style: GoogleFonts.inter(
                color: const Color(0xFF6A7282),
                fontSize: 14.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: const Color(0xFFE8E7F8),
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

  /// Straight from the API's summary.overall_progress now, rather than
  /// averaged client-side from whatever courses happened to be loaded on
  /// this screen - more accurate, and matches what the server considers
  /// authoritative.
  final int overallProgress;

  @override
  Widget build(BuildContext context) {
    final overall = overallProgress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: FigmaTokens.heroGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_border_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'OVERALL LEARNING PROGRESS',
                style: GoogleFonts.inter(
                  color: const Color(0xE6FFFFFF),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$overall%',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: overall / 100,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Discussion Boards ──────────────────────────────────────────────────────

// No discussion-thread API/model exists in the app yet (see class_info.dart's
// discussionForumLink/discussionGuruLink - those are just external webview
// links on a course lesson, not a threads-with-replies feature), so this
// always renders the empty state per the reference's p.empty-state styling.
class _DiscussionBoardsCard extends StatelessWidget {
  const _DiscussionBoardsCard({required this.boards});
  final List<DashboardDiscussionBoardItem> boards;

  @override
  Widget build(BuildContext context) {
    final shown = boards.take(4).toList();
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: 'Discussion Boards', large: true),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No discussion threads yet.',
                style: GoogleFonts.inter(color: const Color(0xFF6A7282), fontSize: 13.6),
              ),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 24, color: _border),
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
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (item.lastRepliedBy.isNotEmpty) item.lastRepliedBy,
                  if (item.lastReply.isNotEmpty) item.lastReply,
                  '${item.replyCount} ${item.replyCount == 1 ? 'reply' : 'replies'}',
                ].join(' • '),
                style: GoogleFonts.inter(color: const Color(0xFF6A7282), fontSize: 11.2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: () => Modular.to.pushNamed(
            CoursesModule.construct('${CoursesModule.detail}/${item.courseId}'),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _purple,
            side: const BorderSide(color: _purple),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.12),
          ),
          child: const Text('View'),
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

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: 'Rewards & Points',
            large: true,
            actionLabel: 'This Month',
            onAction: () => Modular.to.pushNamed(
              CoursesModule.construct(CoursesModule.redeemPoints),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
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
                        color: const Color(0xFF1E2939),
                        fontSize: 15.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've earned points by completing courses and attending virtual classes.",
                      style: GoogleFonts.inter(color: const Color(0xFF6A7282), fontSize: 13.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activity.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No reward points earned this month yet.',
                style: GoogleFonts.inter(color: const Color(0xFF6A7282), fontSize: 13.6),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in activity)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.label,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF1E293B),
                                fontSize: 13.6,
                              ),
                            ),
                          ),
                          Text(
                            '+${a.points} pts',
                            style: GoogleFonts.inter(
                              color: _purple,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.6,
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
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: 'Required For You', large: true),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No required courses.', style: TextStyle(color: _muted)),
            )
          else ...[
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 22, color: _border),
              _RequiredRow(index: i + 1, item: shown[i]),
            ],
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton(
                onPressed: () => Modular.to.pushNamed(
                  CoursesModule.construct(CoursesModule.requiredCourses),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14.4),
                ),
                child: const Text('View All Required Courses'),
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
        SizedBox(
          width: 22,
          child: Text(
            '$index',
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 14.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            item.courseName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF1E2939),
              fontSize: 14.72,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (item.progressLabel != null) ...[
          Text(
            item.progressLabel!,
            style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12.8),
          ),
          const SizedBox(width: 10),
        ],
        OutlinedButton(
          onPressed: viewDisabled
              ? null
              : () => Modular.to.pushNamed(
                    CoursesModule.construct('${CoursesModule.detail}/$courseId'),
                  ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _purple,
            side: const BorderSide(color: _purple),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.12),
          ),
          child: const Text('View'),
        ),
      ],
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
