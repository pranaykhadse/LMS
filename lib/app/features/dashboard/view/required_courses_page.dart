import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/viewmodel/required_courses_view_model.dart';

const _purple = Color(0xFF5756C9);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);
const _bg = Color(0xFFF5F7FC);

class RequiredCoursesPage extends ConsumerWidget {
  const RequiredCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(RequiredCoursesViewModel.provider);
    final notifier = ref.read(RequiredCoursesViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Required Courses',
      selectedSubLabel: 'My Required Courses',
      body: _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final RequiredCoursesState state;
  final RequiredCoursesViewModel notifier;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: state.error ?? 'Unable to load required courses.',
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () => notifier.fetch(page: state.page),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.columns(
                          context,
                          phone: 2,
                          tablet: 3,
                          desktop: 4,
                        ),
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.62,
                        mainAxisExtent: Responsive.isTablet(context) ? 290 : null,
                      ),
                      itemCount: state.courses.length,
                      itemBuilder: (ctx, i) =>
                          _CourseCard(course: state.courses[i]),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      // Must match _limit in required_courses_view_model.dart.
                      child: PerPageBadge(perPage: 10),
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
            PaginationWidget(
              page: state.page,
              pages: state.totalPages,
              onPage: notifier.goToPage,
            ),
          ],
        );
    }
  }
}

// ─── Course card ─────────────────────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            width: double.infinity,
            child: course.logo != null
                ? Image.network(
                    course.logo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImgFallback(),
                  )
                : const _ImgFallback(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (course.displayRating) ...[
                    _StarRow(
                      rating: course.averageRating,
                      count: course.ratingCount,
                    ),
                    const SizedBox(height: 6),
                  ] else
                    const SizedBox(height: 2),
                  if (course.progress > 0) ...[
                    _ProgressRow(progress: course.progress),
                    const SizedBox(height: 6),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Modular.to.pushNamed(
                        CoursesModule.construct(
                          '${CoursesModule.detail}/${course.id}',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      child: const Text('View Course'),
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

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 5,
            backgroundColor: const Color(0xFFE8E7F8),
            valueColor: const AlwaysStoppedAnimation<Color>(_purple),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$progress% complete',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
      ],
    );
  }
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
            return const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15);
          }
          if (i < rating) {
            return const Icon(Icons.star_half_rounded, color: Color(0xFFFFC107), size: 15);
          }
          return const Icon(Icons.star_border_rounded, color: Color(0xFFFFC107), size: 15);
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

// ─── Image fallback ───────────────────────────────────────────────────────────

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.assignment_outlined, color: _purple, size: 54),
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
              child: const Icon(Icons.assignment_outlined, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Required Courses',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Required courses assigned to you will appear here.',
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
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: _purple),
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

