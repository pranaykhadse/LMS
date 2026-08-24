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
    // CSS ref: px-4 sm:px-6 py-6 sm:py-8
    // mobile: h=16, v=24  |  desktop(sm+): h=24, v=32
    final isWide = MediaQuery.of(context).size.width >= 600;
    final hPad = isWide ? 24.0 : 16.0;
    final vPad = isWide ? 32.0 : 24.0;

    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: friendlyErrorMessage(
              state.error, 'Unable to load in-progress courses.'),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return Column(
          children: [
            // Header — mb-6 = 24px below header
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 24),
              child: _Header(
                count: state.totalCourses,
                title: 'Course in Progress',
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () async => notifier.fetch(page: state.page),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, vPad),
                  children: [
                    if (isWide) const HorizontalScrollHint(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isWide
                          // Desktop: horizontal scroll when narrower than _minTableWidth
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = constraints.maxWidth < _minTableWidth
                                    ? _minTableWidth
                                    : constraints.maxWidth;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        const _TableHeaderRow(),
                                        for (var i = 0; i < state.courses.length; i++)
                                          _CourseRow(
                                            index: (state.page - 1) * 10 + i + 1,
                                            item: state.courses[i],
                                            showDivider: i < state.courses.length - 1,
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
// CSS ref: flex items-center gap-3 mb-6
//   Back: flex items-center gap-1.5 text-sm font-semibold text-[#693D94]
//         ArrowLeft icon 14×14
//   separator: text-gray-300 = #D1D5DB
//   title: text-sm font-semibold text-gray-800
//   count badge: text-sm text-gray-400 bg-gray-100 rounded-full px-2.5 py-0.5

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.title});
  final int count;
  final String title;

  @override
  Widget build(BuildContext context) {
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
                const Icon(LucideIcons.arrowLeft, size: 14, color: _purple),
                const SizedBox(width: 6), // gap-1.5 = 6px
                Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: _purple,
                    fontSize: 14, // text-sm
                    fontWeight: FontWeight.w600, // font-semibold
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12), // gap-3 = 12px
        // Separator "|" — text-gray-300 = #D1D5DB
        Text(
          '|',
          style: GoogleFonts.inter(
            color: const Color(0xFFD1D5DB),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
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
// CSS ref: grid grid-cols-[2rem_1fr_90px_80px] gap-6 px-4 py-3
//          border-b border-gray-100 bg-gray-50
//          text-[11px] font-semibold text-gray-400 uppercase tracking-wider

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({this.isWide = true});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      color: const Color(0xFF9CA3AF), // gray-400
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8, // tracking-wider ≈ 0.05em at 11px ≈ 0.55px, use 0.8 for wider
      height: 16 / 11,
    );

    // Narrower STATUS/ACTION on mobile so BRIDGEWORK (Expanded) gets enough room
    final statusW = isWide ? 90.0 : 80.0;
    final actionW = isWide ? 80.0 : 76.0;

    return Container(
      // px-4 py-3 = 16/12
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB), // bg-gray-50
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))), // border-gray-100
      ),
      child: Row(
        children: [
          // # column: reduced to 24px on mobile
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
          // ACTION
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
          border: widget.showDivider
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6)), // border-gray-100
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
            Expanded(child: _Bridgework(item: widget.item, disabled: viewDisabled)),
            const SizedBox(width: 24), // gap-6
            // Status pill
            SizedBox(
              width: widget.isWide ? 90.0 : 80.0,
              child: Center(child: _StatusPill(status: widget.item.status)),
            ),
            const SizedBox(width: 24), // gap-6
            // Resume button
            SizedBox(
              width: widget.isWide ? 80.0 : 76.0,
              child: Center(child: _ResumeButton(item: widget.item, disabled: viewDisabled)),
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
        GestureDetector(
          onTap: disabled
              ? null
              : () => Modular.to.pushNamed(
                    CoursesModule.construct(
                        '${CoursesModule.detail}/${item.courseId}'),
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
// CSS ref: flex items-center justify-center px-2 py-1 rounded-full
//          text-[10px] font-semibold bg-[#f0e8f7] text-[#693D94]
//          leading-tight whitespace-nowrap

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // px-2 py-1
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8F7),
        borderRadius: BorderRadius.circular(999), // rounded-full
      ),
      child: Text(
        status.isNotEmpty ? status : 'In Progress',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: _purple,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.25, // leading-tight
        ),
      ),
    );
  }
}

// ─── Resume button ────────────────────────────────────────────────────────────
// CSS ref: inline-flex items-center justify-center px-3 py-1 rounded-xl
//          text-[11px] font-semibold text-white bg-[#693D94] hover:bg-[#5a3480]
//          whitespace-nowrap

class _ResumeButton extends StatefulWidget {
  const _ResumeButton({required this.item, required this.disabled});
  final ContinueLearningListItem item;
  final bool disabled;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.disabled
        ? _purple.withValues(alpha: 0.4)
        : _hovering
            ? const Color(0xFF5A3480) // hover:bg-[#5a3480]
            : _purple;

    return MouseRegion(
      cursor: widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.disabled
            ? null
            : () => Modular.to.pushNamed(
                  CoursesModule.construct(
                      '${CoursesModule.detail}/${widget.item.courseId}'),
                ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), // px-3 py-1
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12), // rounded-xl
          ),
          alignment: Alignment.center,
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: Text(
              'Resume',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 16 / 11,
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
              child: const Icon(Icons.play_circle_outline, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No In-Progress Courses',
              style: TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
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
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted)),
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
