import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_grid_card.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/dashboard/model/dashboard.dart';
import 'package:lms/app/features/dashboard/viewmodel/development_plan_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;

class DevelopmentPlanPage extends ConsumerWidget {
  const DevelopmentPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(DevelopmentPlanViewModel.provider);
    final notifier = ref.read(DevelopmentPlanViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Development Plan',
      selectedSubLabel: 'My Development Plan',
      onRefresh: () => notifier.fetch(page: state.page),
      body: _Body(state: state, notifier: notifier),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.notifier});
  final DevelopmentPlanState state;
  final DevelopmentPlanViewModel notifier;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: state.error ?? 'Unable to load development plan.',
          onRetry: () => notifier.fetch(),
        );
      case DataProviderState.data:
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
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'My Development Plan',
                                  style: TextStyle(
                                    color: _purple,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                HoverBuilder(
                                  builder: (context, hovering) =>
                                      ElevatedButton.icon(
                                    onPressed: () => _showAddPlanItemDialog(
                                        context, notifier),
                                    icon: const Icon(Icons.add_rounded,
                                        size: 18),
                                    label: Transform.translate(
                                      offset: const Offset(0, -1),
                                      child: const Text(
                                          'Add Custom Plan Item'),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: hovering
                                          ? FigmaTokens.purpleHover
                                          : _purple,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize: const Size(0, 40),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (state.courses.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 40, bottom: 40),
                              child: _EmptyState(),
                            )
                          else ...[
                            GridView.builder(
                              padding: const EdgeInsets.all(16),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Responsive.columns(
                                  context,
                                  phone: 2,
                                  tablet: 3,
                                  desktop: 4,
                                ),
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                mainAxisExtent:
                                    Responsive.isTablet(context) ? 360 : 340,
                              ),
                              itemCount: state.courses.length,
                              itemBuilder: (ctx, i) => _CourseCard(
                                  course: state.courses[i],
                                  notifier: notifier),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: PerPageBadge(perPage: state.perPage),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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

void _showAddPlanItemDialog(BuildContext context, DevelopmentPlanViewModel notifier) {
  showDialog(
    context: context,
    builder: (dialogContext) => _AddPlanItemDialog(
      onAdd: (name) async {
        final result = await notifier.addCustomPlanItem(name);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (!context.mounted) return;
        if (result.success) {
          Toast.success(context, result.message ?? 'Plan item added successfully.');
        } else {
          Toast.error(context, result.message ?? 'Unable to add plan item.');
        }
      },
    ),
  );
}

// ─── Add custom plan item dialog ───────────────────────────────────────────────

class _AddPlanItemDialog extends StatefulWidget {
  const _AddPlanItemDialog({required this.onAdd});
  final Future<void> Function(String name) onAdd;

  @override
  State<_AddPlanItemDialog> createState() => _AddPlanItemDialogState();
}

class _AddPlanItemDialogState extends State<_AddPlanItemDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onAdd(name);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Non Course Development Plan',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter Name of Development Plan Item',
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: HoverBuilder(
                builder: (context, hovering) => ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hovering ? FigmaTokens.purpleHover : _purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: _purple.withValues(alpha: 0.6),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showUpdatePlanItemDialog(
  BuildContext context,
  DevelopmentPlanViewModel notifier,
  DashboardCourse course,
) {
  showDialog(
    context: context,
    builder: (dialogContext) => _UpdatePlanItemDialog(
      onUpdate: (percentage) async {
        final result = await notifier.updateCustomPlanItem(course.id, percentage);
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (!context.mounted) return;
        if (result.success) {
          Toast.success(context, result.message ?? 'Plan item updated successfully.');
        } else {
          Toast.error(context, result.message ?? 'Unable to update plan item.');
        }
      },
    ),
  );
}

// ─── Update custom plan item dialog ────────────────────────────────────────────

class _UpdatePlanItemDialog extends StatefulWidget {
  const _UpdatePlanItemDialog({required this.onUpdate});
  final Future<void> Function(int percentage) onUpdate;

  @override
  State<_UpdatePlanItemDialog> createState() => _UpdatePlanItemDialogState();
}

class _UpdatePlanItemDialogState extends State<_UpdatePlanItemDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final percentage = int.tryParse(_controller.text.trim());
    if (percentage == null || percentage < 0 || percentage > 100) {
      setState(() => _error = 'Enter a value between 0 and 100');
      return;
    }
    if (_submitting) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    await widget.onUpdate(percentage);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Status Update',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Status (in percentage)',
                hintStyle: const TextStyle(color: _muted, fontSize: 13),
                errorText: _error,
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: HoverBuilder(
                builder: (context, hovering) => ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hovering ? FigmaTokens.purpleHover : _purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: _purple.withValues(alpha: 0.6),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Course card ─────────────────────────────────────────────────────────────

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, required this.notifier});
  final DashboardCourse course;
  final DevelopmentPlanViewModel notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewDisabled =
        !course.isNonCourse && isViewCourseDisabled(ref, course.id);
    return CourseGridCard(
      imageUrl: course.logo,
      title: course.name,
      buttonLabel: course.isNonCourse ? 'Update' : 'View Course',
      onPressed: course.isNonCourse
          ? () => _showUpdatePlanItemDialog(context, notifier, course)
          : viewDisabled
              ? null
              : () => Modular.to.pushNamed(
                  CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
                ),
      offlineCourse: course.isNonCourse
          ? null
          : Course(
              id: course.id,
              name: course.name,
              logoLink: course.logo,
              averageRating: course.averageRating,
              ratingCount: course.ratingCount,
              displayRating: course.displayRating ? 1 : 0,
            ),
      infoSection: _buildInfoSection(course),
    );
  }

  Widget? _buildInfoSection(DashboardCourse course) {
    final showStars = course.displayRating && course.ratingCount > 0;
    final showProgress = course.progress > 0;
    if (!showStars && !showProgress) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStars) ...[
          _StarRow(rating: course.averageRating, count: course.ratingCount),
          if (showProgress) const SizedBox(height: 6),
        ],
        if (showProgress) _ProgressRow(progress: course.progress),
      ],
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress});
  final int progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 5,
            backgroundColor: const Color(0xFFE8E7F8),
            valueColor: const AlwaysStoppedAnimation<Color>(_purple),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$progress% complete',
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
      ],
    );
  }
}

// ─── Star rating ──────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15);
          }
          if (i < rating) {
            return const Icon(Icons.star_half_rounded, color: Color(0xFFFFC107), size: 15);
          }
          return const Icon(Icons.star_border_rounded, color: Color(0xFFFFC107), size: 15);
        }),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
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
              child: const Icon(Icons.timeline_outlined, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Development Plan',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your development plan courses will appear here.',
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
              RetryButton(onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}

