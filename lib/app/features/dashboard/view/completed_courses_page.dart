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
import 'package:lms/app/features/dashboard/viewmodel/completed_courses_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _titleColor = Color(0xFFA20067);

// FLAGGED, NOT IMPLEMENTED: CSS ref, confirmed against `origin/staging`'s
// backend/views/lmsclass/_completed_course.php — a conditional green
// "🏆 X Pts" pill (bg #10b981, top:10/left:10, radius 20, shadow) shows
// when the course has non-empty `$points`. `DashboardCourse` (this
// screen's model) has no `points` field at all — the API this app
// consumes doesn't expose it. Adding this needs an API/model change, not
// just a UI fix; same category as the "deleted group" case flagged in
// docs/offline_lms_ui_audit.md. Skipped for now.

/// CSS ref, confirmed against `origin/staging`'s
/// backend/views/lmsclass/_completed_course.php: `.group-item` column
/// classes — `col-lg-3 col-md-6 col-sm-12 col-12`, the same 4/2/1-at-
/// 992/768 ladder as Course Catalog/Enrolled Courses — not the shared
/// `Responsive` helper's generic 700/1024 thresholds with 3 tablet columns.
int _columnsFor(double width) {
  if (width >= 992) return 4;
  if (width >= 768) return 2;
  return 1;
}

bool _isComplete(Course course) => course.percentage >= 1.0;

class CompletedCoursesPage extends ConsumerWidget {
  const CompletedCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(CompletedCoursesViewModel.provider);
    final notifier = ref.read(CompletedCoursesViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Completed Courses',
      selectedSubLabel: 'My Completed Courses',
      onRefresh: () => notifier.fetch(page: state.page),
      body:
          isEffectivelyOffline(ref)
              ? const OfflineCoursesSection(
                matches: _isComplete,
                emptyMessage:
                    'No offline courses found.\nConnect to the internet and save a completed course first.',
              )
              : _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final CompletedState state;
  final CompletedCoursesViewModel notifier;

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
            'Unable to load completed courses.',
          ),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        // Design ref, confirmed against the live DOM: same
        // `.structure-block` white-card pattern as My Enrolled Courses —
        // #pagination flows as the last child inside the same card, not
        // pinned outside the scroll area.
        // Per explicit request: the footer should span the full window
        // width on every screen, like the header above it — it was the
        // last child of this ListView, inheriting the ListView's own
        // horizontal `padding` instead of running edge to edge.
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
                    // Design ref: .structure-block — bg #fff, radius 16px,
                    // border 1px solid #E7E4FF (rgb(231,228,255)), padding
                    // 20px.
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
                          // Design ref: h1 — "Completed Courses" (no "My"
                          // prefix, unlike this route's own page title), color
                          // #A20067 (rgb(162,0,103)), 24px/weight 400,
                          // line-height 28px, margin-bottom 8px.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Completed Courses',
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
                              // CSS ref: .card-image-wrapper — padding-top:
                              // 56.25% (16:9) of the card's own fluid width —
                              // same fix as Course Catalog/Enrolled Courses
                              // (see docs/offline_lms_ui_audit.md). The old
                              // fixed 320/360 ignored actual card width.
                              final cardWidth =
                                  (constraints.maxWidth - (columns - 1) * gap) /
                                  columns;
                              final imageHeight = cardWidth * 9 / 16;
                              // Below-image content budget: this is the exact
                              // same `.modern-course-card` markup/CSS as
                              // Course Catalog's, so it gets the identical
                              // live-measured budget rather than a separately-
                              // derived one (see docs/offline_lms_ui_audit
                              // .md) — keeps this screen's card height pixel-
                              // identical to Course Catalog's. This card never
                              // shows a rating-bar (confirmed absent from the
                              // real markup), so it has more slack than most,
                              // but never overflows since 172/200 was already
                              // sized for the widest real case; `Spacer()`
                              // absorbs it.
                              final contentBudget =
                                  columns == 4 ? 172.0 : 200.0;
                              final extent = imageHeight + contentBudget;
                              final rows =
                                  (state.courses.length / columns).ceil();
                              final gridHeight =
                                  rows * extent + (rows - 1) * gap;
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
                  ],
                ),
              ),
            ),
            const AppFooter(),
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
//
// Page-local card matching the captured `.modern-course-card` DOM/CSS for
// this screen exactly — identical structure to My Enrolled Courses' card
// (same classes in the live markup), just swapping the progress-ring
// overlay for the completed badge and the "Next session" row for
// "Completed".

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

    // Design ref, confirmed against live CSS: `.modern-course-card:hover`
    // — translateY(-8px) lift + `--card-shadow-hover` (0 20px 40px
    // rgba(0,0,0,.12)); `:hover .card-image-wrapper img` — scale(1.05);
    // `:hover .view-course-btn` — fills solid purple with white text. All
    // three driven by hovering the CARD, so one HoverBuilder wraps
    // everything and threads `hovering` down.
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
                // Design ref: the real `.modern-course-card:hover` only
                // lifts (translateY) and gains a shadow — no tint, so
                // suppress InkWell's own default hover overlay.
                hoverColor: Colors.transparent,
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: _CompletedRow(
                                  date: course.completedDate,
                                ),
                              ),
                              // CSS ref: .session-info's own margin-bottom is
                              // commented out in the real stylesheet (dead —
                              // see docs/offline_lms_ui_audit.md), so no
                              // gap belongs here.
                              // CSS ref: `.course-title` is defined TWICE —
                              // modern-course-cards.css (18px/700, margin-
                              // bottom 6px, color var(--text-main)=#1E293B)
                              // and, loaded AFTER it in the same site-wide
                              // asset bundle (`BlueThemeAsset`, shared by
                              // every page), bluetheme-layout.css (1rem/
                              // 700, color var(--card-title)=#1E2939,
                              // margin 0 0 8px). Equal specificity, later
                              // wins per-property — so the REAL computed
                              // title is 16px (16.8px below 991px, not
                              // 768px), color #1E2939 (not #1E293B — was
                              // wrongly dismissed as a typo without tracing
                              // this cascade), margin-bottom 8px. Exactly
                              // matches Course Catalog's card (see docs/
                              // offline_lms_ui_audit.md).
                              //
                              // `.course-title a:hover{color:var(--primary-
                              // color)}` also exists in the stylesheet, but
                              // the real markup renders the title as a
                              // plain `<h3 class="course-title">` with no
                              // nested `<a>`, so it never actually fires.
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final fontSize =
                                        MediaQuery.sizeOf(context).width >= 991
                                            ? 16.0
                                            : 16.8;
                                    return Text(
                                      course.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF1E2939),
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
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
      // Design ref, confirmed against live computed style: .card-image-
      // wrapper uses `padding-top: 56.25%` (the generic rule, since this
      // card isn't inside .resources-block which overrides to a fixed
      // 180px) — i.e. a plain 16:9 box.
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Design ref: .modern-course-card:hover .card-image-wrapper img
          // — scale(1.05).
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
          // Design ref: the real `.progress-container` badge here is a
          // subtle thin-outline `completed.svg` (a light stroke circle
          // with small text inside, color #5457C1) rendered via a plain
          // `<img>` tag. `Image.network` can't decode SVG at all, so this
          // always fell through to a bold solid-fill purple-circle
          // fallback that reads nothing like the real subtle badge —
          // user-reported as a "big checkmark not in the web app".
          // Removed rather than approximated.
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
  // Design ref: `.modern-course-card:hover .view-course-btn` fills solid
  // purple with white text — driven by the CARD's hover.
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
          // Design ref: `.view-course-btn`'s only state changes are
          // driven by the CARD's hover (the `filled` flag above) — no
          // separate tint of its own.
          hoverColor: Colors.transparent,
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

