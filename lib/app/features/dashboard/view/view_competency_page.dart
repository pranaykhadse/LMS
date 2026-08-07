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
          child: Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.competency.isNotEmpty ? result.competency : 'Competency',
                  style: const TextStyle(
                    color: _vcInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (result.learningPathName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.learningPathName,
                    style: const TextStyle(color: _vcMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (courses.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No courses found for this competency.',
                  style: TextStyle(color: _vcMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Container(
              color: FigmaTokens.pageBackground,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: const Row(
                children: [
                  SizedBox(width: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Course Name',
                      style: TextStyle(
                        color: _vcMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: courses.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: FigmaTokens.cardBorders),
            itemBuilder: (context, i) => _CourseRow(index: i + 1, course: courses[i]),
          ),
        ],
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.index, required this.course});
  final int index;
  final DashboardCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index',
              style: const TextStyle(color: _vcMuted, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              course.name,
              style: const TextStyle(
                color: _vcInk,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          HoverBuilder(
            builder: (context, hovering) {
              final onPressed = () => Modular.to.pushNamed(
                    CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
                  );
              final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(7));
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
                        side: BorderSide(color: _vcPurple.withValues(alpha: 0.5)),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: shape,
                        textStyle: textStyle,
                      ),
                    );
            },
          ),
        ],
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
            const Icon(Icons.error_outline, color: _vcMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _vcMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
