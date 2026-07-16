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
import 'package:lms/app_module.dart';

const _catalogPurple = Color(0xFF5756C9);
const _catalogPink = Color(0xFFB0006D);
const _catalogInk = Color(0xFF172033);
const _catalogMuted = Color(0xFF7C879D);
const _catalogBackground = Color(0xFFF4F7F8);

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
  bool _filtersExpanded = false;
  bool _redirectingUnauthorized = false;
  String? _selectedSkillId;

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
      drawer: isWide ? null : const _CatalogDrawer(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isWide ? 78 : 60),
        child: _CatalogAppBar(isWide: isWide),
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
                  expanded: isWide || _filtersExpanded,
                  showHeader: !isWide,
                  onToggle:
                      () =>
                          setState(() => _filtersExpanded = !_filtersExpanded),
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
                    mainAxisExtent: width >= 760 ? 260 : 318,
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
        return [_groupTitle('Available'), _catalogGrid(courses)];
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
              mainAxisExtent: width >= 760 ? 260 : 318,
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

class _CatalogAppBar extends ConsumerWidget {
  const _CatalogAppBar({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final canPop = Navigator.canPop(context);
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: isWide ? 42 : 60,
      backgroundColor: _catalogPurple,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: isWide ? 0 : (canPop ? 106 : 68),
      leading:
          isWide
              ? null
              : Builder(
                builder:
                    (ctx) => Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canPop) ...[
                              _TopIconButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 6),
                            ],
                            _TopIconButton(
                              icon: Icons.menu_rounded,
                              onTap: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
      title: const SizedBox.shrink(),
      actions: [
        if (isWide) ...[const _DatePill(), const SizedBox(width: 8)],
        _TopIconButton(
          icon: Icons.notifications_rounded,
          onTap: () => _showNotifications(context),
          boxed: false,
        ),
        SizedBox(width: isWide ? 8 : 12),
        PopupMenuButton<String>(
          offset: Offset(0, isWide ? 38 : 54),
          constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(AuthStateNotifier.provider.notifier).logout();
              Modular.to.navigate('/');
            }
          },
          itemBuilder:
              (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: _ProfileHeader(profile: profile),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: _ProfileMenuRow(
                    icon: Icons.settings,
                    label: 'Account Settings',
                  ),
                ),
                PopupMenuItem<String>(
                  enabled: false,
                  child: _ProfileMenuRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'My Points: ${profile?.points ?? 0}',
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: _ProfileMenuRow(
                    icon: Icons.logout,
                    label: 'Logout Account',
                  ),
                ),
              ],
          child: _Avatar(profile: profile, radius: isWide ? 15 : 21),
        ),
        SizedBox(width: isWide ? 7 : 8),
        Icon(Icons.play_arrow_rounded, size: isWide ? 18 : 26),
        SizedBox(width: isWide ? 10 : 12),
      ],
      bottom: isWide ? const _HeaderNavBar() : null,
    );
  }
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
          children: const [
            _NavItem(icon: Icons.menu_book_outlined, label: 'Course Catalog'),
            _NavItem(
              icon: Icons.library_books_outlined,
              label: 'My Courses',
              menu: true,
            ),
            _NavItem(
              icon: Icons.account_tree_outlined,
              label: 'Learning Paths',
            ),
            _NavItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Points & Badges',
              menu: true,
            ),
            _NavItem(
              icon: Icons.support_agent_outlined,
              label: 'Contact a Coach',
              menu: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.menu = false});

  final IconData icon;
  final String label;
  final bool menu;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        'Tuesday July 14, 2026|1:04 PM',
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.boxed = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final size = isWide ? 30.0 : 42.0;
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color:
              boxed ? Colors.white.withValues(alpha: .12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(icon, size: isWide ? 18 : 27),
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.expanded,
    required this.showHeader,
    required this.onToggle,
    required this.searchController,
    required this.skills,
    required this.selectedSkillId,
    required this.onSkillChanged,
    required this.onApply,
    required this.onReset,
  });

  final bool expanded;
  final bool showHeader;
  final VoidCallback onToggle;
  final TextEditingController searchController;
  final List<CatalogSkill> skills;
  final String? selectedSkillId;
  final ValueChanged<String?> onSkillChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 14 : 14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B172033),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          if (showHeader)
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_rounded,
                      color: _catalogPurple,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _catalogInk,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _catalogPurple,
                    ),
                  ],
                ),
              ),
            ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: EdgeInsets.only(top: showHeader ? 10 : 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final fields = <Widget>[
                    _CatalogField(
                      controller: searchController,
                      hint: 'Search',
                      showClear: true,
                    ),
                    _SkillDropdown(
                      skills: skills,
                      value: selectedSkillId,
                      onChanged: onSkillChanged,
                    ),
                  ];
                  return Column(
                    children: [
                      if (!wide && showHeader)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 14),
                          child: Divider(height: 1, color: Color(0xFFE9EDF4)),
                        ),
                      if (wide)
                        SingleChildScrollView(
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
                                  icon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Search',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...fields.map(
                          (field) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: field,
                          ),
                        ),
                      if (!wide) ...[
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: onReset,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  side: BorderSide.none,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Icon(Icons.undo_rounded),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: onApply,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: _catalogPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Search',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
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
  });
  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return _ClearableTextField(
      controller: controller,
      enabled: enabled,
      hint: hint,
      showClear: showClear,
    );
  }
}

