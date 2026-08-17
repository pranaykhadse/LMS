import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_grid_card.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart';
import 'package:lms/app/features/dashboard/viewmodel/enrolled_courses_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _titleColor = Color(0xFFA20067);

// "Enrolled" here means not yet fully complete - a fully completed offline
// course belongs on the Completed page's offline section instead.
bool _isEnrolledNotComplete(Course course) => course.percentage < 1.0;

class EnrolledCoursesPage extends ConsumerWidget {
  const EnrolledCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(EnrolledCoursesViewModel.provider);
    final notifier = ref.read(EnrolledCoursesViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Enrolled Courses',
      selectedSubLabel: 'My Enrolled Courses',
      onRefresh: () => notifier.fetch(page: state.page),
      body: isEffectivelyOffline(ref)
          ? const OfflineCoursesSection(
              matches: _isEnrolledNotComplete,
              emptyMessage:
                  'No offline courses found.\nConnect to the internet and save a course first.',
            )
          : _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final EnrolledState state;
  final EnrolledCoursesViewModel notifier;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(state.error, 'Unable to load enrolled courses.'),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () async {
                  await notifier.fetch(page: state.page);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
                    // ── White card: title + grid ──────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Text(
                              'My Enrolled Courses',
                              style: TextStyle(
                                color: _titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GridView.builder(
                            padding: const EdgeInsets.all(16),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: Responsive.columns(
                                context,
                                phone: 1,
                                tablet: 3,
                                desktop: 4,
                              ),
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              // Phone: single-column — card is full-width
                              // so less vertical space is needed.
                              mainAxisExtent: Responsive.isTablet(context) ? 360 : 320,
                            ),
                            itemCount: state.courses.length,
                            itemBuilder: (ctx, i) =>
                                _CourseCard(course: state.courses[i]),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: PerPageBadge(perPage: state.perPage),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            PaginationWidget(
              page: state.page,
              pages: state.totalPages,
              onPage: (page) => _goToPage(context, page),
            ),
          ],
        );
    }
  }

  void _goToPage(BuildContext context, int page) {
    notifier.goToPage(page).then((error) {
      if (error != null && context.mounted) Toast.error(context, error);
    });
  }
}

// ─── Course card ─────────────────────────────────────────────────────────────

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled = isViewCourseDisabled(ref, course.id);
    return CourseGridCard(
      imageUrl: course.logo,
      title: course.name,
      buttonLabel: 'View Course',
      onPressed: viewDisabled
          ? null
          : () => Modular.to.pushNamed(
              CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
            ),
      offlineCourse: Course(
        id: course.id,
        name: course.name,
        logoLink: course.logo,
        averageRating: course.averageRating,
        ratingCount: course.ratingCount,
        displayRating: course.displayRating ? 1 : 0,
      ),
      infoSection: _buildInfoSection(course),
      progress: course.progress,
    );
  }

  Widget? _buildInfoSection(DashboardCourse course) {
    final showSession = course.nextSession != null;
    final showStars = course.displayRating && course.ratingCount > 0;
    if (!showSession && !showStars) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSession) ...[
          _NextSessionRow(date: course.nextSession!),
          if (showStars) const SizedBox(height: 6),
        ],
        if (showStars)
          _StarRow(rating: course.averageRating, count: course.ratingCount),
      ],
    );
  }
}

// ─── Next session ───────────────────────────────────────────────────────────

class _NextSessionRow extends StatelessWidget {
  const _NextSessionRow({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT SESSION',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 12, color: _purple),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _formatNextSession(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatNextSession(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final hourStr = hour12.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, $hourStr:$minute $ampm';
}

// ─── Star rating ──────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(
              Icons.star_rounded,
              color: Color(0xFFFFC107),
              size: 15,
            );
          }
          if (i < rating) {
            return const Icon(
              Icons.star_half_rounded,
              color: Color(0xFFFFC107),
              size: 15,
            );
          }
          return const Icon(
            Icons.star_border_rounded,
            color: Color(0xFFFFC107),
            size: 15,
          );
        }),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(Icons.school_outlined, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Enrolled Courses',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'You have not enrolled in any courses yet. Browse the course catalog to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
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

