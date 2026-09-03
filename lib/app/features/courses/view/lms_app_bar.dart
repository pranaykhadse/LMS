import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/providers/shell_destination_provider.dart';
import 'package:lms/app/core/utils/dev_image_proxy.dart';
import 'package:lms/app/core/views/elements/contact_links.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/logo.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/view/account_settings_page.dart';
import 'package:lms/app/features/dashboard/view/notifications_page.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';

const _appPurple = FigmaTokens.primaryPurple;
// CSS ref, confirmed straight from `origin/staging`'s bluetheme-layout
// .css (`#navbarMenu .sub-nav-item a:hover{color:var(--primary-color)
// !important}`, `--primary-color:#693D94`): matches `FigmaTokens
// .primaryPurple` already.
const _navActive = FigmaTokens.primaryPurple;
// CSS ref, confirmed straight from `origin/staging`'s bluetheme-layout
// .css: `#navbarMenu .sub-nav-item a{color:#64748b!important}` — was
// wrongly `#6B7280` (Tailwind gray-500, visually close but a
// different, unconfirmed value).
const _navDefault = Color(0xFF64748B);
// CSS/markup ref: real `#homeSubMenu` item icons, from
// `origin/staging`'s bluetheme_layout.php `'icon' => '<img
// src="...">'` config for each nav item.
const _navIconBase =
    'https://staging.trainingpipeline.com/backend/web/dist/images/';

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

/// "Firstname Lastname" for the desktop header's profile menu trigger.
String _lastFirst(dynamic profile) {
  final first = profile?.firstname?.toString() ?? '';
  final last = profile?.lastname?.toString() ?? '';
  if (last.isEmpty) return first;
  if (first.isEmpty) return last;
  return '$first $last';
}