// ─── Completed date ────────────────────────────────────────────────────────

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Design ref: .session-info .label — color #64748B, 11px/500,
        // uppercase (source text is "Completed", CSS text-transforms it),
        // letter-spacing 0.3px (was missing — matches Course Catalog's
        // card).
        Text(
          'COMPLETED',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            height: 16.5 / 11,
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: 2),
          // Design ref: .date-display — color #693D94, 13px/700, with
          // i.fas.fa-check-circle (not the calendar icon Enrolled uses).
          Row(
            children: [
              // Size bumped up from the literal CSS 10px per explicit
              // user request (a deliberate deviation, not a web-match
              // fix).
              const Icon(Icons.check_circle, size: 12, color: _purple),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _formatCompletedDate(date!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The height (line-height) multiplier otherwise adds
                  // extra leading that Flutter splits unevenly above/
                  // below the glyphs by default, visually pushing the
                  // text off-center against the icon beside it.
                  // Distributing it evenly aligns them (same fix as the
                  // "View" pill button elsewhere in the app).
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
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
      ],
    );
  }
}

// Design ref: date-display renders as e.g. "Mar 31, 2026" — abbreviated
// month, no time component (unlike the Enrolled screen's next-session date).
String _formatCompletedDate(DateTime dt) {
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
  return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
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
              child: const Icon(Icons.task_alt, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Completed Courses',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Courses you complete will appear here.',
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
