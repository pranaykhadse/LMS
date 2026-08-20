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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: _Header(
                  count: state.totalCourses, title: 'Course in Progress'),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _purple,
                onRefresh: () async => notifier.fetch(page: state.page),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      clipBehavior: Clip.antiAlias,
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
                    const AppFooter(),
                  ],
                ),
              ),
            ),
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

// ─── In-page header ─────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.title});
  final int count;
  final String title;

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
          title,
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
// #  |  BRIDGEWORK (title + class + date, all inline)  |  STATUS  |  ACTION

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isTablet(context);
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
          Expanded(child: Text('BRIDGEWORK', style: style)),
          // Status/Action move into the Bridgework cell on phone (see
          // _CourseRow) - no separate columns to head there.
          if (isDesktop) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text('STATUS', style: style, textAlign: TextAlign.center),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text('ACTION', style: style, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Course row ───────────────────────────────────────────────────────────────

class _CourseRow extends ConsumerWidget {
  const _CourseRow({
    required this.index,
    required this.item,
    required this.showDivider,
  });
  final int index;
  final ContinueLearningListItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Responsive.isTablet(context);
    final viewDisabled = isViewCourseDisabled(ref, item.courseId);

    final bridgework = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
        // Class type and date sit on one line, separated by a dot - not
        // stacked on separate lines.
        if (item.className.isNotEmpty || item.date.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (item.className.isNotEmpty)
                Text(
                  item.className,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              if (item.className.isNotEmpty && item.date.isNotEmpty)
                Text(
                  '  ·  ',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              if (item.date.isNotEmpty) ...[
                const Icon(Icons.calendar_today_rounded, size: 10, color: _purple),
                const SizedBox(width: 4),
                Text(
                  item.date,
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
    );

    final statusPill = _StatusPill(status: item.status);
    final resumeButton = _ResumeButton(item: item, disabled: viewDisabled);

    // Fixed-width Status/Action columns only fit alongside a narrow
    // Bridgework cell on tablet+ - on phone they're appended below
    // Bridgework instead, to avoid the row overflowing.
    final leftColumn = isDesktop
        ? bridgework
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bridgework,
              const SizedBox(height: 10),
              Row(children: [statusPill, const SizedBox(width: 10), resumeButton]),
            ],
          );

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
          Expanded(child: leftColumn),
          if (isDesktop) ...[
            const SizedBox(width: 12),
            SizedBox(width: 120, child: Center(child: statusPill)),
            const SizedBox(width: 12),
            SizedBox(width: 120, child: Center(child: resumeButton)),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    // px-2 py-1 rounded-full text-[10px] font-semibold, #693D94 on #F0E8F7.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.isNotEmpty ? status : 'In Progress',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: _purple,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ResumeButton extends StatelessWidget {
  const _ResumeButton({required this.item, required this.disabled});
  final ContinueLearningListItem item;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    // Plain InkWell + Container (not ElevatedButton) - Material's button
    // widgets impose their own minimum tap-target/padding defaults on top
    // of whatever style is passed in, which kept rendering this visibly
    // larger than the inspected 80x24.5px spec no matter what padding was
    // set. This mirrors _StatusPill's own implementation so both chips are
    // sized purely by their own padding/text, guaranteed.
    // px-3 py-1 rounded-xl text-[11px] font-semibold, white on #693D94.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () => Modular.to.pushNamed(
                  CoursesModule.construct('${CoursesModule.detail}/${item.courseId}'),
                ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: disabled ? _purple.withValues(alpha: 0.4) : _purple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Resume',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
              child: const Icon(Icons.play_circle_outline,
                  color: _purple, size: 52),
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
