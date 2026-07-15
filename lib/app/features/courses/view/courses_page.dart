import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/model/course_catalog.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/course_catalog_view_model.dart';

const _catalogPurple = Color(0xFF5756C9);
const _catalogPink = Color(0xFFB0006D);
const _catalogInk = Color(0xFF172033);
const _catalogMuted = Color(0xFF7C879D);
const _catalogBackground = Color(0xFFF4F7F8);

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  final _searchController = TextEditingController();
  bool _filtersExpanded = false;
  String? _selectedSkillId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(CourseCatalogViewModel.provider);
    final auth = ref.watch(AuthStateNotifier.provider);
    final response = catalogState.result.data;
    final groupName = auth?.group?.isNotEmpty == true
        ? auth!.group!.first.name
        : null;

    return Scaffold(
      backgroundColor: _catalogBackground,
      drawer: const _CatalogDrawer(),
      appBar: const _CatalogAppBar(),
      body: RefreshIndicator(
        onRefresh: () => ref.read(CourseCatalogViewModel.provider.notifier).fetch(
              page: response?.page ?? 1,
            ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
              sliver: SliverToBoxAdapter(
                child: _FilterPanel(
                  expanded: _filtersExpanded,
                  onToggle: () => setState(() => _filtersExpanded = !_filtersExpanded),
                  searchController: _searchController,
                  skills: response?.skills ?? const [],
                  selectedSkillId: _selectedSkillId,
                  onSkillChanged: (value) => setState(() => _selectedSkillId = value),
                  onApply: () => ref
                      .read(CourseCatalogViewModel.provider.notifier)
                      .applyFilters(
                        search: _searchController.text,
                        skillId: _selectedSkillId,
                      ),
                  onReset: () {
                    _searchController.clear();
                    setState(() => _selectedSkillId = null);
                    ref.read(CourseCatalogViewModel.provider.notifier).reset();
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${groupName?.trim().isNotEmpty == true ? groupName : 'Available'} Courses',
                  style: const TextStyle(
                    color: _catalogPink,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            ..._buildContent(catalogState.result),
            if (response != null && response.pages > 1)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                sliver: SliverToBoxAdapter(
                  child: _CatalogPagination(
                    page: response.page,
                    pages: response.pages,
                    onPage: (page) => ref
                        .read(CourseCatalogViewModel.provider.notifier)
                        .fetch(page: page),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(DataState<CourseCatalogResponse> state) {
    switch (state.state) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: _catalogPurple)),
          ),
        ];
      case DataProviderState.error:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _CatalogError(
              message: state.error ?? 'Unable to load courses.',
              onRetry: () => ref.read(CourseCatalogViewModel.provider.notifier).fetch(),
            ),
          ),
        ];
      case DataProviderState.data:
        final courses = state.data?.courses ?? const <CatalogCourse>[];
        if (courses.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No courses found.')),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 980 ? 3 : (width >= 620 ? 2 : 1);
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 22,
                    mainAxisExtent: 320,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _CatalogCourseCard(course: courses[index]),
                    childCount: courses.length,
                  ),
                );
              },
            ),
          ),
        ];
    }
  }
}

