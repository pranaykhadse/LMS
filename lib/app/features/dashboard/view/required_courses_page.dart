import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart';
import 'package:lms/app/features/dashboard/viewmodel/required_courses_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _titleColor = Color(0xFFA20067);

bool _isRequired(Course course) => course.isRequired == 1;

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
      onRefresh: () => notifier.fetch(page: state.page),
      body: isEffectivelyOffline(ref)
          ? const OfflineCoursesSection(
              matches: _isRequired,
              emptyMessage:
                  'No offline courses found.\nConnect to the internet and save a required course first.',
            )
          : _Body(state: state, notifier: notifier),
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
                onRefresh: () async {
                  await notifier.fetch(page: state.page);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  children: [
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
                              'My Required Courses',
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
                                phone: 2,
                                tablet: 3,
                                desktop: 4,
                              ),
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              mainAxisExtent: Responsive.isTablet(context) ? 360 : 340,
                            ),
                            itemCount: state.courses.length,
                            itemBuilder: (ctx, i) =>
                                _CourseCard(course: state.courses[i]),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image — 224px tall, fills width
          SizedBox(
            height: 180,
            width: double.infinity,
            child: course.logo != null
                ? Image.network(
                    course.logo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF3F4F6),
                      alignment: Alignment.center,
                      child: const Icon(Icons.school_outlined,
                          color: _purple, size: 40),
                    ),
                  )
                : Container(
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: const Icon(Icons.school_outlined,
                        color: _purple, size: 40),
                  ),
          ),
          // Content — purple background matching CourseGridCard style
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              color: FigmaTokens.primaryPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      course.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // "View Course" button — white outlined
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: viewDisabled
                          ? null
                          : () => Modular.to.pushNamed(
                                CoursesModule.construct(
                                    '${CoursesModule.detail}/${course.id}'),
                              ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
              RetryButton(onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}

