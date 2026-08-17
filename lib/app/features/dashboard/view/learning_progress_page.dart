import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/dashboard/model/learning_progress_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/learning_progress_view_model.dart';

const _lpPurple = FigmaTokens.primaryPurple;
const _lpNavy = FigmaTokens.cardTitles;
const _lpMuted = FigmaTokens.noteBodyText;
const _lpBg = FigmaTokens.pageBackground;

class LearningProgressPage extends ConsumerWidget {
  const LearningProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(LearningProgressViewModel.provider);
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final firstName = profile?.firstname?.trim() ?? 'there';

    return AppScaffold(
      backgroundColor: _lpBg,
      title: 'My Learning Progress',
      onRefresh: () => ref.read(LearningProgressViewModel.provider.notifier).fetch(),
      body: _buildBody(context, ref, state, firstName),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    DataState<LearningProgressData> state,
    String firstName,
  ) {
    switch (state.state) {
      case DataProviderState.idle:
      case DataProviderState.loading:
        return const Center(
          child: CircularProgressIndicator(color: _lpPurple),
        );
      case DataProviderState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: _lpMuted),
                const SizedBox(height: 12),
                Text(
                  state.error ?? 'Unable to load progress.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _lpMuted, fontSize: 14),
                ),
                const SizedBox(height: 20),
                HoverBuilder(
                  builder: (context, hovering) => ElevatedButton.icon(
                    onPressed: () => ref
                        .read(LearningProgressViewModel.provider.notifier)
                        .fetch(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _lpPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case DataProviderState.data:
        if (state.data == null) return const SizedBox.shrink();
        return _ProgressBody(data: state.data!, firstName: firstName);
    }
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.data, required this.firstName});

  final LearningProgressData data;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 760;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ─────────────────────────────────────────────────
          const Text(
            "Welcome back! Here's what's happening with your courses.",
            style: TextStyle(fontSize: 13, color: _lpMuted, height: 1.4),
          ),
          const SizedBox(height: 16),

          // ── Stat cards — 3 equal columns ──────────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.bookOpen,
                  iconColor: _lpPurple,
                  label: 'ENROLLED',
                  value: '${data.summary.enrolledCourses}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.alertCircle,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'REQUIRED',
                  value: '${data.summary.requiredCourses}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.checkCircle,
                  iconColor: const Color(0xFF22C55E),
                  label: 'COMPLETED',
                  value: '${data.summary.completedCourses}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Row 2: Continue Learning (left) + Upcoming Sessions (right) ─
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ContinueLearningCard(
                    courses: data.extras.continueLearning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _UpcomingSessionsCard(
                    sessions: data.upcomingSessions,
                    title: 'Upcoming Virtual Classes',
                  ),
                ),
              ],
            )
          else ...[
            _ContinueLearningCard(courses: data.extras.continueLearning),
            const SizedBox(height: 16),
            _UpcomingSessionsCard(
              sessions: data.upcomingSessions,
              title: 'Upcoming Virtual Classes',
            ),
          ],
          const SizedBox(height: 16),

          // ── Row 3: Course Progress (left) + Overall Progress (right) ──
          if (data.progressStatus.isNotEmpty)
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CourseProgressCard(courses: data.progressStatus),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _OverallProgressCard(
                        progress: data.summary.overallProgress),
                  ),
                ],
              )
            else ...[
              _CourseProgressCard(courses: data.progressStatus),
              const SizedBox(height: 16),
              _OverallProgressCard(progress: data.summary.overallProgress),
            ]
          else
            _OverallProgressCard(progress: data.summary.overallProgress),
          const SizedBox(height: 16),

          // ── Row 4: Rewards & Points (left) + Discussion Board (right) ─
          if (isWide &&
              (data.extras.rewards != null ||
                  data.extras.discussionBoards.isNotEmpty))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _RewardsPointsCard(rewards: data.extras.rewards),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DiscussionBoardCard(
                      boards: data.extras.discussionBoards),
                ),
              ],
            )
          else ...[
            if (data.extras.rewards != null) ...[
              _RewardsPointsCard(rewards: data.extras.rewards),
              const SizedBox(height: 16),
            ],
            if (data.extras.discussionBoards.isNotEmpty) ...[
              _DiscussionBoardCard(boards: data.extras.discussionBoards),
              const SizedBox(height: 16),
            ],
          ],
          const SizedBox(height: 16),

          // ── Required For You ──────────────────────────────────────────
          if (data.requiredForYou.isNotEmpty) ...[
            _RequiredCoursesCard(courses: data.requiredForYou),
            const SizedBox(height: 8),
          ],
          const AppFooter(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────
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
  final String value;

  @override
  Widget build(BuildContext context) {
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
                    color: const Color(0xFF9CA3AF),
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
            value,
            style: GoogleFonts.inter(
              color: const Color(0xFF1F2937),
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

// ─────────────────────────────────────────────────────────────────────────────
// Overall progress card
// ─────────────────────────────────────────────────────────────────────────────
class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress / 100.0).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF4A439F), Color(0xFF9650B4)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_border_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 6),
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
          Text(
            '$progress%',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Course progress list
// ─────────────────────────────────────────────────────────────────────────────
class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({required this.courses});
  final List<CourseProgressItem> courses;

  @override
  Widget build(BuildContext context) {
    final shown = courses.take(2).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Course Progress',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF374151),
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (shown.isNotEmpty)
                  GestureDetector(
                    onTap: () => Modular.to.pushNamed(
                        CoursesModule.construct(CoursesModule.allCourseProgress)),
                    child: Text('View All',
                        style: GoogleFonts.inter(
                            color: _lpPurple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Text('No courses in progress.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280), fontSize: 14)),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1,
                    color: FigmaTokens.cardBorders,
                    indent: 16,
                    endIndent: 16),
              _CourseProgressRow(course: shown[i]),
            ],
        ],
      ),
    );
  }
}

