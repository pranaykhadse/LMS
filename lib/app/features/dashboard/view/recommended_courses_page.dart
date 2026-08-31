import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/utils/dev_image_proxy.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/course_image_fallback.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart';
import 'package:lms/app/features/dashboard/viewmodel/recommended_courses_view_model.dart';

// CSS ref, confirmed against `origin/staging`'s
// backend/views/my-required-courses/index.php +
// MyRequiredCoursesController::actionIndex(): this screen is served by the
// exact same controller action/card partial as My Required Courses
// (required_courses_page.dart), differing only by the `type=recommended`
// query param and page title ("My Recommended Courses" vs "My Required
// Courses") — so every fix/finding there (grid columns, dynamic image
// height, progress-ring + "Next session" row, rating-bar colors) applies
// identically here.

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _titleColor = Color(0xFFA20067);

// App-only feature (offline mode): the real web app has no notion of a
// "recommended" flag on a course to filter offline-saved courses by, so
// this approximates it as "not marked required" — the same courses this
// screen's live list would show.
bool _isRecommended(Course course) => course.isRequired != 1;

/// CSS ref: `.group-item` column classes — `col-lg-3 col-md-6 col-sm-12
/// col-12`, the same 4/2/1-at-992/768 ladder every other My Courses screen
/// uses.
int _columnsFor(double width) {
  if (width >= 992) return 4;
  if (width >= 768) return 2;
  return 1;
}

class RecommendedCoursesPage extends ConsumerWidget {
  const RecommendedCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(RecommendedCoursesViewModel.provider);
    final notifier = ref.read(RecommendedCoursesViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Recommended Courses',
      // Nav ref: the sub-nav item's label is literally "My Recomended
      // Courses" (typo, confirmed against `origin/staging`'s
      // bluetheme_layout.php) — selectedSubLabel must match that exact
      // string for the nav highlight to line up, even though the page's
      // own h1/title is correctly spelled (per MyRequiredCoursesController
      // ::actionIndex()'s `$title`).
      selectedSubLabel: 'My Recomended Courses',
      onRefresh: () => notifier.fetch(page: state.page),
      body:
          isEffectivelyOffline(ref)
              ? const OfflineCoursesSection(
                matches: _isRecommended,
                emptyMessage:
                    'No offline courses found.\nConnect to the internet and save a recommended course first.',
              )
              : _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final RecommendedCoursesState state;
  final RecommendedCoursesViewModel notifier;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load recommended courses.',
          ),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return RefreshIndicator(
          color: _purple,
          onRefresh: () async {
            await notifier.fetch(page: state.page);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              // CSS ref: .structure-block { border: 1px solid #E7E4FF }.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7E4FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'My Recommended Courses',
                        style: GoogleFonts.inter(
                          color: _titleColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          height: 28 / 24,
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = _columnsFor(
                          MediaQuery.sizeOf(context).width,
                        );
                        const gap = 30.0;
                        final cardWidth =
                            (constraints.maxWidth - (columns - 1) * gap) /
                            columns;
                        final imageHeight = cardWidth * 9 / 16;
                        // CSS ref: .course-title is 18px/1.4 above 768px,
                        // 16px/1.4 at/below it — content budget's title
                        // term must match.
                        final titleHeight =
                            MediaQuery.sizeOf(context).width <= 768
                                ? 44.8
                                : 50.4;
                        final contentBudget =
                            16 + 46 + 34 + titleHeight + 8 + 15 + 41;
                        final extent = imageHeight + contentBudget;
                        final rows = (state.courses.length / columns).ceil();
                        final gridHeight = rows * extent + (rows - 1) * gap;
                        return SizedBox(
                          height: gridHeight,
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  mainAxisExtent: extent,
                                ),
                            itemCount: state.courses.length,
                            itemBuilder:
                                (ctx, i) =>
                                    _CourseCard(course: state.courses[i]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    PaginationWidget(
                      page: state.page,
                      pages: state.totalPages,
                      onPage: (page) => _goToPage(context, page),
                      showProgressBar: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppFooter(),
            ],
          ),
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
//
// Identical `.modern-course-card` markup to My Required/Enrolled Courses —
// same shared `_required_courses.php` partial.

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled = isViewCourseDisabled(ref, course.id);
    final onTap =
        viewDisabled
            ? null
            : () => Modular.to.pushNamed(
              CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
            );

    return HoverBuilder(
      builder:
          (context, hovering) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0, hovering ? -8 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  hovering
                      ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ]
                      : null,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    // CSS ref: .modern-course-card { border: 1px solid
                    // rgba(0,0,0,.03) }.
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.03),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardImage(course: course, hovering: hovering),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (course.nextSession != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: _NextSessionRow(
                                    date: course.nextSession!,
                                  ),
                                ),
                              if (course.displayRating &&
                                  course.ratingCount > 0) ...[
                                _RatingBar(
                                  rating: course.averageRating,
                                  count: course.ratingCount,
                                ),
                                const SizedBox(height: 2),
                              ],
                              // CSS ref: .course-title — 18px/700 (drops to
                              // 16px only below 768px), color #1E293B.
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final fontSize =
                                        MediaQuery.sizeOf(context).width <= 768
                                            ? 16.0
                                            : 18.0;
                                    return Text(
                                      course.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color:
                                            hovering
                                                ? _purple
                                                : const Color(0xFF1E293B),
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  15,
                                ),
                                child: _ViewCourseButton(
                                  onPressed: onTap,
                                  filled: hovering,
                                ),
                              ),
                            ],
                          ),
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

