import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/contact_links.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _muted = FigmaTokens.noteBodyText;
const _navy = FigmaTokens.cardTitles;
const _chevron = Color(0xFF98A2B3);
const _activeBg = Color(0xFFF3ECFB);
const _activeBorder = Color(0xFFDCC9F2);

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

/// The phone slide-out navigation drawer. Desktop/tablet use a horizontal
/// nav bar in LmsAppBar instead (see that file's `_DesktopNavBar`).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    this.selectedLabel,
    this.selectedSubLabel,
  });

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

  void _closeIfNeeded(BuildContext context) => Navigator.pop(context);

  void _goTo(BuildContext context, String route) {
    resetToModularRoot(context);
    Modular.to.pushNamed(route);
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

    final content = SafeArea(
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
                    onPressed: () => _closeIfNeeded(context),
                    icon: const Icon(Icons.close, size: 20, color: _purple),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: FigmaTokens.cardBorders),
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
                        _closeIfNeeded(context);
                        resetToModularRoot(context);
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
                        _closeIfNeeded(context);
                        resetToModularRoot(context);
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
                            _closeIfNeeded(context);
                            _goTo(
                              context,
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
                            _closeIfNeeded(context);
                            _goTo(
                              context,
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
                            _closeIfNeeded(context);
                            _goTo(
                              context,
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
                            _closeIfNeeded(context);
                            _goTo(
                              context,
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
                      selected: sel == 'Learning Paths',
                      onTap: () {
                        _closeIfNeeded(context);
                        _goTo(
                          context,
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
                            _closeIfNeeded(context);
                            _goTo(
                              context,
                              CoursesModule.construct(CoursesModule.redeemPoints),
                            );
                          },
                        ),
                        _SubItem(
                          label: 'Badges',
                          icon: Icons.military_tech_outlined,
                          selected: subSel == 'Badges',
                          onTap: () {
                            _closeIfNeeded(context);
                            _goTo(
                              context,
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
                            _closeIfNeeded(context);
                            launchContactCoachUrl(ref, context);
                          },
                        ),
                        _SubItem(
                          label: 'Virtual Development Pro',
                          icon: Icons.smart_toy_outlined,
                          disabled: !isOnline,
                          onTap: () {
                            _closeIfNeeded(context);
                            launchVirtualDevUrl(context, ref);
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
    );

    return Drawer(
      width: (width * .8).clamp(300, 315).toDouble(),
      backgroundColor: Colors.white,
      child: content,
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

/// Every top-level item — group or leaf — sits in its own bordered,
/// rounded box. A group's box fills with a light purple tint and its
/// sub-items appear inline (behind a purple left accent line) instead of
/// in a separate floating card, matching the reference design.
class _DrawerItem extends StatefulWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
    this.children = const [],
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final List<_SubItem> children;

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  late bool _expanded = widget.selected;

  @override
  void didUpdateWidget(_DrawerItem old) {
    super.didUpdateWidget(old);
    // Mirrors the old ExpansionTile+ValueKey(selected) approach: expansion
    // state fully resets to match `selected` whenever it changes, in
    // either direction (auto-expand when navigated to, auto-collapse
    // when navigated away from).
    if (widget.selected != old.selected) {
      setState(() => _expanded = widget.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = widget.children.isNotEmpty;
    final active = widget.selected;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: active ? _activeBg : Colors.white,
        border: Border.all(color: active ? _activeBorder : FigmaTokens.cardBorders),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: hasChildren
                ? () => setState(() => _expanded = !_expanded)
                : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: active ? _purple : _navy),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: active ? _purple : const Color(0xFF23292F),
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasChildren)
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _chevron,
                    ),
                ],
              ),
            ),
          ),
          if (hasChildren)
            // AnimatedSize instead of an instant conditional insert -
            // toggling this InkWell used to swap a whole subtree into the
            // tree within the same tap's hit-test frame, which corrupted
            // the semantics tree ('!semantics.parentDataDirty' assertion
            // flood + "Cannot hit test a render box with no size").
            // AnimatedCrossFade was tried first but its internal Stack +
            // AnimatedOpacity produced its own layout failure
            // ("RenderAnimatedOpacity was not laid out") in this
            // Column/Drawer context - AnimatedSize is the simpler
            // single-child RenderObject ExpansionTile itself uses.
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 2,
                            margin: const EdgeInsets.only(right: 12),
                            color: _purple,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                for (final sub in widget.children) _SubTile(sub: sub),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
        ],
      ),
    );
  }
}

class _SubTile extends StatelessWidget {
  const _SubTile({required this.sub});
  final _SubItem sub;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: sub.disabled ? null : sub.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              sub.disabled ? Icons.cloud_off_rounded : sub.icon,
              size: 18,
              color: sub.disabled ? _muted : (sub.selected ? _purple : _navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                sub.label,
                style: TextStyle(
                  color: sub.disabled
                      ? _muted
                      : (sub.selected ? _purple : const Color(0xFF23292F)),
                  fontSize: 13.5,
                  fontWeight: sub.selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
