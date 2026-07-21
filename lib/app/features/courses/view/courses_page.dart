import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/offline_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/dashboard/repository/development_plan_action_repository.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';
import 'package:lms/app/features/dashboard/viewmodel/dev_plan_membership_view_model.dart';
import 'package:lms/app_module.dart';
import 'package:lms/app/features/courses/view/calendar_courses_page.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';

const _catalogPurple = Color(0xFF5756C9);
const _catalogPink = Color(0xFFB0006D);
const _catalogInk = Color(0xFF172033);
const _catalogMuted = Color(0xFF7C879D);
const _catalogBackground = Color(0xFFF4F7F8);
const _catalogCalendarBlue = Color(0xFF3454D1);

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _isUnauthorizedError(catalogState.result.error)) {
      _redirectingUnauthorized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(AuthStateNotifier.provider.notifier).logout();
        if (!mounted) return;
        Modular.to.navigate(AppModule.auth);
      });
    }

    return Scaffold(
      backgroundColor: _catalogBackground,
      drawer: isWide ? null : const AppDrawer(selectedLabel: 'Course Catalog'),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isWide ? 78 : 60),
        child: LmsAppBar(
          isWide: isWide,
          bottom: isWide ? const _HeaderNavBar() : null,
        ),
      ),
      body: RefreshIndicator(
        onRefresh:
            () =>
                effectivelyOffline
                    ? Future.value()
                    : ref
                        .read(CourseCatalogViewModel.provider.notifier)
                        .fetch(),
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
                  onSkillChanged:
                      (value) => setState(() => _selectedSkillId = value),
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
                    mainAxisExtent: width >= 760 ? 190 : 230,
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
        if (_isUnauthorizedError(catalogState.result.error)) {
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
              if (group.pagination.pages > 1)
                _groupPagination(
                  group,
                  catalogState.groupPages[group.id] ?? group.pagination.page,
                ),
            ],
            _bottomSpacer,
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
        return [_groupTitle('Available'), _catalogGrid(courses), _bottomSpacer];
    }
  }

  Widget _groupPagination(CatalogCourseGroup group, int selectedPage) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 42),
      sliver: SliverToBoxAdapter(
        child: PaginationWidget(
          page: selectedPage,
          pages: group.pagination.pages,
          onPage: (page) => ref
              .read(CourseCatalogViewModel.provider.notifier)
              .changeGroupPage(group.id, page),
        ),
      ),
    );
  }

  Widget _groupTitle(String groupName) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final title = groupName.trim().isEmpty ? 'Courses' : '$groupName Courses';
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(isWide ? 48 : 27, 14, isWide ? 48 : 27, 12),
      sliver: SliverToBoxAdapter(
        child: Text(
          title,
          style: const TextStyle(
            color: _catalogPink,
            fontSize: 17,
            fontWeight: FontWeight.w500,
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
              mainAxisExtent: width >= 760 ? 190 : 230,
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

bool _isUnauthorizedError(String? error) {
  final value = error?.toLowerCase() ?? '';
  return value.startsWith('unauthorized') ||
      value.contains('invalid credentials') ||
      value.contains('status code of 401') ||
      value.contains(' 401');
}


class _HeaderNavBar extends StatelessWidget implements PreferredSizeWidget {
  const _HeaderNavBar();

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const _NavItem(icon: Icons.menu_book_outlined, label: 'Course Catalog'),
            const _NavItem(
              icon: Icons.library_books_outlined,
              label: 'My Courses',
              menu: true,
            ),
            _NavItem(
              icon: Icons.account_tree_outlined,
              label: 'Learning Paths',
              onTap: () => Modular.to.pushNamed(
                CoursesModule.construct(CoursesModule.learningPaths),
              ),
            ),
            const _NavItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Points & Badges',
              menu: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.menu = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool menu;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: _catalogMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: _catalogInk,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (menu) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: _catalogMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.skills,
    required this.selectedSkillId,
    required this.onSkillChanged,
    required this.onApply,
    required this.onReset,
    required this.onCalendarView,
  });

  final TextEditingController searchController;
  final List<CatalogSkill> skills;
  final String? selectedSkillId;
  final ValueChanged<String?> onSkillChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onCalendarView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B172033),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final fields = <Widget>[
            _CatalogField(
              controller: searchController,
              hint: 'Search Course',
              showClear: true,
              showLeadingIcon: false,
              onSubmitted: (_) => onApply(),
            ),
            _SkillDropdown(
              skills: skills,
              value: selectedSkillId,
              onChanged: onSkillChanged,
            ),
          ];

          if (wide) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(width: 230, child: fields[0]),
                  const SizedBox(width: 12),
                  SizedBox(width: 240, child: fields[1]),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 42,
                    child: OutlinedButton(
                      onPressed: onReset,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        backgroundColor: _catalogBackground,
                      ),
                      child: const Icon(Icons.undo_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 118,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: onApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _catalogPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text(
                        'Search',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: onCalendarView,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _catalogCalendarBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: const Text(
                        'Calendar View',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              fields[0],
              const SizedBox(height: 14),
              fields[1],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: _catalogPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text(
                    'Search',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onReset,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: _catalogPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Icon(Icons.undo_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onCalendarView,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: _catalogCalendarBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 20),
                      label: const Text(
                        'Calendar View',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
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

class _SkillDropdown extends StatelessWidget {
  const _SkillDropdown({
    required this.skills,
    required this.value,
    required this.onChanged,
  });
  final List<CatalogSkill> skills;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final unique =
        <String, CatalogSkill>{
          for (final skill in skills) skill.id: skill,
        }.values.toList();
    final selected = _selectedSkill(unique, value);
    return InkWell(
      onTap:
          unique.isEmpty
              ? null
              : () async {
                final picked = await showModalBottomSheet<CatalogSkill?>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (context) => _SkillPickerSheet(
                        skills: unique,
                        selectedId: selected?.id,
                      ),
                );
                if (picked != null) onChanged(picked.id);
              },
      borderRadius: BorderRadius.circular(9),
      child: InputDecorator(
        decoration: _fieldDecoration(
          'Search Skills or Behavior',
          showLeadingIcon: false,
        ).copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () => onChanged(null),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _catalogMuted,
                    size: 20,
                  ),
                ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _catalogMuted,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        child: Text(
          selected?.name ?? 'Search Skills or Behavior',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected == null ? _catalogMuted : _catalogInk,
            fontSize: 13,
          ),
        ),
      ),
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
      hintStyle: const TextStyle(color: _catalogMuted, fontSize: 13),
      prefixIcon: showLeadingIcon
          ? const Icon(
              Icons.search_rounded,
              color: Color(0xFF91A0B8),
              size: 18,
            )
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
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
        fit: StackFit.expand,
        children: [
          // Image fills the whole card
          _CourseImage(url: widget.course.logo),
          if (membership.loaded)
            Positioned(
              top: 12,
              right: 12,
              child: _DevPlanButton(
                isInPlan: isInPlan,
                onTap: isOnline ? () => setState(() => _showOverlay = true) : null,
              ),
            ),
          // Title + View Course overlaid on the bottom of the image
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(14, 12, 14, isWide ? 10 : 14),
              decoration: BoxDecoration(color: _catalogPurple.withValues(alpha: 0.93)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.course.nextSessionLabel != null) ...[
                    _NextSession(
                      date: widget.course.nextSession,
                      label: widget.course.nextSessionLabel!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    widget.course.name.isEmpty ? 'Untitled Course' : widget.course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWide ? 13 : 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: isWide ? 8 : 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Modular.to.pushNamed(
                        CoursesModule.construct(
                          '${CoursesModule.detail}/${widget.course.id}',
                        ),
                        arguments: widget.course.offlineCourse,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(isWide ? 34 : 42),
                        backgroundColor: const Color(0xFF433FA0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWide ? 7 : 10),
                        ),
                      ),
                      child: const Text(
                        'View Course',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Overlay covers the full card (image + text area)
          if (_showOverlay)
            _DevPlanOverlay(
              isInPlan: isInPlan,
              isBusy: _isBusy,
              onYes: () => _handleDevPlanAction(context, isInPlan),
              onNo: () => setState(() => _showOverlay = false),
            ),
        ],
      ),
    );
  }
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
          color: isDisabled ? _catalogMuted : (isInPlan ? _catalogPink : _catalogPurple),
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

class _OfflineCourseAction extends StatelessWidget {
  const _OfflineCourseAction({
    required this.isOnline,
    required this.isSavedOffline,
    required this.isDownloading,
    required this.progress,
    required this.onSave,
    required this.onRemove,
  });

  final bool isOnline;
  final bool isSavedOffline;
  final bool isDownloading;
  final double? progress;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return _roundActionShell(
        tooltip: 'Saving course offline',
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.4,
            color: _catalogPurple,
          ),
        ),
      );
    }

    if (isSavedOffline) {
      return _roundActionButton(
        tooltip: 'Remove offline copy',
        icon: Icons.bookmark_remove_outlined,
        color: const Color(0xFF24A35A),
        onTap: onRemove,
      );
    }

    return _roundActionButton(
      tooltip: isOnline ? 'Save for offline' : 'Connect to save offline',
      icon: isOnline ? Icons.bookmark_add_outlined : Icons.wifi_off_rounded,
      color: isOnline ? _catalogPurple : _catalogMuted,
      onTap: isOnline ? onSave : null,
    );
  }

  Widget _roundActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return _roundActionShell(
      tooltip: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }

  Widget _roundActionShell({required String tooltip, required Widget child}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 5,
        shape: const CircleBorder(),
        child: Padding(
          padding: child is InkWell ? EdgeInsets.zero : const EdgeInsets.all(8),
          child: child,
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
      child: const Icon(Icons.school_outlined, size: 58, color: _catalogPurple),
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

class _NextSession extends StatelessWidget {
  const _NextSession({required this.date, required this.label});
  final DateTime? date;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT AVAILABLE',
          style: TextStyle(
            fontSize: 9,
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              date == null ? label : _formatDate(date!),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
          if (onRetry != null)
            ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) {
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
  final hour =
      value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${months[value.month - 1]} ${value.day}, ${hour.toString().padLeft(2, '0')}:$minute $period';
}
