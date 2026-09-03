import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/horizontal_scroll_hint.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/dashboard/repository/all_course_progress_repository.dart';
import 'package:lms/app/features/dashboard/viewmodel/all_course_progress_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;

// Desktop: table scrolls horizontally below _minTableWidth. Mobile: columns flex naturally.
const _minTableWidth = 520.0;

class AllCourseProgressPage extends ConsumerWidget {
  const AllCourseProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(AllCourseProgressViewModel.provider);
    final notifier = ref.read(AllCourseProgressViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'All Course Progress',
      selectedSubLabel: 'Course Progress',
      onRefresh: () => notifier.fetch(page: state.page),
      body: _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final AllCourseProgressState state;
  final AllCourseProgressViewModel notifier;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s all-course-progress.php
    // (`<div class="cl-container cl-all-course-progress p-3">`, same
    // structure as continue-learning.php — see course_catalog audit
    // Round 20/21): Bootstrap's `.p-3` utility is `padding:1rem
    // !important`, which beats both `.cl-container`'s own padding and the
    // mobile override, leaving a flat 16px on every side, both breakpoints.
    final isWide = MediaQuery.of(context).size.width >= 600;
    const pad = 16.0;

    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load course progress.',
          ),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return Column(
          children: [
            // CSS ref: `.cl-header` margin-bottom 24px desktop; mobile
            // override replaces it with `margin: 0 2px 16px`.
            Padding(
              padding:
                  isWide
                      ? const EdgeInsets.fromLTRB(pad, pad, pad, 24)
                      : const EdgeInsets.fromLTRB(pad + 2, pad, pad + 2, 16),
              child: _Header(count: state.totalCourses, isWide: isWide),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () async => notifier.fetch(page: state.page),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(pad, 0, pad, pad),
                  children: [
                    if (isWide) const HorizontalScrollHint(),
                    // CSS ref: `.cl-card` — radius 24px/no border of its
                    // own on desktop (edge comes from Bootstrap `.card`+
                    // `.shadow-sm`); mobile override: border #E7EAF0,
                    // radius 14px, no shadow.
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isWide ? 24 : 14),
                        border: Border.all(
                          color:
                              isWide
                                  ? const Color(0xFFE5E7EB)
                                  : const Color(0xFFE7EAF0),
                        ),
                        boxShadow:
                            isWide
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.075,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          isWide
                              // Desktop: horizontal scroll when narrower than _minTableWidth
                              ? LayoutBuilder(
                                builder: (context, constraints) {
                                  final tableWidth =
                                      constraints.maxWidth < _minTableWidth
                                          ? _minTableWidth
                                          : constraints.maxWidth;
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: Column(
                                        children: [
                                          const _TableHeaderRow(isWide: true),
                                          for (
                                            var i = 0;
                                            i < state.courses.length;
                                            i++
                                          )
                                            _CourseRow(
                                              index:
                                                  (state.page - 1) * 100 +
                                                  i +
                                                  1,
                                              item: state.courses[i],
                                              showDivider:
                                                  i < state.courses.length - 1,
                                              isWide: true,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                              // Mobile: columns flex, no horizontal scroll
                              : Column(
                                children: [
                                  const _TableHeaderRow(isWide: false),
                                  for (var i = 0; i < state.courses.length; i++)
                                    _CourseRow(
                                      index: (state.page - 1) * 100 + i + 1,
                                      item: state.courses[i],
                                      showDivider: i < state.courses.length - 1,
                                      isWide: false,
                                    ),
                                ],
                              ),
                    ),
                  ],
                ),
              ),
            ),
            // Hide pagination when there's only one page
            if (state.totalPages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: PaginationWidget(
                  page: state.page,
                  pages: state.totalPages,
                  onPage: (page) => _goToPage(context, page),
                ),
              ),
            // Per explicit request: every screen should show the shared
            // footer, spanning the full window width like the header
            // above it — missing from this screen entirely before.
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

// ─── In-page header ──────────────────────────────────────────────────────────
// CSS ref, confirmed against `origin/staging`'s all-course-progress.php and
// bluetheme-layout.css: same `.cl-back-link`/`.cl-divider-vertical` as
// In-Progress Courses, but a *different* mobile back-link override here —
// weight700 only, font-size stays 14px (In-Progress's mobile back-link
// bumps to 16px; this page's doesn't). `.cl-title`/`.cl-count-text` remain
// dead for this page too — the real `<h4>`/`<span>` carry plain `text-sm
// font-semibold text-gray-800` / `text-sm text-gray-400 bg-gray-100
// rounded-full px-2.5 py-0.5`, both unconditional `text-sm` (14px) with no
// responsive variant — so the count badge should be a flat 14px on every
// width, not the invented "12px mobile / 14px desktop" split this had.

class _Header extends StatelessWidget {
  const _Header({required this.count, this.isWide = true});
  final int count;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => safePop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.arrowLeft, size: 14, color: _purple),
                const SizedBox(width: 6),
                Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: _purple,
                    fontSize: 14,
                    fontWeight: isWide ? FontWeight.w600 : FontWeight.w700,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isWide ? 12 : 14),
        // .cl-divider-vertical — 1px vertical line, #E5E7EB, height 18px
        // desktop / 24px mobile (was a "|" text glyph in the wrong color).
        Container(
          width: 1,
          height: isWide ? 18 : 24,
          color: const Color(0xFFE5E7EB),
        ),
        SizedBox(width: isWide ? 12 : 14),
        Text(
          'All Course Progress',
          style: GoogleFonts.inter(
            color: const Color(0xFF1F2937),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count courses',
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF),
              fontSize: 14, // text-sm, unconditional — no mobile variant
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Table header row ─────────────────────────────────────────────────────────
// CSS ref: `.cl-table th` — bg #F9FBFA (was #F9FAFB typo), color #99A1AF
// (was gray-400 #9CA3AF), 11px/letterSpacing.8 desktop (was a flat 10px
// on every width — 10px/.7 is only the mobile value), vertical padding
// 16px (was 12). `.cl-all-course-progress .cl-progress-column{display:
// none}` hides the PROGRESS column entirely on mobile — unlike In-
// Progress's Resume button, hiding this loses no functionality (the row
// still opens the course), so it's replicated exactly rather than kept.

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({this.isWide = true});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      color: const Color(0xFF99A1AF),
      fontSize: isWide ? 11 : 10,
      fontWeight: FontWeight.w600,
      letterSpacing: isWide ? 0.8 : 0.7,
      height: 16 / 11,
    );

    // Per explicit request: the # and PROGRESS header labels weren't
    // aligning with their column content below — same root cause as
    // the In-Progress page's header: this header's outer horizontal
    // padding was 8px (row's is 16px), and the `#`/PROGRESS columns
    // each padded themselves an extra 16px on top of their own width
    // that the row's matching columns don't have. Header now mirrors
    // the row's own padding/column widths exactly.
    return Container(
      padding:
          isWide
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 16),
      height: isWide ? null : 40,
      alignment: isWide ? null : Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBFA),
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          // # column — matches `_CourseRow`'s index column width exactly.
          SizedBox(width: isWide ? 32.0 : 24.0, child: Text('#', style: style)),
          const SizedBox(width: 16),
          Expanded(child: Text('COURSE / CATEGORY / DUE DATE', style: style)),
          const SizedBox(width: 16),
          // PROGRESS — matches `_CourseRow`'s progress column width.
          // The real site's own CSS hides this column below 767px, but a
          // live phone-width screenshot of the actual site shows it still
          // rendered there (percent + bar, right-aligned, just narrower)
          // — that screenshot overrides the stale CSS reading, so this
          // column stays visible at every width.
          SizedBox(
            width: isWide ? 140.0 : 80.0,
            child: Text('PROGRESS', style: style),
          ),
        ],
      ),
    );
  }
}

