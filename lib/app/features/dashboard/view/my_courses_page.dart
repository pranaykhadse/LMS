import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/utils/dev_image_proxy.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/course_image_fallback.dart';
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
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _lavender = Color(0xFFEFEDFB);
// CSS ref: `--primary-second` / `#my-courses .sec-title h2`.
const _titleColor = Color(0xFFA20067);

enum _StatusFilter { all, inProgress, completed }

// CSS ref: `myCourses.php`'s `itemOptions` — `col-lg-3 col-md-6 col-sm-12
// col-12`, the same 4/2/1-at-992/768 ladder every other My Courses screen
// uses.
int _columnsFor(double width) {
  if (width >= 992) return 4;
  if (width >= 768) return 2;
  return 1;
}

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
        DataProviderState.idle || DataProviderState.loading => const Center(
          child: CircularProgressIndicator(color: _purple),
        ),
        DataProviderState.error => _ErrorView(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load your courses.',
          ),
          onRetry: () => ref.read(MyCoursesViewModel.provider.notifier).fetch(),
        ),
        // Per explicit request: the footer should span the full window
        // width on every screen, like the header above it — it was the
        // last child of this ListView, inheriting the ListView's own
        // horizontal `padding` instead of running edge to edge.
        DataProviderState.data => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // CSS ref: the real page's filter panel is `_searchCatalogue.
                  // php` — the same 5-field Search/Strategic Imperative/
                  // Competencies/Skills/Calendar panel Course Catalog uses.
                  // The mobile `my-courses` endpoint only accepts `page`/
                  // `limit` (confirmed against `LmsScreenController::
                  // actionMyCourses`'s @SWG doc — no search/filter params at
                  // all), so that panel can't actually be wired here without a
                  // backend addition; kept as this simplified client-side
                  // search+status-filter substitute rather than building
                  // non-functional UI for fields nothing can filter by yet.
                  _FiltersPanel(
                    expanded: _filtersExpanded,
                    onToggle:
                        () => setState(
                          () => _filtersExpanded = !_filtersExpanded,
                        ),
                    searchController: _searchController,
                    statusFilter: _statusFilter,
                    onStatusChanged: (v) => setState(() => _statusFilter = v),
                  ),
                  const SizedBox(height: 18),
                  // CSS ref: `#resources` — white bg, border 1px #E7E4FF,
                  // radius 14px, padding 30px (was a plain radius-14 white
                  // card with no matching padding/border spec cited, and the
                  // grid/title lived loose in the page rather than inside this
                  // wrapper).
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE7E4FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CSS ref: `#resources .sec-title h2` — 24px/weight400/
                        // lineHeight28, color var(--primary-second)=#A20067,
                        // margin-bottom 20px (was a 4px accent bar + 20px/900
                        // heading with a 14px gap after — an invented "section
                        // header" pattern from elsewhere in the app, not this
                        // real page's own title).
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Text(
                            'My Courses',
                            style: GoogleFonts.inter(
                              color: _titleColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              height: 28 / 24,
                            ),
                          ),
                        ),
                        _CoursesList(
                          courses: state.data?.courses ?? const [],
                          query: _query,
                          statusFilter: _statusFilter,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
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
                  const Icon(
                    Icons.filter_alt_outlined,
                    color: _purple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                    ),
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
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _muted,
                        size: 22,
                      ),
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
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
      ),
    );
  }
}

