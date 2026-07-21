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
const _navy = Color(0xFF37424E);
const _chevron = Color(0xFF98A2B3);

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, this.selectedLabel, this.selectedSubLabel});

  /// The top-level nav item label that should appear highlighted (e.g.
  /// 'Dashboard', 'Course Catalog', or a group label like 'My Courses' —
  /// grouped items also auto-expand and highlight their header when this
  /// or [selectedSubLabel] matches one of their children).
  final String? selectedLabel;

  /// The specific child label within a group that should also appear
  /// highlighted (e.g. 'My Enrolled Courses'). Its parent group header
  /// highlights and auto-expands automatically — no need to also pass
  /// [selectedLabel] for the group.
  final String? selectedSubLabel;

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
    final isOnline = _watchIsOnline(ref);
    final width = MediaQuery.sizeOf(context).width;
    final sel = selectedLabel;
    final subSel = selectedSubLabel;

    const myCoursesChildren = [
      'My Enrolled Courses',
      'My Completed Courses',
      'My Development Plan',
      'My Required Courses',
    ];
    const pointsBadgesChildren = ['Redeem your Points', 'Badges'];

    final myCoursesActive =
        sel == 'My Courses' || myCoursesChildren.contains(subSel);
    final pointsBadgesActive =
        sel == 'Points & Badges' || pointsBadgesChildren.contains(subSel);

    return Drawer(
      width: (width * .8).clamp(300, 315).toDouble(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MAIN NAVIGATION',
                      style: TextStyle(
                        color: _purple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: _purple),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF3)),
            const SizedBox(height: 6),
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
                      selected: myCoursesActive,
                      children: [
                        _SubItem(
                          label: 'My Enrolled Courses',
                          icon: Icons.school_outlined,
                          selected: subSel == 'My Enrolled Courses',
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
                          selected: subSel == 'My Completed Courses',
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
                          selected: subSel == 'My Development Plan',
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
                          selected: subSel == 'My Required Courses',
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
                      selected: pointsBadgesActive,
                      children: [
                        _SubItem(
                          label: 'Redeem your Points',
                          icon: Icons.redeem_outlined,
                          selected: subSel == 'Redeem your Points',
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
                          selected: subSel == 'Badges',
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
    this.selected = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool disabled;
  final bool selected;
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

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('drawer-group-$label-$selected'),
          initiallyExpanded: selected,
          tilePadding: const EdgeInsets.fromLTRB(24, 0, 20, 0),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          leading: Icon(icon, size: 21, color: selected ? _purple : _navy),
          title: Text(
            label,
            style: TextStyle(
              color: selected ? _purple : const Color(0xFF23292F),
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          iconColor: _chevron,
          collapsedIconColor: _chevron,
          children: children
              .map(
                (sub) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.fromLTRB(48, 0, 20, 0),
                  leading: Icon(
                    sub.disabled ? Icons.cloud_off_rounded : sub.icon,
                    size: 18,
                    color: sub.disabled
                        ? _muted
                        : (sub.selected ? _purple : _navy),
                  ),
                  title: Text(
                    sub.label,
                    style: TextStyle(
                      color: sub.disabled
                          ? _muted
                          : (sub.selected ? _purple : const Color(0xFF23292F)),
                      fontSize: 14,
                      fontWeight:
                          sub.selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  onTap: sub.disabled ? null : sub.onTap,
                ),
              )
              .toList(),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 20, 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: selected ? _purple : _navy),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? _purple : const Color(0xFF23292F),
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (trailing)
              const Icon(Icons.arrow_forward_ios, size: 13, color: _chevron),
          ],
        ),
      ),
    );
  }
}
