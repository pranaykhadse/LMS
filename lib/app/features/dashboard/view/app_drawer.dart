import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';

const _purple = Color(0xFF5756C9);
const _muted = Color(0xFF7C879D);

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final title =
        auth?.group?.isNotEmpty == true
            ? auth!.group!.first.name
            : 'Main Menu';
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * .8).clamp(300, 315).toDouble(),
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
                        color: _purple,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18, color: _muted),
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
                  color: _muted,
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
                    _DrawerItem(
                      icon: Icons.menu_book_outlined,
                      label: 'Course Catalog',
                      onTap: () {
                        Navigator.pop(context);
                        Modular.to.navigate(
                          CoursesModule.construct(CoursesModule.root),
                        );
                      },
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
                              CoursesModule.construct(
                                CoursesModule.enrolledCourses,
                              ),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'My Completed Courses',
                          icon: Icons.task_alt,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(
                                CoursesModule.completedCourses,
                              ),
                            );
                          },
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
    child: Icon(icon, size: 20, color: isSelected ? _purple : _muted),
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
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: _iconBox(false),
            title: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF354056),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            iconColor: _muted,
            collapsedIconColor: _muted,
            children: children
                .map(
                  (sub) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                    leading: sub.icon != null
                        ? Icon(sub.icon, size: 18, color: _muted)
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
                  ),
                )
                .toList(),
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
                    color: selected ? _purple : const Color(0xFF354056),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing)
                const Icon(Icons.arrow_forward_ios, size: 14, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}
