import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/features/dashboard/model/my_course_item.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_action_repository.dart';
import 'package:lms/app/features/dashboard/viewmodel/dev_plan_membership_view_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/my_courses_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _pink = Color(0xFFB0006D);
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _lavender = Color(0xFFEFEDFB);

enum _StatusFilter { all, inProgress, completed }

class MyCoursesPage extends ConsumerStatefulWidget {
  const MyCoursesPage({super.key});

  @override
  ConsumerState<MyCoursesPage> createState() => _MyCoursesPageState();
}

class _MyCoursesPageState extends ConsumerState<MyCoursesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _filtersExpanded = false;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(MyCoursesViewModel.provider);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'My Courses',
      selectedLabel: 'My Courses',
      onRefresh: () => ref.read(MyCoursesViewModel.provider.notifier).fetch(),
      body: switch (state.state) {
        DataProviderState.idle ||
        DataProviderState.loading =>
          const Center(child: CircularProgressIndicator(color: _purple)),
        DataProviderState.error => _ErrorView(
            message: friendlyErrorMessage(state.error, 'Unable to load your courses.'),
            onRetry: () => ref.read(MyCoursesViewModel.provider.notifier).fetch(),
          ),
        DataProviderState.data => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _FiltersPanel(
                expanded: _filtersExpanded,
                onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
                searchController: _searchController,
                statusFilter: _statusFilter,
                onStatusChanged: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(height: 18),
              const _SectionHeader(title: 'My Courses'),
              const SizedBox(height: 14),
              _CoursesList(
                courses: state.data?.courses ?? const [],
                query: _query,
                statusFilter: _statusFilter,
              ),
              const AppFooter(),
            ],
          ),
      },
    );
  }
}

