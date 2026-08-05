import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/contact_links.dart';
import 'package:lms/app/core/views/elements/logo.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';
import 'package:lms/app/features/dashboard/view/learning_progress_page.dart';
import 'package:lms/app/features/dashboard/view/notifications_page.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

// Matches the Figma design system's exact primary purple (#693D94), used
// throughout the desktop header - see FigmaTokens.primaryPurple, the same
// value the redesigned Dashboard body already uses.
const _appPurple = Color(0xFF693D94);
const _appInk = Color(0xFF172033);
const _appMuted = Color(0xFF9AA8C0);

bool watchIsOnline(WidgetRef ref) {
  final isManualOffline = ref.watch(OfflineModeNotifier.provider);
  final connectionVM = ref.watch(InternetConnectionProvider.provider);
  ref.watch(SyncViewModel.provider);
  return !isManualOffline && connectionVM.isConnected;
}

/// Same check as [watchIsOnline] but safe to call from callbacks
/// (onTap/onPressed) where `ref.watch` isn't allowed — reads the current
/// value once instead of subscribing to changes.
bool readIsOnline(WidgetRef ref) {
  final isManualOffline = ref.read(OfflineModeNotifier.provider);
  final connectionVM = ref.read(InternetConnectionProvider.provider);
  return !isManualOffline && connectionVM.isConnected;
}

/// "Lastname, Firstname" for the desktop header's profile menu trigger.
String _lastFirst(dynamic profile) {
  final first = profile?.firstname?.toString() ?? '';
  final last = profile?.lastname?.toString() ?? '';
  if (last.isEmpty) return first;
  if (first.isEmpty) return last;
  return '$last, $first';
}

// Figma spec is Height Hug 44px, but that clipped the logo mark once it
// was swapped in - taller than spec so the logo has room to breathe.
const double _desktopTopBarHeight = 64;
const double _desktopHeaderHeight = 48;

// ── Shared AppBar ─────────────────────────────────────────────────────────────

class LmsAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const LmsAppBar({
    super.key,
    this.isWide = false,
    this.bottom,
    this.onBack,
    this.title,
    this.centerTitle = false,
    this.onRefresh,
    this.hideBack = false,
    this.selectedLabel,
    this.selectedSubLabel,
  });

  /// Responsive wide-screen layout (catalog page only).
  final bool isWide;

  /// Optional bottom widget (e.g. nav-tab bar) — catalog page only. On a
  /// wide screen this renders below the desktop nav bar, not in its place.
  final PreferredSizeWidget? bottom;

  /// The top-level nav item to highlight in the desktop nav bar (isWide
  /// only) — same values as AppDrawer's `selectedLabel`.
  final String? selectedLabel;

  /// The nav sub-item to highlight within its dropdown (isWide only) —
  /// same values as AppDrawer's `selectedSubLabel`.
  final String? selectedSubLabel;

  /// If provided, a back button is shown that calls this. If null and
  /// `Navigator.canPop` is true, standard pop is used instead.
  final VoidCallback? onBack;

  /// Forces the back button off even if [onBack] is set or
  /// `Navigator.canPop` is true — for top-level destinations reached via
  /// a stack-clearing `Modular.to.navigate` (Dashboard, Course Catalog),
  /// where `canPop` can still read true from routes flutter_modular keeps
  /// underneath (e.g. the auth/startup redirect), even though there's
  /// nowhere meaningful to go back to.
  final bool hideBack;

  /// Optional title text (e.g. "Dashboard"). Omitted on pages that render
  /// their own heading in the body (e.g. the course catalog).
  final String? title;

  /// Whether [title] is centered. Ignored when [title] is null.
  final bool centerTitle;

  /// If provided, shows a refresh button that re-runs whichever fetch this
  /// screen's data provider already uses.
  final VoidCallback? onRefresh;

  @override
  Size get preferredSize => Size.fromHeight(
        (isWide ? _desktopTopBarHeight + _desktopHeaderHeight : 60.0) +
            (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return isWide ? _buildDesktop(context, ref) : _buildMobile(context, ref);
  }

  // ── Desktop/tablet ───────────────────────────────────────────────────────
  //
  // Two stacked white rows, matching the Figma spec exactly: a 44px "TopBar"
  // (logo left, date/time + utilities + profile right, space-between) over
  // a "NavBar" row with the nav destinations. Built as plain Rows with an
  // explicit `crossAxisAlignment: CrossAxisAlignment.center` rather than
  // through AppBar's leading/title/actions, since AppBar's NavigationToolbar
  // centers those *slots* as blocks, and mixed-height children within one
  // slot don't share a visual baseline.
  Widget _buildDesktop(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final canPop = Navigator.canPop(context);
    final showBack =
        !hideBack && (onBack != null || (canPop && onBack == null));
    final isOffline = ref.watch(OfflineModeNotifier.provider);
    final unreadCount = ref.watch(NotificationsViewModel.unreadCountProvider);

    final utilities = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DatePill(),
        const SizedBox(width: 14),
        if (onRefresh != null) ...[
          LmsAppBarButton(
            icon: Icons.refresh_rounded,
            iconSize: 18,
            // The bell/badge in this same header is shared across every
            // screen, so a manual refresh should always pick up fresh
            // notifications too, not just whatever this particular page's
            // own onRefresh re-fetches.
            onTap: () {
              onRefresh!();
              ref.read(NotificationsViewModel.provider.notifier).fetch();
            },
          ),
          const SizedBox(width: 4),
        ],
        LmsOfflineToggle(
          isOffline: isOffline,
          iconSize: 18,
          switchScale: 0.8,
          onChanged: (val) {
            ref.read(OfflineModeNotifier.provider.notifier).setMode(val);
            if (!val) ref.read(SyncViewModel.provider).onManualOnline();
            Toast.info(context,
                val ? 'Offline mode enabled' : 'Back to online mode');
          },
        ),
        SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LmsAppBarButton(
                icon: Icons.notifications_none_rounded,
                iconSize: 18,
                onTap: () => showLmsNotifications(context),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IgnorePointer(child: LmsNotifBadge(count: unreadCount)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        LmsAppBarButton(
          icon: Icons.play_arrow_rounded,
          iconSize: 18,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LearningProgressPage()),
          ),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          offset: const Offset(0, 38),
          constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: (value) => _onProfileMenuSelected(context, ref, value),
          itemBuilder: (context) => _profileMenuItems(profile),
          // Pill container: #7D4AAB background, 4px radius, 6px gap
          // between avatar/name/chevron - padding widened past the Figma
          // spec's tight 8/2/8/2 so it actually reads as a chip against
          // the TopBar's own close-in-tone purple.
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7D4AAB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LmsAvatar(
                  profile: profile,
                  radius: 10,
                  fallbackColor: const Color(0xFF6A7282),
                ),
                const SizedBox(width: 6),
                Text(
                  _lastFirst(profile),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE5E7EB),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 16 / 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF99A1AF), size: 14),
              ],
            ),
          ),
        ),
      ],
    );

    // "TopBar": logo left, back button (detail pages only) + utilities
    // right - purple (#693D94) background, 16px left/right padding, 10px
    // top/bottom padding, space-between (taller than the Figma spec's
    // 44px so the logo mark isn't clipped - see _desktopTopBarHeight).
    final topBar = Container(
      width: double.infinity,
      height: _desktopTopBarHeight,
      color: _appPurple,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBack) ...[
                LmsAppBarButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack ?? () => safePop(context),
                  iconSize: 16,
                  boxSize: 28,
                ),
                const SizedBox(width: 8),
              ],
              const Logo(size: 40),
            ],
          ),
          utilities,
        ],
      ),
    );

    final navBar = _DesktopNavBar(
      selectedLabel: selectedLabel,
      selectedSubLabel: selectedSubLabel,
    );

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [topBar, navBar],
    );
    final headerHeight = _desktopTopBarHeight + _desktopHeaderHeight;
    if (bottom == null) {
      return PreferredSize(
        preferredSize: Size.fromHeight(headerHeight),
        child: header,
      );
    }
    return PreferredSize(
      preferredSize: Size.fromHeight(
        headerHeight + bottom!.preferredSize.height,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, bottom!],
      ),
    );
  }

  // ── Phone ────────────────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final canPop = Navigator.canPop(context);
    final showBack =
        !hideBack && (onBack != null || (canPop && onBack == null));
    final isOffline = ref.watch(OfflineModeNotifier.provider);
    final unreadCount = ref.watch(NotificationsViewModel.unreadCountProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      backgroundColor: _appPurple,
      foregroundColor: Colors.white,
      elevation: 2,
      titleSpacing: 0,
      // The hamburger/back button and the title are kept together as a
      // single left-hand group (via `title` below, not `leading`) so they
      // read as one cluster, with the action icons as a separate cluster
      // hugging the right edge - rather than the built-in AppBar
      // leading/title split, which left an ambiguous, similarly sized gap
      // on both sides of the title instead of grouping it with the menu
      // button next to it.
      leadingWidth: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 4, right: 4),
        child: Row(
          children: [
            if (showBack) ...[
              LmsAppBarButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack ?? () => safePop(context),
                iconSize: 18,
              ),
              const SizedBox(width: 2),
            ],
            Builder(
              builder: (ctx) => LmsAppBarButton(
                icon: Icons.menu_rounded,
                onTap: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            if (title != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (onRefresh != null) ...[
          LmsAppBarButton(
            icon: Icons.refresh_rounded,
            // The bell/badge in this same app bar is shared across every
            // screen, so a manual refresh should always pick up fresh
            // notifications too, not just whatever this particular page's
            // own onRefresh re-fetches.
            onTap: () {
              onRefresh!();
              ref.read(NotificationsViewModel.provider.notifier).fetch();
            },
          ),
          const SizedBox(width: 2),
        ],
        LmsOfflineToggle(
          isOffline: isOffline,
          onChanged: (val) {
            ref.read(OfflineModeNotifier.provider.notifier).setMode(val);
            if (!val) ref.read(SyncViewModel.provider).onManualOnline();
            Toast.info(
                context, val ? 'Offline mode enabled' : 'Back to online mode');
          },
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            LmsAppBarButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => showLmsNotifications(context),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: IgnorePointer(child: LmsNotifBadge(count: unreadCount)),
              ),
          ],
        ),
        const SizedBox(width: 2),
        PopupMenuButton<String>(
          offset: const Offset(0, 54),
          constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: (value) => _onProfileMenuSelected(context, ref, value),
          itemBuilder: (context) => _profileMenuItems(profile),
          child: LmsAvatar(profile: profile, radius: 18),
        ),
        const SizedBox(width: 2),
        LmsAppBarButton(
          icon: Icons.play_arrow_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LearningProgressPage()),
          ),
        ),
        const SizedBox(width: 6),
      ],
      bottom: bottom,
    );
  }

  void _onProfileMenuSelected(BuildContext context, WidgetRef ref, String value) {
    if (value == 'logout') {
      ref.read(AuthStateNotifier.provider.notifier).logout();
      Modular.to.navigate('/');
    } else if (value == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
      );
    } else if (value == 'points') {
      Modular.to.pushNamed(CoursesModule.construct(CoursesModule.redeemPoints));
    }
  }

  List<PopupMenuEntry<String>> _profileMenuItems(dynamic profile) => [
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
          value: 'points',
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
      ];
}