class _CourseProgressRow extends StatelessWidget {
  const _CourseProgressRow({required this.course});
  final CourseProgressItem course;

  @override
  Widget build(BuildContext context) {
    final pct = (course.progress / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, size: 13, color: _lpPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course.courseName,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4B5563),
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
                  color: const Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(_lpPurple),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue Learning card — PageView carousel with auto-advance
// ─────────────────────────────────────────────────────────────────────────────
class _ContinueLearningCard extends StatefulWidget {
  const _ContinueLearningCard({required this.courses});
  final List<DashboardContinueLearningItem> courses;

  @override
  State<_ContinueLearningCard> createState() => _ContinueLearningCardState();
}

class _ContinueLearningCardState extends State<_ContinueLearningCard> {
  final _controller = PageController();
  int _index = 0;
  Timer? _timer;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_ContinueLearningCard old) {
    super.didUpdateWidget(old);
    if (old.courses.length != widget.courses.length) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.courses.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients || _hovering) return;
      _controller.animateToPage(
        (_index + 1) % widget.courses.length,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'CONTINUE LEARNING',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (widget.courses.isNotEmpty)
                    GestureDetector(
                      onTap: () => Modular.to.pushNamed(
                        CoursesModule.construct(
                            CoursesModule.inProgressCourses),
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          color: _lpPurple,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── PageView ─────────────────────────────────────────────
            if (widget.courses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No courses in progress.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280), fontSize: 14),
                ),
              )
            else
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: widget.courses.length,
                  itemBuilder: (_, i) =>
                      _ContinueLearningItem(course: widget.courses[i]),
                ),
              ),
            // ── Dot indicators ────────────────────────────────────────
            if (widget.courses.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.courses.length, (i) {
                    return GestureDetector(
                      onTap: () {
                        _startTimer();
                        _controller.animateToPage(i,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? _lpPurple
                              : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueLearningItem extends StatelessWidget {
  const _ContinueLearningItem({required this.course});
  final DashboardContinueLearningItem course;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thumbnail
        SizedBox(
          width: 120,
          child: course.logoLink != null
              ? Image.network(course.logoLink!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImgFallback())
              : const _ImgFallback(),
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (course.className.isNotEmpty)
                  Text(
                    course.className.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: _lpPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                const SizedBox(height: 4),
                Text(
                  course.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1F2937),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (course.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 12,
                        height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                _BrandButton(
                  label: 'Resume Lesson →',
                  onPressed: () {
                    final id = int.tryParse(course.courseId);
                    if (id != null) {
                      Modular.to.pushNamed(CoursesModule.construct(
                          '${CoursesModule.detail}/$id'));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upcoming sessions
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Upcoming sessions — filterd/sorted/collapsible like dashboard
// ─────────────────────────────────────────────────────────────────────────────
class _UpcomingSessionsCard extends StatefulWidget {
  const _UpcomingSessionsCard(
      {required this.sessions, this.title = 'Upcoming Sessions'});
  final List<UpcomingSession> sessions;
  final String title;

  @override
  State<_UpcomingSessionsCard> createState() => _UpcomingSessionsCardState();
}

class _UpcomingSessionsCardState extends State<_UpcomingSessionsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = widget.sessions
        .where((s) => s.startDateTime?.isAfter(now) ?? false)
        .toList()
      ..sort((a, b) =>
          (a.startDateTime ?? DateTime(0))
              .compareTo(b.startDateTime ?? DateTime(0)));
    final shown = upcoming.take(8).toList();
    const collapsed = 3;
    final visible = _expanded ? shown : shown.take(collapsed).toList();
    final hasMore = shown.length > collapsed;

    return Container(
      width: double.infinity,
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
            widget.title,
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
              child: Text('No upcoming sessions.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF6B7280), fontSize: 14)),
            )
          else ...[
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _SessionRow(session: visible[i]),
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
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF6B7280), size: 22),
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
  const _SessionRow({required this.session});
  final UpcomingSession session;

  String _formatDate(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final startDt = session.startDateTime;
    final isTablet = Responsive.isTablet(context);

    final title = Text(
      session.courseName,
      style: GoogleFonts.inter(
        color: isTablet ? const Color(0xFF1F2937) : const Color(0xFF1E2939),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: isTablet ? 1.4 : 22 / 16,
      ),
    );

    final dateRow = startDt != null
        ? Row(
            children: [
              const Icon(LucideIcons.calendarDays, size: 10, color: _lpPurple),
              const SizedBox(width: 6),
              Text(
                _formatDate(startDt),
                style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF), fontSize: 12, height: 1.4),
              ),
              if (session.startTime != null &&
                  session.startTime!.isNotEmpty) ...[
                Text(' • ',
                    style: GoogleFonts.inter(
                        color: const Color(0xFFD1D5DB), fontSize: 12)),
                Text(
                  _formatTime(startDt),
                  style: GoogleFonts.inter(
                      color: const Color(0xFF9CA3AF), fontSize: 12, height: 1.4),
                ),
              ],
            ],
          )
        : const SizedBox.shrink();

    final hostedBy =
        session.instructor != null && session.instructor!.isNotEmpty
            ? Text.rich(TextSpan(children: [
                TextSpan(
                  text: 'Hosted by ',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF9CA3AF), fontSize: 12),
                ),
                TextSpan(
                  text: session.instructor,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]))
            : null;

    void openSession() {
      final id = int.tryParse(session.courseId);
      if (id != null) {
        Modular.to.pushNamed(
            CoursesModule.construct('${CoursesModule.detail}/$id'));
      }
    }

    // Join pill — inline on tablet/desktop, full-width at bottom on phone
    final joinPill = GestureDetector(
      onTap: openSession,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _lpPurple,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Join',
          style: GoogleFonts.inter(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return HoverBuilder(
      builder: (context, hovering) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hovering
              ? _lpPurple.withValues(alpha: 0.05)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(isTablet ? 8 : 10),
          border: Border.all(
            color: hovering
                ? _lpPurple.withValues(alpha: 0.3)
                : const Color(0xFFF3F4F6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isTablet
              ? [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      joinPill,
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
                      onTap: openSession,
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _lpPurple,
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

// ─────────────────────────────────────────────────────────────────────────────
// Required For You
// ─────────────────────────────────────────────────────────────────────────────
class _RequiredCoursesCard extends StatelessWidget {
  const _RequiredCoursesCard({required this.courses});
  final List<RequiredCourseItem> courses;

  @override
  Widget build(BuildContext context) {
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
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ...courses.take(5).toList().asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Column(
              children: [
                if (i > 0)
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                _RequiredCourseRow(course: c, index: i + 1),
              ],
            );
          }),
          const SizedBox(height: 20),
          Center(
            child: _BrandButton(
              label: 'View All Required Courses',
              onPressed: () => Modular.to.pushNamed(
                CoursesModule.construct(CoursesModule.requiredCourses),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RequiredCourseRow extends StatelessWidget {
  const _RequiredCourseRow({required this.course, required this.index});
  final RequiredCourseItem course;
  final int index;

  @override
  Widget build(BuildContext context) {
    final courseId = int.tryParse(course.courseId) ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
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
          Expanded(
            child: Text(
              course.courseName,
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
          _ViewButton(
            onPressed: courseId == 0
                ? null
                : () => Modular.to.pushNamed(
                      CoursesModule.construct(
                          '${CoursesModule.detail}/$courseId'),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── View button (outlined → filled on hover) ────────────────────────────────

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
          color: filled ? _lpPurple : Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: _lpPurple),
                borderRadius: borderRadius,
              ),
              child: Text(
                'View',
                style: GoogleFonts.inter(
                  color: filled ? Colors.white : _lpPurple,
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

// ─── Brand button (solid purple, hover state) ─────────────────────────────────

class _BrandButton extends StatefulWidget {
  const _BrandButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

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
            ? _lpPurple.withValues(alpha: 0.5)
            : _hovering
                ? FigmaTokens.purpleHover
                : _lpPurple,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onPressed,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              widget.label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Rewards & Points card ────────────────────────────────────────────────────

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
          Row(
            children: [
              Expanded(
                child: Text('Rewards & Points',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF374151),
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () => Modular.to.pushNamed(
                    CoursesModule.construct(CoursesModule.redeemPoints)),
                child: Text('This Month',
                    style: GoogleFonts.inter(
                        color: _lpPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: _lpPurple, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$points',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    Text('pts',
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
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
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've earned points by completing courses and attending virtual classes.",
                      style: GoogleFonts.inter(
                          color: const Color(0xFF6B7280), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activity.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  for (final a in activity)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(a.label,
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF1F2937),
                                      fontSize: 13))),
                          Text('+${a.points} pts',
                              style: GoogleFonts.inter(
                                  color: _lpPurple,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
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

// ─── Discussion Board card ────────────────────────────────────────────────────

class _DiscussionBoardCard extends StatelessWidget {
  const _DiscussionBoardCard({required this.boards});
  final List<DashboardDiscussionBoardItem> boards;

  @override
  Widget build(BuildContext context) {
    if (boards.isEmpty) return const SizedBox.shrink();
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
          Row(
            children: [
              Text('Discussion Board',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF374151),
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _lpPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${boards.length} Active',
                    style: GoogleFonts.inter(
                        color: _lpPurple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF3F4F6)),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shown[i].title,
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF1F2937),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (shown[i].lastRepliedBy.isNotEmpty)
                                shown[i].lastRepliedBy,
                              if (shown[i].lastReply.isNotEmpty)
                                shown[i].lastReply,
                              '${shown[i].replyCount} ${shown[i].replyCount == 1 ? 'reply' : 'replies'}',
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
                            '${CoursesModule.detail}/${shown[i].courseId}'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
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
      color: FigmaTokens.pageBackground,
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _lpPurple, size: 40),
    );
  }
}
