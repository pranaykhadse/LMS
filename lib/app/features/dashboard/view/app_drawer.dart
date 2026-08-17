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

// ── Design tokens ──────────────────────────────────────────────────────────
const _purple = FigmaTokens.primaryPurple;
const _muted = FigmaTokens.noteBodyText;
const _itemText = Color(0xFF23292F);
const _sectionLabel = Color(0xFF6B7280);
// Lavender tint used for an expanded group's header card and children panel
const _lavender = Color(0xFFEDE8F7);
// Left accent bar for the expanded-children panel
const _accentBar = _purple;

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

// ── Public widget ──────────────────────────────────────────────────────────

/// The phone slide-out navigation drawer. Desktop/tablet use a horizontal
/// nav bar in LmsAppBar instead (see that file's `_DesktopNavBar`).
class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    this.selectedLabel,
    this.selectedSubLabel,
  });

  /// The top-level nav item label that should appear highlighted
  /// (e.g. 'Dashboard', 'Course Catalog', or a group label like
  /// 'My Courses' — grouped items auto-expand when this or
  /// [selectedSubLabel] matches one of their children).
  final String? selectedLabel;

  /// The specific child label within a group that should appear highlighted
  /// (e.g. 'My Enrolled Courses'). Its parent group auto-expands and
  /// highlights automatically.
  final String? selectedSubLabel;

  void _close(BuildContext context) => Navigator.pop(context);

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

    return Drawer(
      width: (width * .8).clamp(300, 315).toDouble(),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            _DrawerHeader(onClose: () => _close(context)),

            // ── Section label ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'MAIN NAVIGATION',
                style: TextStyle(
                  color: _sectionLabel,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),

            // ── Nav items ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    // Dashboard
                    _NavCard(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      selected: sel == 'Dashboard',
                      onTap: () {
                        _close(context);
                        resetToModularRoot(context);
                        if (sel != 'Dashboard') {
                          Modular.to.navigate(
                            CoursesModule.construct(CoursesModule.dashboard),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Course Catalog
                    _NavCard(
                      icon: Icons.menu_book_outlined,
                      label: 'Course Catalog',
                      selected: sel == 'Course Catalog',
                      onTap: () {
                        _close(context);
                        resetToModularRoot(context);
                        if (sel != 'Course Catalog') {
                          Modular.to.navigate(
                            CoursesModule.construct(CoursesModule.root),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // My Courses (expandable)
                    _ExpandableNavCard(
                      icon: Icons.library_books_outlined,
                      label: 'My Courses',
                      selected: myCoursesActive,
                      children: [
                        _SubNavItem(
                          icon: Icons.school_outlined,
                          label: 'My Enrolled Courses',
                          selected: subSel == 'My Enrolled Courses',
                          onTap: () {
                            _close(context);
                            _goTo(
                              context,
                              CoursesModule.construct(
                                CoursesModule.enrolledCourses,
                              ),
                            );
                          },
                        ),
                        _SubNavItem(
                          icon: Icons.task_alt,
                          label: 'My Completed Courses',
                          selected: subSel == 'My Completed Courses',
                          onTap: () {
                            _close(context);
                            _goTo(
                              context,
                              CoursesModule.construct(
                                CoursesModule.completedCourses,
                              ),
                            );
                          },
                        ),
                        _SubNavItem(
                          icon: Icons.timeline_outlined,
                          label: 'My Development Plan',
                          selected: subSel == 'My Development Plan',
                          onTap: () {
                            _close(context);
                            _goTo(
                              context,
                              CoursesModule.construct(
                                CoursesModule.developmentPlan,
                              ),
                            );
                          },
                        ),
                        _SubNavItem(
                          icon: Icons.assignment_outlined,
                          label: 'My Required Courses',
                          selected: subSel == 'My Required Courses',
                          onTap: () {
                            _close(context);
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
                    const SizedBox(height: 10),

                    // Learning Paths
                    _NavCard(
                      icon: Icons.account_tree_outlined,
                      label: 'Learning Paths',
                      selected: sel == 'Learning Paths',
                      onTap: () {
                        _close(context);
                        _goTo(
                          context,
                          CoursesModule.construct(CoursesModule.learningPaths),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Points & Badges (expandable)
                    _ExpandableNavCard(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Points & Badges',
                      selected: pointsBadgesActive,
                      children: [
                        _SubNavItem(
                          icon: Icons.redeem_outlined,
                          label: 'Redeem your Points',
                          selected: subSel == 'Redeem your Points',
                          onTap: () {
                            _close(context);
                            _goTo(
                              context,
                              CoursesModule.construct(
                                CoursesModule.redeemPoints,
                              ),
                            );
                          },
                        ),
                        _SubNavItem(
                          icon: Icons.military_tech_outlined,
                          label: 'Badges',
                          selected: subSel == 'Badges',
                          onTap: () {
                            _close(context);
                            _goTo(
                              context,
                              CoursesModule.construct(CoursesModule.badges),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Contact a Coach (expandable)
                    _ExpandableNavCard(
                      icon: Icons.support_agent_outlined,
                      label: 'Contact a Coach',
                      selected: false,
                      children: [
                        _SubNavItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Contact a Development Pro',
                          disabled: !isOnline,
                          onTap: () {
                            _close(context);
                            launchContactCoachUrl(ref, context);
                          },
                        ),
                        _SubNavItem(
                          icon: Icons.smart_toy_outlined,
                          label: 'Virtual Development Pro',
                          disabled: !isOnline,
                          onTap: () {
                            _close(context);
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
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Training  Pipeline',
              style: TextStyle(
                color: _purple,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close, size: 20, color: _purple),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plain (non-expandable) nav card ────────────────────────────────────────

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? _purple : _itemText,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _purple : _itemText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

// ── Expandable nav card ────────────────────────────────────────────────────

class _ExpandableNavCard extends StatefulWidget {
  const _ExpandableNavCard({
    required this.icon,
    required this.label,
    required this.children,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final List<_SubNavItem> children;

  @override
  State<_ExpandableNavCard> createState() => _ExpandableNavCardState();
}

class _ExpandableNavCardState extends State<_ExpandableNavCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.selected;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: widget.selected ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(_ExpandableNavCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the active route changes externally, sync expansion state.
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _expanded = true;
        _controller.forward();
      }
      // Don't auto-collapse when navigating away — let the user control it.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header card ──────────────────────────────────────────────
        _CardShell(
          selected: isActive,
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 22,
                    color: isActive ? _purple : _itemText,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: isActive ? _purple : _itemText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: isActive ? _purple : const Color(0xFF98A2B3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Children panel ───────────────────────────────────────────
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: _ChildrenPanel(children: widget.children),
        ),
      ],
    );
  }
}

// ── Card shell (shared border + background logic) ──────────────────────────

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.selected = false});
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? _lavender : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? _purple.withOpacity(0.18)
              : FigmaTokens.cardBorders,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ── Children panel with left accent bar ───────────────────────────────────

class _ChildrenPanel extends StatelessWidget {
  const _ChildrenPanel({required this.children});
  final List<_SubNavItem> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left purple accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: _accentBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Children list with lavender background
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _lavender,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in children) ...[
                      _SubItemTile(item: item),
                      if (item != children.last) const SizedBox(height: 4),
                    ],
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

// ── Sub-item tile ─────────────────────────────────────────────────────────

class _SubNavItem {
  const _SubNavItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.disabled = false,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final bool selected;
}

class _SubItemTile extends StatelessWidget {
  const _SubItemTile({required this.item});
  final _SubNavItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.disabled
        ? _muted
        : (item.selected ? _purple : _itemText);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.disabled ? null : item.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: item.selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: item.selected
                ? [
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                item.disabled ? Icons.cloud_off_rounded : item.icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: item.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    height: 1.3,
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
