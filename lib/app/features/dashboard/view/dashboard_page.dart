import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_progress_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/mentor_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/supervisor_view_model.dart';
import 'package:lms/app/features/dashboard/model/mentor_modal.dart';
import 'package:lms/app/features/dashboard/repository/mentor_repository.dart';
import 'package:lms/app/core/views/elements/toast.dart';

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

  // Guards the supervisor/mentor flow to run exactly once per State
  // lifetime. Set true immediately in initState (not after the flow
  // finishes) - it previously lived in a build()-scoped post-frame
  // callback guarded only at the very end, so every setState during the
  // flow (each dialog open/close) re-registered a fresh callback and
  // spawned a duplicate, concurrent copy of the whole flow.
  bool _supervisorMentorFlowStarted = false;

  bool _showSupervisorInline = false;
  bool _showMentorInline = false;
  MentorModalData? _supData;
  MentorModalData? _mentData;
  Completer<void>? _supervisorCompleter;
  Completer<void>? _mentorCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _runSupervisorMentorFlow());
  }

  /// Fetches supervisor then mentor data, and shows each one's confirm
  /// overlay in turn - supervisor first, then mentor - skipping any whose
  /// should_show is false.
  Future<void> _runSupervisorMentorFlow() async {
    if (_supervisorMentorFlowStarted || !mounted) return;
    _supervisorMentorFlowStarted = true;

    try {
      await ref.read(SupervisorViewModel.provider.notifier).fetchIfNeeded();
      await ref.read(MentorViewModel.provider.notifier).fetchIfNeeded();
      if (!mounted) return;

      final supData = ref.read(SupervisorViewModel.provider).data;
      final mentData = ref.read(MentorViewModel.provider).data;
      setState(() {
        _supData = supData;
        _mentData = mentData;
      });

      final showSupervisor = supData != null && supData.shouldShow;
      final showMentor = mentData != null && mentData.shouldShow;

      if (showSupervisor) {
        _supervisorCompleter = Completer<void>();
        setState(() => _showSupervisorInline = true);
        await _supervisorCompleter!.future;
      }
      if (!mounted) return;

      // When both modals are due, pause 2s between the supervisor modal
      // closing and the mentor one opening instead of chaining them
      // instantly - gives the confirm toast a moment to be seen.
      if (showSupervisor && showMentor) {
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }

      if (showMentor) {
        _mentorCompleter = Completer<void>();
        setState(() => _showMentorInline = true);
        await _mentorCompleter!.future;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DashboardPage] supervisor/mentor flow error: $e');
      }
    }
  }

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

    // Reminders for learning events starting soon - checked against
    // whatever upcoming-sessions data Dashboard already has loaded (there's
    // no background/push infrastructure to check this while the app isn't
    // open, so "soon" only ever gets (re-)evaluated on a Dashboard visit or
    // refresh). Deferred to a post-frame callback since it writes to
    // another provider (NotificationsViewModel) - not safe to do mid-build.
    // Safe to call every build: _checkLearningEventReminders is idempotent
    // per session (see NotificationsViewModel.hasRemindedSession).
    final upcomingSessions = state.data?.upcomingSessions;
    if (upcomingSessions != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkLearningEventReminders(upcomingSessions);
      });
    }

    if (!_redirectingUnauthorized &&
        state.state == DataProviderState.error &&
        isUnauthorizedError(state.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    // Wrap scaffold in a Stack so we can render inline overlays above the page when needed.
    return Stack(
      children: [
        AppScaffold(
          backgroundColor: _bg,
          title: 'Dashboard',
          selectedLabel: 'Dashboard',
          hideBack: true,
          onRefresh: _refetchAll,
          body: _redirectingUnauthorized
              ? const Center(child: CircularProgressIndicator(color: _purple))
              : DashboardBody(auth: auth, state: state, onRefetchAll: _refetchAll),
        ),
        // Supervisor/mentor confirm overlays, shown in sequence by
        // _runSupervisorMentorFlow - each completer's completion is what
        // lets that async flow advance to the next step.
        if (_showSupervisorInline && _supData != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(color: const Color(0xFF693D94).withOpacity(0.06)),
                    ),
                  ),
                  Center(
                    child: _InlineConfirmDialog(
                      // Explicit key so this never gets mistaken for the
                      // mentor dialog below and has its State reused across
                      // them - see the mentor one's key comment.
                      key: const ValueKey('supervisor-confirm-dialog'),
                      data: _supData!,
                      title: 'Confirm Your Supervisor',
                      type: 'supervisor',
                      onConfirmed: () {
                        if (kDebugMode) debugPrint('[DashboardPage] supervisor onConfirmed');
                        setState(() => _showSupervisorInline = false);
                        if (_supervisorCompleter?.isCompleted == false) {
                          _supervisorCompleter!.complete();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_showMentorInline && _mentData != null)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(color: const Color(0xFF693D94).withOpacity(0.06)),
                    ),
                  ),
                  Center(
                    child: _InlineConfirmDialog(
                      // Without a distinct key from the supervisor dialog
                      // above, Flutter can reconcile them as "the same
                      // widget updated" (same runtimeType, same Stack slot)
                      // once the supervisor overlay closes and the mentor
                      // one opens - reusing the old State object instead of
                      // creating a fresh one. That left _submitting stuck
                      // at true from the supervisor confirm, permanently
                      // disabling the mentor dialog's Confirm button.
                      key: const ValueKey('mentor-confirm-dialog'),
                      data: _mentData!,
                      title: 'Confirm Your Mentor',
                      type: 'mentor',
                      onConfirmed: () {
                        if (kDebugMode) debugPrint('[DashboardPage] mentor onConfirmed');
                        setState(() => _showMentorInline = false);
                        if (_mentorCompleter?.isCompleted == false) {
                          _mentorCompleter!.complete();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // A session "starting soon" gets a reminder once it's within this window
  // of its start time (and hasn't already started).
  static const _reminderWindow = Duration(hours: 24);

  void _checkLearningEventReminders(List<UpcomingSession> sessions) {
    final notifier = ref.read(NotificationsViewModel.provider.notifier);
    final now = DateTime.now();
    for (final session in sessions) {
      final start = session.startDateTime;
      if (start == null) continue;
      final remaining = start.difference(now);
      if (remaining.isNegative || remaining > _reminderWindow) continue;

      final sessionKey = '${session.courseId}-${session.classId}';
      if (notifier.hasRemindedSession(sessionKey)) continue;
      notifier.markSessionReminded(sessionKey);

      notifier.addLocal(
        NotificationItem(
          id: 'reminder-$sessionKey',
          title: 'Upcoming Session',
          message:
              "'${session.courseName}' starts ${_relativeTime(remaining)}.",
          type: 'reminder',
          isRead: false,
          createdAt: now,
        ),
      );
    }
  }

  String _relativeTime(Duration remaining) {
    if (remaining.inHours < 1) {
      final minutes = remaining.inMinutes;
      return 'in $minutes minute${minutes == 1 ? '' : 's'}';
    }
    final hours = remaining.inHours;
    return 'in $hours hour${hours == 1 ? '' : 's'}';
  }
}

// ─── Body (also used by LearningProgressPage) ─────────────────────────────────

class DashboardBody extends ConsumerWidget {
  const DashboardBody({
    super.key,
    required this.auth,
    required this.state,
    required this.onRefetchAll,
    this.showBanner = true,
  });
  final AuthState? auth;
  final DataState<LearningProgressData> state;
  final VoidCallback onRefetchAll;
  /// When false the gradient hero banner is omitted — used by
  /// LearningProgressPage which shares this body but has its own AppBar.
  final bool showBanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(state.error, 'Unable to load dashboard.'),
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
              // Design ref: px-3 sm:px-6 (outer) / space-y-4 sm:space-y-5 (gaps)
              final outerH = Responsive.isTablet(context) ? 24.0 : 12.0;
              final gapV = Responsive.isTablet(context) ? 20.0 : 16.0;
              // Design ref: the whole section list sits in a single
              // px-3 sm:px-6 py-4 sm:py-6 space-y-4 sm:space-y-5 wrapper -
              // py-6/py-4 is this wrapper's OWN top/bottom padding
              // (applies once, before the first child), separate from the
              // smaller space-y-5/4 gap between children.
              final containerV = Responsive.isTablet(context) ? 24.0 : 16.0;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (showBanner) _BannerSection(auth: auth),
                  // Design ref: <p className="hidden sm:block ..."> - shown
                  // at the sm breakpoint (isTablet), not lg (isWide/
                  // isDesktop) - and as the first child in the wrapper, its
                  // top spacing is the wrapper's own py-6/py-4 (containerV),
                  // not the smaller space-y-5/4 gap (gapV) used between
                  // later siblings.
                  Padding(
                      padding: EdgeInsets.fromLTRB(outerH, containerV, outerH, 0),
                      child: Text(
                        "Welcome back! Here's what's happening with your courses.",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF826A72),
                          fontSize: Responsive.isTablet(context) ? 16 : 13,
                          height: 24 / 16,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(outerH, gapV, outerH, 0),
                    child: _StatRow(
                      isWide: isWide,
                      enrolled: data.summary.enrolledCourses,
                      required: data.summary.requiredCourses,
                      completed: data.summary.completedCourses,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(outerH, gapV, outerH, 0),
                    // Continue Learning has its own fixed height (matching
                    // the reference's h-[200px] content area) - not
                    // CrossAxisAlignment.stretch, which was forcing it to
                    // grow/shrink to match however many sessions Upcoming
                    // Sessions happened to have that load, making its image
                    // and content visibly resize between page loads.
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                    padding: EdgeInsets.fromLTRB(outerH, gapV, outerH, 0),
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
                    padding: EdgeInsets.fromLTRB(outerH, gapV, outerH, 0),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(
                                  child: _RewardsPointsCard(
                                    rewards: data.extras.rewards,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _DiscussionBoardsCard(
                                    boards: data.extras.discussionBoards,
                                  ),
                                ),
                              ],
                            )
                        : Column(
                            children: [
                              _RewardsPointsCard(
                                  rewards: data.extras.rewards),
                              const SizedBox(height: 16),
                              _DiscussionBoardsCard(
                                  boards: data.extras.discussionBoards),
                            ],
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(outerH, gapV, outerH, gapV),
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
          dueDateRaw: item.dueDateTime,
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
    // Design ref: h-[160px] sm:h-[220px] lg:h-[276px]
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);
    final height = isDesktop ? 276.0 : (isTablet ? 220.0 : 160.0);
    // Design ref: px-3 sm:px-6 pt-4 pb-2 (outer wrapper, not inner padding)
    final outerH = isTablet ? 24.0 : 12.0;
    // Design ref: px-5 sm:px-10 (inner content padding)
    final innerH = isTablet ? 40.0 : 20.0;
    final greetingSize = isDesktop ? 22.0 : (isTablet ? 18.0 : 16.0);
    final quoteSize = isDesktop ? 16.0 : (isTablet ? 13.0 : 11.0);
    final attributionSize = isDesktop ? 14.0 : 12.0;

    return Container(
      width: double.infinity,
      height: height,
      // Design ref: rounded-xl (12px)
      margin: EdgeInsets.fromLTRB(outerH, 16, outerH, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/dashboard-hero.jpg', fit: BoxFit.cover),
          // Design ref: solid #693D94 tint at 82% opacity (not a two-tone
          // gradient - both linear-gradient stops are the same color).
          Container(
            color: FigmaTokens.primaryPurple.withValues(alpha: 0.82),
          ),
          // Design ref: absolute inset-0 flex items-center px-5 sm:px-10 -
          // content is vertically centered within the banner, not
          // top-anchored.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: innerH),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 578),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Greeting
                    Text(
                      'Good ${_greeting()}, ${_userName()}!',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: greetingSize,
                        height: 36 / 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.75,
                      ),
                    ),
                    // Design ref: greeting -> gap-8 -> (quote -> gap-4 -> attribution)
                    SizedBox(height: isTablet ? 7 : 8),
                    // Quote body
                    Text(
                      'A leader is best when people barely know he exists...when his '
                      'work is done, his aim fulfilled, they will all say: We did it ourselves."',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: quoteSize,
                        fontWeight: FontWeight.w400,
                        height: 22 / 16,
                      ),
                    ),
                    SizedBox(height: isTablet ? 14 : 4),
                    // Attribution
                    Text(
                      '- Lao-Tzu',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: attributionSize,
                        height: 20 / 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
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
            // Design ref: <BookOpen size={13} className="text-[#693D94]" />
            icon: LucideIcons.bookOpen,
            iconColor: _purple,
            label: 'ENROLLED',
            value: enrolled,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: LucideIcons.alertCircle,
            iconColor: const Color(0xFFFD9A02),
            label: 'REQUIRED',
            value: required,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: LucideIcons.checkCircle,
            iconColor: const Color(0xFF00C950),
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
    final isTablet = Responsive.isTablet(context);
    // Design ref (>=700px): bg-white rounded-lg border border-gray-200 px-5 py-4
    // Design ref (phone): padding 16/12/16/12, radius 10, label 10px
    // uppercase #99A1AF, value 30px bold #1E2939.
    return Container(
      padding: isTablet
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
          : const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                    color: isTablet ? const Color(0xFFAF99A1) : const Color(0xFF99A1AF),
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: isTablet ? 0.6 : 0.5,
                    height: isTablet ? 18 / 12 : 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _AnimatedCounter(
            value: value,
            style: GoogleFonts.inter(
              color: isTablet ? const Color(0xFF391E29) : const Color(0xFF1E2939),
              fontSize: isTablet ? 36 : 30,
              // Design ref: font-semibold (600) on tablet/desktop, bold
              // (700) on phone per the mobile spec.
              fontWeight: isTablet ? FontWeight.w600 : FontWeight.w700,
              height: isTablet ? 40 / 36 : 1.2,
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
  bool _hovering = false;

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
      // Pause auto-advance while the user is hovering over the card.
      if (!mounted || !_controller.hasClients || _hovering) return;
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
    // dueDate is a display string ("August 1, 2026") - not re-parseable.
    // dueDateRaw is the actual DateTime it was derived from.
    final due = course.dueDateRaw;
    if (due == null) return false;
    return due.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.courses.isEmpty ? null : widget.courses[_index];
    final overdue = current != null && _isOverdue(current);
    final accentColor = overdue ? const Color(0xFFDC2626) : _purple;
    // Header background and outer card border stay their normal, non-red
    // colors regardless of overdue status - only the accent (button, dots,
    // due-date text) turns red for an overdue course, matching the
    // reference design.
    const borderColor = Color(0xFFE5E7EB);
    const headerBg = Colors.white;
    final headerBorder = overdue ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6);

    final isTablet = Responsive.isTablet(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
      // Design ref: header (pt-4 pb-3 + 24px text line-height) 52 +
      // content h-[200px] + dots row (py-3 + 6px dot) 30 = 282 - matches
      // the measured rendered row height (284.8, ~3px of font-metrics
      // rounding) closer than the earlier 290px guess.
      // Design ref (phone): the whole card is Fill(239.24) - phone's
      // content has no thumbnail so it needs far less height. Bumped to
      // 242 - 239 overflowed by 2px in the rendered app (font-metrics
      // rounding, same as the desktop 284 above).
      height: isTablet ? 286 : 242,
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
          // Design ref: flex items-center justify-between px-5 pt-4 pb-3
          // border-b border-gray-100 - text-base font-semibold
          // text-gray-500 uppercase / text-xs font-semibold text-[#693D94]
          Container(
            padding: EdgeInsets.fromLTRB(20, isTablet ? 18 : 16, 20, 12),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: headerBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'CONTINUE LEARNING',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF826A72),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      // Design ref: text-base default line-height = 24px
                      height: 24 / 16,
                    ),
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
                        // Design ref (phone): 16px, line-height 24
                        fontSize: isTablet ? 12 : 16,
                        fontWeight: FontWeight.w600,
                        height: isTablet ? 16 / 12 : 24 / 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Course card (PageView) fills remaining space ─────────────
          if (widget.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No courses in progress.',
                style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else
            Expanded(
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
              // Design ref: flex items-center justify-center gap-1.5 py-3
              // (no border)
              padding: const EdgeInsets.symmetric(vertical: 12),
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
    ), // Container
    ); // MouseRegion
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

    // Design ref: the row layout below is "hidden sm:flex" - phone gets
    // its own simpler card instead (no thumbnail, full-width Resume).
    if (!Responsive.isTablet(context)) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (course.category != null) ...[
              Text(
                course.category!.toUpperCase(),
                style: GoogleFonts.inter(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  height: 18 / 12,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              course.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF1E2939),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 22 / 16,
              ),
            ),
            if (course.dueDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(LucideIcons.calendarDays, size: 10, color: accentColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${accentColor == const Color(0xFFDC2626) ? "Overdue: " : "Due: "}${course.dueDate}',
                      style: GoogleFonts.inter(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 18 / 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
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
                color: accentColor,
                hoverColor: accentColor == const Color(0xFFDC2626)
                    ? const Color(0xFFB91C1C)
                    : FigmaTokens.purpleHover,
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 18 / 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Design ref: hidden sm:flex gap-0 h-[200px]; image div
    // flex-shrink-0 style="padding: 0 0 0 18px", w-36 (144px) h-full
    // rounded-xl; text div flex flex-1 items-center p-4
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Thumbnail (left, fills full card height) ───────────────────
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: SizedBox(
            width: 144,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
        ),

        // ── Text content (right) ──────────────────────────────────────
        // Design ref: flex flex-1 items-center p-4 - the content block is
        // vertically centered within the row's full height, but stays
        // Content starts at the top of the row instead of being vertically
        // centered - explicit user preference, overriding the reference's
        // own items-center.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category label
                if (course.category != null)
                  Text(
                    course.category!.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: accentColor,
                      fontSize: 13,
                      height: 19.5 / 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.325,
                    ),
                  ),
                const SizedBox(height: 2),

                // Course title
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF391E29),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 22 / 16,
                  ),
                ),

                // Description (2 lines max)
                if (course.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    course.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFAF99A1),
                      fontSize: 16,
                      // Design ref: leading-relaxed = 1.625
                      height: 1.625,
                    ),
                  ),
                ],

                // Due date — Design ref: mb-2 (8px) below the description
                if (course.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Design ref: <CalendarDays size={10} />
                      Icon(LucideIcons.calendarDays,
                          size: 10, color: accentColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${accentColor == const Color(0xFFDC2626) ? "Overdue: " : "Due: "}${course.dueDate}',
                          style: GoogleFonts.inter(
                            color: accentColor,
                            fontSize: 16,
                            height: 24 / 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Resume button — Design ref: px-4 py-2 rounded-[20px]
                // text-base font-medium; bg matches the overdue accent
                // color (red) or purple otherwise, same as the due-date
                // text/icon above.
                _BrandButton(
                  label: 'Resume',
                  onPressed: viewDisabled
                      ? null
                      : () => Modular.to.pushNamed(
                            CoursesModule.construct(
                              '${CoursesModule.detail}/${course.id}',
                            ),
                          ),
                  color: accentColor,
                  hoverColor: accentColor == const Color(0xFFDC2626)
                      ? const Color(0xFFB91C1C) // red-700 hover
                      : FigmaTokens.purpleHover,
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              ),
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
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Keep UpcomingSession alongside its CalendarEvent so virtualClassNumber
    // can be passed to _SessionRow without routing through CalendarEvent.
    final upcomingPairs = widget.sessions
        .map((s) => (session: s, event: _toCalendarEvent(s)))
        .where((p) => p.event != null)
        .where((p) => p.event!.startDateTime.isAfter(now))
        .toList()
      ..sort((a, b) =>
          a.event!.startDateTime.compareTo(b.event!.startDateTime));
    const collapsedCount = 2;
    final visible = upcomingPairs.take(collapsedCount).toList();
    final isTablet = Responsive.isTablet(context);

    return Container(
      // Design ref (phone): the two cards stack instead of sitting side by
      // side, so there's no need to match Continue Learning's fixed height.
      // Bumped 284 -> 286: the exact line-heights added to the row's
      // due-date/hosted-by text (matching live inspection) render a couple
      // px taller than the earlier estimate, overflowing the old value.
      height: isTablet ? 286 : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — "Upcoming Virtual Classes" plain title, no action
          Text(
            'Upcoming Virtual Classes',
            style: GoogleFonts.inter(
              color: const Color(0xFF533641),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No upcoming sessions.',
                style: GoogleFonts.inter(color: const Color(0xFF6B7280), fontSize: 14),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _SessionRow(
                event: visible[i].event!,
                virtualClassNumber: visible[i].session.virtualClassNumber,
              ),
            ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.event, this.virtualClassNumber});
  final CalendarEvent event;
  final int? virtualClassNumber;

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

  void _openSession(BuildContext context) => Modular.to.pushNamed(
        CoursesModule.construct('${CoursesModule.detail}/${event.courseId}'),
      );

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final titleText = Text(
      event.courseName.isNotEmpty ? event.courseName : event.title,
      style: GoogleFonts.inter(
        color: isTablet ? const Color(0xFF391E29) : const Color(0xFF1E2939),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
      ),
    );

    // "Virtual Class N" badge — shown only when virtualClassNumber is set
    // Treat 0 and negative values as not-present to avoid showing an empty/invalid
    // badge; ensure we convert to string safely.
    final int? _vcNum = virtualClassNumber;
    final bool _showBadge = _vcNum != null && _vcNum > 0;

    final badge = _showBadge
        ? Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Virtual Class ${_vcNum.toString()}',
              style: GoogleFonts.inter(
                color: _purple,
                fontSize: 11,
                height: 15.125 / 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : null;

    final title = _showBadge
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(child: titleText),
              badge!,
            ],
          )
        : titleText;
    final dateRow = Row(
      children: [
        const Icon(LucideIcons.calendarDays, size: 10, color: _purple),
        const SizedBox(width: 6),
        Text(
          _formatDate(event.startDateTime),
          style: GoogleFonts.inter(
            color: const Color(0xFF9CA3AF),
            fontSize: 12,
            height: 18 / 12,
          ),
        ),
        if (event.startTime != null && event.startTime!.isNotEmpty) ...[
          Text(
            ' • ',
            style: GoogleFonts.inter(color: const Color(0xFFDCD1D5), fontSize: 12, height: 18 / 12),
          ),
          Text(
            _formatTime(event.startDateTime),
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 12,
              height: 18 / 12,
            ),
          ),
        ],
      ],
    );
    final hostedBy = event.instructor != null && event.instructor!.isNotEmpty
        ? Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'Hosted by ',
                style: GoogleFonts.inter(color: const Color(0xFFAF99A1), fontSize: 12, height: 18 / 12),
              ),
              TextSpan(
                text: event.instructor,
                style: GoogleFonts.inter(
                  color: const Color(0xFF654A55),
                  fontSize: 12,
                  height: 18 / 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          )
        : null;

    // Design ref: rounded-lg border border-gray-100 bg-gray-50 p-3
    // hover:border-[#693D94]/30 hover:bg-[#693D94]/5
    return HoverBuilder(
      builder: (context, hovering) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hovering
            ? _purple.withValues(alpha: 0.05)
            : const Color(0xFFFBF9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hovering
              ? _purple.withValues(alpha: 0.3)
              : const Color(0xFFF3F4F6), // gray-100
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isTablet
            ? [
                // Title + Join button row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    // Design ref: px-2.5 py-1 rounded-xl, no dot/icon at all -
                    // just the "Join" label (44.75x26 measured, matching plain
                    // text at this padding - a pulse dot was inflating the width
                    // beyond spec and isn't in the reference).
                    GestureDetector(
                      onTap: () => _openSession(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _purple,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Join',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            height: 18 / 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                dateRow,
                if (hostedBy != null) ...[const SizedBox(height: 2), hostedBy],
              ]
            : [
                title,
                const SizedBox(height: 6),
                dateRow,
                if (hostedBy != null) ...[const SizedBox(height: 2), hostedBy],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => _openSession(context),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Join',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 18 / 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
      ),
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
    final isTablet = Responsive.isTablet(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                    color: const Color(0xFF533641),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
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
                      height: 16 / 12,
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
            // Design ref: space-y-8 (32px)
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 32),
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
            // Design ref: <BookOpen size={13} />
            const Icon(LucideIcons.bookOpen, size: 13, color: _purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF1A1A2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 24 / 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _AnimatedCounter(
              value: course.progress,
              suffix: '%',
              style: GoogleFonts.inter(
                color: const Color(0xFFAF99A1),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 24 / 16,
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
            backgroundColor: const Color(0xFFF6F3F4),
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
    final isTablet = Responsive.isTablet(context);
    // Design ref (>=700px): linear-gradient(to right, #693d94, #aa399f),
    // rounded-xl p-5. Design ref (phone): padding 12, radius 14, label
    // 12px/0.3 letter-spacing, percentage 30px, gaps 8/8 instead of 12/16.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [FigmaTokens.primaryPurple, FigmaTokens.gradientEnd],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row: star icon + "OVERALL LEARNING PROGRESS"
          Row(
            children: [
              // Design ref: <Star size={14} className="text-white opacity-90" />
              Icon(LucideIcons.star,
                  color: Colors.white.withValues(alpha: 0.9), size: 14),
              const SizedBox(width: 8),
              Text(
                'OVERALL LEARNING PROGRESS',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: isTablet ? 16 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: isTablet ? 0.4 : 0.3,
                  height: isTablet ? 24 / 16 : 16 / 12,
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 12 : 8),
          // Big percentage number — animates up from 0
          _AnimatedCounter(
            value: overallProgress,
            suffix: '%',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: isTablet ? 48 : 30,
              // Design ref: font-semibold (600), was 700
              fontWeight: FontWeight.w600,
              height: isTablet ? 1 : 36 / 30,
            ),
          ),
          SizedBox(height: isTablet ? 16 : 8),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Discussion Board',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF533641),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
              if (shown.isNotEmpty)
                // Design ref: text-xs font-semibold text-[#693D94]
                // bg-[#f0e8f7] px-2.5 py-1 rounded-full
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E8F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${shown.length} Active',
                    style: GoogleFonts.inter(
                      color: _purple,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Text(
              'No discussion threads yet.',
              style: GoogleFonts.inter(
                  color: const Color(0xFF6B7280), fontSize: 14),
            )
          else
            // Design ref: space-y-3 (12px gap, no dividers)
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
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
    // Design ref: rounded-lg border border-gray-100 bg-gray-50 p-3
    // hover:border-[#693D94]/30 hover:bg-[#f0e8f7]/30
    return HoverBuilder(
      builder: (context, hovering) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hovering
            ? const Color(0xFFF0E8F7).withValues(alpha: 0.3)
            : const Color(0xFFFBF9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hovering
              ? _purple.withValues(alpha: 0.3)
              : const Color(0xFFF3F4F6), // gray-100
        ),
      ),
      child: Row(
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
                  color: const Color(0xFF391E29),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 19.25 / 14,
                ),
              ),
              // Design ref: mt-0.5 (2px)
              const SizedBox(height: 2),
              Text(
                [
                  if (item.lastRepliedBy.isNotEmpty) item.lastRepliedBy,
                  if (item.lastReply.isNotEmpty) item.lastReply,
                  '${item.replyCount} ${item.replyCount == 1 ? 'reply' : 'replies'}',
                ].join(' • '),
                style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 16 / 12),
              ),
            ],
          ),
        ),
        // Design ref: gap-2 (8px)
        const SizedBox(width: 8),
        _ViewButton(
          onPressed: () => Modular.to.pushNamed(
            CoursesModule.construct(
                '${CoursesModule.detail}/${item.courseId}'),
          ),
        ),
      ],
      ),
      ),
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
        borderRadius: BorderRadius.circular(10),
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
                    color: const Color(0xFF533641),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Modular.to.pushNamed(
                  CoursesModule.construct(CoursesModule.redeemPoints),
                ),
                // Design ref: text-xs text-[#693D94] font-semibold
                // bg-[#f0e8f7] px-2.5 py-1 rounded-full
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E8F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'This Month',
                    style: GoogleFonts.inter(
                      color: _purple,
                      fontSize: 12,
                      height: 16 / 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Points circle + name/description
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [FigmaTokens.primaryPurple, FigmaTokens.gradientEnd],
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedCounter(
                      value: points,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    Text(
                      'pts',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Great progress${firstName != null && firstName.isNotEmpty ? ', $firstName' : ''}!',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF391E29),
                        fontSize: 14,
                        // Design ref: font-semibold (600), was 700
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've earned points by completing courses and attending virtual classes.",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFAF99A1),
                        fontSize: 12,
                        // Design ref: leading-relaxed = 1.625
                        height: 1.625,
                      ),
                    ),

                    // Activity list or empty state — Design ref: this sits
                    // inside the text column (indented under the circle),
                    // not spanning the full card width.
                    if (activity.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'No reward points earned this month yet.',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF6B7280), fontSize: 12),
                        ),
                      )
                    else
                      // Design ref: border-t border-gray-100 pt-2 space-y-1
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Color(0xFFF3F4F6))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final a in activity)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                // Design ref: bg-gray-50 rounded-lg px-2.5 py-1.5
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFBF9FA),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          a.label,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF6B7280),
                                            fontSize: 12,
                                            height: 16 / 12,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '+${a.points} pts',
                                        style: GoogleFonts.inter(
                                          color: _purple,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          height: 16 / 12,
                                        ),
                                      ),
                                    ],
                                  ),
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
    final isTablet = Responsive.isTablet(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 8 : 10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required For You',
            style: GoogleFonts.inter(
              color: const Color(0xFF374151),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 24 / 16,
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
                borderRadius: isTablet ? 20 : 14,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                textStyle: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: isTablet ? FontWeight.w500 : FontWeight.w600,
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
        // Number — Design ref: w-4 (16px), shrink-0, text-right
        SizedBox(
          width: 16,
          child: Text(
            '$index',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Course name — Design ref: line-clamp-2
        Expanded(
          child: Text(
            item.courseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF374151),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 24 / 16,
            ),
          ),
        ),
        // Design ref: mr-8 (32px) on the number+title group, before the
        // View button
        const SizedBox(width: 32),
        // View button — outlined purple, fills on hover. Design ref:
        // text-[13px] font-medium here (Discussion Board's View button is
        // a different 12px/font-semibold spec, despite sharing this widget)
        _ViewButton(
          fontSize: 13,
          fontWeight: FontWeight.w500,
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
  const _ViewButton({
    required this.onPressed,
    // Design ref default: Discussion Board's text-xs font-semibold (12/600)
    this.fontSize = 12,
    this.fontWeight = FontWeight.w600,
  });
  final VoidCallback? onPressed;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) {
        final filled = hovering && onPressed != null;
        // Design ref (>=700px): rounded-xl (12px). Design ref (phone): 4px.
        final borderRadius = BorderRadius.all(
          Radius.circular(Responsive.isTablet(context) ? 12 : 4),
        );
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
                  fontSize: fontSize,
                  fontWeight: fontWeight,
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
    this.color,
    this.hoverColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;

  /// Overrides the default purple background — e.g. red for an overdue
  /// course's Resume button.
  final Color? color;
  final Color? hoverColor;

  @override
  State<_BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<_BrandButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final baseColor = widget.color ?? _purple;
    final hoverColor = widget.hoverColor ?? FigmaTokens.purpleHover;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: !enabled
            ? baseColor.withOpacity(0.5)
            : _hovering
                ? hoverColor
                : baseColor,
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

// ─── Animated counter ─────────────────────────────────────────────────────────
//
// Counts up from 0 to [value] over [duration] using a curved animation,
// triggered whenever the widget is first built or [value] changes.

class _AnimatedCounter extends StatefulWidget {
  const _AnimatedCounter({
    required this.value,
    required this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1400),
  });

  final int value;
  final TextStyle style;
  final String suffix;
  final Duration duration;

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // Animate from the currently displayed value to the new one.
      _from = _displayValue;
      _controller.reset();
      _controller.forward();
    }
  }

  int get _displayValue {
    return (_from + (_animation.value * (widget.value - _from))).round();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          '${_displayValue}${widget.suffix}',
          style: widget.style,
        );
      },
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
              RetryButton(onRetry: onRetry!, errorMessage: message),
            ],
          ],
        ),
      ),
    );
  }
}

