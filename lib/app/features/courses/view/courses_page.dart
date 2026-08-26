import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/utils/dev_image_proxy.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/courses/view/widgets/course_grid_card.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_action_repository.dart';
import 'package:lms/app/features/dashboard/viewmodel/dev_plan_membership_view_model.dart';
import 'package:lms/app/features/courses/view/calendar_courses_page.dart';

const _catalogPurple = FigmaTokens.primaryPurple;
const _catalogPink = Color(0xFFB0006D);
const _catalogInk = FigmaTokens.cardTitles;
const _catalogMuted = FigmaTokens.noteBodyText;
const _catalogBackground = FigmaTokens.pageBackground;
const _catalogCalendarBlue = FigmaTokens.primaryPurple;
const _catalogUndoBlue = FigmaTokens.primaryPurple;

int _catalogColumns(double width) {
  if (width >= 900) return 4;
  if (width >= 760) return 3;
  if (width >= 620) return 2;
  return 1;
}

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  final _searchController = TextEditingController();
  bool _redirectingUnauthorized = false;
  String? _selectedSkillId;

  // Extra breathing room below the last card so it isn't flush against the
  // screen edge / home indicator.
  static const _bottomSpacer = SliverToBoxAdapter(child: SizedBox(height: 32));

  @override
  void initState() {
    super.initState();
    // The provider (now kept alive, not autoDispose - see
    // course_catalog_view_model.dart) already holds whatever filters were
    // last applied, e.g. after coming back from a course detail page. Seed
    // the search box / skill dropdown from it so the UI matches the
    // already-filtered results being shown, instead of appearing reset.
    final applied = ref.read(CourseCatalogViewModel.provider);
    _searchController.text = applied.search;
    _selectedSkillId = applied.skillId ?? applied.behaviorId;
    // Auto-commit the search text a moment after typing stops, instead of
    // only on the explicit Search button/Enter key - otherwise a term
    // typed but never submitted just sits in the box looking like an
    // applied filter while the results underneath stay unfiltered. The
    // debounce itself lives on the notifier (queueSearch), not a Timer
    // here - a widget-owned Timer got silently cancelled by dispose()
    // whenever the user typed and tapped into a course before it fired,
    // so the just-typed filter never actually landed.
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onSearchTextChanged() {
    ref.read(CourseCatalogViewModel.provider.notifier).queueSearch(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _changeGroupPage(String groupId, int page) async {
    final error = await ref
        .read(CourseCatalogViewModel.provider.notifier)
        .changeGroupPage(groupId, page);
    if (error != null && mounted) {
      Toast.error(context, error);
    }
  }

  void _applyCatalogFilters() {
    final options = ref.read(CourseCatalogViewModel.provider).filterOptions;
    final selected = _selectedSkill(options, _selectedSkillId);
    ref
        .read(CourseCatalogViewModel.provider.notifier)
        .applyFilters(
          search: _searchController.text,
          skillId: selected != null && !_isBehaviorFilter(selected)
              ? selected.id
              : null,
          behaviorId: selected != null && _isBehaviorFilter(selected)
              ? selected.id
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(CourseCatalogViewModel.provider);
    final offlineState = ref.watch(OfflineViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    ref.watch(SyncViewModel.provider);
    final response = catalogState.result.data;
    final effectivelyOffline = isManualOffline || !connectionVM.isConnected;
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    if (!effectivelyOffline &&
        !_redirectingUnauthorized &&
        isUnauthorizedError(catalogState.result.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        redirectToLoginOnSessionExpired(context, ref);
      });
    }

    return AppScaffold(
      backgroundColor: _catalogBackground,
      title: 'Course Catalog',
      selectedLabel: 'Course Catalog',
      onRefresh: () => ref.read(CourseCatalogViewModel.provider.notifier).fetch(),
      body: RefreshIndicator(
        onRefresh: () async {
          if (effectivelyOffline) return;
          await ref.read(CourseCatalogViewModel.provider.notifier).fetch();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 40 : 16,
                isWide ? 16 : 24,  // py-2 = 8px, plus breathing room
                isWide ? 40 : 16,
                isWide ? 8 : 16,
              ),
              sliver: SliverToBoxAdapter(
                child: _FilterPanel(
                  searchController: _searchController,
                  skills: catalogState.filterOptions,
                  selectedSkillId: _selectedSkillId,
                  offline: effectivelyOffline,
                  onSkillChanged: (value) {
                    setState(() => _selectedSkillId = value);
                    _applyCatalogFilters();
                  },
                  onApply: _applyCatalogFilters,
                  onReset: () {
                    _searchController.clear();
                    setState(() => _selectedSkillId = null);
                    ref.read(CourseCatalogViewModel.provider.notifier).reset();
                  },
                  onCalendarView: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CalendarCoursesPage(),
                    ),
                  ),
                ),
              ),
            ),
            if (effectivelyOffline)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 48 : 20,
                  14,
                  isWide ? 48 : 20,
                  12,
                ),
                sliver: const SliverToBoxAdapter(
                  child: Text(
                    'Offline Courses',
                    style: TextStyle(
                      color: _catalogPink,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            if (effectivelyOffline)
              ..._buildOfflineContent(offlineState.courses)
            else
              ..._buildContent(catalogState),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOfflineContent(DataState<List<Course>> state) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: _catalogPurple),
            ),
          ),
        ];
      case DataProviderState.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: 'Unable to load offline courses.',
              onRetry: null,
            ),
          ),
        ];
      case DataProviderState.data:
        final courses = state.data ?? const <Course>[];
        if (courses.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No offline courses found.\nConnect to the internet and save a course first.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width >= 760 ? 48 : 27,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = _catalogColumns(width);
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: width >= 760 ? 28 : 18,
                    mainAxisSpacing: width >= 760 ? 28 : 34,
                    mainAxisExtent: width >= 760 ? 360 : 380,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CatalogCourseCard(
                      course: _CourseCardData.fromOffline(courses[index]),
                    ),
                    childCount: courses.length,
                  ),
                );
              },
            ),
          ),
          _bottomSpacer,
          const SliverToBoxAdapter(child: AppFooter()),
        ];
    }
  }

  List<Widget> _buildContent(CourseCatalogState catalogState) {
    switch (catalogState.result.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: _catalogPurple),
            ),
          ),
        ];
      case DataProviderState.error:
        if (isUnauthorizedError(catalogState.result.error)) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: _catalogPurple),
              ),
            ),
          ];
        }
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: catalogState.result.error ?? 'Unable to load courses.',
              onRetry:
                  () =>
                      ref
                          .read(CourseCatalogViewModel.provider.notifier)
                          .fetch(),
            ),
          ),
        ];
      case DataProviderState.data:
        final response = catalogState.result.data;
        final groups = response?.groups ?? const <CatalogCourseGroup>[];
        if (groups.isNotEmpty) {
          return [
            for (final group in groups)
              _groupBlock(
                group,
                catalogState.groupPages[group.id] ?? group.pagination.page,
              ),
            _bottomSpacer,
            const SliverToBoxAdapter(child: AppFooter()),
          ];
        }

        final courses = response?.courses ?? const <CatalogCourse>[];
        if (courses.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No courses found.')),
            ),
          ];
        }
        return [
          _groupBlock(
            CatalogCourseGroup(
              id: 'available',
              name: 'Available',
              pagination: const CatalogPagination(),
              courses: courses,
            ),
            1,
          ),
          _bottomSpacer,
          const SliverToBoxAdapter(child: AppFooter()),
        ];
    }
  }

  /// CSS ref: .sec-title is outside div#resources (separate element above the card grid)
  /// div#resources: bg #fff, border 1px #E7E4FF, border-radius 14px, padding 30px
  Widget _groupBlock(CatalogCourseGroup group, int selectedPage) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final hPad = isWide ? 40.0 : 16.0;
    final title = group.name.trim().isEmpty ? 'Courses' : '${group.name} Courses';

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CSS .sec-title h2.title — height:48px, color #A20067, font 24px, margin-bottom 20px
            Container(
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(bottom: 20),
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: const Color(0xFFA20067),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  height: 28 / 24,
                ),
              ),
            ),
            // CSS div#resources — bg #fff, border 1px #E7E4FF, radius 14px, padding 30px
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE7E4FF)),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = _catalogColumns(constraints.maxWidth);
                      final extent = isWide ? 360.0 : 380.0;
                      final rows = (group.courses.length / columns).ceil();
                      final gridH = rows * extent + (rows - 1) * (isWide ? 28 : 34);
                      return SizedBox(
                        height: gridH,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: isWide ? 28 : 18,
                            mainAxisSpacing: isWide ? 28 : 34,
                            mainAxisExtent: extent,
                          ),
                          itemCount: group.courses.length,
                          itemBuilder: (context, index) => _CatalogCourseCard(
                            course: _CourseCardData.fromCatalog(group.courses[index]),
                          ),
                        ),
                      );
                    },
                  ),
                  // Per page badge
                  const SizedBox(height: 8),
                  PerPageBadge(perPage: group.pagination.perPage),
                  // Pagination
                  if (group.pagination.pages > 1) ...[
                    const SizedBox(height: 8),
                    PaginationWidget(
                      page: selectedPage,
                      pages: group.pagination.pages,
                      onPage: (page) => _changeGroupPage(group.id, page),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perPageBadge(int perPage) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final hPad = isWide ? 40.0 : 16.0;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
      sliver: SliverToBoxAdapter(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: PerPageBadge(perPage: perPage),
        ),
      ),
    );
  }

  Widget _groupPagination(CatalogCourseGroup group, int selectedPage) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final hPad = isWide ? 40.0 : 16.0;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PaginationWidget(
            page: selectedPage,
            pages: group.pagination.pages,
            onPage: (page) => _changeGroupPage(group.id, page),
          ),
        ),
      ),
    );
  }

  Widget _groupTitle(String groupName) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final title = groupName.trim().isEmpty ? 'Courses' : '$groupName Courses';
    final hPad = isWide ? 40.0 : 16.0;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFF693D94),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 28 / 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _catalogGrid(List<CatalogCourse> courses) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final hPad = isWide ? 40.0 : 16.0;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
      sliver: SliverToBoxAdapter(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth - 40; // account for container padding
              final columns = _catalogColumns(constraints.maxWidth);
              final itemW = (width - (columns - 1) * (isWide ? 28 : 18)) / columns;
              final extent = isWide ? 360.0 : 380.0;
              final rows = (courses.length / columns).ceil();
              final gridH = rows * extent + (rows - 1) * (isWide ? 28 : 34);
              return SizedBox(
                height: gridH,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: isWide ? 28 : 18,
                    mainAxisSpacing: isWide ? 28 : 34,
                    mainAxisExtent: extent,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, index) => _CatalogCourseCard(
                    course: _CourseCardData.fromCatalog(courses[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}  // end _CoursesPageState


class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.skills,
    required this.selectedSkillId,
    required this.offline,
    required this.onSkillChanged,
    required this.onApply,
    required this.onReset,
    required this.onCalendarView,
  });

  final TextEditingController searchController;
  final List<CatalogSkill> skills;
  final String? selectedSkillId;
  final bool offline;
  final ValueChanged<String?> onSkillChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onCalendarView;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;

        // CSS ref: search input — rounded-[12px] border-[#e2e8f0] bg-[#f8fafc] h-[42px] px-4
        final searchField = _CatalogField(
          controller: searchController,
          hint: offline ? "You're offline" : 'Search',
          showClear: true,
          showLeadingIcon: true,
          enabled: !offline,
          onSubmitted: (_) => onApply(),
        );

        // CSS ref: Strategic Imperative input — same style as search
        final strategicField = _CatalogField(
          hint: 'Strategic Imperative',
          showLeadingIcon: true,
          enabled: !offline,
        );

        // CSS ref: Competencies input — same style as search
        final competenciesField = _CatalogField(
          hint: 'Competencies',
          showLeadingIcon: true,
          enabled: !offline,
        );

        final skillDropdown = _SkillDropdown(
          skills: skills,
          value: selectedSkillId,
          onChanged: onSkillChanged,
          inline: wide,
        );

        // CSS ref: undo-btn — bg-[#f1f5f9] text-[#64748b] rounded-[12px] h-[42px] w-[30%]
        final undoButton = SizedBox(
          width: 42,
          height: 42,
          child: HoverBuilder(
            builder: (context, hovering) => GestureDetector(
              onTap: offline ? null : onReset,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: hovering
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.undo_rounded,
                    size: 18, color: Color(0xFF64748B)),
              ),
            ),
          ),
        );

        // CSS ref: calendar-btn — bg-[#693D94] rounded-[12px] font-semibold text-[13px] h-[42px]
        final calendarButton = HoverBuilder(
          builder: (context, hovering) => GestureDetector(
            onTap: onCalendarView,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: hovering
                    ? const Color(0xFF5A3480)
                    : _catalogCalendarBlue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF693D94).withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'Calendar View',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );

        // CSS ref: search-blcok — bg-white rounded-[16px] p-[10px] shadow border-[#f0f1f5]
        const outerDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        );

        if (wide) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: outerDecoration.copyWith(
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.05),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFF0F1F5)),
            ),
            // CSS ref: row — Search | Strategic Imperative | Competencies | Skills | [Reset] [Calendar]
            child: Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                Expanded(child: strategicField),
                const SizedBox(width: 8),
                Expanded(child: competenciesField),
                const SizedBox(width: 8),
                Expanded(child: skillDropdown),
                const SizedBox(width: 8),
                undoButton,
                const SizedBox(width: 8),
                calendarButton,
              ],
            ),
          );
        }

        // Mobile: stack vertically
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: outerDecoration.copyWith(
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.05),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF0F1F5)),
          ),
          child: Column(
            children: [
              searchField,
              const SizedBox(height: 10),
              skillDropdown,
              const SizedBox(height: 10),
              Row(
                children: [
                  undoButton,
                  const SizedBox(width: 8),
                  Expanded(child: calendarButton),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CatalogField extends StatelessWidget {
  const _CatalogField({
    this.controller,
    required this.hint,
    this.enabled = true,
    this.showClear = false,
    this.showLeadingIcon = true,
    this.onSubmitted,
  });
  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final bool showClear;
  final bool showLeadingIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return _ClearableTextField(
      controller: controller,
      enabled: enabled,
      hint: hint,
      showClear: showClear,
      showLeadingIcon: showLeadingIcon,
      onSubmitted: onSubmitted,
    );
  }
}

class _ClearableTextField extends StatefulWidget {
  const _ClearableTextField({
    required this.hint,
    this.controller,
    this.enabled = true,
    this.showClear = false,
    this.showLeadingIcon = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final bool showClear;
  final bool showLeadingIcon;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_ClearableTextField> createState() => _ClearableTextFieldState();
}

class _ClearableTextFieldState extends State<_ClearableTextField> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  bool _focused = false;

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Theme(
        // Remove Flutter's default gray hover color on TextField
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            hoverColor: Colors.transparent,
          ),
        ),
        child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        style: GoogleFonts.inter(
          color: const Color(0xFF2D3748),
          fontSize: 14,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w400,
        ),
        onChanged: widget.onChanged,
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
          widget.onSubmitted?.call(value);
        },
        decoration: _fieldDecoration(
          widget.hint,
          showLeadingIcon: widget.showLeadingIcon,
          // CSS ref: focus:background-color: #fff (was #f8fafc when unfocused)
          fillColor: _focused ? Colors.white : const Color(0xFFF8FAFC),
          suffixIcon: widget.showClear && _controller.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _catalogMuted,
                    size: 20,
                  ),
                )
              : null,
        ),
        ),
      ),
    );
  }
}

