import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/courses/view/widgets/course_view_availability.dart';
import 'package:lms/app/features/courses/view/widgets/offline_course_action.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_action_repository.dart';
import 'package:lms/app/features/dashboard/viewmodel/dev_plan_membership_view_model.dart';
import 'package:lms/app/features/courses/view/calendar_courses_page.dart';

const _catalogPurple = Color(0xFF5756C9);
const _catalogPink = Color(0xFFB0006D);
const _catalogInk = Color(0xFF172033);
const _catalogMuted = Color(0xFF7C879D);
const _catalogBackground = Color(0xFFF4F7F8);
const _catalogCalendarBlue = Color(0xFF693D94);
const _catalogUndoBlue = Color(0xFF693D94);

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
      hideBack: true,
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
                isWide ? 32 : 12,
                isWide ? 24 : 42,
                isWide ? 32 : 12,
                isWide ? 12 : 28,
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
                    mainAxisExtent: width >= 760 ? 365 : 390,
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
            for (final group in groups) ...[
              _groupTitle(group.name),
              _catalogGrid(group.courses),
              _perPageBadge(group.pagination.perPage),
              if (group.pagination.pages > 1)
                _groupPagination(
                  group,
                  catalogState.groupPages[group.id] ?? group.pagination.page,
                ),
            ],
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
          _groupTitle('Available'),
          _catalogGrid(courses),
          _perPageBadge(5),
          _bottomSpacer,
          const SliverToBoxAdapter(child: AppFooter()),
        ];
    }
  }

  Widget _perPageBadge(int perPage) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(isWide ? 48 : 27, 10, isWide ? 48 : 27, 0),
      sliver: SliverToBoxAdapter(child: PerPageBadge(perPage: perPage)),
    );
  }

  Widget _groupPagination(CatalogCourseGroup group, int selectedPage) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 42),
      sliver: SliverToBoxAdapter(
        child: PaginationWidget(
          page: selectedPage,
          pages: group.pagination.pages,
          onPage: (page) => _changeGroupPage(group.id, page),
        ),
      ),
    );
  }

  Widget _groupTitle(String groupName) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final title = groupName.trim().isEmpty ? 'Courses' : '$groupName Courses';
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(isWide ? 48 : 27, 14, isWide ? 48 : 27, 20),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: GoogleFonts.roboto(
            color: const Color(0xFFA20067),
            fontSize: 24,
            fontWeight: FontWeight.w400,
            height: 28 / 24,
          ),
        ),
      ),
    );
  }

  Widget _catalogGrid(List<CatalogCourse> courses) {
    return SliverPadding(
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
              mainAxisExtent: width >= 760 ? 365 : 390,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CatalogCourseCard(
                course: _CourseCardData.fromCatalog(courses[index]),
              ),
              childCount: courses.length,
            ),
          );
        },
      ),
    );
  }
}


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
  // Search/Reset both hit the live API with no offline fallback - offering
  // them while there's no real connection just invites a tap that can only
  // fail, the same reasoning as RetryButton.
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
        final searchField = _CatalogField(
          controller: searchController,
          hint: offline ? "You're offline" : 'Search',
          showClear: true,
          showLeadingIcon: true,
          enabled: !offline,
          onSubmitted: (_) => onApply(),
        );
        final skillDropdown = _SkillDropdown(
          skills: skills,
          value: selectedSkillId,
          onChanged: onSkillChanged,
          inline: wide,
        );
        final undoButton = SizedBox(
          width: 48,
          height: 42,
          child: ElevatedButton(
            onPressed: offline ? null : onReset,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: _catalogUndoBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Icon(Icons.undo_rounded, size: 18),
          ),
        );
        final calendarButton = ElevatedButton(
          onPressed: onCalendarView,
          style: ElevatedButton.styleFrom(
            backgroundColor: _catalogCalendarBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            'Calendar View',
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        );

        if (wide) {
          return Row(
            children: [
              Expanded(flex: 5, child: searchField),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: skillDropdown),
              const SizedBox(width: 16),
              undoButton,
              const SizedBox(width: 16),
              SizedBox(height: 42, child: calendarButton),
            ],
          );
        }

        return Column(
          children: [
            searchField,
            const SizedBox(height: 14),
            skillDropdown,
            const SizedBox(height: 14),
            Row(
              children: [
                undoButton,
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(height: 48, child: calendarButton),
                ),
              ],
            ),
          ],
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

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      style: GoogleFonts.roboto(color: const Color(0xFF495057), fontSize: 16),
      onChanged: widget.onChanged,
      onSubmitted: (value) {
        FocusScope.of(context).unfocus();
        widget.onSubmitted?.call(value);
      },
      decoration: _fieldDecoration(
        widget.hint,
        showLeadingIcon: widget.showLeadingIcon,
        suffixIcon:
            widget.showClear && _controller.text.isNotEmpty
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
          showLeadingIcon: false,
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
                    color: _catalogMuted,
                    size: 20,
                  ),
                ),
              Icon(
                _open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: _catalogMuted,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          selected?.name ?? 'Skills or Behavior',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            color: selected == null ? const Color(0xFF999999) : const Color(0xFF495057),
            fontSize: 16,
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
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: widget.width,
                constraints: const BoxConstraints(maxHeight: 340),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE3E8EF)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: TextField(
                        controller: _queryController,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.roboto(fontSize: 15, color: const Color(0xFF495057)),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: const BorderSide(color: Colors.black87),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: const BorderSide(color: Colors.black87),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(2),
                            borderSide: const BorderSide(color: Colors.black87, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No matching filters found.'),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final skill = filtered[index];
                                final selected = skill.id == widget.selectedId;
                                return InkWell(
                                  onTap: () => widget.onSelected(skill),
                                  child: Container(
                                    width: double.infinity,
                                    color: selected ? const Color(0xFF5B8DEF) : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Text(
                                      skill.name,
                                      style: GoogleFonts.roboto(
                                        fontSize: 15,
                                        color: selected ? Colors.white : const Color(0xFF495057),
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
}) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.roboto(color: const Color(0xFF999999), fontSize: 16),
      prefixIcon: showLeadingIcon
          ? const Icon(
              Icons.search_rounded,
              color: Color(0xFF693D94),
              size: 20,
            )
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE7E4FF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE7E4FF)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE7E4FF)),
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

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWide ? 15 : 14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: isWide ? 140 : 160,
                child: _CourseImage(url: widget.course.logo),
              ),
              // Fixed height regardless of whether a course has a next
              // session, so every card in a row lines up identically
              // instead of the footer's position shifting per-card.
              SizedBox(
                height: 58,
                child: widget.course.nextSession == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'The next available course begins on',
                              style: GoogleFonts.roboto(
                                color: const Color(0xFF767676),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatNextSession(widget.course.nextSession!),
                              style: GoogleFonts.roboto(
                                color: const Color(0xFF484848),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(14, 12, 14, isWide ? 10 : 14),
                  decoration: const BoxDecoration(gradient: FigmaTokens.heroGradient),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.course.name.isEmpty ? 'Untitled Course' : widget.course.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          height: 27 / 22,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: viewDisabled
                            ? null
                            : () => Modular.to.pushNamed(
                                CoursesModule.construct(
                                  '${CoursesModule.detail}/${widget.course.id}',
                                ),
                                arguments: widget.course.offlineCourse,
                              ),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isWide ? 7 : 10),
                          ),
                        ),
                        child: Transform.translate(
                          offset: const Offset(0, -1),
                          child: Text(
                            'View Course',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 21 / 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (membership.loaded)
            Positioned(
              top: 12,
              right: 12,
              child: _DevPlanButton(
                isInPlan: isInPlan,
                onTap: isOnline ? () => setState(() => _showOverlay = true) : null,
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: OfflineCourseButton(course: widget.course.offlineCourse),
          ),
          // Overlay covers the full card
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
          color: isDisabled ? _catalogMuted : (isInPlan ? _catalogPink : const Color(0xFF693D94)),
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
    final fallback = Container(
      color: const Color(0xFFF1EFFB),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, size: 58, color: Color(0xFF693D94)),
    );
    if (url == null) return fallback;
    return Image.network(
      url!,
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
          if (onRetry != null) RetryButton(onRetry: onRetry!),
        ],
      ),
    ),
  );
}

