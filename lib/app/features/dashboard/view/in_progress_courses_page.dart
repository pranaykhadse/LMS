import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/horizontal_scroll_hint.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/dashboard/repository/continue_learning_list_repository.dart';
import 'package:lms/app/features/dashboard/viewmodel/continue_learning_list_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;

// Desktop: table scrolls horizontally below _minTableWidth. Mobile: columns flex naturally.
const _minTableWidth = 600.0;

class InProgressCoursesPage extends ConsumerWidget {
  const InProgressCoursesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ContinueLearningListViewModel.provider);
    final notifier = ref.read(ContinueLearningListViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Course in Progress',
      selectedSubLabel: 'Continue Learning',
      onRefresh: () => notifier.fetch(page: state.page),
      body: _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final ContinueLearningListState state;
  final ContinueLearningListViewModel notifier;

  @override
  Widget build(BuildContext context) {
    // CSS ref: the real page is `<div class="cl-container cl-continue-
    // learning p-3">` — Bootstrap's `.p-3` utility is `padding: 1rem
    // !important`, which beats both `.cl-container`'s own `padding:
    // var(--spacing-lg) var(--spacing-xl)` (24/32 desktop) and
    // `.cl-continue-learning`'s mobile override (`20px 0 28px`) regardless
    // of source order, since neither carries `!important`. The effective
    // real padding is a flat 16px on every side, both breakpoints — not
    // the swapped/breakpoint-varying h/v values this used to assume.
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
            'Unable to load in-progress courses.',
          ),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return Column(
          children: [
            // CSS ref: `.cl-header` margin-bottom: var(--spacing-lg) = 24px
            // desktop; the mobile override replaces this with `margin: 0
            // 2px 16px` instead (a near-zero 2px horizontal inset, not the
            // container's own 16px).
            Padding(
              padding:
                  isWide
                      ? const EdgeInsets.fromLTRB(pad, pad, pad, 24)
                      : const EdgeInsets.fromLTRB(pad + 2, pad, pad + 2, 16),
              child: _Header(
                count: state.totalCourses,
                title: 'Course in Progress',
                isWide: isWide,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () async => notifier.fetch(page: state.page),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(pad, 0, pad, pad),
                  children: [
                    if (isWide) const HorizontalScrollHint(),
                    // CSS ref: `<div class="card cl-card shadow-sm">` —
                    // `.cl-card` itself sets only radius 24px/overflow-
                    // hidden/white bg on desktop (no border of its own);
                    // the visible edge comes from Bootstrap's `.card`
                    // default border + `.shadow-sm`'s subtle shadow. The
                    // `@media (max-width:767px)` override replaces both
                    // with its own explicit border (#E7EAF0), radius 14px,
                    // and `box-shadow:none`.
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
                                          const _TableHeaderRow(),
                                          for (
                                            var i = 0;
                                            i < state.courses.length;
                                            i++
                                          )
                                            _CourseRow(
                                              index:
                                                  (state.page - 1) * 10 + i + 1,
                                              item: state.courses[i],
                                              showDivider:
                                                  i < state.courses.length - 1,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                              // Mobile: columns flex, title wraps — no horizontal scroll
                              : Column(
                                children: [
                                  const _TableHeaderRow(isWide: false),
                                  for (var i = 0; i < state.courses.length; i++)
                                    _CourseRow(
                                      index: (state.page - 1) * 10 + i + 1,
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
// CSS ref, confirmed against `origin/staging`'s continue-learning.php and
// bluetheme-layout.css:
//   `.cl-back-link` — color var(--primary-color)=#693D94, weight600,
//     14px desktop; mobile override bumps this to 16px/weight700 (both the
//     text AND the `<i>` arrow icon scale with it, since the icon's size
//     is just inherited font-size).
//   `.cl-divider-vertical` — a real 1px vertical line (border-left, color
//     var(--card-border)=#E5E7EB), height 18px desktop/24px mobile — NOT
//     a "|" text glyph in gray-300, which was neither the right technique
//     nor the right color (that class is genuinely used by this page's
//     markup, unlike `.cl-title`/`.cl-count-text` below).
//   title/count badge: these do NOT use `.cl-title`/`.cl-count-text` (real,
//     but dead for this specific page's markup) — the actual `<h4>`/`<span>`
//     carry plain `text-sm font-semibold text-gray-800` / `text-sm text-
//     gray-400 bg-gray-100 rounded-full px-2.5 py-0.5`, exactly what was
//     already implemented below - left unchanged.

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.title, this.isWide = true});
  final int count;
  final String title;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final backFontSize = isWide ? 14.0 : 16.0;
    final backWeight = isWide ? FontWeight.w600 : FontWeight.w700;
    return Row(
      children: [
        // Back button
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => safePop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.arrowLeft, size: backFontSize, color: _purple),
                const SizedBox(width: 6), // gap-1.5 = 6px
                Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: _purple,
                    fontSize: backFontSize,
                    fontWeight: backWeight,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: isWide ? 12 : 14), // mx-3=12 desktop, 14 mobile
        // .cl-divider-vertical — 1px vertical line, #E5E7EB, height
        // 18px desktop / 24px mobile.
        Container(
          width: 1,
          height: isWide ? 18 : 24,
          color: const Color(0xFFE5E7EB),
        ),
        SizedBox(width: isWide ? 12 : 14),
        // Title — text-sm font-semibold text-gray-800 = #1F2937
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFF1F2937),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 20 / 14,
          ),
        ),
        const SizedBox(width: 8), // visual spacing before badge
        // Count badge — bg-gray-100 rounded-full px-2.5 py-0.5 text-sm text-gray-400
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6), // gray-100
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count courses',
            style: GoogleFonts.inter(
              color: const Color(0xFF9CA3AF), // gray-400
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Table header row ─────────────────────────────────────────────────────────
// CSS ref: `.cl-table th` — bg #F9FBFA (was #F9FAFB, a transposed-letter
// typo), color var(--close-btn-gray)=#99A1AF !important (was gray-400
// #9CA3AF, a different real token), padding-top/bottom 16px (was 12),
// 11px/weight600/letter-spacing .8px unchanged. Horizontal padding follows
// Bootstrap's default table-cell padding (~8px) except the real markup's
// `ps-4`/`pe-4` utilities (24px) on the # and ACTION columns specifically.
// Mobile override: height 40px fixed, `padding:0 8px`, 10px/letter-spacing
// .7px (both smaller than desktop).

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

    // Narrower STATUS/ACTION on mobile so BRIDGEWORK (Expanded) gets enough room
    final statusW = isWide ? 90.0 : 80.0;
    final actionW = isWide ? 80.0 : 76.0;

    // Per explicit request: STATUS/ACTION/# header labels weren't
    // aligning with their column content below. Root cause was two
    // mismatches against `_CourseRow`'s own layout: this header's outer
    // horizontal padding was 8px (row's is 16px), and the `#`/ACTION
    // columns each padded themselves an extra 16px on top of their own
    // width (`32.0 + 16`/`actionW + 16` plus an inner `Padding`) that
    // the row's matching columns don't have — both differences
    // cascade through the shared `Expanded` BRIDGEWORK column and shift
    // every column after it out of alignment. Header now mirrors the
    // row's own padding/column widths exactly, with no per-column
    // extras — the outer `Container` padding alone provides the outer
    // page-edge inset.
    return Container(
      padding:
          isWide
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 16),
      height: isWide ? null : 40,
      alignment: isWide ? null : Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBFA),
        border: Border(
          bottom: BorderSide(color: Color(0xFFF3F4F6)),
        ), // border-gray-100
      ),
      child: Row(
        children: [
          // # column — matches `_CourseRow`'s index column width exactly.
          SizedBox(width: isWide ? 32.0 : 24.0, child: Text('#', style: style)),
          const SizedBox(width: 24), // gap-6
          // BRIDGEWORK: flex-1
          Expanded(child: Text('BRIDGEWORK', style: style)),
          const SizedBox(width: 24), // gap-6
          // STATUS
          SizedBox(
            width: statusW,
            child: Text('STATUS', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 24), // gap-6
          // ACTION — matches `_CourseRow`'s Resume-button column width.
          SizedBox(
            width: actionW,
            child: Text('ACTION', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ─── Course row ───────────────────────────────────────────────────────────────
// CSS ref: grid grid-cols-[2rem_1fr_90px_80px] gap-6 px-4 py-4
//          border-b border-gray-100 hover:bg-[#f8f8ff] items-center

class _CourseRow extends ConsumerStatefulWidget {
  const _CourseRow({
    required this.index,
    required this.item,
    required this.showDivider,
    this.isWide = true,
  });
  final int index;
  final ContinueLearningListItem item;
  final bool showDivider;
  final bool isWide;

  @override
  ConsumerState<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends ConsumerState<_CourseRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final viewDisabled = isViewCourseDisabled(ref, widget.item.courseId);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // px-4 py-4 = 16/16
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          // hover:bg-[#f8f8ff]
          color: _hovering ? const Color(0xFFF8F8FF) : Colors.white,
          border:
              widget.showDivider
                  ? const Border(
                    bottom: BorderSide(
                      color: Color(0xFFF3F4F6),
                    ), // border-gray-100
                  )
                  : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Index — text-sm text-gray-400 font-medium
            SizedBox(
              width: widget.isWide ? 32.0 : 24.0,
              child: Text(
                '${widget.index}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9CA3AF), // gray-400
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 20 / 14,
                ),
              ),
            ),
            const SizedBox(width: 24), // gap-6
            // Bridgework column
            Expanded(
              child: _Bridgework(item: widget.item, disabled: viewDisabled),
            ),
            const SizedBox(width: 24), // gap-6
            // Status pill
            SizedBox(
              width: widget.isWide ? 90.0 : 80.0,
              child: Center(
                child: _StatusPill(
                  status: widget.item.status,
                  isWide: widget.isWide,
                ),
              ),
            ),
            const SizedBox(width: 24), // gap-6
            // Resume button
            SizedBox(
              width: widget.isWide ? 80.0 : 76.0,
              child: Center(
                child: _ResumeButton(
                  item: widget.item,
                  disabled: viewDisabled,
                  isWide: widget.isWide,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bridgework cell ──────────────────────────────────────────────────────────
// title: text-sm font-semibold text-gray-800 leading-snug line-clamp-2
// type: text-xs text-gray-400
// dot: text-gray-300
// calendar icon: lucide CalendarDays 10×10 text-[#693D94]
// date: text-xs text-gray-500

class _Bridgework extends ConsumerWidget {
  const _Bridgework({required this.item, required this.disabled});
  final ContinueLearningListItem item;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor:
              disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: GestureDetector(
            onTap:
                disabled
                    ? null
                    : () => Modular.to.pushNamed(
                      CoursesModule.construct(
                        '${CoursesModule.detail}/${item.courseId}',
                      ),
                    ),
            child: Text(
              item.courseName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF1F2937), // gray-800
                fontSize: 14, // text-sm
                fontWeight: FontWeight.w600, // font-semibold
                height: 1.375, // leading-snug
              ),
            ),
          ),
        ),
        if (item.className.isNotEmpty || item.date.isNotEmpty) ...[
          const SizedBox(height: 2), // mt-0.5
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8, // gap-x-2
            runSpacing: 2, // gap-y-0.5
            children: [
              if (item.className.isNotEmpty)
                Text(
                  item.className,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF), // gray-400, text-xs
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
              if (item.className.isNotEmpty && item.date.isNotEmpty)
                Text(
                  '·',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFD1D5DB), // gray-300
                    fontSize: 12,
                  ),
                ),
              if (item.date.isNotEmpty)
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
                        item.date,
                        softWrap: true,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6B7280), // gray-500, text-xs
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
    );
  }
}

// ─── Status pill ──────────────────────────────────────────────────────────────
// CSS ref: `.cl-status-badge` — bg var(--primary-light)=#F0E8F7, color
// var(--primary-color)=#693D94 (both already matched), padding 6px 14px,
// radius 50px, 12px/weight600 (was 8px/4px padding and a flat 10px font -
// only the mobile override is actually 10px). Mobile override: padding
// 5px 12px, 10px/lineHeight12.

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.isWide = true});
  final String status;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          isWide
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8F7),
        borderRadius: BorderRadius.circular(999), // rounded-full
      ),
      child: Text(
        status.isNotEmpty ? status : 'In Progress',
        textAlign: TextAlign.center,
        // Must never wrap — the fixed-width column (90/80px) is tight
        // enough at this font size that "In Progress" would otherwise
        // break across two lines.
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: GoogleFonts.inter(
          color: _purple,
          fontSize: isWide ? 12 : 10,
          fontWeight: FontWeight.w600,
          height: isWide ? 1.25 : 12 / 10,
        ),
      ),
    );
  }
}