// Inline variant of the confirm dialog that doesn't use Navigator.pop — used when showDialog is not appearing on the device.
class _InlineConfirmDialog extends ConsumerStatefulWidget {
  const _InlineConfirmDialog({super.key, required this.data, required this.title, required this.type, required this.onConfirmed});
  final MentorModalData data;
  final String title;

  /// 'mentor' or 'supervisor' - sent as-is to the confirm-mentor-supervisor API.
  final String type;
  final VoidCallback onConfirmed;

  @override
  ConsumerState<_InlineConfirmDialog> createState() => _InlineConfirmDialogState();
}

class _InlineConfirmDialogState extends ConsumerState<_InlineConfirmDialog> {
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _valid = false;

  bool _isValidEmail(String s) {
    final email = s.trim();
    if (email.isEmpty) return false;
    final regex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    return regex.hasMatch(email);
  }

  void _validate() {
    final f = _firstController.text.trim().isNotEmpty;
    final l = _lastController.text.trim().isNotEmpty;
    final e = _isValidEmail(_emailController.text);
    setState(() {
      _valid = f && l && e;
    });
  }

  @override
  void initState() {
    super.initState();
    _firstController.text = widget.data.firstname ?? '';
    _lastController.text = widget.data.lastname ?? '';
    _emailController.text = widget.data.email ?? '';
    _firstController.addListener(_validate);
    _lastController.addListener(_validate);
    _emailController.addListener(_validate);
    _validate();
  }

