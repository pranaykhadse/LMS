import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/providers/shell_destination_provider.dart';
import 'package:lms/app/core/views/elements/contact_links.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _border = FigmaTokens.cardBorders;
const _labelActive = FigmaTokens.primaryPurple;
const _labelInactive = FigmaTokens.noteBodyText;

bool _watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

/// Bottom navigation bar for the iPad / tablet tier (700 – 1023 px).
///
/// Shows five primary destinations as icon+label tabs. "My Courses" and
/// "Points & Badges" expand into a modal bottom sheet with their sub-items
/// (same destinations as the phone [AppDrawer] and the desktop
/// [_DesktopNavBar]) so every platform can reach every destination.
class TabletNavBar extends ConsumerWidget {
  const TabletNavBar({super.key, this.selectedLabel, this.selectedSubLabel});

  final String? selectedLabel;
  final String? selectedSubLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(currentShellDestinationProvider);

    // Map the current destination to a tab index so the active tab lights up.
    final activeTab = _tabIndexFor(destination, selectedLabel, selectedSubLabel);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavTab(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: 'Dashboard',
                active: activeTab == 0,
                onTap: () => _goTo(
                  context,
                  ref,
                  ShellDestination.dashboard,
                  CoursesModule.construct(CoursesModule.dashboard),
                ),
              ),
              _NavTab(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book_rounded,
                label: 'Catalog',
                active: activeTab == 1,
                onTap: () => _goTo(
                  context,
                  ref,
                  ShellDestination.courseCatalog,
                  CoursesModule.construct(CoursesModule.root),
                ),
              ),
              _NavTab(
                icon: Icons.library_books_outlined,
                activeIcon: Icons.library_books_rounded,
                label: 'My Courses',
                active: activeTab == 2,
                onTap: () => _showMyCoursesSheet(context, ref),
              ),
              _NavTab(
                icon: Icons.account_tree_outlined,
                activeIcon: Icons.account_tree_rounded,
                label: 'Learning',
                active: activeTab == 3,
                onTap: () => _goTo(
                  context,
                  ref,
                  ShellDestination.learningPaths,
                  CoursesModule.construct(CoursesModule.learningPaths),
                ),
              ),
              _NavTab(
                icon: Icons.workspace_premium_outlined,
                activeIcon: Icons.workspace_premium_rounded,
                label: 'More',
                active: activeTab == 4,
                onTap: () => _showMoreSheet(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _goTo(
    BuildContext context,
    WidgetRef ref,
    ShellDestination destination,
    String route,
  ) {
    if (ShellMarker.isInShell(context)) {
      navigateShell(ref, destination);
      return;
    }
    resetToModularRoot(context);
    Modular.to.navigate(route);
  }

  // ── My Courses sheet ──────────────────────────────────────────────────────

  void _showMyCoursesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SubSheet(
        title: 'My Courses',
        items: [
          _SheetItem(
            icon: Icons.school_outlined,
            label: 'My Enrolled Courses',
            onTap: () {
              Navigator.pop(ctx);
              _goTo(
                context,
                ref,
                ShellDestination.myEnrolledCourses,
                CoursesModule.construct(CoursesModule.enrolledCourses),
              );
            },
          ),
          _SheetItem(
            icon: Icons.task_alt,
            label: 'My Completed Courses',
            onTap: () {
              Navigator.pop(ctx);
              _goTo(
                context,
                ref,
                ShellDestination.myCompletedCourses,
                CoursesModule.construct(CoursesModule.completedCourses),
              );
            },
          ),
          _SheetItem(
            icon: Icons.timeline_outlined,
            label: 'My Development Plan',
            onTap: () {
              Navigator.pop(ctx);
              _goTo(
                context,
                ref,
                ShellDestination.myDevelopmentPlan,
                CoursesModule.construct(CoursesModule.developmentPlan),
              );
            },
          ),
          _SheetItem(
            icon: Icons.assignment_outlined,
            label: 'My Required Courses',
            onTap: () {
              Navigator.pop(ctx);
              _goTo(
                context,
                ref,
                ShellDestination.myRequiredCourses,
                CoursesModule.construct(CoursesModule.requiredCourses),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── More sheet ────────────────────────────────────────────────────────────

  void _showMoreSheet(BuildContext context, WidgetRef ref) {
    final isOnline = ref.read(InternetConnectionProvider.provider).isConnected &&
        !ref.read(OfflineModeNotifier.provider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SubSheet(
        title: 'More',
        items: [
          _SheetItem(
            icon: Icons.redeem_outlined,
            label: 'Redeem your Points',
            onTap: () {
              Navigator.pop(ctx);
              _goTo(
                context,
                ref,
                ShellDestination.redeemPoints,
                CoursesModule.construct(CoursesModule.redeemPoints),
              );
            },
          ),
          _SheetItem(
            icon: Icons.military_tech_outlined,
            label: 'Badges',
            onTap: () {
              Navigator.pop(ctx);
              _goTo(
                context,
                ref,
                ShellDestination.badges,
                CoursesModule.construct(CoursesModule.badges),
              );
            },
          ),
          _SheetItem(
            icon: Icons.person_outline_rounded,
            label: 'Contact a Development Pro',
            disabled: !isOnline,
            onTap: () {
              Navigator.pop(ctx);
              launchContactCoachUrl(ref, context);
            },
          ),
          _SheetItem(
            icon: Icons.smart_toy_outlined,
            label: 'Virtual Development Pro',
            disabled: !isOnline,
            onTap: () {
              Navigator.pop(ctx);
              launchVirtualDevUrl(context, ref);
            },
          ),
        ],
      ),
    );
  }

  // ── Active-tab resolver ───────────────────────────────────────────────────

  static int _tabIndexFor(
    ShellDestination destination,
    String? selectedLabel,
    String? selectedSubLabel,
  ) {
    switch (destination) {
      case ShellDestination.dashboard:
        return 0;
      case ShellDestination.courseCatalog:
        return 1;
      case ShellDestination.myEnrolledCourses:
      case ShellDestination.myCompletedCourses:
      case ShellDestination.myDevelopmentPlan:
      case ShellDestination.myRequiredCourses:
        return 2;
      case ShellDestination.learningPaths:
        return 3;
      case ShellDestination.badges:
      case ShellDestination.redeemPoints:
        return 4;
    }
  }
}

// ── Individual tab ────────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _labelActive : _labelInactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 4 : 0,
                height: active ? 4 : 0,
                decoration: BoxDecoration(
                  color: active ? _purple : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet chrome ───────────────────────────────────────────────────────

class _SubSheet extends StatelessWidget {
  const _SubSheet({required this.title, required this.items});

  final String title;
  final List<_SheetItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DC),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: FigmaTokens.cardTitles,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: _border),
        ...items.map((item) => _SheetRow(item: item)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SheetItem {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.item});
  final _SheetItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.disabled ? FigmaTokens.noteBodyText : FigmaTokens.cardTitles;
    return InkWell(
      onTap: item.disabled ? null : item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              item.disabled ? Icons.cloud_off_rounded : item.icon,
              size: 20,
              color: item.disabled ? FigmaTokens.noteBodyText : _purple,
            ),
            const SizedBox(width: 16),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
