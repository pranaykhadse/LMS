import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

// # (36) + gap (12) + COURSE/CATEGORY/DUE DATE (240 min, enough for a
// course title on two lines) + gap (12) + PROGRESS (160) + the table row's
// own horizontal padding (24 each side) - the narrowest the table can go
// before it needs to scroll horizontally instead of squeezing the course
// column down to nothing (which is what silently hid its category/date
// subtitle on a phone-narrow screen).
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
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: _Header(count: state.totalCourses),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () async => notifier.fetch(page: state.page),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    const HorizontalScrollHint(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      // Squeezing the course column's Expanded into
                      // whatever's left after the fixed-width PROGRESS
                      // column on a phone-narrow screen collapsed it far
                      // enough to silently hide the category/date subtitle
                      // line entirely. Below the table's real minimum
                      // width, this scrolls horizontally instead - same
                      // columns, same widths, just pannable.
                      child: LayoutBuilder(
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
                      ),
                    ),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
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

// ─── In-page header ─────────────────────────────────────────────────────────

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
                const Icon(Icons.arrow_back, size: 14, color: _purple),
                const SizedBox(width: 6),
                Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: _purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 16, color: const Color(0xFFD1D5DB)),
        const SizedBox(width: 12),
        Text(
          'All Course Progress',
          style: GoogleFonts.inter(
            color: const Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count courses',
          style: GoogleFonts.inter(
            color: const Color(0xFF9CA3AF),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─── Table header row ────────────────────────────────────────────────────────
//
// #  |  COURSE / CATEGORY / DUE DATE  (combined, every size)  |  PROGRESS

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.inter(
      color: const Color(0xFF9CA3AF),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#', style: style)),
          Expanded(
            child: Text('COURSE / CATEGORY / DUE DATE', style: style),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 160, child: Text('PROGRESS', style: style)),
        ],
      ),
    );
  }
}

// ─── Course row ───────────────────────────────────────────────────────────────

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.index,
    required this.item,
    required this.showDivider,
  });
  final int index;
  final AllCourseProgressItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── # ──────────────────────────────────────────────────────
          SizedBox(
            width: 36,
            child: Text(
              '$index',
              style: GoogleFonts.inter(
                color: const Color(0xFF9CA3AF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // ── COURSE / CATEGORY / DUE DATE ───────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Modular.to.pushNamed(
                    CoursesModule.construct(
                        '${CoursesModule.detail}/${item.courseId}'),
                  ),
                  child: Text(
                    item.courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1F2937),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                if (item.category.isNotEmpty || item.dueDate.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.category.isNotEmpty)
                        Text(
                          item.category,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      if (item.category.isNotEmpty && item.dueDate.isNotEmpty)
                        Text(
                          '  ·  ',
                          style: GoogleFonts.inter(
                              color: const Color(0xFFD1D5DB), fontSize: 12),
                        ),
                      if (item.dueDate.isNotEmpty) ...[
                        const Icon(Icons.calendar_today_rounded,
                            size: 10, color: _purple),
                        const SizedBox(width: 4),
                        Text(
                          item.dueDate,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── PROGRESS ────────────────────────────────────────────────
          const SizedBox(width: 12),
          SizedBox(width: 160, child: _ProgressCell(percent: item.progress)),
        ],
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

// ─── Empty / error states ───────────────────────────────────────────────────

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