// TopBar's Figma spec is Height Hug 44px, but that clipped the logo mark
// once it was swapped in - taller than spec so the logo has room to
// breathe. NavBar matches its own Figma spec exactly (Height Hug 44px).
const double _desktopTopBarHeight = 44;
const double _desktopHeaderHeight = 45;
// Phone gets a condensed version of the desktop purple TopBar (logo +
// notification bell + profile avatar only - no date pill/refresh/offline
// toggle/progress icon, too many to fit legibly on a narrow screen) above
// the existing white "Menu" bar.
const double _mobileTopBarHeight = 44; // py-2.5 (10px×2) + content

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
    this.useDashboardMobileProfileStyle = false,
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

  /// Applies the website's 37x20 profile trigger only to the Dashboard on
  /// phones; all other headers retain their existing profile control.
  final bool useDashboardMobileProfileStyle;

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
    (isWide
            ? _desktopTopBarHeight + _desktopHeaderHeight
            : _mobileTopBarHeight + 48.0) +
        (bottom?.preferredSize.height ?? 1.0), // 1px for the bottom divider
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return isWide ? _buildDesktop(context, ref) : _buildMobile(context, ref);
  }

  // ── Desktop/tablet ───────────────────────────────────────────────────────
  //
  // Two stacked white rows, matching the Figma spec: a "TopBar" (logo left,
  // date/time + utilities + profile right, space-between) over a "NavBar"
  // row with the nav destinations. Built as plain Rows with an
  // explicit `crossAxisAlignment: CrossAxisAlignment.center` rather than
  // through AppBar's leading/title/actions, since AppBar's NavigationToolbar
  // centers those *slots* as blocks, and mixed-height children within one
  // slot don't share a visual baseline.
  Widget _buildDesktop(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
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
            // Design ref: bell svg is w-[14px] h-[14px] - matched across
            // every icon in this row for consistency.
            iconSize: 14,
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
          iconSize: 14,
          switchScale: 0.65,
          onChanged: (val) {
            ref.read(OfflineModeNotifier.provider.notifier).setMode(val);
            if (!val) ref.read(SyncViewModel.provider).onManualOnline();
            Toast.info(
              context,
              val ? 'Offline mode enabled' : 'Back to online mode',
            );
          },
        ),
        SizedBox(
          width: 34,
          height: 34,
          child: Builder(
            builder:
                (bellContext) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    LmsAppBarButton(
                      icon: Icons.notifications_none_rounded,
                      iconSize: 14,
                      boxSize: 34,
                      onTap: () => showLmsNotifications(bellContext),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: IgnorePointer(
                          child: LmsNotifBadge(count: unreadCount),
                        ),
                      ),
                  ],
                ),
          ),
        ),
        const SizedBox(width: 6),
        _ProfileMenuButton(
          profile: profile,
          onSelected: (value) => _onProfileMenuSelected(context, ref, value),
          itemBuilder: (context) => _profileMenuItems(
            profile,
            ref.watch(AuthStateNotifier.provider)?.role?.itemName,
          ),
        ),
      ],
    );

    // "TopBar": logo left, back button (detail pages only) + utilities
    // right - purple (#693D94) background, 16px left/right padding, 10px
    // top/bottom padding, space-between - matches the Figma spec's 44px
    // exactly; the logo is sized to fit the 24px of padding-free height
    // that leaves (see the Logo(size: ...) call below).
    final topBar = Container(
      width: double.infinity,
      height: _desktopTopBarHeight,
      color: _appPurple,
      // Horizontal padding matches the dashboard banner's own outer
      // margin (outerH = 24 at this tablet+ width) so the logo/avatar
      // line up with the banner card's left/right edges below.
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back button — left of the logo, shown whenever there's
              // actually somewhere to go back to. Shell-tab switches
              // (Dashboard <-> Course Catalog <-> Learning Paths <-> ...)
              // never touch Navigator, so canPop() alone can't see that
              // history - shellHistoryProvider tracks it instead, and this
              // reverses through tab switches and pushed routes (course
              // detail, etc.) alike, in the order they actually happened.
              if (!hideBack && _canGoBack(context, ref))
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack ?? () => _goBack(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (ShellMarker.isInShell(context)) {
                      navigateShell(ref, ShellDestination.dashboard);
                      return;
                    }
                    resetToModularRoot(context);
                    Modular.to.navigate(
                      CoursesModule.construct(CoursesModule.dashboard),
                    );
                  },
                  child: const Logo(size: 24),
                ),
              ),
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

    final header = Container(
      color: FigmaTokens.pageBackground,
      child: Column(mainAxisSize: MainAxisSize.min, children: [topBar, navBar]),
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

  /// True once there's actually somewhere for the back button to go -
  /// [shellHistoryProvider] while inside the shell (tab switches never
  /// reach Navigator), otherwise a normal [Navigator.canPop] check for
  /// pushed routes (course detail, notifications, account settings, ...).
  bool _canGoBack(BuildContext context, WidgetRef ref) {
    if (onBack != null) return true;
    if (ShellMarker.isInShell(context)) {
      return ref.watch(shellHistoryProvider).isNotEmpty;
    }
    return Navigator.of(context).canPop();
  }

  /// Reverses one step - out of shell history if inside the shell (falling
  /// through to a normal pop if history is somehow already empty), or a
  /// normal pop otherwise.
  void _goBack(BuildContext context, WidgetRef ref) {
    if (ShellMarker.isInShell(context) && goBackInShell(ref)) return;
    safePop(context);
  }

  // ── Phone ────────────────────────────────────────────────────────────────
  //
  // Condensed version of the desktop purple TopBar (back button, logo,
  // offline toggle, notification bell, profile avatar - no date pill,
  // refresh, or progress icon, too many to fit legibly on a narrow
  // screen), stacked above the existing white "Menu" bar.
  Widget _buildMobileTopBar(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final unreadCount = ref.watch(NotificationsViewModel.unreadCountProvider);
    final isOffline = ref.watch(OfflineModeNotifier.provider);

    return Container(
      width: double.infinity,
      height: _mobileTopBarHeight,
      color: _appPurple,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back button — same visibility rule as desktop's TopBar.
              if (!hideBack && _canGoBack(context, ref))
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBack ?? () => _goBack(context, ref),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  if (ShellMarker.isInShell(context)) {
                    navigateShell(ref, ShellDestination.dashboard);
                    return;
                  }
                  resetToModularRoot(context);
                  Modular.to.navigate(
                    CoursesModule.construct(CoursesModule.dashboard),
                  );
                },
                child: const Logo(size: 24), // h-6 = 24px
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              LmsOfflineToggle(
                isOffline: isOffline,
                // w-[14px] h-[14px] from dashboard CSS
                iconSize: 14,
                switchScale: 0.65,
                onChanged: (val) {
                  ref.read(OfflineModeNotifier.provider.notifier).setMode(val);
                  if (!val) ref.read(SyncViewModel.provider).onManualOnline();
                  Toast.info(
                    context,
                    val ? 'Offline mode enabled' : 'Back to online mode',
                  );
                },
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                height: 30,
                child: Builder(
                  builder:
                      (bellContext) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          LmsAppBarButton(
                            icon: Icons.notifications_none_rounded,
                            // w-[14px] h-[14px] from dashboard CSS
                            iconSize: 14,
                            boxSize: 30,
                            onTap: () => showLmsNotifications(bellContext),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: IgnorePointer(
                                child: LmsNotifBadge(count: unreadCount),
                              ),
                            ),
                        ],
                      ),
                ),
              ),
              // gap-3 = 12px between bell and profile
              const SizedBox(width: 12),
              Theme(
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: PopupMenuButton<String>(
                  offset: const Offset(0, 34),
                  // Same web-matched panel as the desktop _ProfileMenuButton:
                  // `.dropdown-profile .dropdown-menu` = 250px, white,
                  // radius 16, `0 15px 50px rgba(0,0,0,.2)`.
                  constraints: const BoxConstraints(
                    minWidth: 250,
                    maxWidth: 250,
                  ),
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected:
                      (value) => _onProfileMenuSelected(context, ref, value),
                  itemBuilder: (context) => _profileMenuItems(
                    profile,
                    ref.watch(AuthStateNotifier.provider)?.role?.itemName,
                  ),
                  padding: EdgeInsets.zero,
                  // Phone-only: avatar sits inside a small rounded box with a
                  // dropdown chevron, instead of desktop's bare avatar + name.
                  child: Container(
                    padding:
                        useDashboardMobileProfileStyle
                            ? EdgeInsets.zero
                            : const EdgeInsets.fromLTRB(4, 4, 6, 4),
                    decoration:
                        useDashboardMobileProfileStyle
                            ? null
                            : BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LmsAvatar(
                          profile: profile,
                          radius: useDashboardMobileProfileStyle ? 10 : 12,
                          fallbackColor: _appPurple,
                        ),
                        SizedBox(width: useDashboardMobileProfileStyle ? 6 : 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, WidgetRef ref) {
    // Back navigation is always handled inline in the page body header
    // (← Back | Page Title) — the AppBar always shows "Menu" + hamburger.

    // Figma mobile app bar spec (matched from reference HTML/CSS):
    // Container: bg-white, border-bottom 1px #E5E7EB, height ~48px
    // Padding: px-3 (12px) left/right, flex items-center justify-between
    // "Menu" label: Inter SemiBold 600, text-sm 14px, color gray-700 #374151
    // Hamburger button: p-1.5 (6px), icon 20×20, color gray-500 #6B7280
    final menuBar = Material(
      color: Colors.white,
      child: Container(
        height: 48,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: "Menu" label — text-sm font-semibold text-gray-700
            const Text(
              'Menu',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
                letterSpacing: 0,
                color: Color(0xFF374151),
              ),
            ),
            // Right: hamburger — p-1.5 text-gray-500
            Builder(
              builder:
                  (ctx) => GestureDetector(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.menu_rounded,
                        size: 20,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );

    // Use the caller's bottom widget if provided (e.g. a tab bar on the
    // catalog page); otherwise render a thin 1px divider to separate the
    // white bar from the page body.
    final bottomWidget =
        bottom ?? Container(height: 1, color: FigmaTokens.cardBorders);

    // Neither of these plain widgets auto-insets for the status bar/notch
    // the way a real AppBar does, so without this the purple bar paints
    // straight from y=0, underneath the status bar.
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_buildMobileTopBar(context, ref), menuBar, bottomWidget],
      ),
    );
  }

  void _onProfileMenuSelected(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) {
    if (value == 'logout') {
      ref.read(AuthStateNotifier.provider.notifier).logout();
      Modular.to.navigate('/');
    } else if (value == 'settings') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AccountSettingsPage()));
    } else if (value == 'points') {
      Modular.to.pushNamed(CoursesModule.construct(CoursesModule.redeemPoints));
    }
  }

  List<PopupMenuEntry<String>> _profileMenuItems(dynamic profile,
      String? role) => [
    PopupMenuItem<String>(
      enabled: false,
      padding: EdgeInsets.zero,
      child: _ProfileHeader(profile: profile, role: role),
    ),
    const PopupMenuItem<String>(
      value: 'settings',
      padding: EdgeInsets.zero,
      child: _ProfileMenuRow(icon: Icons.settings, label: 'Account Settings'),
    ),
    PopupMenuItem<String>(
      value: 'points',
      padding: EdgeInsets.zero,
      child: _ProfileMenuRow(
        icon: Icons.workspace_premium_outlined,
        label: 'My Points: ${profile?.points ?? 0}',
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'logout',
      padding: EdgeInsets.zero,
      child: _ProfileMenuRow(
        icon: Icons.logout,
        label: 'Logout Account',
        isLogout: true,
      ),
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

  void _goTo(
    BuildContext context,
    WidgetRef ref,
    ShellDestination destination,
    String route,
  ) {
    // Inside the shell, switching tabs is just a provider write - no
    // Modular navigation, so the header never gets torn down/rebuilt and
    // the page doesn't slide. Falls back to a real navigation if somehow
    // reached from outside the shell.
    if (ShellMarker.isInShell(context)) {
      navigateShell(ref, destination);
      return;
    }
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
    final myCoursesActive =
        selectedLabel == 'My Courses' ||
        myCoursesChildren.contains(selectedSubLabel);
    final pointsBadgesActive =
        selectedLabel == 'Points & Badges' ||
        pointsBadgesChildren.contains(selectedSubLabel);

    return Container(
      width: double.infinity,
      height: _desktopHeaderHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: FigmaTokens.cardBorders)),
      ),
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _NavItem(
                      icon: LucideIcons.library,
                      label: 'Course Catalog',
                      selected: selectedLabel == 'Course Catalog',
                      onTap:
                          () => _goTo(
                            context,
                            ref,
                            ShellDestination.courseCatalog,
                            CoursesModule.construct(CoursesModule.root),
                          ),
                    ),
                    const SizedBox(width: 48),
                    _NavDropdown(
                      icon: LucideIcons.bookOpen,
                      label: 'My Courses',
                      selected: myCoursesActive,
                      items: [
                        _NavSubItem(
                          label: 'My Enrolled Courses',
                          iconAsset: '${_navIconBase}courses-icon.svg',
                          selected: selectedSubLabel == 'My Enrolled Courses',
                          onTap:
                              () => _goTo(
                                context,
                                ref,
                                ShellDestination.myEnrolledCourses,
                                CoursesModule.construct(
                                  CoursesModule.enrolledCourses,
                                ),
                              ),
                        ),
                        _NavSubItem(
                          label: 'My Completed Courses',
                          iconAsset: '${_navIconBase}courses-icon.svg',
                          selected: selectedSubLabel == 'My Completed Courses',
                          onTap:
                              () => _goTo(
                                context,
                                ref,
                                ShellDestination.myCompletedCourses,
                                CoursesModule.construct(
                                  CoursesModule.completedCourses,
                                ),
                              ),
                        ),
                        _NavSubItem(
                          label: 'My Development Plan',
                          iconAsset: '${_navIconBase}development-plan-icon.svg',
                          selected: selectedSubLabel == 'My Development Plan',
                          onTap:
                              () => _goTo(
                                context,
                                ref,
                                ShellDestination.myDevelopmentPlan,
                                CoursesModule.construct(
                                  CoursesModule.developmentPlan,
                                ),
                              ),
                        ),
                        _NavSubItem(
                          label: 'My Required Courses',
                          iconAsset: '${_navIconBase}required-courses-icon.svg',
                          selected: selectedSubLabel == 'My Required Courses',
                          onTap:
                              () => _goTo(
                                context,
                                ref,
                                ShellDestination.myRequiredCourses,
                                CoursesModule.construct(
                                  CoursesModule.requiredCourses,
                                ),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48),
                    _NavItem(
                      icon: LucideIcons.map,
                      label: 'Learning Paths',
                      selected: selectedLabel == 'Learning Paths',
                      onTap:
                          () => _goTo(
                            context,
                            ref,
                            ShellDestination.learningPaths,
                            CoursesModule.construct(
                              CoursesModule.learningPaths,
                            ),
                          ),
                    ),
                    const SizedBox(width: 48),
                    _NavDropdown(
                      icon: LucideIcons.award,
                      label: 'Points & Badges',
                      selected: pointsBadgesActive,
                      items: [
                        _NavSubItem(
                          label: 'Redeem your Points',
                          iconAsset: '${_navIconBase}redeem-icon.svg',
                          selected: selectedSubLabel == 'Redeem your Points',
                          onTap:
                              () => _goTo(
                                context,
                                ref,
                                ShellDestination.redeemPoints,
                                CoursesModule.construct(
                                  CoursesModule.redeemPoints,
                                ),
                              ),
                        ),
                        _NavSubItem(
                          label: 'Badges',
                          iconAsset: '${_navIconBase}badges-icon.svg',
                          selected: selectedSubLabel == 'Badges',
                          onTap:
                              () => _goTo(
                                context,
                                ref,
                                ShellDestination.badges,
                                CoursesModule.construct(CoursesModule.badges),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48),
                    _NavDropdown(
                      icon: LucideIcons.messageCircle,
                      label: 'Contact a Coach',
                      selected: false,
                      items: [
                        _NavSubItem(
                          label: 'Contact a Development Pro',
                          iconAsset: '${_navIconBase}coach.svg',
                          disabled: !isOnline,
                          onTap: () => launchContactCoachUrl(ref, context),
                        ),
                        _NavSubItem(
                          label: 'Virtual Development Pro',
                          // Nav ref: real markup reuses the "Badges"
                          // icon here — not a mistake, straight from
                          // the PHP config.
                          iconAsset: '${_navIconBase}badges-icon.svg',
                          disabled: !isOnline,
                          onTap: () => launchVirtualDevUrl(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final color = selected ? _navActive : _navDefault;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, 1),
              child: Icon(icon, size: 13, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              // Explicit 16/12 line-height matches the Figma spec's own
              // measured 16px exactly - GoogleFonts.inter's unset default
              // leading is taller than that, which was clipping descenders
              // against the 44px button height.
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 16 / 12,
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
    required this.iconAsset,
    this.selected = false,
    this.disabled = false,
    required this.onTap,
  });
  final String label;
  // CSS/markup ref, confirmed against `origin/staging`'s
  // bluetheme_layout.php: every `#homeSubMenu` item renders its own
  // `<img>` icon (`'icon' => '<img src="...">'` in the dropdown
  // config).
  final String iconAsset;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
}

// Several of these real icon assets (e.g. development-plan-icon.svg,
// required-courses-icon.svg, coach.svg) are Figma exports that embed a
// raster PNG inside an SVG `<pattern>` fill (`<image xlink:href="data:
// image/png;base64,...">`) rather than real vector paths — confirmed by
// fetching the raw asset text directly. `flutter_svg`'s renderer has no
// support for `<pattern>` fills at all, so `SvgPicture.network` on
// those specific files silently renders nothing (not a network/CORS
// problem — plain SVGs like courses-icon.svg render fine through the
// exact same proxy). Fetches the raw SVG text once, extracts the
// embedded PNG and paints it with `Image.memory` when present, and
// falls back to `SvgPicture.string` (parsing the already-fetched text,
// no second network round-trip) for real vector icons that have no
// embedded raster at all.
class _NavIcon extends StatefulWidget {
  const _NavIcon({required this.url, required this.color});
  final String url;

  // App-only deviation, per explicit request: every icon across a
  // dropdown is tinted to this one color (its own label's color) instead
  // of each icon's native/mixed color, so the whole list reads as
  // visually consistent. Applied at build time (not baked into the
  // cached decoded icon itself) so the same cached SVG/PNG can be
  // re-tinted per render as its highlighted state changes.
  final Color color;

  // CSS ref: `#navbarMenu .nav-link img{width:14px;height:14px}` — the
  // one size every dropdown item icon uses; not exposed as a
  // constructor param since nothing needs a different size.
  static const _size = 14.0;

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  static final _embeddedPngPattern = RegExp(r'data:image/png;base64,([^"]+)');

  // These dropdowns get rebuilt (and every `_NavIcon` re-created) each time
  // a `PopupMenuButton` menu is opened, so without a cache this widget was
  // re-fetching and re-decoding the same handful of SVG/PNG icon assets
  // from the network on every single open — a visible flash-then-pop-in
  // delay each time. Keyed by URL and shared across every `_NavIcon`
  // instance (static, not per-State), so the first open per icon still
  // fetches once, but every open after that renders instantly from memory.
  static final Map<String, Widget> _cache = {};

  Widget? _resolved;

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.url];
    if (cached != null) {
      _resolved = cached;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final response = await Dio().get<String>(
        devProxiedImageUrl(widget.url),
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data ?? '';
      final embeddedPng = _embeddedPngPattern.firstMatch(body);
      final resolved =
          embeddedPng != null
              // App-only fix, per explicit request: the raster art
              // extracted from these `<pattern>`-fill icons renders
              // much darker/heavier than the flat, naturally-light
              // vector icons (`courses-icon.svg`) sitting beside it in
              // the same dropdown — no way to derive a "right" opacity
              // for this from the real CSS, since the real site never
              // actually renders these `<pattern>`-fill icons at all.
              // A fixed `Opacity` here (rather than on the outer hover-
              // driven one, which both icon kinds already share)
              // lightens only the raster path, bringing it in line
              // with the vector icons' natural lightness.
              ? Opacity(
                // Lowered further than the previous 0.55 per explicit
                // follow-up request — still read as too dark next to
                // the vector icon.
                opacity: 0.35,
                child: Image.memory(
                  base64Decode(embeddedPng.group(1)!),
                  width: _NavIcon._size,
                  height: _NavIcon._size,
                  fit: BoxFit.contain,
                ),
              )
              : SvgPicture.string(
                body,
                width: _NavIcon._size,
                height: _NavIcon._size,
              );
      _cache[widget.url] = resolved;
      if (mounted) setState(() => _resolved = resolved);
    } catch (_) {
      // Leave `_resolved` null — renders as a correctly-sized blank
      // box instead of collapsing the icon slot and shifting the
      // label over.
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    return SizedBox(
      width: _NavIcon._size,
      height: _NavIcon._size,
      child:
          resolved == null
              ? null
              : ColorFiltered(
                colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
                child: resolved,
              ),
    );
  }
}

class _ProfileMenuButton extends StatefulWidget {
  const _ProfileMenuButton({
    required this.profile,
    required this.onSelected,
    required this.itemBuilder,
  });
  final dynamic profile;
  final ValueChanged<String> onSelected;
  final List<PopupMenuEntry<String>> Function(BuildContext) itemBuilder;

  @override
  State<_ProfileMenuButton> createState() => _ProfileMenuButtonState();
}

class _ProfileMenuButtonState extends State<_ProfileMenuButton> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 38),
        // CSS ref (`origin/staging` bluetheme-layout.css:
        // `.dropdown-profile .dropdown-menu{width:250px!important;
        // min-width:250px!important;padding:0;overflow:hidden;border:none;
        // box-shadow:0 15px 50px rgba(0,0,0,.2)!important}`) — pinned to a
        // fixed 250px panel, white bg, radius 16, deep drop shadow.
        constraints: const BoxConstraints(minWidth: 250, maxWidth: 250),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onOpened: () => setState(() => _isOpen = true),
        onCanceled: () => setState(() => _isOpen = false),
        onSelected: (value) {
          setState(() => _isOpen = false);
          widget.onSelected(value);
        },
        itemBuilder: widget.itemBuilder,
        // Design ref: no background pill - just avatar (w-5 h-5) + name
        // (text-xs, #FFFFFF, Inter) + chevron (w-[11px] h-[11px]) directly
        // on the purple bar, 6px gap between them (gap-1.5).
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LmsAvatar(
              profile: widget.profile,
              radius: 10,
              fallbackColor: const Color(0xFF693D94),
            ),
            const SizedBox(width: 6),
            Text(
              _lastFirst(widget.profile),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 16 / 12,
              ),
            ),
            const SizedBox(width: 6),
            Transform.translate(
              offset: const Offset(0, 1.0),
              child: Icon(
                _isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDropdown extends StatefulWidget {
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
  State<_NavDropdown> createState() => _NavDropdownState();
}

class _NavDropdownState extends State<_NavDropdown> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final label = widget.label;
    final selected = widget.selected;
    final items = widget.items;
    final color = selected ? _navActive : _navDefault;
    // `PopupMenuButton` captures the ambient `Theme` from THIS
    // context when it opens (via `InheritedTheme.capture`) and re-
    // applies it inside the popup route, which otherwise renders in
    // the root `Overlay`, outside this widget's own position in the
    // tree. Wrapping the override here — not around each item's own
    // `child:` content further down, which sits INSIDE (below) each
    // `PopupMenuItem`'s own hover `InkWell` and so can never reach
    // back up to affect it — is what actually reaches that `InkWell`
    // and suppresses its default full-item-width grey hover/splash
    // overlay, leaving only the app's own inset, rounded, purple-
    // tinted pill (built per-item below) visible on hover/selection.
    return Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<int>(
        offset: const Offset(0, 40),
        // CSS ref, confirmed straight from `origin/staging`'s
        // bluetheme-layout.css: `#navbarMenu #homeSubMenu{background:#fff
        // !important;border-radius:16px!important;box-shadow:0 10px 40px
        // rgba(0,0,0,.1)!important;padding:8px 0!important}` (reaffirmed
        // by `#navbarMenu .nav-item.show > #homeSubMenu{border-
        // radius:16px!important;padding:8px 0!important}`) — was wrongly
        // radius 12 with no shadow/background override at all. Flutter's
        // Material elevation shadow shape doesn't literally reproduce a
        // CSS box-shadow, so `elevation:8` is an approximation, not an
        // exact match; `surfaceTintColor:transparent` keeps the panel
        // pure white instead of Material 3's default tint.
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onOpened: () => setState(() => _isOpen = true),
        onCanceled: () => setState(() => _isOpen = false),
        onSelected: (index) {
          setState(() => _isOpen = false);
          final item = items[index];
          if (!item.disabled) item.onTap();
        },
        itemBuilder:
            (context) => [
              // CSS ref, confirmed straight from `origin/staging`'s
              // dist/app.css (`@media(min-width:992px){#homeSubMenu li{
              // padding:0 .5rem!important;height:2.2rem}}`) and
              // bluetheme-layout.css (`@media(max-width:1200px){
              // #homeSubMenu li{margin:.1rem 0!important}}` — wins over
              // dist/app.css's own `margin:.5rem 0` at that width, loses
              // above 1200px; used here as the confirmed value since a
              // live devtools measurement showed it winning): each
              // `<li>` is 35.2px tall + 1.6px top/bottom margin (38.4px
              // total slot) with its own 8px horizontal padding, outside
              // the `<a>`'s own padding. `#navbarMenu .sub-nav-item a`:
              // `height:100%` (fills the li via flex), `padding:10px
              // 15px`, `border-radius:8px`, `display:flex;gap:10px`,
              // `color:#64748b`. `#homeSubMenu .sub-nav-item:hover{
              // background-color:transparent!important}` (unscoped,
              // always wins) — the `<li>` itself never gets a background;
              // the highlight lives on the `<a>`:
              // `#navbarMenu .sub-nav-item a:hover{background:var(--
              // primary-soft)!important;color:var(--primary-color)
              // !important}` (`--primary-soft`=`#F0E8F7`=`FigmaTokens
              // .badgeBackground`, `--primary-color`=`#693D94`=
              // `FigmaTokens.primaryPurple`).
              for (var i = 0; i < items.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  enabled: !items[i].disabled,
                  height: 38.4,
                  padding: EdgeInsets.zero,
                  // `PopupMenuItem` paints its OWN default grey hover/
                  // splash overlay (from the ambient `Theme`'s
                  // `hoverColor`) underneath whatever `child` renders —
                  // a full-item-width strip, separate from and visible
                  // behind our own inset, rounded, purple-tinted pill
                  // built below via `HoverBuilder`+`Container`.
                  // Suppressed by wrapping the WHOLE `PopupMenuButton` in
                  // a transparent-hover `Theme` above (not here — this
                  // subtree sits INSIDE `PopupMenuItem`'s own hover
                  // `InkWell`, below it in the tree, so a `Theme`
                  // override placed here could never reach back up to
                  // affect that `InkWell`; the override has to be an
                  // ancestor of the button itself, captured into the
                  // popup route when it opens).
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1.6,
                    ),
                    child: HoverBuilder(
                      builder: (context, hovering) {
                        final highlighted =
                            !items[i].disabled &&
                            (hovering || items[i].selected);
                        return Container(
                          // No explicit `width` here — a `Container(width:
                          // double.infinity)` lies about its own
                          // intrinsic width to `_PopupMenu`'s internal
                          // `IntrinsicWidth` pass (which measures every
                          // item to compute one shared menu width),
                          // throwing that computation off and rendering
                          // this box narrower than the real menu width.
                          // `_PopupMenu` already stretches every item to
                          // the determined width via its own
                          // `crossAxisAlignment.stretch` during the real
                          // layout pass, so the ambient tight constraint
                          // fills this box regardless.
                          height: 35.2,
                          alignment: Alignment.centerLeft,
                          // Right padding padded past the real CSS's 15px
                          // — the shared menu width comes from an
                          // `IntrinsicWidth` pass that runs before Google
                          // Fonts' network-loaded "Inter" finishes
                          // fetching, so it measures each label with a
                          // narrower system fallback font; once Inter
                          // actually loads, the real (wider) painted text
                          // can overflow that already-locked-in width by
                          // a few pixels (confirmed: "My Completed
                          // Courses" overflowed by 11px). This buffer
                          // absorbs that font-metric mismatch rather than
                          // trying to force `IntrinsicWidth` to wait for
                          // the font load — trimmed down to 20 (was 27)
                          // per explicit request for a narrower panel;
                          // still enough headroom to avoid the overflow.
                          padding: const EdgeInsets.fromLTRB(15, 0, 20, 0),
                          decoration: BoxDecoration(
                            color:
                                highlighted
                                    ? FigmaTokens.badgeBackground
                                    : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // CSS ref: `#navbarMenu .nav-link img{
                              // width:14px;height:14px;opacity:.8}`,
                              // `.navbar-menu .nav-link img{margin-
                              // right:8px}` (on top of the `<a>`'s own
                              // `gap:10px` flex spacing — the two stack,
                              // ~18px total gap to the label). `#navbar
                              // Menu .nav-link:hover img{opacity:1
                              // !important}` — was previously missing
                              // entirely (text-only).
                              //
                              // A prior pass wrapped this in a
                              // `ColorFiltered`/`BlendMode.srcIn` tint,
                              // guessing these should be monochrome like
                              // the real site's separate `.nav-icon-mask`
                              // class (`background-color:currentColor`)
                              // — but that class only applies to a
                              // different, unused icon-rendering path
                              // (a `<span>`/`<i>` with that class), never
                              // to the real `<img>` markup these items
                              // actually use, which has no color/filter
                              // rule at all, and a live screenshot
                              // confirmed the real icons render in their
                              // own native (mixed) colors.
                              //
                              // App-only deviation, per explicit request:
                              // the real site's own mixed icon colors read
                              // as inconsistent in this app, so every
                              // dropdown icon is now tinted to the same
                              // color as its own label — `_navDefault`
                              // normally, `_navActive` while
                              // hovered/selected — the same two colors the
                              // label text right beside it already uses.
                              Opacity(
                                opacity: highlighted ? 1 : 0.8,
                                child: _NavIcon(
                                  url: items[i].iconAsset,
                                  color: highlighted ? _navActive : _navDefault,
                                ),
                              ),
                              const SizedBox(width: 18),
                              // No `Flexible`/`overflow:ellipsis` here —
                              // wrapping it that way was truncating "My
                              // Completed Courses" even though the menu
                              // had room to grow. `_PopupMenu` sizes the
                              // whole panel from each item's own natural
                              // intrinsic width via `IntrinsicWidth`; a
                              // bare `Text` reports its full, untruncated
                              // width into that measurement, so the panel
                              // simply grows wide enough for every label,
                              // per explicit request.
                              Text(
                                items[i].label,
                                style: GoogleFonts.inter(
                                  color:
                                      items[i].disabled
                                          ? FigmaTokens.noteBodyText
                                          : (highlighted
                                              ? _navActive
                                              : _navDefault),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, 1),
                child: Icon(icon, size: 13, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 16 / 12,
                ),
              ),
              const SizedBox(width: 2),
              // Empirically-tuned offset to match the label's visual (not
              // geometric) center - see commit history if this needs
              // further adjustment.
              Transform.translate(
                offset: const Offset(0, 1.0),
                child: SizedBox(
                  height: 16,
                  child: Center(
                    child: Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      // Design ref: svg w-[11px] h-[11px] opacity-60
                      size: 11,
                      color: color.withValues(alpha: 0.6),
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
    // Fixed square (not min-constraints + padding) so the circle stays
    // perfectly round and the count stays exactly centered regardless
    // of digit count.
    width: 16,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.transparent,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
      textAlign: TextAlign.center,
    ),
  );
}

// ── Shared notifications dialog ───────────────────────────────────────────────

/// Opens the notifications dropdown anchored just under-and-right of
/// whichever bell icon triggered it, rather than centered on the whole
/// screen - [context] must belong to the bell itself (see the `Builder`
/// wrapping each bell icon) so its on-screen position can be read.
void showLmsNotifications(BuildContext context) {
  final renderBox = context.findRenderObject() as RenderBox?;
  final screenSize = MediaQuery.of(context).size;
  double topInset = 76;
  double rightInset = 16;
  if (renderBox != null && renderBox.attached) {
    final topLeft = renderBox.localToGlobal(Offset.zero);
    topInset = topLeft.dy + renderBox.size.height + 8;
    rightInset = (screenSize.width - (topLeft.dx + renderBox.size.width) - 40)
        .clamp(8.0, screenSize.width);
  }

  showDialog<void>(
    context: context,
    // The web bell dropdown is an undimmed popover (no modal overlay) that
    // closes on an outside click - `barrierDismissible` still handles that.
    barrierColor: Colors.transparent,
    builder:
        (ctx) =>
            _NotificationsDialog(topInset: topInset, rightInset: rightInset),
  );
}

class _NotificationsDialog extends ConsumerWidget {
  const _NotificationsDialog({
    required this.topInset,
    required this.rightInset,
  });
  final double topInset;
  final double rightInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(NotificationsViewModel.provider);

    // CSS ref (staging bluetheme-layout.css): `.notification-dropdown` —
    // width 360, radius 16, border 1px rgba(0,0,0,.05), shadow
    // 0 15px 50px rgba(0,0,0,.18) (this was width 430, radius 18, and the
    // default dialog shadow). `.dropdown-header` padding 16px 20px with a
    // #F1F5F9 bottom border; `#notificationList` max-height 380.
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: EdgeInsets.fromLTRB(16, topInset, rightInset, 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 50,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  // CSS ref: `.dropdown-header a` — a plain 12px/600
                  // primary-color text link that the staging template
                  // renders unconditionally (this was a TextButton only
                  // shown when unreadCount > 0, styled 700).
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap:
                          () =>
                              ref
                                  .read(
                                    NotificationsViewModel.provider.notifier,
                                  )
                                  .markAllAsRead(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          'Mark all as read',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: _appPurple,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (notifState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: _appPurple),
              )
            else if (notifState.notifications.isEmpty)
              const _NotifEmpty()
            else
              // CSS ref: `#notificationList` — max-height 380px (the web
              // scrolls; the old modal force-capped display at 5 rows and
              // drew extra Divider separators — each item already carries
              // its own #F1F5F9 bottom border).
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount:
                        notifState.notifications.length > 5
                            ? 5
                            : notifState.notifications.length,
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
                              Toast.info(
                                context,
                                'Internet required to open this link.',
                              );
                              return;
                            }
                            final uri = Uri.tryParse(url);
                            if (uri != null) {
                              InAppWebViewPage.showWithAuth(
                                context,
                                ref,
                                url: url,
                                title:
                                    item.title.isNotEmpty
                                        ? item.title
                                        : 'Notification',
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            // CSS ref: `.notification-dropdown .dropdown-footer` — padding
            // 14px 20px, bg #FAFBFC, top border #F1F5F9; the link is
            // 13px/600 in the primary color (was a 700-weight link padded
            // 16 all sides on #FAFBFD with rounded bottom corners).
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFBFC),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // Replace the dialog route directly — pop + push on the
                    // same context risks using the dialog's disposed context
                    // (the source of the `this.widget.build` NoSuchMethodError).
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                  child: Center(
                    child: Text(
                      'View All Notifications',
                      style: GoogleFonts.inter(
                        color: _appPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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

class _NotifEmpty extends StatelessWidget {
  const _NotifEmpty();

  @override
  Widget build(BuildContext context) {
    // CSS ref: `.notif-empty-state` — padding 32px 20px, centered; the
    // icon is a 32px #22C55E check (the modal previously used a wrong
    // 27px #24C56B checkmark inside a filled circle), margin-bottom 10px;
    // text 14px/500/#94A3B8 "You're all caught up".
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 32, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 32),
          SizedBox(height: 10),
          Text(
            "You're all caught up",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifRow extends StatefulWidget {
  const _NotifRow({required this.item, required this.onTap});
  final NotificationItem item;
  final VoidCallback onTap;

  @override
  State<_NotifRow> createState() => _NotifRowState();
}

class _NotifRowState extends State<_NotifRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isUnread = !item.isRead;
    // CSS ref (staging bluetheme-layout.css, §5 Notification System):
    // `.notification-item` padding 16px 20px, gap 14px, border-bottom
    // #F1F5F9, bg #fff; `.unread` bg #F8F9FF; hover bg #FAFBFC (unread
    // items keep #F8F9FF — `.notification-item.unread` beats `:hover`).
    // Icon 36x36 radius 10: read bg #F1F4F9 + icon #94A3B8; unread
    // (`.icon-unread`) bg rgba(92,82,212,.1) + icon = primary; hover bg
    // #E8ECF1 (read) / rgba(92,82,212,.15) (unread). The unread dot is a
    // 7px primary circle inline in the title row. `.notif-item-title`
    // 13px/600/#1E293B nowrap, hover -> primary; `.notif-item-body`
    // 12px/#64748B/lh1.5, margin-top 4px, clamped to 2 lines. The modal
    // shows no timestamp or action menu (those belong to the full page's
    // cards, not the bell dropdown), so both were removed.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color:
                isUnread
                    ? const Color(0xFFF8F9FF)
                    : _hover
                    ? const Color(0xFFFAFBFC)
                    : Colors.white,
            border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      isUnread
                          ? _appPurple.withValues(alpha: _hover ? 0.15 : 0.10)
                          : _hover
                          ? const Color(0xFFE8ECF1)
                          : const Color(0xFFF1F4F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 14,
                  color: isUnread ? _appPurple : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color:
                                  _hover ? _appPurple : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: _appPurple,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  /// Initial letter color shown when there's no photo (background is
  /// always white in that case) — defaults to the app purple.
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final url = profile?.avatarUrl?.toString() ?? '';
    if (url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: radius - 2,
          backgroundImage: NetworkImage(url),
        ),
      );
    }
    // No photo: flat white circle with the initial in fallbackColor -
    // matches reference (bg #FFFFFF, text #693D94), not a filled/ringed
    // circle with white text.
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Text(
        _initial(profile),
        style: GoogleFonts.inter(
          color: fallbackColor,
          fontWeight: FontWeight.w600,
          fontSize: radius * 1.1,
        ),
      ),
    );
  }
}

/// First letter of the user's first name (falling back to their username),
/// shown in the avatar circle when there's no profile photo - matches the
/// Figma spec's single-initial fallback rather than a generic person icon.
String _initial(dynamic profile) {
  final firstname = profile?.firstname?.toString() ?? '';
  return firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';
}

// ── Profile popup widgets ─────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, this.role});
  final dynamic profile;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final name =
        '${profile?.firstname ?? ''} ${profile?.lastname ?? ''}'.trim();
    final roleLabel = (role?.trim().isNotEmpty ?? false)
        ? role!.trim()
        : 'User';
    // Reference site's `.profile-header-box`: solid var(--primary-first)
    // background, 40px avatar, name as h6 (#fff/700/15px/letter-spacing
    // -0.3px) with the role as an uppercase, letter-spaced 11px caption.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      decoration: const BoxDecoration(
        color: _appPurple,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          LmsAvatar(profile: profile, radius: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'User' : name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                roleLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xCCFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
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
  const _ProfileMenuRow({
    required this.icon,
    required this.label,
    this.isLogout = false,
  });
  final IconData icon;
  final String label;
  final bool isLogout;

  // Matches the reference site's a.dropdown-item (#4A5568, Inter
  // 14px/500, margin 2/10 + padding 10/15) but split into an outer
  // margin (8/2) and an inner padded pill so the hover highlight can
  // breathe — the web pill is inset with generous internal padding.
  // Hover mirrors `.dropdown-profile .dropdown-item:hover`: background
  // var(--primary-soft) / FigmaTokens.badgeBackground + primary color +
  // translateX(6px); the logout item (.logout-item:hover) uses a red
  // tint + #e53e3e instead. Wrapped `PopupMenuButton` in a transparent-
  // hover Theme above, so PopupMenuItem's default light-blue ink no
  // longer shows behind this pill.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovering) {
        final tint = isLogout
            ? const Color(0x1AEF4444)
            : FigmaTokens.badgeBackground;
        final textColor = hovering
            ? (isLogout ? const Color(0xFFE53E3E) : _appPurple)
            : const Color(0xFF4A5568);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hovering ? tint : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Transform.translate(
            offset: hovering ? const Offset(6, 0) : Offset.zero,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: textColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
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
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
      ),
    );
  }
}

const _datePillWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _datePillMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _formatDatePill(DateTime dt) {
  final weekday = _datePillWeekdays[dt.weekday - 1];
  final month = _datePillMonths[dt.month - 1];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$weekday $month ${dt.day}, ${dt.year} | $hour12:$minute $ampm';
}