// ─── Section header ─────────────────────────────────────────────────────────

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
      filtered =
          filtered
              .where((c) => c.courseName.toLowerCase().contains(query))
              .toList();
    }
    switch (statusFilter) {
      case _StatusFilter.inProgress:
        filtered =
            filtered.where((c) => c.progress > 0 && c.progress < 100).toList();
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
          child: Text(
            'No courses match your filters.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }

    // CSS ref: `_courseContainer.php` cards laid out via Bootstrap's
    // `col-lg-3 col-md-6 col-sm-12` grid (see `_columnsFor`) with the
    // framework's default 30px gutter — was a single-column vertical list
    // of full-width cards, which the real page never renders at any
    // width above 768px.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(MediaQuery.sizeOf(context).width);
        const gap = 30.0;
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final imageHeight = cardWidth * 9 / 16;
        // Below-image content budget: this is the exact same `.modern-
        // course-card` markup/CSS as Course Catalog's, so it gets the
        // identical live-measured budget rather than a separately-
        // derived one (see docs/course-catalog-ui-audit.md) — keeps
        // this screen's card height pixel-identical to Course
        // Catalog's for the same content. `Spacer()` on the card
        // absorbs slack when session-info/rating-bar are absent.
        final contentBudget = columns == 4 ? 172.0 : 200.0;
        final extent = imageHeight + contentBudget;
        final rows = (filtered.length / columns).ceil();
        final gridHeight = rows * extent + (rows - 1) * gap;
        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              mainAxisExtent: extent,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) => _CourseCard(course: filtered[i]),
          ),
        );
      },
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
    final result =
        isInPlan
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
        Toast.error(
          context,
          result.message ?? 'Action failed. Please try again.',
        );
      }
    }
  }

  // CSS ref: `_courseContainer.php` is the exact same `.modern-course-
  // card` partial Course Catalog and every other My Courses tab render
  // (see `required_courses_page.dart`'s `_CourseCard`, ported here) —
  // white card, session-info/rating-bar/title stacked in a plain white
  // body, outlined "View Course" pill. Was a bespoke design with a solid
  // purple footer bar behind the rating/title/button — a different card
  // entirely, not a mis-tuned value.
  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final membership = ref.watch(DevPlanMembershipViewModel.provider);
    final isInPlan = membership.ids.contains(course.courseId);
    final viewDisabled = isViewCourseDisabled(ref, course.courseId);
    final onTap =
        viewDisabled
            ? null
            : () => Modular.to.pushNamed(
              CoursesModule.construct(
                '${CoursesModule.detail}/${course.courseId}',
              ),
            );

    // CSS ref: `.modern-course-card:hover` — translateY(-8px) + shadow;
    // `:hover img` — scale(1.05); `:hover .view-course-btn` — fills solid
    // purple. One HoverBuilder drives all three, same as every other My
    // Courses card.
    return HoverBuilder(
      builder:
          (context, hovering) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0, hovering ? -8 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  hovering
                      ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ]
                      : null,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                // Design ref: the real `.modern-course-card:hover` only
                // lifts (translateY) and gains a shadow — no tint, so
                // suppress InkWell's own default hover overlay.
                hoverColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.03),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              scale: hovering ? 1.05 : 1.0,
                              child:
                                  course.logo != null
                                      ? Image.network(
                                        devProxiedImageUrl(course.logo!),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                const _ImgFallback(),
                                      )
                                      : const _ImgFallback(),
                            ),
                            // App-only: offline-save, top-left (the real card
                            // has no such button; kept per the standing rule
                            // to preserve app-only features).
                            Positioned(
                              top: 8,
                              left: 8,
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
                            // CSS ref: `.dev-plan-action` — position absolute
                            // top:12/right:12.
                            if (membership.loaded)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: _DevPlanButton(
                                  isInPlan: isInPlan,
                                  onTap:
                                      () => setState(() => _showOverlay = true),
                                ),
                              ),
                            if (_showOverlay)
                              _DevPlanOverlay(
                                isInPlan: isInPlan,
                                isBusy: _isBusy,
                                onYes: () => _handleDevPlanAction(isInPlan),
                                onNo:
                                    () => setState(() => _showOverlay = false),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (course.nextSession != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: _NextSessionRow(
                                    date: course.nextSession!,
                                  ),
                                ),
                              if (course.displayRating &&
                                  course.ratingCount > 0) ...[
                                _RatingBar(
                                  rating: course.averageRating,
                                  count: course.ratingCount,
                                ),
                                const SizedBox(height: 2),
                              ],
                              // CSS ref: `.course-title` is defined TWICE —
                              // modern-course-cards.css (18px/700, margin-
                              // bottom 6px, color var(--text-main)=#1E293B)
                              // and, loaded AFTER it in the same site-wide
                              // asset bundle (`BlueThemeAsset`, shared by
                              // every page), bluetheme-layout.css (1rem/
                              // 700, color var(--card-title)=#1E2939,
                              // margin 0 0 8px). Equal specificity, later
                              // wins per-property — so the REAL computed
                              // title is 16px (16.8px below 991px, not
                              // 768px), color #1E2939 (not #1E293B — was
                              // wrongly dismissed as a typo without tracing
                              // this cascade), margin-bottom 8px. Exactly
                              // matches Course Catalog's card (see docs/
                              // course-catalog-ui-audit.md).
                              //
                              // `.course-title a:hover{color:var(--primary-
                              // color)}` also exists in the stylesheet, but
                              // the real markup renders the title as a
                              // plain `<h3 class="course-title">` with no
                              // nested `<a>`, so it never actually fires.
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final fontSize =
                                        MediaQuery.sizeOf(context).width >= 991
                                            ? 16.0
                                            : 16.8;
                                    return Text(
                                      course.courseName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF1E2939),
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w700,
                                        height: 1.4,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  15,
                                ),
                                child: _ViewCourseButton(
                                  onPressed: onTap,
                                  filled: hovering,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

// CSS ref: `.plus-icon, .minus-icon` — 36x36 circle, white@90%+blur bg,
// purple icon always (both add/remove share the same color — was 30x30
// solid white/no-blur, and used a pink tint for the remove state that
// doesn't exist in the real CSS).
class _DevPlanButton extends StatelessWidget {
  const _DevPlanButton({required this.isInPlan, required this.onTap});
  final bool isInPlan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Material(
          color: Colors.white.withValues(alpha: 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                isInPlan ? Icons.remove_rounded : Icons.add_rounded,
                color: _purple,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// CSS ref: `.overlay` — absolute, full card, `backdrop-filter: blur(8px)`
// (no solid tint of its own), padding 15px; `.overlay p` — 15px/weight600,
// margin-bottom 25px (was a solid `#CC5756C9` tint with no blur, 13px/700
// text and only a 12px gap).
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withValues(alpha: 0.15),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$action this course $prep your development plan?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 25),
            if (isBusy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _OverlayBtn(label: 'YES', onTap: onYes),
                  const SizedBox(width: 10),
                  _OverlayBtn(label: 'NO', onTap: onNo),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// CSS ref: `.overlay_btn` — white bg, purple text, radius 12, padding 8px
// 20px, 13px/weight700/uppercase/letterSpacing .5px, shadow. Both YES and
// NO share this one style in the real CSS — was a filled-white/outline-
// white distinction between them that doesn't exist.
class _OverlayBtn extends StatelessWidget {
  const _OverlayBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _purple,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── View Course button ─────────────────────────────────────────────────────
// CSS ref: `.view-course-btn` — border 1px purple, radius 10, 41px tall;
// `.modern-course-card:hover .view-course-btn` fills solid purple with
// white text, driven by the CARD's hover (ported from
// `required_courses_page.dart`'s identical button rather than the shared
// `ViewCourseButton` widget, which drives its own independent hover).
class _ViewCourseButton extends StatelessWidget {
  const _ViewCourseButton({required this.onPressed, this.filled = false});
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 41,
      child: Material(
        color:
            disabled
                ? const Color(0xFFF8FAFC).withValues(alpha: 0.5)
                : (filled ? _purple : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          // Design ref: `.view-course-btn`'s only state changes are
          // driven by the CARD's hover (the `filled` flag above) — no
          // separate tint of its own.
          hoverColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _purple.withValues(alpha: disabled ? 0.3 : 1),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'View Course',
              style: GoogleFonts.inter(
                color:
                    disabled
                        ? _purple.withValues(alpha: 0.4)
                        : (filled ? Colors.white : _purple),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 19.5 / 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Next session ───────────────────────────────────────────────────────────

class _NextSessionRow extends StatelessWidget {
  const _NextSessionRow({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // CSS ref: .session-info .label — letter-spacing 0.3px (was
        // missing — matches Course Catalog's card).
        Text(
          'NEXT SESSION',
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            height: 16.5 / 11,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            // Size bumped up from the literal CSS 10px per explicit user
            // request (a deliberate deviation, not a web-match fix).
            const Icon(Icons.calendar_today_rounded, size: 12, color: _purple),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _formatNextSession(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The height (line-height) multiplier otherwise adds
                // extra leading that Flutter splits unevenly above/below
                // the glyphs by default, visually pushing the text
                // off-center against the calendar icon beside it.
                // Distributing it evenly aligns them (same fix as the
                // "View" pill button elsewhere in the app).
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: GoogleFonts.inter(
                  color: _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 19.5 / 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _formatNextSession(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final hourStr = hour12.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final day = dt.day.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} $day, $hourStr:$minute $ampm';
}

// ─── Star rating ──────────────────────────────────────────────────────────────
// CSS ref: `.rating-bar` — height 32px, padding 4px 12px; stars color
// #FFD700 with a 1px gap between glyphs, `.average-rating` color #1E293B
// (was #FFC107 stars with no gap, and #6B7280-ish muted text).

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          ...List.generate(5, (i) {
            IconData icon;
            if (i < rating.floor()) {
              icon = Icons.star_rounded;
            } else if (i < rating) {
              icon = Icons.star_half_rounded;
            } else {
              icon = Icons.star_border_rounded;
            }
            return Padding(
              padding: EdgeInsets.only(right: i < 4 ? 1 : 0),
              child: Icon(icon, color: const Color(0xFFFFD700), size: 18),
            );
          }),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.inter(
              color: const Color(0xFF1E293B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: GoogleFonts.inter(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();

  @override
  Widget build(BuildContext context) {
    // The real fallback (`/dist/images/course-bg.svg`) can never actually
    // render in this app — see `CourseImageFallback`'s own doc comment —
    // so a real local placeholder is used instead of a broken network
    // fetch that always ends up blank.
    return const CourseImageFallback();
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
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
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
