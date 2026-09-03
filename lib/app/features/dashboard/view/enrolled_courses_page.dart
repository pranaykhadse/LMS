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
import 'package:lms/app/features/courses/view/widgets/reviews_modal.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart';
import 'package:lms/app/features/dashboard/viewmodel/enrolled_courses_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _titleColor = Color(0xFFA20067);

/// CSS ref, confirmed against `origin/staging`'s
/// backend/views/my-required-courses/_enrolled_courses.php: `.group-item`
/// column classes — `col-lg-3 col-md-6 col-sm-12 col-12`, i.e. the SAME
/// 4/2/1-at-992/768 ladder as Course Catalog — not the shared `Responsive`
/// helper's generic 700/1024 tablet/desktop thresholds (which don't match
/// Bootstrap's real breakpoints here) with a 3-column tablet tier (should
/// be 2).
int _columnsFor(double width) {
  if (width >= 992) return 4;
  if (width >= 768) return 2;
  return 1;
}

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
      body:
          isEffectivelyOffline(ref)
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
          message: friendlyErrorMessage(
            state.error,
            'Unable to load enrolled courses.',
          ),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        // Design ref: the reference markup nests `#pagination` as the LAST
        // child of the SAME `.row` that holds the course cards — i.e. it
        // flows immediately below the grid, still inside `.structure-block`
        // (the white card), not pinned to the bottom of the viewport as a
        // separate element outside the scrollable area.
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
                    // ── White card: title + grid + pagination ──────────────
                    // Design ref: .structure-block — bg #fff, radius 16px,
                    // border 1px solid #E7E4FF (rgb(231,228,255)),
                    // padding 20px, margin-bottom (h1) 8px.
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        // CSS ref, confirmed against `origin/staging`'s
                        // dist/app.css: `.structure-block { border: 1px solid
                        // #E7E4FF }` — was wrongly 0.8px (copy-pasted from
                        // elsewhere; Course Catalog's own `.structure-block`
                        // already uses the correct default 1px).
                        border: Border.all(color: const Color(0xFFE7E4FF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Design ref: h1 — color #A20067 (rgb(162,0,103)),
                          // 24px / weight 400, line-height 28px, margin-
                          // bottom 8px.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'My Enrolled Courses',
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
                              // 56.25% (16:9) of the card's own fluid width, not
                              // a fixed pixel value — same fix as Course
                              // Catalog's grid (see docs/course-catalog-ui-audit
                              // .md). The old fixed 320/360 ignored actual card
                              // width entirely.
                              final cardWidth =
                                  (constraints.maxWidth - (columns - 1) * gap) /
                                  columns;
                              final imageHeight = cardWidth * 9 / 16;
                              // Below-image content budget: this card is the
                              // exact same `.modern-course-card` markup/CSS as
                              // Course Catalog's (session-info + rating-bar are
                              // independent there too, not either/or), so it
                              // gets the identical live-measured budget rather
                              // than a separately-derived one — was a much
                              // taller from-scratch "widest case" estimate
                              // (~204-210px) that made this screen's cards
                              // visibly taller than Course Catalog's for the
                              // same content. `Spacer()` below still absorbs
                              // slack on shorter cards.
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
                          // Design ref: #pagination — margin-top 30px from the
                          // last row of cards.
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
// this screen exactly (NOT the shared CourseGridCard used elsewhere in the
// app, whose image height / progress-ring size / button radius follow a
// different Figma spec — kept untouched so other course-list screens don't
// shift).

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

    // Design ref: `.card-link-wrapper` wraps the ENTIRE enrolled-course card
    // in a single anchor (unlike the Course Catalog, where only the "View
    // Course" pill is a link) — so tapping anywhere on the card (image,
    // title, whitespace) navigates to the course, not just the button.
    //
    // Design ref, confirmed against live CSS: `.modern-course-card:hover`
    // — translateY(-8px) lift + `--card-shadow-hover` (0 20px 40px
    // rgba(0,0,0,.12)); `.modern-course-card:hover .card-image-wrapper
    // img` — scale(1.05); `.modern-course-card:hover .view-course-btn` —
    // fills solid purple with white text. All three are driven by hovering
    // the CARD, not the button/image individually, so one HoverBuilder
    // wraps the whole thing and threads `hovering` down.
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
                // lifts (translateY) and gains a shadow — no tint. Without
                // this, InkWell's own default `hoverColor` (a grey
                // overlay from the Material theme) paints on top the
                // moment the card lifts, which has no real counterpart.
                hoverColor: Colors.transparent,
                child: Container(
                  // Design ref: .modern-course-card — radius 16px, border 1px
                  // solid rgba(0,0,0,0.03).
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                          // Design ref: .card-body-modern — padding 8px all sides.
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // CSS ref, confirmed against `origin/staging`'s
                              // _required_courses.php: these are two
                              // INDEPENDENT `<?php if ?>` blocks in the real
                              // markup, not either/or — a course with both a
                              // next session and a rating shows both, stacked.
                              // Was wrongly `if / else if`, so a rated course
                              // with an upcoming session never showed its
                              // rating at all.
                              if (course.nextSession != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: _NextSessionRow(
                                    date: course.nextSession!,
                                  ),
                                ),
                              // CSS ref: .session-info's own margin-bottom is
                              // commented out in the real stylesheet (dead —
                              // see docs/course-catalog-ui-audit.md), so no
                              // gap belongs here regardless of what follows.
                              if (course.displayRating &&
                                  course.ratingCount > 0) ...[
                                _RatingBar(
                                  rating: course.averageRating,
                                  count: course.ratingCount,
                                  courseId: course.id,
                                ),
                                // CSS ref: .rating-bar { margin: 0 0 2px }.
                                const SizedBox(height: 2),
                              ],
                              // CSS ref: `.course-title` is defined TWICE —
                              // modern-course-cards.css (18px/700, margin-
                              // bottom 6px, color var(--text-main)=#1E293B,
                              // line-height 1.4, padding 0 12px) and, loaded
                              // AFTER it in the same site-wide asset bundle
                              // (`BlueThemeAsset`, shared by every page —
                              // confirmed via `blue_main.php` -> `bluetheme_
                              // layout.php` -> `blue_base.php`, which
                              // registers it), bluetheme-layout.css (1rem/
                              // 700, color var(--card-title)=#1E2939, margin
                              // 0 0 8px — no line-height/padding of its
                              // own). Equal specificity, same page, later
                              // wins per-property — so the REAL computed
                              // title is: font-size 16px (16.8px below
                              // 991px, via bluetheme-layout.css's own `@
                              // media (max-width:991px){.course-title{font-
                              // size:1.05rem!important}}` — not 768px),
                              // weight 700, color #1E2939 (not #1E293B —
                              // this exact color was wrongly dismissed as a
                              // typo in an earlier round without tracing
                              // this cascade; see docs/course-catalog-ui-
                              // audit.md), margin-bottom 8px (not 6px),
                              // padding 0 12px/line-height 1.4 surviving
                              // from modern-course-cards.css since
                              // bluetheme-layout.css doesn't touch them.
                              // Exactly matches Course Catalog's card,
                              // which already had this right.
                              //
                              // `.course-title a:hover{color:var(--primary-
                              // color)}` exists in the stylesheet too, but
                              // the real markup (`_required_courses.php`)
                              // renders the title as a plain `<h3
                              // class="course-title">` with no nested `<a>`
                              // at all — so that selector never matches
                              // anything here and the title never changes
                              // color on hover (a dead-CSS-class trap).
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
                              // Design ref: .card-actions-modern — padding 0 12 15
                              // 12; .view-course-btn — bg #F8FAFC, color #693D94,
                              // radius 10px, border 0.8px solid #693D94, fontSize
                              // 13/600, height ~41px.
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
      // 180px) — i.e. a plain 16:9 box, not the ~334/180 approximation
      // this previously used.
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
          // Design ref: reference markup renders `.progress-container`
          // whenever the course has a next session — even at 0% progress
          // (e.g. "Introduction to Cultural Bridges", "Zig zag wallpaper
          // and baskets" both ship data-perc="0" but still show the ring).
          // Courses with no next session never get one, rating-bar or not.
          if (course.nextSession != null)
            Positioned(
              // Design ref (computed style): inset-block-end/right: 10px —
              // not 8.
              bottom: 10,
              right: 10,
              // Design ref: .progress-container — 44x44 circle, bg
              // rgba(255,255,255,.95), box-shadow 0 2px 8px rgba(0,0,0,.15),
              // padding 2px -> a 40x40 `.progress-p` inner box.
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
                // Design ref: the SVG ring is `r=30` inside a 90-unit
                // viewBox rendered at 40x40px — i.e. its real diameter is
                // only (30*2/90)*40 ≈ 26.7px, not the full 40x40 box.
                // CircularProgressIndicator fills whatever box it's given
                // edge-to-edge, so it has to be constrained to that smaller
                // size explicitly rather than left to fill the 40x40
                // `.progress-p` box — otherwise the ring reads far bigger/
                // bolder than the reference, which shows a visible white
                // margin around it.
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
  // Design ref: `.modern-course-card:hover .view-course-btn` fills solid
  // purple with white text — driven by the CARD's hover, not this
  // button's own hover, so the parent card passes this through directly
  // rather than the button tracking its own MouseRegion.
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
          // Design ref: `.view-course-btn`'s only state changes are driven
          // by the CARD's hover (the `filled` flag above) — no separate
          // tint of its own, so suppress InkWell's default hover overlay.
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
        // Design ref: .session-info .label — color #64748B, 11px, inherits
        // .session-info's own font-weight:500 (nothing on .label itself
        // overrides it), letter-spacing 0.3px (was missing — matches
        // Course Catalog's card, which already had it).
        Text(
          'NEXT SESSION',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            height: 16.5 / 11,
          ),
        ),
        const SizedBox(height: 2),
        // Design ref: .date-display — color #693D94, 13px/700, 10px
        // calendar icon.
        Row(
          children: [
            // Size bumped up from the literal CSS 10px per explicit user
            // request (a deliberate deviation, not a web-match fix).
            const Icon(Icons.calendar_today_rounded, size: 12, color: _purple),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _formatNextSession(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The height (line-height) multiplier otherwise adds
                // extra leading that Flutter splits unevenly above/below
                // the glyphs by default, visually pushing the text
                // off-center against the calendar icon beside it.
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
    );
  }
}

// CSS/markup ref, confirmed against `origin/staging`'s
// _required_courses.php: `date("M d, h:i A", $date)` — PHP's `d` is a
// zero-padded day (01-31), e.g. "Nov 05, 05:30 AM" — was missing its
// .padLeft (same bug found and fixed on Course Catalog's card, see
// docs/course-catalog-ui-audit.md).
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

class _RatingBar extends ConsumerWidget {
  const _RatingBar({
    required this.rating,
    required this.count,
    required this.courseId,
  });
  final double rating;
  final int count;
  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // CSS ref, confirmed against `origin/staging`'s modern-course-cards
    // .css (same `.rating-bar` class Course Catalog uses — see
    // docs/course-catalog-ui-audit.md): height 32px explicit (not left to
    // padding+content, which only reaches ~26px), padding 4px 12px,
    // radius 8px; stars color #FFD700 with a 1px gap between glyphs (was
    // wrongly #FFA534 with no gap); .average-rating color #1E293B (was
    // wrongly #2D3748, the Student Dashboard's own card-title color);
    // .review-count #64748B/13px (already correct).
    //
    // CSS/markup ref: the real `.rating-bar` carries `onclick=
    // "openreviewsModal(<?= $course->id ?>)"` and `.rating-bar:hover
    // {background:#f5f3ff}` — this whole card is otherwise one big
    // `<a>` link to the course, but the rating bar is its own nested
    // click target that opens the reviews modal instead of navigating.
    // Was entirely non-interactive, just decorative text.
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder:
          (context, hovering) => Material(
            color: hovering ? const Color(0xFFF5F3FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showReviewsModal(context, ref, courseId: courseId),
              // The Material `color` above already reproduces the real
              // `.rating-bar:hover{background:#f5f3ff}` — suppress
              // InkWell's own default hover overlay so it isn't doubled.
              hoverColor: Colors.transparent,
              child: Container(
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
                        child: Icon(
                          icon,
                          color: const Color(0xFFFFD700),
                          size: 18,
                        ),
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
              ),
            ),
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
                Icons.school_outlined,
                color: _purple,
                size: 52,
              ),
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