// ── Desktop nav bar ──────────────────────────────────────────────────────────

/// The horizontal white nav bar under the TopBar row on desktop/tablet,
/// replacing the persistent left sidebar. Same destinations as the mobile
/// AppDrawer (kept in sync by hand — see that file for the mobile
/// equivalent), styled to sit flush under [LmsAppBar]'s TopBar.
class _DesktopNavBar extends ConsumerWidget implements PreferredSizeWidget {
  const _DesktopNavBar({this.selectedLabel, this.selectedSubLabel});

  final String? selectedLabel;
  final String? selectedSubLabel;

  @override
  Size get preferredSize => const Size.fromHeight(_desktopHeaderHeight);

  void _goTo(BuildContext context, String route) {
    resetToModularRoot(context);
    Modular.to.navigate(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = watchIsOnline(ref);
    const myCoursesChildren = [
      'My Enrolled Courses',
      'My Completed Courses',
      'My Development Plan',
      'My Required Courses',
    ];
    const pointsBadgesChildren = ['Redeem your Points', 'Badges'];
    final myCoursesActive = selectedLabel == 'My Courses' ||
        myCoursesChildren.contains(selectedSubLabel);
    final pointsBadgesActive = selectedLabel == 'Points & Badges' ||
        pointsBadgesChildren.contains(selectedSubLabel);

    return Container(
      width: double.infinity,
      height: _desktopHeaderHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEFF3))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
          children: [
            _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: selectedLabel == 'Dashboard',
            onTap: () => _goTo(
              context,
              CoursesModule.construct(CoursesModule.dashboard),
            ),
          ),
          const SizedBox(width: 40),
          _NavItem(
            icon: Icons.menu_book_outlined,
            label: 'Course Catalog',
            selected: selectedLabel == 'Course Catalog',
            onTap: () => _goTo(
              context,
              CoursesModule.construct(CoursesModule.root),
            ),
          ),
          const SizedBox(width: 40),
          _NavDropdown(
            icon: Icons.library_books_outlined,
            label: 'My Courses',
            selected: myCoursesActive,
            items: [
              _NavSubItem(
                label: 'My Enrolled Courses',
                selected: selectedSubLabel == 'My Enrolled Courses',
                onTap: () => _goTo(
                  context,
                  CoursesModule.construct(CoursesModule.enrolledCourses),
                ),
              ),
              _NavSubItem(
                label: 'My Completed Courses',
                selected: selectedSubLabel == 'My Completed Courses',
                onTap: () => _goTo(
                  context,
                  CoursesModule.construct(CoursesModule.completedCourses),
                ),
              ),
              _NavSubItem(
                label: 'My Development Plan',
                selected: selectedSubLabel == 'My Development Plan',
                onTap: () => _goTo(
                  context,
                  CoursesModule.construct(CoursesModule.developmentPlan),
                ),
              ),
              _NavSubItem(
                label: 'My Required Courses',
                selected: selectedSubLabel == 'My Required Courses',
                onTap: () => _goTo(
                  context,
                  CoursesModule.construct(CoursesModule.requiredCourses),
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          _NavItem(
            icon: Icons.account_tree_outlined,
            label: 'Learning Paths',
            selected: selectedLabel == 'Learning Paths',
            onTap: () => _goTo(
              context,
              CoursesModule.construct(CoursesModule.learningPaths),
            ),
          ),
          const SizedBox(width: 40),
          _NavDropdown(
            icon: Icons.workspace_premium_outlined,
            label: 'Points & Badges',
            selected: pointsBadgesActive,
            items: [
              _NavSubItem(
                label: 'Redeem your Points',
                selected: selectedSubLabel == 'Redeem your Points',
                onTap: () => _goTo(
                  context,
                  CoursesModule.construct(CoursesModule.redeemPoints),
                ),
              ),
              _NavSubItem(
                label: 'Badges',
                selected: selectedSubLabel == 'Badges',
                onTap: () => _goTo(
                  context,
                  CoursesModule.construct(CoursesModule.badges),
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),
          _NavDropdown(
            icon: Icons.support_agent_outlined,
            label: 'Contact a Coach',
            selected: false,
            items: [
              _NavSubItem(
                label: 'Contact a Development Pro',
                disabled: !isOnline,
                onTap: () => launchContactCoachUrl(ref),
              ),
              _NavSubItem(
                label: 'Virtual Development Pro',
                disabled: !isOnline,
                onTap: launchVirtualDevUrl,
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
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _appPurple : const Color(0xFF4A4A4A);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavSubItem {
  const _NavSubItem({
    required this.label,
    this.selected = false,
    this.disabled = false,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
}

class _NavDropdown extends StatelessWidget {
  const _NavDropdown({
    required this.icon,
    required this.label,
    required this.selected,
    required this.items,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final List<_NavSubItem> items;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _appPurple : const Color(0xFF4A4A4A);
    return PopupMenuButton<int>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (index) {
        final item = items[index];
        if (!item.disabled) item.onTap();
      },
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: !items[i].disabled,
            child: Text(
              items[i].label,
              style: TextStyle(
                color: items[i].disabled
                    ? const Color(0xFF9AA8C0)
                    : (items[i].selected ? _appPurple : const Color(0xFF23292F)),
                fontWeight:
                    items[i].selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Shared icon button ────────────────────────────────────────────────────────

class LmsAppBarButton extends StatelessWidget {
  const LmsAppBarButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize,
    this.boxSize,
  });
  final IconData icon;
  final VoidCallback onTap;

  /// Overrides the default responsive icon size (e.g. to visually balance
  /// glyphs like `arrow_back_ios` that render smaller than others at the
  /// same nominal size).
  final double? iconSize;

  /// Overrides the default responsive tap-target box size — needed
  /// whenever [iconSize] is pushed past the default box's own size.
  final double? boxSize;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final size = boxSize ?? (isWide ? 38.0 : 36.0);
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize ?? (isWide ? 24 : 23),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared offline toggle ─────────────────────────────────────────────────────

class LmsOfflineToggle extends StatelessWidget {
  const LmsOfflineToggle({
    super.key,
    required this.isOffline,
    required this.onChanged,
    this.iconSize,
    this.switchScale,
  });
  final bool isOffline;
  final ValueChanged<bool> onChanged;

  /// Overrides the default responsive icon/switch size — used by the
  /// desktop header to match its smaller, button-less icon styling.
  final double? iconSize;
  final double? switchScale;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
          size: iconSize ?? (isWide ? 22 : 18),
          color: isOffline ? Colors.amber.shade600 : Colors.white70,
        ),
        Transform.scale(
          scale: switchScale ?? (isWide ? 0.85 : 0.72),
          child: Switch(
            value: isOffline,
            onChanged: onChanged,
            activeThumbColor: Colors.amber.shade600,
            activeTrackColor: Colors.amber.shade200,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

// ── Shared notification badge ─────────────────────────────────────────────────

class LmsNotifBadge extends StatelessWidget {
  const LmsNotifBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 13, minHeight: 13),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      );
}

// ── Shared notifications dialog ───────────────────────────────────────────────

void showLmsNotifications(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (ctx) => const _NotificationsDialog(),
  );
}

class _NotificationsDialog extends ConsumerWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(NotificationsViewModel.provider);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 76, 16, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _appInk,
                    ),
                  ),
                  const Spacer(),
                  if (notifState.unreadCount > 0)
                    TextButton(
                      onPressed: () => ref
                          .read(NotificationsViewModel.provider.notifier)
                          .markAllAsRead(),
                      style: TextButton.styleFrom(
                        foregroundColor: _appPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Mark all as read',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (notifState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: _appPurple),
              )
            else if (notifState.notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircleAvatar(
                      backgroundColor: Color(0xFF24C56B),
                      child: Icon(Icons.check, color: Colors.white, size: 27),
                    ),
                    SizedBox(height: 14),
                    Text(
                      "You're all caught up",
                      style: TextStyle(
                        color: Color(0xFF9AA8C0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: notifState.notifications.length > 5
                      ? 5
                      : notifState.notifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  itemBuilder: (ctx, i) {
                    final item = notifState.notifications[i];
                    return _NotifRow(
                      item: item,
                      onTap: () {
                        ref
                            .read(NotificationsViewModel.provider.notifier)
                            .markOneAsRead(item.id);
                        final url = item.redirectUrl;
                        if (url != null && url.isNotEmpty) {
                          if (!readIsOnline(ref)) {
                            Toast.info(context, 'Internet required to open this link.');
                            return;
                          }
                          final uri = Uri.tryParse(url);
                          if (uri != null) {
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            const Divider(height: 1),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NotificationsPage()),
                );
              },
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFD),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: const Center(
                  child: Text(
                    'View All Notifications',
                    style: TextStyle(
                      color: _appPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _appPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: _appPurple,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: item.isRead ? _appMuted : _appInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _appMuted,
                      height: 1.35,
                    ),
                  ),
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(item.createdAt!),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFABB6C8)),
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _appPurple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared avatar ─────────────────────────────────────────────────────────────

class LmsAvatar extends StatelessWidget {
  const LmsAvatar({
    super.key,
    required this.profile,
    required this.radius,
    this.fallbackColor = _appPurple,
  });
  final dynamic profile;
  final double radius;

  /// Background color shown when there's no photo (an initial/icon
  /// instead) — defaults to the app purple; the desktop header's TopBar
  /// pill uses the Figma spec's own #6A7282 instead.
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final url = profile?.avatarUrl?.toString() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: radius - 2,
        backgroundColor: fallbackColor,
        backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
        child: url.isEmpty
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
    );
  }
}

// ── Profile popup widgets ─────────────────────────────────────────────────────

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
          LmsAvatar(profile: profile, radius: 22),
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
          Icon(icon, size: 21, color: const Color(0xFF9AA8C0)),
          const SizedBox(width: 13),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF4C586C), fontSize: 15),
          ),
        ],
      );
}

// ── Date pill (wide mode only) ────────────────────────────────────────────────

class _DatePill extends StatefulWidget {
  const _DatePill();

  @override
  State<_DatePill> createState() => _DatePillState();
}

class _DatePillState extends State<_DatePill> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDatePill(_now),
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
      ),
    );
  }
}

const _datePillWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _datePillMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _formatDatePill(DateTime dt) {
  final weekday = _datePillWeekdays[dt.weekday - 1];
  final month = _datePillMonths[dt.month - 1];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$weekday $month ${dt.day}, ${dt.year} | $hour12:$minute $ampm';
}
