import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

const _purple = Color(0xFF5756C9);
const _muted = Color(0xFF7C879D);

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, this.selectedLabel});

  /// The nav item label that should appear highlighted (e.g. 'Dashboard', 'Course Catalog').
  final String? selectedLabel;

  Future<void> _launchContactUrl(BuildContext context, WidgetRef ref) async {
    final user = ref.read(AuthStateNotifier.provider)?.user;
    final email = Uri.encodeComponent(user?.email ?? '');
    final authKey = Uri.encodeComponent(user?.authKey ?? '');
    final uri = Uri.parse(
      'https://login.leadershipedge.coach/backend/web/sign-in/oauth-login?email=$email&authkey=$authKey',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchVirtualDev() async {
    final uri = Uri.parse(
      'https://staging.trainingpipeline.com/backend/web/chatgpt/virtual-development-pro/index',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    final isOnline = _watchIsOnline(ref);
    final title =
        auth?.group?.isNotEmpty == true
            ? auth!.group!.first.name
            : 'Main Menu';
    final width = MediaQuery.sizeOf(context).width;
    final sel = selectedLabel;
    return Drawer(
      width: (width * .8).clamp(300, 315).toDouble(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 10, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title?.toUpperCase() ?? 'MAIN MENU',
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16, color: _muted),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
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
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _DrawerItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      selected: sel == 'Dashboard',
                      onTap: () {
                        Navigator.pop(context);
                        if (sel != 'Dashboard') {
                          Modular.to.navigate(
                            CoursesModule.construct(CoursesModule.dashboard),
                          );
                        }
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.menu_book_outlined,
                      label: 'Course Catalog',
                      selected: sel == 'Course Catalog',
                      onTap: () {
                        Navigator.pop(context);
                        if (sel != 'Course Catalog') {
                          Modular.to.navigate(
                            CoursesModule.construct(CoursesModule.root),
                          );
                        }
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
                        _SubItem(
                          label: 'My Development Plan',
                          icon: Icons.timeline_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(
                                CoursesModule.developmentPlan,
                              ),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'My Required Courses',
                          icon: Icons.assignment_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(
                                CoursesModule.requiredCourses,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    _DrawerItem(
                      icon: Icons.account_tree_outlined,
                      label: 'Learning Paths',
                      onTap: () {
                        Navigator.pop(context);
                        Modular.to.pushNamed(
                          CoursesModule.construct(CoursesModule.learningPaths),
                        );
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Points & Badges',
                      children: [
                        _SubItem(
                          label: 'Redeem your Points',
                          icon: Icons.redeem_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.redeemPoints),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'Badges',
                          icon: Icons.military_tech_outlined,
                          onTap: () {
                            Navigator.pop(context);
                            Modular.to.pushNamed(
                              CoursesModule.construct(CoursesModule.badges),
                            );
                          },
                        ),
                      ],
                    ),
                    _DrawerItem(
                      icon: Icons.support_agent_outlined,
                      label: 'Contact a Coach',
                      children: [
                        _SubItem(
                          label: 'Contact a Development Pro',
                          icon: Icons.person_outline_rounded,
                          disabled: !isOnline,
                          onTap: () {
                            Navigator.pop(context);
                            _launchContactUrl(context, ref);
                          },
                        ),
                        _SubItem(
                          label: 'Virtual Development Pro',
                          icon: Icons.smart_toy_outlined,
                          disabled: !isOnline,
                          onTap: () {
                            Navigator.pop(context);
                            _launchVirtualDev();
                          },
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
  const _SubItem({
    required this.label,
    this.icon,
    this.onTap,
    this.disabled = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool disabled;
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
    width: 30,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: isSelected ? const Color(0xFFE8E7F8) : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Icon(icon, size: 17, color: isSelected ? _purple : _muted),
  );

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            childrenPadding: const EdgeInsets.only(left: 12, bottom: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: _iconBox(false),
            title: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF354056),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconColor: _muted,
            collapsedIconColor: _muted,
            children: children
                .map(
                  (sub) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
                    leading: Icon(
                      sub.disabled ? Icons.cloud_off_rounded : sub.icon,
                      size: 16,
                      color: _muted,
                    ),
                    title: Text(
                      sub.label,
                      style: TextStyle(
                        color: sub.disabled ? _muted : const Color(0xFF354056),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: sub.disabled ? null : sub.onTap,
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0EFFF) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _iconBox(selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _purple : const Color(0xFF354056),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing)
                const Icon(Icons.arrow_forward_ios, size: 13, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}