class _CatalogAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _CatalogAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      backgroundColor: _catalogPurple,
      foregroundColor: Colors.white,
      elevation: 2,
      titleSpacing: 14,
      title: Builder(
        builder: (context) => _TopIconButton(
          icon: Icons.menu_rounded,
          onTap: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        _TopIconButton(
          icon: Icons.notifications_rounded,
          onTap: () => _showNotifications(context),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          offset: const Offset(0, 54),
          constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(AuthStateNotifier.provider.notifier).logout();
              Modular.to.navigate('/');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: _ProfileHeader(profile: profile),
            ),
            const PopupMenuItem<String>(
              value: 'settings',
              child: _ProfileMenuRow(icon: Icons.settings, label: 'Account Settings'),
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
              child: _ProfileMenuRow(icon: Icons.logout, label: 'Logout Account'),
            ),
          ],
          child: _Avatar(profile: profile, radius: 21),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.play_arrow_rounded, size: 26),
        const SizedBox(width: 14),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.1),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 27),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.expanded,
    required this.onToggle,
    required this.searchController,
    required this.skills,
    required this.selectedSkillId,
    required this.onSkillChanged,
    required this.onApply,
    required this.onReset,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController searchController;
  final List<CatalogSkill> skills;
  final String? selectedSkillId;
  final ValueChanged<String?> onSkillChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0B172033), blurRadius: 20, offset: Offset(0, 7))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _catalogBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_rounded, color: _catalogPurple, size: 20),
                  const SizedBox(width: 8),
                  const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700, color: _catalogInk)),
                  const Spacer(),
                  Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _catalogPurple),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final fields = <Widget>[
                    _CatalogField(controller: searchController, hint: 'Search'),
                    const _CatalogField(hint: 'Strategic Initiative', enabled: false),
                    const _CatalogField(hint: 'Competencies', enabled: false),
                    _SkillDropdown(skills: skills, value: selectedSkillId, onChanged: onSkillChanged),
                  ];
                  return Column(
                    children: [
                      if (wide)
                        Row(children: [for (final field in fields) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: field))])
                      else
                        ...fields.map((field) => Padding(padding: const EdgeInsets.only(bottom: 9), child: field)),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: onReset,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(42),
                                side: BorderSide.none,
                                backgroundColor: _catalogBackground,
                              ),
                              child: const Icon(Icons.undo_rounded),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: onApply,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(42),
                                backgroundColor: _catalogPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              child: const Text('Calendar View', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
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
  const _CatalogField({this.controller, required this.hint, this.enabled = true});
  final TextEditingController? controller;
  final String hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: _fieldDecoration(hint),
    );
  }
}

class _SkillDropdown extends StatelessWidget {
  const _SkillDropdown({required this.skills, required this.value, required this.onChanged});
  final List<CatalogSkill> skills;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final unique = <String, CatalogSkill>{for (final skill in skills) skill.id: skill}.values.toList();
    return DropdownButtonFormField<String>(
      value: unique.any((skill) => skill.id == value) ? value : null,
      isExpanded: true,
      decoration: _fieldDecoration('Skills or Behavior'),
      items: unique
          .map((skill) => DropdownMenuItem(value: skill.id, child: Text(skill.name, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _catalogMuted, fontSize: 13),
      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF91A0B8), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE3E8EF))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE3E8EF))),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFE3E8EF))),
    );

class _CatalogCourseCard extends StatelessWidget {
  const _CatalogCourseCard({required this.course});
  final CatalogCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Color(0x10172033), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _CourseImage(url: course.logo),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    elevation: 5,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {},
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.add, size: 21, color: _catalogPurple),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (course.nextSession != null) ...[
                  _NextSession(date: course.nextSession!),
                  const SizedBox(height: 10),
                ],
                Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _catalogInk, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Modular.to.pushNamed(
                      CoursesModule.construct('${CoursesModule.detail}/${course.id}'),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: _catalogPurple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                    ),
                    child: const Text('View Course', style: TextStyle(fontWeight: FontWeight.w700)),
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
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: const Color(0xFFF1EFFB),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2, color: _catalogPurple),
            ),
    );
  }
}