// ─── Filters panel ──────────────────────────────────────────────────────────

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.expanded,
    required this.onToggle,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
  });
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController searchController;
  final _StatusFilter statusFilter;
  final ValueChanged<_StatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined, color: _purple, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search courses...',
                      hintStyle: const TextStyle(color: _muted, fontSize: 14),
                      prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 22),
                      filled: true,
                      fillColor: _bg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: 'All',
                        selected: statusFilter == _StatusFilter.all,
                        onTap: () => onStatusChanged(_StatusFilter.all),
                      ),
                      _StatusChip(
                        label: 'In Progress',
                        selected: statusFilter == _StatusFilter.inProgress,
                        onTap: () => onStatusChanged(_StatusFilter.inProgress),
                      ),
                      _StatusChip(
                        label: 'Completed',
                        selected: statusFilter == _StatusFilter.completed,
                        onTap: () => onStatusChanged(_StatusFilter.completed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _purple : _lavender,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _purple,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

// ─── Courses list ────────────────────────────────────────────────────────────

class _CoursesList extends StatelessWidget {
  const _CoursesList({
    required this.courses,
    required this.query,
    required this.statusFilter,
  });
  final List<MyCourseItem> courses;
  final String query;
  final _StatusFilter statusFilter;

  @override
  Widget build(BuildContext context) {
    var filtered = courses;
    if (query.isNotEmpty) {
      filtered = filtered.where((c) => c.courseName.toLowerCase().contains(query)).toList();
    }
    switch (statusFilter) {
      case _StatusFilter.inProgress:
        filtered = filtered.where((c) => c.progress > 0 && c.progress < 100).toList();
        break;
      case _StatusFilter.completed:
        filtered = filtered.where((c) => c.progress >= 100).toList();
        break;
      case _StatusFilter.all:
        break;
    }

    if (courses.isEmpty) return const _EmptyState();
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No courses match your filters.', style: TextStyle(color: _muted)),
        ),
      );
    }

    return Column(
      children: [
        for (final course in filtered) ...[
          _CourseCard(course: course),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _CourseCard extends ConsumerStatefulWidget {
  const _CourseCard({required this.course});
  final MyCourseItem course;

  @override
  ConsumerState<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends ConsumerState<_CourseCard> {
  bool _showOverlay = false;
  bool _isBusy = false;

  Future<void> _handleDevPlanAction(bool isInPlan) async {
    final userId = ref.read(AuthStateNotifier.provider)?.user?.id;
    if (userId == null) return;

    setState(() => _isBusy = true);
    final repo = ref.read(DevelopmentPlanActionRepository.provider);
    final result = isInPlan
        ? await repo.removeFromDevPlan(courseId: widget.course.courseId)
        : await repo.addToDevPlan(courseId: widget.course.courseId);

    if (!mounted) return;
    if (result.success) {
      final membership = ref.read(DevPlanMembershipViewModel.provider.notifier);
      if (isInPlan) {
        membership.markRemoved(widget.course.courseId);
      } else {
        membership.markInPlan(widget.course.courseId);
      }
      setState(() {
        _showOverlay = false;
        _isBusy = false;
      });
      if (context.mounted) {
        Toast.success(
          context,
          isInPlan
              ? 'Course removed from My Development Plan'
              : 'Course added to My Development Plan',
        );
      }
    } else {
      setState(() {
        _isBusy = false;
        _showOverlay = false;
      });
      if (context.mounted) {
        Toast.error(context, result.message ?? 'Action failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final membership = ref.watch(DevPlanMembershipViewModel.provider);
    final isInPlan = membership.ids.contains(course.courseId);
    final viewDisabled = isViewCourseDisabled(ref, course.courseId);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                course.logo != null
                    ? Image.network(
                        course.logo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _ImgFallback(),
                      )
                    : const _ImgFallback(),
                if (membership.loaded)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _DevPlanButton(
                      isInPlan: isInPlan,
                      onTap: () => setState(() => _showOverlay = true),
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: OfflineCourseButton(
                    course: Course(
                      id: course.courseId,
                      name: course.courseName,
                      logoLink: course.logo,
                      averageRating: course.averageRating,
                      ratingCount: course.ratingCount,
                      displayRating: course.displayRating ? 1 : 0,
                    ),
                  ),
                ),
                if (_showOverlay)
                  _DevPlanOverlay(
                    isInPlan: isInPlan,
                    isBusy: _isBusy,
                    onYes: () => _handleDevPlanAction(isInPlan),
                    onNo: () => setState(() => _showOverlay = false),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: FigmaTokens.primaryPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (course.displayRating) ...[
                  _StarRow(rating: course.averageRating, count: course.ratingCount),
                  const SizedBox(height: 8),
                ],
                Text(
                  course.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: HoverBuilder(
                    builder: (context, hovering) => OutlinedButton(
                      onPressed: viewDisabled
                          ? null
                          : () => Modular.to.pushNamed(
                              CoursesModule.construct(
                                '${CoursesModule.detail}/${course.courseId}',
                              ),
                            ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                        backgroundColor: hovering
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      child: const Text('View Course'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DevPlanButton extends StatelessWidget {
  const _DevPlanButton({required this.isInPlan, required this.onTap});
  final bool isInPlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            isInPlan ? Icons.remove_rounded : Icons.add_rounded,
            color: isInPlan ? _pink : _purple,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _DevPlanOverlay extends StatelessWidget {
  const _DevPlanOverlay({
    required this.isInPlan,
    required this.isBusy,
    required this.onYes,
    required this.onNo,
  });
  final bool isInPlan;
  final bool isBusy;
  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  Widget build(BuildContext context) {
    final action = isInPlan ? 'Remove' : 'Add';
    final prep = isInPlan ? 'from' : 'to';
    return Container(
      color: const Color(0xCC5756C9),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$action this course $prep your\ndevelopment plan?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (isBusy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OverlayBtn(label: 'YES', onTap: onYes, filled: true),
                const SizedBox(width: 10),
                _OverlayBtn(label: 'NO', onTap: onNo, filled: false),
              ],
            ),
        ],
      ),
    );
  }
}

class _OverlayBtn extends StatelessWidget {
  const _OverlayBtn({required this.label, required this.onTap, required this.filled});
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? _purple : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

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
            return const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16);
          }
          if (i < rating) {
            return const Icon(Icons.star_half_rounded, color: Color(0xFFFFC107), size: 16);
          }
          return const Icon(Icons.star_border_rounded, color: Color(0xFFFFC107), size: 16);
        }),
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: _purple, size: 60),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
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
            child: const Icon(Icons.school_outlined, color: _purple, size: 52),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Courses Yet',
            style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const Text(
            'Courses you are enrolled in will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
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
            const Icon(Icons.error_outline, color: _muted, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
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
