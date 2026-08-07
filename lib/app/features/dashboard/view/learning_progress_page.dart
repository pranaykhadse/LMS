import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
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
const _lpGreen = Color(0xFF22C55E);
const _lpOrange = Color(0xFFF59E0B);
const _lpBlue = Color(0xFF3B82F6);

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ─────────────────────────────────────────────────
          Text(
            'Hey $firstName!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _lpNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Welcome back! Here's what's happening with your courses.",
            style: TextStyle(fontSize: 13, color: _lpMuted, height: 1.4),
          ),
          const SizedBox(height: 20),

          // ── Summary cards ─────────────────────────────────────────────
          _SummarySection(summary: data.summary),
          const SizedBox(height: 16),

          // ── Overall progress ─────────────────────────────────────────
          _OverallProgressCard(progress: data.summary.overallProgress),
          const SizedBox(height: 24),

          // ── Course Progress ───────────────────────────────────────────
          if (data.progressStatus.isNotEmpty) ...[
            const _SectionLabel('Course Progress'),
            const SizedBox(height: 10),
            _CourseProgressCard(courses: data.progressStatus),
            const SizedBox(height: 24),
          ],

          // ── Continue Learning ─────────────────────────────────────────
          if (data.continueLearning != null) ...[
            _ContinueLearningCard(info: data.continueLearning!),
            const SizedBox(height: 24),
          ],

          // ── Upcoming Sessions ─────────────────────────────────────────
          const _SectionLabel('Upcoming Sessions'),
          const SizedBox(height: 10),
          _UpcomingSessionsCard(sessions: data.upcomingSessions),
          const SizedBox(height: 24),

          // ── Required For You ─────────────────────────────────────────
          if (data.requiredForYou.isNotEmpty) ...[
            const _SectionLabel('Required For You'),
            const SizedBox(height: 10),
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
// Summary stat cards
// ─────────────────────────────────────────────────────────────────────────────
class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});
  final LearningProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.menu_book_rounded,
                iconColor: _lpBlue,
                label: 'ENROLLED',
                value: '${summary.enrolledCourses}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_rounded,
                iconColor: _lpGreen,
                label: 'COMPLETED',
                value: '${summary.completedCourses}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _StatCard(
            icon: Icons.bolt_rounded,
            iconColor: _lpOrange,
            label: 'REQUIRED',
            value: '${summary.requiredCourses}',
            wide: true,
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
    this.wide = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A172033), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _lpMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _lpNavy,
                  height: 1.1,
                ),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: FigmaTokens.heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x30172033), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.show_chart_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Overall Learning Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$progress%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A172033), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: courses.asMap().entries.map((e) {
          final i = e.key;
          final course = e.value;
          return Column(
            children: [
              if (i > 0)
                const Divider(height: 1, color: Color(0xFFEEF0F5), indent: 16, endIndent: 16),
              _CourseProgressRow(course: course),
            ],
          );
        }).toList(),
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
    final barColor = course.progress == 100 ? _lpGreen : _lpPurple;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _lpPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school_rounded, color: _lpPurple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _lpNavy,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFEEF0F5),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${course.progress}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: course.progress == 100 ? _lpGreen : _lpNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue Learning card
// ─────────────────────────────────────────────────────────────────────────────
class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({required this.info});
  final ContinueLearningInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A172033), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue Learning',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _lpNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            info.courseName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _lpPurple,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: HoverBuilder(
              builder: (context, hovering) => ElevatedButton.icon(
                onPressed: () {
                  final courseId = int.tryParse(info.courseId);
                  if (courseId != null) {
                    Modular.to.pushNamed(
                      CoursesModule.construct(
                          '${CoursesModule.detail}/$courseId'),
                    );
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text(
                  'Resume Lesson',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hovering ? FigmaTokens.purpleHover : _lpPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upcoming sessions
// ─────────────────────────────────────────────────────────────────────────────
class _UpcomingSessionsCard extends StatelessWidget {
  const _UpcomingSessionsCard({required this.sessions});
  final List<UpcomingSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A172033), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: sessions.isEmpty
          ? const Text(
              'All caught up!',
              style: TextStyle(color: _lpMuted, fontSize: 14),
            )
          : Column(
              children: sessions.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                return Column(
                  children: [
                    if (i > 0)
                      const Divider(height: 1, color: Color(0xFFEEF0F5)),
                    _SessionRow(session: s),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final UpcomingSession session;

  String get _dateTimeLabel {
    final date = session.startDate ?? '';
    final time = session.startTime ?? '';
    if (date.isEmpty && time.isEmpty) return '';
    if (date.isEmpty) return time;
    if (time.isEmpty) return date;
    // Format: "Jul 18, 2026 · 11:00 AM"
    final dt = DateTime.tryParse('$date ${time.length > 5 ? time.substring(0, 5) : time}');
    if (dt == null) return '$date · $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _lpPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
                Icons.calendar_today_rounded, color: _lpPurple, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.courseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _lpNavy,
                  ),
                ),
                if (_dateTimeLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _dateTimeLabel,
                    style: const TextStyle(fontSize: 12, color: _lpMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A172033), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          ...courses.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            return Column(
              children: [
                if (i > 0)
                  const Divider(
                      height: 1, color: Color(0xFFEEF0F5), indent: 16, endIndent: 16),
                _RequiredCourseRow(course: c),
              ],
            );
          }),
          const Divider(height: 1, color: Color(0xFFEEF0F5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: HoverBuilder(
                builder: (context, hovering) => ElevatedButton(
                  onPressed: () => Modular.to.pushNamed(
                    CoursesModule.construct(CoursesModule.requiredCourses),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hovering ? FigmaTokens.purpleHover : _lpPurple,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'View All Required Courses',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredCourseRow extends StatelessWidget {
  const _RequiredCourseRow({required this.course});
  final RequiredCourseItem course;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: _lpOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              course.courseName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _lpNavy,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              final courseId = int.tryParse(course.courseId);
              if (courseId != null) {
                Modular.to.pushNamed(
                  CoursesModule.construct(
                      '${CoursesModule.detail}/$courseId'),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _lpPurple,
              side: BorderSide(color: _lpPurple.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _lpNavy,
        ),
      );
}