  @override
  void dispose() {
    _firstController.removeListener(_validate);
    _lastController.removeListener(_validate);
    _emailController.removeListener(_validate);
    _firstController.dispose();
    _lastController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    _validate();
    if (!_valid || _submitting) return;
    if (kDebugMode) debugPrint('[_InlineConfirmDialog] confirm tapped: ${widget.title}');
    if (mounted) setState(() => _submitting = true);

    try {
      await ref.read(MentorRepository.provider).confirm(
            type: widget.type,
            firstname: _firstController.text.trim(),
            lastname: _lastController.text.trim(),
            email: _emailController.text.trim(),
          );
    } catch (e) {
      if (kDebugMode) debugPrint('[_InlineConfirmDialog] confirm API error: $e');
      if (mounted) {
        setState(() => _submitting = false);
        Toast.error(context, e);
      }
      return;
    }

    if (mounted && context.mounted) {
      Toast.success(context, '${widget.title.replaceFirst('Confirm Your ', '')} details confirmed.');
    }
    // NOTE: intentionally NOT gated on `mounted` past this point -
    // onConfirmed() only invokes the callback closure supplied by the
    // parent (which does setState on the *parent's* own State, not this
    // dialog's). If this dialog's Element got torn down and rebuilt
    // during the delay (this shell rebuilds fairly often - see
    // AppScaffold's shellHeaderConfigProvider post-frame write),
    // `mounted` here can be false while the parent is still very much
    // alive and still needs to hear about the confirmation - bailing
    // out here would silently drop the tap and freeze the flow with
    // the dialog stuck on screen.
    if (kDebugMode) debugPrint('[_InlineConfirmDialog] calling onConfirmed: ${widget.title}');
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.9;
    final dialogWidth = maxWidth > 640 ? 640.0 : maxWidth;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.10), offset: Offset(0, 8), blurRadius: 10, spreadRadius: -6),
              BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.10), offset: Offset(0, 20), blurRadius: 25, spreadRadius: -5),
            ],
            border: Border.all(color: const Color(0xFFD5E6FF).withOpacity(0.6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      height: 32 / 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.6,
                      color: const Color(0xFF364153),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'First Name',
                  style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: const Color(0xFF364153)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _firstController,
                    style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: const Color(0xFF533641)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),

                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Last Name',
                  style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: const Color(0xFF364153)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _lastController,
                    style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: const Color(0xFF533641)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),

                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Email',
                  style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: const Color(0xFF364153)),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 50,
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: const Color(0xFF533641)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                      ),

                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Note: ',
                        style: GoogleFonts.inter(fontSize: 12, height: 20 / 12, fontWeight: FontWeight.w700, color: const Color(0xFF6A7282)),
                      ),
                      TextSpan(
                        text: widget.title.toLowerCase().contains('supervisor')
                            ? "We ask that you confirm your supervisor's information every three months. If the above information is correct, click Confirm. You can edit your supervisor's information at anytime through your profile."
                            : "We ask that you confirm your mentor's information every three months. If the above information is correct, click Confirm. You can edit your mentor's information at anytime through your profile.",
                        style: GoogleFonts.inter(fontSize: 12, height: 20 / 12, fontWeight: FontWeight.w400, color: const Color(0xFF6A7282)),
                      ),
                    ],
                  ),
                  ),
                ),
                const SizedBox(height: 16),

                // Skip + Confirm buttons, centered as a pair
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: null, // Skip is intentionally disabled.
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F5F7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: const Color(0xFF826A72)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: (!_valid || _submitting) ? null : _confirm,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _valid ? const Color(0xFF693D94) : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF000000).withOpacity(0.08), offset: const Offset(0, 8), blurRadius: 10, spreadRadius: -6),
                                ],
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                              child: Text(
                                _submitting ? 'Confirming...' : 'Confirm',
                                style: GoogleFonts.inter(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w500, color: _valid ? Colors.white : const Color(0xFF6B7280)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        ),
    );
  }
}
