import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
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

const _appPurple = Color(0xFF5756C9);
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

// ── Shared AppBar ─────────────────────────────────────────────────────────────

class LmsAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const LmsAppBar({
    super.key,
    this.isWide = false,
    this.bottom,
    this.onBack,
    this.title,
    this.centerTitle = false,
  });

  /// Responsive wide-screen layout (catalog page only).
  final bool isWide;

  /// Optional bottom widget (e.g. nav-tab bar) — catalog page only.
  final PreferredSizeWidget? bottom;

  /// If provided, a back button is shown that calls this. If null and
  /// `Navigator.canPop` is true, standard pop is used instead.
  final VoidCallback? onBack;

  /// Optional title text (e.g. "Dashboard"). Omitted on pages that render
  /// their own heading in the body (e.g. the course catalog).
  final String? title;

  /// Whether [title] is centered. Ignored when [title] is null.
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(
        (isWide ? 52.0 : 60.0) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final canPop = Navigator.canPop(context);
    final showBack = onBack != null || (canPop && onBack == null);
    final isOffline = ref.watch(OfflineModeNotifier.provider);
    final unreadCount = ref.watch(NotificationsViewModel.unreadCountProvider);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: isWide ? 52 : 60,
      backgroundColor: _appPurple,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: title != null && centerTitle,
      titleSpacing: 0,
      leadingWidth: isWide
          ? (showBack ? 46 : 0)
          : (showBack ? 106 : 68),
      leading: isWide && !showBack
          ? null
          : Padding(
              padding: EdgeInsets.only(left: isWide ? 8 : 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showBack) ...[
                      LmsAppBarButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: onBack ?? () => Navigator.pop(context),
                        iconSize: isWide ? 21 : 31,
                      ),
                      if (!isWide) const SizedBox(width: 6),
                    ],
                    // The sidebar is always visible on wide screens, so
                    // there's nothing for a hamburger button to open.
                    if (!isWide)
                      Builder(
                        builder: (ctx) => LmsAppBarButton(
                          icon: Icons.menu_rounded,
                          onTap: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      title: title == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                title!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
      actions: [
        if (isWide) ...[const _DatePill(), const SizedBox(width: 8)],
        LmsOfflineToggle(
          isOffline: isOffline,
          onChanged: (val) {
            ref.read(OfflineModeNotifier.provider.notifier).setMode(val);
            if (!val) ref.read(SyncViewModel.provider).onManualOnline();
            Toast.info(
                context, val ? 'Offline mode enabled' : 'Back to online mode');
          },
        ),
        // Bell with unread badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            LmsAppBarButton(
              icon: Icons.notifications_rounded,
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
        SizedBox(width: isWide ? 8 : 12),
        // Avatar with profile popup menu
        PopupMenuButton<String>(
          offset: Offset(0, isWide ? 38 : 54),
          constraints: const BoxConstraints(minWidth: 290, maxWidth: 390),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(AuthStateNotifier.provider.notifier).logout();
              Modular.to.navigate('/');
            } else if (value == 'settings') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
              );
            } else if (value == 'points') {
              Modular.to.pushNamed(
                CoursesModule.construct(CoursesModule.redeemPoints),
              );
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
          ],
          child: LmsAvatar(profile: profile, radius: isWide ? 19 : 21),
        ),
        SizedBox(width: isWide ? 7 : 8),
        LmsAppBarButton(
          icon: Icons.play_arrow_rounded,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LearningProgressPage()),
          ),
        ),
        SizedBox(width: isWide ? 10 : 12),
      ],
      bottom: bottom,
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
  });
  final IconData icon;
  final VoidCallback onTap;

  /// Overrides the default responsive icon size (e.g. to visually balance
  /// glyphs like `arrow_back_ios` that render smaller than others at the
  /// same nominal size).
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final size = isWide ? 38.0 : 42.0;
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
              size: iconSize ?? (isWide ? 24 : 27),
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
  });
  final bool isOffline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
          size: 22,
          color: isOffline ? Colors.amber.shade600 : Colors.white70,
        ),
        Transform.scale(
          scale: 0.85,
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
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
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
  const LmsAvatar({super.key, required this.profile, required this.radius});
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

class _DatePill extends StatelessWidget {
  const _DatePill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'Tuesday July 14, 2026|1:04 PM',
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, height: 1.0),
        ),
      ),
    );
  }
}