// ─── Course row ───────────────────────────────────────────────────────────────

class _CourseRow extends StatefulWidget {
  const _CourseRow({
    required this.index,
    required this.item,
    required this.showDivider,
    this.isWide = true,
  });
  final int index;
  final AllCourseProgressItem item;
  final bool showDivider;
  final bool isWide;

  @override
  State<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends State<_CourseRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _hovering ? const Color(0xFFF8F8FF) : Colors.white,
          border:
              widget.showDivider
                  ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))
                  : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Index
            SizedBox(
              width: widget.isWide ? 32.0 : 24.0,
              child: Text(
                '${widget.index}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 20 / 14,
                ),
              ),
            ),
            SizedBox(width: 16), // gap-4 — same on both mobile and desktop
            // Course / Category / Due Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CSS ref: `<div class="course-name fw-bold">` —
                  // `.cl-table .course-name` gives color var(--card-title)
                  // =#1E2939/15px/marginBottom3 (was gray-800 #1F2937/
                  // 14px, no bottom gap); `.fw-bold` is redefined by this
                  // theme to weight 600 (not Bootstrap's default 700,
                  // already matched by luck). Mobile override: 14px/
                  // lineHeight18/marginBottom4 (smaller than desktop, the
                  // same "shrinks on mobile" pattern as the page header).
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap:
                          () => Modular.to.pushNamed(
                            CoursesModule.construct(
                              '${CoursesModule.detail}/${widget.item.courseId}',
                            ),
                          ),
                      child: Text(
                        widget.item.courseName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E2939),
                          fontSize: widget.isWide ? 15 : 14,
                          fontWeight: FontWeight.w600,
                          height: widget.isWide ? 1.2 : 18 / 14,
                        ),
                      ),
                    ),
                  ),
                  if (widget.item.category.isNotEmpty ||
                      widget.item.dueDate.isNotEmpty) ...[
                    SizedBox(height: widget.isWide ? 3 : 4),
                    // CSS ref: `.cl-table .class-info` — every child
                    // (category, dot, date) is #99A1AF/13px, inherited
                    // from this one flex container (was a per-span
                    // gray-400/gray-300/gray-500 rainbow); only the
                    // calendar `<i>` icon itself gets its own explicit
                    // #6B7280/12px (`text-xs text-gray-500`). Mobile:
                    // 12px/lineHeight16, wraps.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5, // gap:5px
                      runSpacing: 2,
                      children: [
                        if (widget.item.category.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.item.category,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF99A1AF),
                                  fontSize: widget.isWide ? 13 : 12,
                                  height: widget.isWide ? 1.2 : 16 / 12,
                                ),
                              ),
                              if (widget.item.dueDate.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '·',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF99A1AF),
                                    fontSize: widget.isWide ? 13 : 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (widget.item.dueDate.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendarDays,
                                size: 10,
                                color: _purple,
                              ),
                              const SizedBox(width: 4), // gap-1
                              Flexible(
                                child: Text(
                                  widget.item.dueDate,
                                  softWrap: true,
                                  style: GoogleFonts.inter(
                                    color: const Color(
                                      0xFF6B7280,
                                    ), // text-xs text-gray-500
                                    fontSize: 12,
                                    height: 16 / 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // CSS ref: `.cl-all-course-progress .cl-progress-column
            // {display:none}` claims this is hidden below 767px, but a
            // live phone-width screenshot of the real site shows the
            // percent + bar still rendered there (just a narrower
            // column) — trusting that screenshot over the stale CSS
            // reading, so this always renders now.
            const SizedBox(width: 16),
            SizedBox(
              width: widget.isWide ? 140.0 : 80.0,
              child: _ProgressCell(
                percent: widget.item.progress,
                isWide: widget.isWide,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCell extends StatelessWidget {
  const _ProgressCell({required this.percent, this.isWide = true});
  final int percent;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // CSS ref: `.cl-progress-percent` — 13px/weight700/var(--primary-
        // color), margin-bottom 6px (was 12px/weight600, gap 4).
        Text(
          '$percent%',
          style: GoogleFonts.inter(
            color: _purple,
            fontSize: isWide ? 13 : 12,
            fontWeight: FontWeight.w700,
            height: 16 / 13,
          ),
        ),
        const SizedBox(height: 6),
        // w-full bg-gray-100 rounded-full h-1.5
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6, // h-1.5 = 6px
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: const AlwaysStoppedAnimation<Color>(_purple),
          ),
        ),
      ],
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

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
                Icons.donut_large_rounded,
                color: _purple,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Course Progress Yet',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your course progress will appear here once you enroll in a course.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

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