class _CardImage extends StatelessWidget {
  const _CardImage({required this.course, this.hovering = false});
  final DashboardCourse course;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: hovering ? 1.05 : 1.0,
            child:
                course.logo != null
                    ? Image.network(
                      devProxiedImageUrl(course.logo!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImgFallback(),
                    )
                    : const _ImgFallback(),
          ),
          Positioned(
            top: 8,
            left: 8,
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
          if (course.nextSession != null)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 26.7,
                    height: 26.7,
                    child: CircularProgressIndicator(
                      value: course.progress / 100,
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(_purple),
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

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    // The real fallback (`/dist/images/course-bg.svg`) can never actually
    // render in this app — see `CourseImageFallback`'s own doc comment —
    // so a real local placeholder is used instead of a broken network
    // fetch that always ends up blank.
    return const CourseImageFallback();
  }
}

// ─── View Course button ─────────────────────────────────────────────────────

class _ViewCourseButton extends StatelessWidget {
  const _ViewCourseButton({required this.onPressed, this.filled = false});
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 41,
      child: Material(
        color:
            disabled
                ? const Color(0xFFF8FAFC).withValues(alpha: 0.5)
                : (filled ? _purple : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              // CSS ref: .view-course-btn { border: 1px solid
              // var(--primary-color) }.
              border: Border.all(
                color: _purple.withValues(alpha: disabled ? 0.3 : 1),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'View Course',
              style: GoogleFonts.inter(
                color:
                    disabled
                        ? _purple.withValues(alpha: 0.4)
                        : (filled ? Colors.white : _purple),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 19.5 / 13,
              ),
            ),
          ),
        ),
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NEXT SESSION',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 16.5 / 11,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 10, color: _purple),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _formatNextSession(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 19.5 / 13,
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
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final hourStr = hour12.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final day = dt.day.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} $day, $hourStr:$minute $ampm';
}

// ─── Star rating ──────────────────────────────────────────────────────────────

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          ...List.generate(5, (i) {
            IconData icon;
            if (i < rating.floor()) {
              icon = Icons.star_rounded;
            } else if (i < rating) {
              icon = Icons.star_half_rounded;
            } else {
              icon = Icons.star_border_rounded;
            }
            return Padding(
              padding: EdgeInsets.only(right: i < 4 ? 1 : 0),
              child: Icon(icon, color: const Color(0xFFFFD700), size: 18),
            );
          }),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.inter(
              color: const Color(0xFF1E293B),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 22.5 / 15,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 19.5 / 13,
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
              child: const Icon(
                Icons.thumb_up_outlined,
                color: _purple,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Recommended Courses',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Courses recommended for you will appear here.',
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
