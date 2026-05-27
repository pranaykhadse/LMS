import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

class FlatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const FlatAppBar({
    super.key,
    required this.title,
    this.actions,
    this.enableBack = true,
  });
  final String title;
  final List<Widget>? actions;
  final bool enableBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile2 = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final isOfflineMode = ref.watch(OfflineModeNotifier.provider);
    final syncVM = ref.watch(SyncViewModel.provider);

    // Scaffold allocates statusBarHeight + preferredSize.height for the appBar.
    // We must pad the content down by statusBarHeight so it sits below the
    // system status bar (time / wifi / battery icons) on real devices.
    final topPadding = MediaQuery.of(context).padding.top;

    return PrimaryCard(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Row(
        children: [
          // ── Back button ────────────────────────────────────────────────
          Opacity(
            opacity: enableBack ? 1.0 : 0.0,
            child: AbsorbPointer(
              absorbing: !enableBack,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(HugeIcons.strokeRoundedArrowLeft01),
              ),
            ),
          ),
          SizedBox(width: context.smallSpace),

          // ── Title ──────────────────────────────────────────────────────
          Text("Course Catalog", style: context.textTheme.titleLarge),
          SizedBox(width: context.smallSpace),

          // ── "OFFLINE" chip (auto-detected network loss) ────────────────
          ConnectionAwareWidget(
            offlineChild: Chip(
              label: Text(
                "OFFLINE",
                style: context.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
            onlineChild: const SizedBox.shrink(),
          ),

          const Spacer(),

          // ── "Go Offline" toggle ────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOfflineMode ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                size: 18,
                color: isOfflineMode
                    ? Colors.amber.shade700
                    : context.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 2),
              Text(
                isOfflineMode ? "Offline" : "Go Offline",
                style: context.textTheme.bodySmall?.copyWith(
                  color: isOfflineMode ? Colors.amber.shade700 : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Switch(
                value: isOfflineMode,
                onChanged: (val) =>
                    ref.read(OfflineModeNotifier.provider.notifier).setMode(val),
                activeColor: Colors.amber.shade700,
              ),
            ],
          ),

          SizedBox(width: context.minorSpace),

          // ── User menu with pending-sync badge ─────────────────────────
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () {
                  ref.read(AuthStateNotifier.provider.notifier).logout();
                  Modular.to.navigate("/");
                },
                child: Row(
                  spacing: context.minorSpace,
                  children: const [Icon(Icons.logout), Text("Logout")],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar with badge when there are pending completions
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    if (syncVM.pendingCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${syncVM.pendingCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: context.minorSpace),
                // Cap width so long names can't push buttons off-screen
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    "${userProfile2?.firstname ?? ""} ${(userProfile2?.middlename ?? "")} ${userProfile2?.lastname ?? ""}",
                    style: context.textTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.minorSpace),
        ],
      ),
    ));
  }

  @override
  Size get preferredSize {
    // Include the top safe-area (status bar) height so Scaffold allocates
    // enough room and the content isn't hidden behind system icons.
    final topPadding = WidgetsBinding
        .instance.platformDispatcher.views.first.padding.top /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return Size.fromHeight(kToolbarHeight + topPadding);
  }
}
