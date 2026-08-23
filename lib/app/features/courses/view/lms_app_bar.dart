import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/providers/shell_destination_provider.dart';
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
const _appMuted = FigmaTokens.noteBodyText;
const _navActive = FigmaTokens.primaryPurple;
const _navDefault = Color(0xFF6A7282);

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
const double _mobileTopBarHeight = 48;

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
          itemBuilder: (context) => _profileMenuItems(profile),
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
                child: const Logo(size: 22),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LmsOfflineToggle(
                isOffline: isOffline,
                iconSize: 16,
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
                width: 30,
                height: 30,
                child: Builder(
                  builder:
                      (bellContext) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          LmsAppBarButton(
                            icon: Icons.notifications_none_rounded,
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
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                offset: const Offset(0, 34),
                constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onSelected:
                    (value) => _onProfileMenuSelected(context, ref, value),
                itemBuilder: (context) => _profileMenuItems(profile),
                padding: EdgeInsets.zero,
                // Phone-only: avatar sits inside a small rounded box with a
                // dropdown chevron, instead of desktop's bare avatar + name.
                child: Container(
                  padding: useDashboardMobileProfileStyle
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(4, 4, 6, 4),
                  decoration: useDashboardMobileProfileStyle
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, WidgetRef ref) {
    // Back navigation is always handled inline in the page body header
    // (← Back | Page Title) — the AppBar always shows "Menu" + hamburger.

    // Figma mobile app bar spec:
    // Container: horizontal, space-between, padding top 8 / right 16 / bottom 8 / left 16
    // "Menu" label: Inter SemiBold 600, 14px, line-height 20px, color #364153
    // Hamburger icon: 20×20px, color #6A7282
    // Background: white
    //
    // Deliberately NOT a real AppBar here — nesting an actual AppBar inside
    // the Column below (alongside the purple top bar) corrupted the
    // semantics tree ('!semantics.parentDataDirty' assertion flood) and
    // rendered a blank body. AppBar expects to be the sole widget handed
    // to Scaffold's `appBar:` slot, not nested under another widget, so
    // this replicates the same visuals with plain Material/Row instead.
    final menuBar = Material(
      color: Colors.white,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: always "Menu" label
              const Text(
                'Menu',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 20 / 14,
                  letterSpacing: 0,
                  color: Color(0xFF533641),
                ),
              ),
              // Right: always hamburger icon
              Builder(
                builder:
                    (ctx) => GestureDetector(
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: Icon(
                            Icons.menu_rounded,
                            size: 20,
                            color: FigmaTokens.noteBodyText,
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

  List<PopupMenuEntry<String>> _profileMenuItems(dynamic profile) => [
    PopupMenuItem<String>(
      enabled: false,
      padding: EdgeInsets.zero,
      child: _ProfileHeader(profile: profile),
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
                          disabled: !isOnline,
                          onTap: () => launchContactCoachUrl(ref, context),
                        ),
                        _NavSubItem(
                          label: 'Virtual Development Pro',
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
    this.selected = false,
    this.disabled = false,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
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
    return PopupMenuButton<String>(
      offset: const Offset(0, 38),
      constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
    return PopupMenuButton<int>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onOpened: () => setState(() => _isOpen = true),
      onCanceled: () => setState(() => _isOpen = false),
      onSelected: (index) {
        setState(() => _isOpen = false);
        final item = items[index];
        if (!item.disabled) item.onTap();
      },
      itemBuilder:
          (context) => [
            // Matches the reference site's #navbarMenu .sub-nav-item a exactly:
            // 14px, #64748b, 10px/15px padding, 8px radius.
            for (var i = 0; i < items.length; i++)
              PopupMenuItem<int>(
                value: i,
                enabled: !items[i].disabled,
                padding: EdgeInsets.zero,
                child: HoverBuilder(
                  builder: (context, hovering) {
                    final highlighted =
                        !items[i].disabled && (hovering || items[i].selected);
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: highlighted ? FigmaTokens.badgeBackground : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        items[i].label,
                        style: GoogleFonts.inter(
                          color:
                              items[i].disabled
                                  ? FigmaTokens.noteBodyText
                                  : (highlighted ? _navActive : _navDefault),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
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
    barrierColor: Colors.black26,
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

    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: EdgeInsets.fromLTRB(16, topInset, rightInset, 20),
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
                  Text(
                    'Notifications',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  if (notifState.unreadCount > 0)
                    TextButton(
                      onPressed:
                          () =>
                              ref
                                  .read(
                                    NotificationsViewModel.provider.notifier,
                                  )
                                  .markAllAsRead(),
                      style: TextButton.styleFrom(
                        foregroundColor: _appPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Mark all as read',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
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
                        color: FigmaTokens.noteBodyText,
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
                  itemCount:
                      notifState.notifications.length > 5
                          ? 5
                          : notifState.notifications.length,
                  separatorBuilder:
                      (_, __) =>
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
            const Divider(height: 1),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFD),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
                child: Center(
                  child: Text(
                    'View All Notifications',
                    style: GoogleFonts.inter(
                      color: _appPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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
                color: const Color(0x1A5C52D4),
                borderRadius: BorderRadius.circular(8),
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
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: item.isRead ? _appMuted : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(item.createdAt!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFABB6C8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 7,
                  height: 7,
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
        gradient: FigmaTokens.heroGradient,
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

  // Matches the reference site's a.dropdown-item exactly: #4A5568, Inter
  // 14px, margin 2/10 + padding 10/15 (combined here into one inset,
  // since PopupMenuItem has no separate margin concept).
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4A5568)),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF4A5568),
            fontSize: 14,
          ),
        ),
      ],
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