// ─── Resume button ────────────────────────────────────────────────────────────
// CSS ref: `<a class="btn-pill btn-pill-sm">` — base `.btn-pill` (bg
// var(--primary-color), white text, hover var(--primary-dark) — already
// matched) sized by `.btn-pill-sm`: padding 6px 16px, 0.8rem≈13px,
// weight600, radius 14px (was 12px 4px padding, 11px, radius12). The real
// `.cl-action-column{display:none}` hides this whole column on mobile —
// this app keeps it visible there instead (with slightly tighter padding
// to fit the narrower slot) since there's no other way to resume a course
// from this screen on mobile web either; an app-only necessity, not a
// literal spec deviation for its own sake.

class _ResumeButton extends StatefulWidget {
  const _ResumeButton({
    required this.item,
    required this.disabled,
    this.isWide = true,
  });
  final ContinueLearningListItem item;
  final bool disabled;
  final bool isWide;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.disabled
            ? _purple.withValues(alpha: 0.4)
            : _hovering
            ? const Color(0xFF5A3480) // hover:bg-[#5a3480]
            : _purple;

    return MouseRegion(
      cursor:
          widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap:
            widget.disabled
                ? null
                : () => Modular.to.pushNamed(
                  CoursesModule.construct(
                    '${CoursesModule.detail}/${widget.item.courseId}',
                  ),
                ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding:
              widget.isWide
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: Text(
              'Resume',
              textAlign: TextAlign.center,
              // Must never wrap — the fixed-width column (80/76px) is
              // tight enough at this font size that "Resume" would
              // otherwise break into "Resum"/"e".
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13, // 0.8rem
                fontWeight: FontWeight.w600,
                height: 16 / 13,
              ),
            ),
          ),
        ),
      ),
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
                Icons.play_circle_outline,
                color: _purple,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No In-Progress Courses',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Courses you start will appear here so you can pick up where you left off.',
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