class _ClearableTextField extends StatefulWidget {
  const _ClearableTextField({
    required this.hint,
    this.controller,
    this.enabled = true,
    this.showClear = false,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String hint;
  final bool enabled;
  final bool showClear;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

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
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: _fieldDecoration(
        widget.hint,
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
        decoration: _fieldDecoration('Skills or Behavior').copyWith(
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
          selected?.name ?? 'Skills or Behavior',
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

InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _catalogMuted, fontSize: 13),
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: Color(0xFF91A0B8),
        size: 18,
      ),
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
  });

  final int id;
  final String name;
  final String? logo;
  final double progress;
  final DateTime? nextSession;
  final String? nextSessionLabel;
  final Course offlineCourse;

  factory _CourseCardData.fromCatalog(CatalogCourse course) {
    return _CourseCardData(
      id: course.id,
      name: course.name,
      logo: course.logo,
      progress: course.progress,
      nextSession: course.nextSession,
      nextSessionLabel: course.nextSessionLabel,
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

class _CatalogCourseCard extends ConsumerWidget {
  const _CatalogCourseCard({required this.course});
  final _CourseCardData course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineVM = ref.watch(OfflineViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    ref.watch(SyncViewModel.provider);

    final isOnline = !isManualOffline && connectionVM.isConnected;
    final isSavedOffline = offlineVM.isAvailable(course.offlineCourse);
    final isDownloading = offlineVM.isDownloading(course.offlineCourse);
    final progress = offlineVM.downloadProgress(course.offlineCourse);
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWide ? 15 : 14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10172033),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: isWide ? 112 : 188,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CourseImage(url: course.logo),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _OfflineCourseAction(
                    isOnline: isOnline,
                    isSavedOffline: isSavedOffline,
                    isDownloading: isDownloading,
                    progress: progress,
                    onSave: () => offlineVM.download(course.offlineCourse),
                    onRemove:
                        () => offlineVM.removeOffline(course.offlineCourse),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(15, isWide ? 8 : 10, 15, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course.nextSessionLabel != null) ...[
                    _NextSession(
                      date: course.nextSession,
                      label: course.nextSessionLabel!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    course.name.isEmpty ? 'Untitled Course' : course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _catalogInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          () => Modular.to.pushNamed(
                            CoursesModule.construct(
                              '${CoursesModule.detail}/${course.id}',
                            ),
                            arguments: course.offlineCourse,
                          ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size.fromHeight(isWide ? 38 : 42),
                        backgroundColor: _catalogPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isWide ? 7 : 10),
                        ),
                      ),
                      child: Text(
                        'View Course',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
        tooltip: 'Remove offline course',
        icon: Icons.remove_rounded,
        color: const Color(0xFF24A35A),
        onTap: onRemove,
      );
    }

    return _roundActionButton(
      tooltip: isOnline ? 'Save course offline' : 'Connect to save offline',
      icon: isOnline ? Icons.add_rounded : Icons.cloud_off_rounded,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3FF),
        border: Border.all(color: const Color(0xFFDCD9F7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT AVAILABLE',
            style: TextStyle(fontSize: 9, color: _catalogMuted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 15,
                color: _catalogPurple,
              ),
              const SizedBox(width: 4),
              Text(
                date == null ? label : _formatDate(date!),
                style: const TextStyle(
                  fontSize: 11,
                  color: _catalogPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogDrawer extends ConsumerWidget {
  const _CatalogDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final title =
        auth?.group?.isNotEmpty == true ? auth!.group!.first.name : 'Main Menu';
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: width >= 760 ? 340 : (width * .8).clamp(300, 315).toDouble(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 13, 14, 54),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title?.toUpperCase() ?? 'MAIN MENU',
                      style: const TextStyle(
                        color: _catalogPurple,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: _catalogMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 26),
              child: Text(
                'MAIN NAVIGATION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _catalogMuted,
                ),
              ),
            ),
            const SizedBox(height: 27),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      onTap: () {
                        Navigator.pop(context);
                        Modular.to.navigate(
                          CoursesModule.construct(CoursesModule.dashboard),
                        );
                      },
                    ),
                    const _DrawerItem(
                      icon: Icons.menu_book_outlined,
                      label: 'Course Catalog',
                      selected: true,
                    ),
                    _DrawerItem(
                      icon: Icons.library_books_outlined,
                      label: 'My Courses',
                      children: [
                        _SubItem(
                          label: 'My Enrolled Courses',
                          icon: Icons.school_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.enrolledCourses),
                            );
                          },
                        ),
                        const _SubItem(
                          label: 'My Completed Courses',
                          icon: Icons.task_alt,
                        ),
                        const _SubItem(
                          label: 'My Development Plan',
                          icon: Icons.timeline_outlined,
                        ),
                        const _SubItem(
                          label: 'My Required Courses',
                          icon: Icons.assignment_outlined,
                        ),
                      ],
                    ),
                    const _DrawerItem(
                      icon: Icons.account_tree_outlined,
                      label: 'Learning Paths',
                    ),
                    const _DrawerItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Points & Badges',
                      children: [
                        _SubItem(
                          label: 'Redeem your Points',
                          icon: Icons.card_giftcard_outlined,
                        ),
                        _SubItem(
                          label: 'Badges',
                          icon: Icons.military_tech_outlined,
                        ),
                      ],
                    ),
                    const _DrawerItem(
                      icon: Icons.support_agent_outlined,
                      label: 'Contact a Coach',
                      children: [
                        _SubItem(
                          label: 'Contact a Development Pro',
                          icon: Icons.person_outline,
                        ),
                        _SubItem(
                          label: 'Virtual Development Pro',
                          icon: Icons.video_call_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubItem {
  const _SubItem({required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.trailing = false,
    this.onTap,
    this.children = const [],
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool trailing;
  final VoidCallback? onTap;
  final List<_SubItem> children;

  Widget _iconBox(bool isSelected) => Container(
    width: 37,
    height: 37,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isSelected ? const Color(0xFFE8E7F8) : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, size: 20, color: isSelected ? _catalogPurple : _catalogMuted),
  );

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 2),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            childrenPadding: const EdgeInsets.only(left: 16, bottom: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: _iconBox(false),
            title: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF354056),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            iconColor: _catalogMuted,
            collapsedIconColor: _catalogMuted,
            children: children.map((sub) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
              leading: sub.icon != null
                  ? Icon(sub.icon, size: 18, color: _catalogMuted)
                  : const SizedBox(width: 18),
              title: Text(
                sub.label,
                style: const TextStyle(
                  color: Color(0xFF354056),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: sub.onTap,
            )).toList(),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0EFFF) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _iconBox(selected),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _catalogPurple : const Color(0xFF354056),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing)
                const Icon(Icons.keyboard_arrow_down, size: 17, color: _catalogMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.radius});
  final dynamic profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = profile?.avatarBaseUrl?.toString() ?? '';
    final path = profile?.avatarPath?.toString() ?? '';
    final url = path.startsWith('http') ? path : '$base$path';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: radius - 2,
        backgroundColor: const Color(0xFF10121B),
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
        child:
            url.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final name =
        '${profile?.firstname ?? ''} ${profile?.lastname ?? ''}'.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7A42C4), Color(0xFFB0006D)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          _Avatar(profile: profile, radius: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'User' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'USER',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 21, color: _catalogMuted),
      const SizedBox(width: 13),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF4C586C), fontSize: 15),
      ),
    ],
  );
}

void _showNotifications(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder:
        (context) => Dialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.fromLTRB(16, 76, 16, 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _catalogInk,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Mark all as read',
                        style: TextStyle(
                          color: _catalogPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 42),
                const CircleAvatar(
                  backgroundColor: Color(0xFF24C56B),
                  child: Icon(Icons.check, color: Colors.white, size: 27),
                ),
                const SizedBox(height: 18),
                const Text(
                  "You're all caught up",
                  style: TextStyle(
                    color: Color(0xFF9AA8C0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 40),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFBFD),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'View All Notifications',
                        style: TextStyle(
                          color: _catalogPurple,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );
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