class _SkillDropdown extends StatefulWidget {
  const _SkillDropdown({
    required this.skills,
    required this.value,
    required this.onChanged,
    this.inline = false,
  });
  final List<CatalogSkill> skills;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Desktop reference shows an inline panel opening directly under the
  /// field (like a web <select2>), rather than a mobile bottom sheet.
  final bool inline;

  @override
  State<_SkillDropdown> createState() => _SkillDropdownState();
}

class _SkillDropdownState extends State<_SkillDropdown> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _open = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_open && mounted) setState(() => _open = false);
  }

  void _openInline(BuildContext context, List<CatalogSkill> unique, CatalogSkill? selected) {
    final box = context.findRenderObject() as RenderBox;
    _overlayEntry = OverlayEntry(
      builder: (context) => _SkillDropdownOverlay(
        link: _layerLink,
        width: box.size.width,
        skills: unique,
        selectedId: selected?.id,
        onDismiss: _removeOverlay,
        onSelected: (skill) {
          widget.onChanged(skill?.id);
          _removeOverlay();
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _open = true);
  }

  Future<void> _openSheet(List<CatalogSkill> unique, CatalogSkill? selected) async {
    final picked = await showModalBottomSheet<CatalogSkill?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SkillPickerSheet(
        skills: unique,
        selectedId: selected?.id,
      ),
    );
    if (picked != null) widget.onChanged(picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final unique = <String, CatalogSkill>{
      for (final skill in widget.skills) skill.id: skill,
    }.values.toList();
    final selected = _selectedSkill(unique, widget.value);

    final field = InkWell(
      onTap: unique.isEmpty
          ? null
          : () => widget.inline
              ? (_open ? _removeOverlay() : _openInline(context, unique, selected))
              : _openSheet(unique, selected),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: _fieldDecoration(
          'Skills or Behavior',
          showLeadingIcon: true, // CSS ref: fa-search prefix icon
        ).copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    widget.onChanged(null);
                    _removeOverlay();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
                  ),
                ),
              Icon(
                _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          selected?.name ?? 'Skills or Behavior',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: selected == null ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            fontSize: 14,
          ),
        ),
      ),
    );

    return CompositedTransformTarget(link: _layerLink, child: field);
  }
}