class _NextSession extends StatelessWidget {
  const _NextSession({required this.date});
  final DateTime date;

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
          const Text('NEXT AVAILABLE', style: TextStyle(fontSize: 9, color: _catalogMuted)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 15, color: _catalogPurple),
              const SizedBox(width: 4),
              Text(_formatDate(date), style: const TextStyle(fontSize: 11, color: _catalogPurple, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogPagination extends StatelessWidget {
  const _CatalogPagination({required this.page, required this.pages, required this.onPage});
  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final visible = <int>{1, page - 1, page, page + 1, pages}.where((value) => value >= 1 && value <= pages).toList()..sort();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _PageButton(icon: Icons.chevron_left, enabled: page > 1, onTap: () => onPage(page - 1)),
              for (var index = 0; index < visible.length; index++) ...[
                if (index > 0 && visible[index] - visible[index - 1] > 1)
                  const SizedBox(width: 34, height: 34, child: Center(child: Text('…'))),
                _PageButton(label: '${visible[index]}', selected: visible[index] == page, onTap: () => onPage(visible[index])),
              ],
              _PageButton(icon: Icons.chevron_right, enabled: page < pages, onTap: () => onPage(page + 1)),
            ],
          ),
          const SizedBox(height: 12),
          Container(width: 12, height: 3, decoration: BoxDecoration(color: _catalogPurple, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          Text('PAGE $page OF $pages', style: const TextStyle(color: Color(0xFFA0A9BC), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .6)),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({this.label, this.icon, this.selected = false, this.enabled = true, required this.onTap});
  final String? label;
  final IconData? icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _catalogPurple : const Color(0xFFF9FAFC),
          border: selected ? null : Border.all(color: const Color(0xFFEDF0F5)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: icon != null
            ? Icon(icon, size: 19, color: enabled ? _catalogPurple : const Color(0xFFCBD1DC))
            : Text(label!, style: TextStyle(color: selected ? Colors.white : _catalogInk, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _CatalogDrawer extends ConsumerWidget {
  const _CatalogDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final title = auth?.group?.isNotEmpty == true ? auth!.group!.first.name : 'Main Menu';
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(260, 340).toDouble(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 28),
              child: Row(
                children: [
                  Expanded(child: Text(title?.toUpperCase() ?? 'MAIN MENU', style: const TextStyle(color: _catalogPurple, fontSize: 16))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18, color: _catalogMuted)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('MAIN NAVIGATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: _catalogMuted)),
            ),
            const SizedBox(height: 16),
            const _DrawerItem(icon: Icons.menu_book_outlined, label: 'Course Catalog', selected: true),
            const _DrawerItem(icon: Icons.library_books_outlined, label: 'My Courses', trailing: true),
            const _DrawerItem(icon: Icons.account_tree_outlined, label: 'Learning Paths'),
            const _DrawerItem(icon: Icons.workspace_premium_outlined, label: 'Points & Badges', trailing: true),
            const _DrawerItem(icon: Icons.support_agent_outlined, label: 'Contact a Coach', trailing: true),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, this.selected = false, this.trailing = false});
  final IconData icon;
  final String label;
  final bool selected;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: selected ? const Color(0xFFF0EFFF) : null, borderRadius: BorderRadius.circular(11)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? _catalogPurple : _catalogMuted),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: TextStyle(color: selected ? _catalogPurple : const Color(0xFF354056), fontSize: 13, fontWeight: FontWeight.w600))),
            if (trailing) const Icon(Icons.keyboard_arrow_down, size: 17, color: _catalogMuted),
          ],
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
        child: url.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final dynamic profile;

  @override
  Widget build(BuildContext context) {
    final name = '${profile?.firstname ?? ''} ${profile?.lastname ?? ''}'.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF7A42C4), Color(0xFFB0006D)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          _Avatar(profile: profile, radius: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? 'User' : name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const Text('USER', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
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
          Text(label, style: const TextStyle(color: Color(0xFF4C586C), fontSize: 15)),
        ],
      );
}

void _showNotifications(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (context) => Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 76, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _catalogInk)),
                  Spacer(),
                  Text('Mark all as read', style: TextStyle(color: _catalogPurple, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 42),
            const CircleAvatar(backgroundColor: Color(0xFF24C56B), child: Icon(Icons.check, color: Colors.white, size: 27)),
            const SizedBox(height: 18),
            const Text("You're all caught up", style: TextStyle(color: Color(0xFF9AA8C0), fontWeight: FontWeight.w700)),
            const SizedBox(height: 40),
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Color(0xFFFAFBFD), borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))),
                child: const Center(child: Text('View All Notifications', style: TextStyle(color: _catalogPurple, fontWeight: FontWeight.w700))),
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
  final VoidCallback onRetry;

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
              ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      );
}

String _formatDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${months[value.month - 1]} ${value.day}, ${hour.toString().padLeft(2, '0')}:$minute $period';
}
