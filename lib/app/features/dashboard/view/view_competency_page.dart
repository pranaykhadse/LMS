import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/model/view_competency.dart';
import 'package:lms/app/features/dashboard/viewmodel/view_competency_view_model.dart';

const _vcPurple = FigmaTokens.primaryPurple;
const _vcInk = FigmaTokens.cardTitles;
const _vcMuted = FigmaTokens.noteBodyText;
const _vcBg = FigmaTokens.pageBackground;

class ViewCompetencyPage extends ConsumerWidget {
  const ViewCompetencyPage({
    super.key,
    required this.learningPathId,
    required this.competency,
  });

  final int learningPathId;
  final String competency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ViewCompetencyArgs(
      learningPathId: learningPathId,
      competency: competency,
    );
    final state = ref.watch(ViewCompetencyViewModel.provider(args));

    return AppScaffold(
      backgroundColor: _vcBg,
      title: competency,
      onRefresh: () =>
          ref.read(ViewCompetencyViewModel.provider(args).notifier).fetch(),
      body: switch (state.state) {
        DataProviderState.idle ||
        DataProviderState.loading =>
          const Center(child: CircularProgressIndicator(color: _vcPurple)),
        DataProviderState.error => _ErrorView(
            message: state.error ?? 'Unable to load competency details.',
            onRetry: () => ref
                .read(ViewCompetencyViewModel.provider(args).notifier)
                .fetch(),
          ),
        DataProviderState.data => state.data == null
            ? const _ErrorView(message: 'No competency details found.')
            : _Body(result: state.data!),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.result});
  final ViewCompetencyResult result;

  @override
  Widget build(BuildContext context) {
    final courses = result.courses;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    child: Text(
                      result.competency.isNotEmpty ? result.competency : 'Competency',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _vcInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (courses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No courses found for this competency.',
                        style: TextStyle(color: _vcMuted, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    _CourseTable(courses: courses),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }
}

class _CourseTable extends StatelessWidget {
  const _CourseTable({required this.courses});
  final List<DashboardCourse> courses;

  @override
  Widget build(BuildContext context) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        top: BorderSide(color: FigmaTokens.cardBorders),
        bottom: BorderSide(color: FigmaTokens.cardBorders),
        horizontalInside: BorderSide(color: FigmaTokens.cardBorders),
        verticalInside: BorderSide(color: FigmaTokens.cardBorders),
      ),
      columnWidths: const {
        0: FixedColumnWidth(56),
        1: FlexColumnWidth(6),
        2: FlexColumnWidth(3),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFEEEEEE)],
            ),
          ),
          children: [
            SizedBox(height: 44),
            Center(
              child: Text(
                'Course Name',
                style: TextStyle(color: _vcPurple, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox.shrink(),
          ],
        ),
        for (var i = 0; i < courses.length; i++)
          TableRow(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: _vcPurple, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Text(
                    courses[i].name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _vcInk,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              Center(child: _ViewButton(course: courses[i])),
            ],
          ),
      ],
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({required this.course});
  final DashboardCourse course;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hovering) {
        final onPressed = () => Modular.to.pushNamed(
              CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
            );
        const shape = StadiumBorder();
        const textStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5);
        return hovering
            ? ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 15, color: Colors.white),
                label: const Text('View'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _vcPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: shape,
                  textStyle: textStyle,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 15),
                label: const Text('View'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _vcPurple,
                  side: const BorderSide(color: _vcPurple),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: shape,
                  textStyle: textStyle,
                ),
              );
      },
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
            const Icon(Icons.error_outline, color: _vcMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _vcMuted),
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
