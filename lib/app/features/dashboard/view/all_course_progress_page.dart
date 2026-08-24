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
    // CSS ref: px-4 sm:px-6 py-6 sm:py-8
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
              state.error, 'Unable to load course progress.'),
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
        if (state.courses.isEmpty) return const _EmptyState();
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 24),
              child: _Header(count: state.totalCourses),
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
                                        const _TableHeaderRow(isWide: true),
                                        for (var i = 0; i < state.courses.length; i++)
                                          _CourseRow(
                                            index: (state.page - 1) * 100 + i + 1,
                                            item: state.courses[i],
                                            showDivider: i < state.courses.length - 1,
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

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

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
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '|',
          style: GoogleFonts.inter(
            color: const Color(0xFFD1D5DB),
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
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

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow({this.isWide = true});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      color: const Color(0xFF9CA3AF),
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      height: 16 / 11,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          SizedBox(width: isWide ? 32.0 : 24.0, child: Text('#', style: style)),
          const SizedBox(width: 24),
          Expanded(
            child: Text('COURSE / CATEGORY / DUE DATE', style: style),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: isWide ? 160.0 : 80.0,
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
          border: widget.showDivider
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
            const SizedBox(width: 24),
            // Course / Category / Due Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => Modular.to.pushNamed(
                      CoursesModule.construct(
                          '${CoursesModule.detail}/${widget.item.courseId}'),
                    ),
                    child: Text(
                      widget.item.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1F2937),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.375,
                      ),
                    ),
                  ),
                  if (widget.item.dueDate.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendarDays,
                            size: 10, color: _purple),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.item.dueDate,
                            softWrap: true,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B7280),
                              fontSize: 12,
                              height: 16 / 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Progress
            SizedBox(
              width: widget.isWide ? 160.0 : 80.0,
              child: _ProgressCell(percent: widget.item.progress),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCell extends StatelessWidget {
  const _ProgressCell({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final fraction = (percent.clamp(0, 100)) / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$percent%',
          style: GoogleFonts.inter(
            color: _purple,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
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
              child: const Icon(Icons.donut_large_rounded,
                  color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Course Progress Yet',
              style: TextStyle(
                  color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
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