class _SkillDropdownOverlay extends StatefulWidget {
  const _SkillDropdownOverlay({
    required this.link,
    required this.width,
    required this.skills,
    required this.selectedId,
    required this.onDismiss,
    required this.onSelected,
  });
  final LayerLink link;
  final double width;
  final List<CatalogSkill> skills;
  final String? selectedId;
  final VoidCallback onDismiss;
  final ValueChanged<CatalogSkill?> onSelected;

  @override
  State<_SkillDropdownOverlay> createState() => _SkillDropdownOverlayState();
}

class _SkillDropdownOverlayState extends State<_SkillDropdownOverlay> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim().toLowerCase();
    final filtered = widget.skills
        .where((skill) => skill.name.toLowerCase().contains(query))
        .toList();
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: widget.link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 2,
              // CSS ref: border-top-left-radius:0, border-top-right-radius:0,
              // border-bottom-left-radius:4px, border-bottom-right-radius:4px
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              child: Container(
                width: widget.width,
                constraints: const BoxConstraints(maxHeight: 280),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  // CSS ref: border: 1px solid #aaa, border-top: none
                  border: Border(
                    left:   BorderSide(color: Color(0xFFAAAAAA)),
                    right:  BorderSide(color: Color(0xFFAAAAAA)),
                    bottom: BorderSide(color: Color(0xFFAAAAAA)),
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CSS ref: select2-search padding: 4px all sides
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            hoverColor: Colors.transparent,
                          ),
                        ),
                        child: TextField(
                          controller: _queryController,
                          autofocus: false,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569)),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '',
                            hoverColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF693D94), width: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(
                          'No results found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF2D3748),
                            height: 21 / 14,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final skill = filtered[index];
                            final selected = skill.id == widget.selectedId;
                            final highlighted = selected ||
                                (widget.selectedId == null && index == 0);
                            return InkWell(
                              onTap: () => widget.onSelected(skill),
                              child: Container(
                                width: double.infinity,
                                color: highlighted
                                    ? const Color(0xFF5897FB)
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Text(
                                  skill.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: highlighted
                                        ? Colors.white
                                        : const Color(0xFF2D3748),
                                    fontWeight: highlighted
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkillPickerSheet extends StatefulWidget {
  const _SkillPickerSheet({required this.skills, this.selectedId});

  final List<CatalogSkill> skills;
  final String? selectedId;

  @override
  State<_SkillPickerSheet> createState() => _SkillPickerSheetState();
}

class _SkillPickerSheetState extends State<_SkillPickerSheet> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final query = _queryController.text.trim().toLowerCase();
    final filtered =
        widget.skills
            .where((skill) => skill.name.toLowerCase().contains(query))
            .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .76,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DEE9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Skills or Behavior',
                        style: TextStyle(
                          color: _catalogInk,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: _ClearableTextField(
                  controller: _queryController,
                  hint: 'Search skill or behavior',
                  showClear: true,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * .42,
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text('No matching filters found.'),
                          ),
                        )
                        : Scrollbar(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder:
                                (_, __) => const Divider(
                                  height: 1,
                                  color: Color(0xFFEFF2F6),
                                ),
                            itemBuilder: (context, index) {
                              final skill = filtered[index];
                              final selected = skill.id == widget.selectedId;
                              return ListTile(
                                onTap: () => Navigator.pop(context, skill),
                                leading: Icon(
                                  _isBehaviorFilter(skill)
                                      ? Icons.psychology_alt_outlined
                                      : Icons.workspace_premium_outlined,
                                  color:
                                      selected ? _catalogPurple : _catalogMuted,
                                ),
                                title: Text(
                                  skill.name,
                                  style: TextStyle(
                                    color:
                                        selected ? _catalogPurple : _catalogInk,
                                    fontWeight:
                                        selected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                  ),
                                ),
                                trailing:
                                    selected
                                        ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: _catalogPurple,
                                        )
                                        : null,
                              );
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  String hint, {
  Widget? suffixIcon,
  bool showLeadingIcon = true,
  Color fillColor = const Color(0xFFF8FAFC),
}) => InputDecoration(
      hintText: hint,
      // CSS ref: color: #94A3B8 placeholder, font-size 14px, letter-spacing 1px
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
        letterSpacing: 1.0,
      ),
      prefixIcon: showLeadingIcon
          ? const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 16)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      // CSS ref: background-color: #f8fafc (unfocused), #fff (focused) — passed via fillColor param
      fillColor: fillColor,
      // Remove Flutter's default gray hover overlay
      hoverColor: Colors.transparent,
      isDense: true,
      // CSS ref: height 42px, padding 6px 12px (vertical), padding-left 42px (prefix icon handles left)
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        // CSS ref: border-radius: 12px
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        // CSS ref: focus:border-color var(--primary-color) + box-shadow 0 0 0 4px rgba(84,87,193,0.1)
        borderSide: const BorderSide(color: Color(0xFF5457C1), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );

CatalogSkill? _selectedSkill(List<CatalogSkill> skills, String? id) {
  if (id == null) return null;
  for (final skill in skills) {
    if (skill.id == id) return skill;
  }
  return null;
}

bool _isBehaviorFilter(CatalogSkill skill) {
  final groupId = skill.groupId.toLowerCase();
  final name = skill.name.toLowerCase();
  return groupId == '2' || groupId.contains('behav') || name.contains('behav');
}


class _CourseCardData {
  const _CourseCardData({
    required this.id,
    required this.name,
    required this.logo,
    required this.progress,
    required this.nextSession,
    required this.nextSessionLabel,
    required this.offlineCourse,
    this.inDevelopmentPlan = false,
    this.planId,
  });

  final int id;
  final String name;
  final String? logo;
  final double progress;
  final DateTime? nextSession;
  final String? nextSessionLabel;
  final Course offlineCourse;
  final bool inDevelopmentPlan;
  final int? planId;

  factory _CourseCardData.fromCatalog(CatalogCourse course) {
    return _CourseCardData(
      id: course.id,
      name: course.name,
      logo: course.logo,
      progress: course.progress,
      nextSession: course.nextSession,
      nextSessionLabel: course.nextSessionLabel,
      inDevelopmentPlan: course.inDevelopmentPlan,
      planId: course.planId,
      offlineCourse: Course(
        id: course.id,
        name: course.name,
        logoLink: course.logo,
        averageRating: course.averageRating,
        ratingCount: course.ratingCount,
        displayRating: course.displayRating ? 1 : 0,
      ),
    );
  }

  factory _CourseCardData.fromOffline(Course course) {
    return _CourseCardData(
      id: course.id ?? 0,
      name: course.name ?? 'Course',
      logo: course.logoLink,
      progress: course.percentage,
      nextSession: null,
      nextSessionLabel: null,
      offlineCourse: course,
    );
  }
}

class _CatalogCourseCard extends ConsumerStatefulWidget {
  const _CatalogCourseCard({required this.course});
  final _CourseCardData course;

  @override
  ConsumerState<_CatalogCourseCard> createState() => _CatalogCourseCardState();
}

class _CatalogCourseCardState extends ConsumerState<_CatalogCourseCard> {
  bool _showOverlay = false;
  bool _isBusy = false;
  bool _hovering = false;

  Future<void> _handleDevPlanAction(BuildContext context, bool isInPlan) async {
    final auth = ref.read(AuthStateNotifier.provider);
    final userId = auth?.user?.id;
    if (userId == null) return;

    setState(() => _isBusy = true);
    final repo = ref.read(DevelopmentPlanActionRepository.provider);

    final result = isInPlan
        ? await repo.removeFromDevPlan(courseId: widget.course.id)
        : await repo.addToDevPlan(courseId: widget.course.id);

    if (!mounted) return;
    if (result.success) {
      final membership = ref.read(DevPlanMembershipViewModel.provider.notifier);
      if (isInPlan) {
        membership.markRemoved(widget.course.id);
      } else {
        membership.markInPlan(widget.course.id);
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
    ref.watch(OfflineViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    ref.watch(SyncViewModel.provider);
    final isOnline = !isManualOffline && connectionVM.isConnected;
    final membership = ref.watch(DevPlanMembershipViewModel.provider);
    final isInPlan = membership.ids.contains(widget.course.id);
    final viewDisabled = isViewCourseDisabled(ref, widget.course.id);

    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, _hovering ? 0.12 : 0.05),
              blurRadius: _hovering ? 40 : 25,
              offset: Offset(0, _hovering ? 20 : 10),
            ),
          ],
        ),
        child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.max,
            children: [
              // -- Full-width image --------------------------------------
              SizedBox(
                height: 160,
                child: _CourseImage(url: widget.course.logo),
              ),
              // -- White content area ------------------------------------
              // -- White content area � title + button pinned to bottom -
              // -- White content area: session info, title, rating, btn --
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CSS ref: .session-info — "NEXT AVAILABLE" label + date
                      if (widget.course.nextSession != null) ...[
                        Text(
                          'NEXT AVAILABLE',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 11, color: Color(0xFF693D94)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _formatNextSession(widget.course.nextSession!),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF693D94),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // CSS ref: .course-title — Inter 14px w600 #1E293B
                      Text(
                        widget.course.name.isEmpty
                            ? 'Untitled Course'
                            : widget.course.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      // CSS ref: .rating-bar — stars + avg + count
                      if (widget.course.offlineCourse.displayRating == 1 &&
                          widget.course.offlineCourse.averageRating > 0) ...[
                        const SizedBox(height: 6),
                        _StarRating(
                          rating: widget.course.offlineCourse.averageRating,
                          count: widget.course.offlineCourse.ratingCount ?? 0,
                        ),
                      ],
                      const Spacer(),
                      // CSS ref: .btn-modern-primary — filled #693D94 hover #5a3480
                      _ModernViewCourseButton(
                        onPressed: viewDisabled
                            ? null
                            : () => Modular.to.pushNamed(
                                  CoursesModule.construct(
                                    '${CoursesModule.detail}/${widget.course.id}',
                                  ),
                                  arguments: widget.course.offlineCourse,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Dev plan button � top-right
          if (membership.loaded)
            Positioned(
              top: 10,
              right: 10,
              child: _DevPlanButton(
                isInPlan: isInPlan,
                onTap:
                    isOnline ? () => setState(() => _showOverlay = true) : null,
              ),
            ),
          // Offline save button � top-left
          Positioned(
            top: 10,
            left: 10,
            child: OfflineCourseButton(course: widget.course.offlineCourse),
          ),
          // Dev plan confirm overlay
          if (_showOverlay)
            Positioned.fill(
              child: _DevPlanOverlay(
                isInPlan: isInPlan,
                isBusy: _isBusy,
                onYes: () => _handleDevPlanAction(context, isInPlan),
                onNo: () => setState(() => _showOverlay = false),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

String _formatNextSession(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final hourStr = hour12.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, $hourStr:$minute $ampm';
}

class _DevPlanButton extends StatelessWidget {
  const _DevPlanButton({required this.isInPlan, required this.onTap});
  final bool isInPlan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isDisabled ? Colors.white : const Color(0xFFE8E7F8),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          isDisabled
              ? Icons.cloud_off_rounded
              : (isInPlan ? Icons.remove_rounded : Icons.add_rounded),
          size: isDisabled ? 15 : 18,
          color: isDisabled ? _catalogMuted : (isInPlan ? _catalogPink : FigmaTokens.primaryPurple),
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
      color: const Color(0xCC172033),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$action this course $prep your development plan?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            if (isBusy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
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
      ),
    );
  }
}

class _OverlayBtn extends StatelessWidget {
  const _OverlayBtn({
    required this.label,
    required this.onTap,
    required this.filled,
  });
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? _catalogPurple : Colors.transparent,
          border: Border.all(color: Colors.white, width: 1.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _CourseImage extends StatelessWidget {
  const _CourseImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset('assets/images/login-bg.png', fit: BoxFit.cover);
    if (url == null) return fallback;
    return Image.network(
      devProxiedImageUrl(url!),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder:
          (context, child, progress) =>
              progress == null
                  ? child
                  : Container(
                    color: const Color(0xFFF1EFFB),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _catalogPurple,
                    ),
                  ),
    );
  }
}

// ── Modern filled View Course button ─────────────────────────────────────────
// CSS ref: .btn-modern-primary — bg-[#693D94] hover:bg-[#5a3480] text-white
//          rounded-[8px] full-width font-weight:600 font-size:13px

class _ModernViewCourseButton extends StatefulWidget {
  const _ModernViewCourseButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  State<_ModernViewCourseButton> createState() => _ModernViewCourseButtonState();
}

class _ModernViewCourseButtonState extends State<_ModernViewCourseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFF693D94).withValues(alpha: 0.4)
                : _hovering
                    ? const Color(0xFF5A3480)
                    : const Color(0xFF693D94),
            borderRadius: BorderRadius.circular(8),
            boxShadow: disabled || _hovering
                ? null
                : const [
                    BoxShadow(
                      color: Color.fromRGBO(105, 61, 148, 0.25),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Text(
            'View Course',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Star rating row ────────────────────────────────────────────────────────────
// CSS ref: .rating-bar — stars (filled/half/empty) + average + (count)

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating >= i + 0.5;
          return Icon(
            filled
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 14,
            color: const Color(0xFFFFA500), // amber star color
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 2),
          Text(
            '($count)',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: _catalogMuted, size: 54),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (onRetry != null) RetryButton(onRetry: onRetry!, errorMessage: message),
        ],
      ),
    ),
  );
}

