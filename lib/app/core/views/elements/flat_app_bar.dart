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

    final topPadding = MediaQuery.of(context).padding.top;
    // Treat anything narrower than 600px as a phone.
    final isPhone = MediaQuery.of(context).size.width < 600;

    final userName =
        "${userProfile2?.firstname ?? ""} ${(userProfile2?.middlename ?? "").trim()} ${userProfile2?.lastname ?? ""}"
            .trim();

    return PrimaryCard(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Row(
          children: [
            // ── Back button (only rendered when navigation is possible) ──
            if (enableBack)
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  HugeIcons.strokeRoundedArrowLeft01,
                  size: isPhone ? 20 : 24,
                ),
              )
            else
              const SizedBox(width: 8),

            // ── Title ────────────────────────────────────────────────────
            Flexible(
              child: Text(
                "Course Catalog",
                style: isPhone
                    ? context.textTheme.titleMedium
                    : context.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            // ── "OFFLINE" chip (auto-detected network loss) ───────────────
            ConnectionAwareWidget(
              offlineChild: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Chip(
                  label: Text(
                    isPhone ? "OFF" : "OFFLINE",
                    style: context.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontSize: isPhone ? 9 : null,
                    ),
                  ),
                  padding: isPhone
                      ? const EdgeInsets.symmetric(horizontal: 2)
                      : null,
                  backgroundColor: Colors.redAccent,
                ),
              ),
              onlineChild: const SizedBox.shrink(),
            ),

            const Spacer(),

            // ── "Go Offline" toggle ───────────────────────────────────────
            // Phone: icon + compact Switch only. Tablet: icon + label + Switch.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOfflineMode
                      ? Icons.wifi_off_rounded
                      : Icons.wifi_rounded,
                  size: 16,
                  color: isOfflineMode
                      ? Colors.amber.shade700
                      : context.textTheme.bodySmall?.color,
                ),
                if (!isPhone) ...[
                  const SizedBox(width: 2),
                  Text(
                    isOfflineMode ? "Offline" : "Go Offline",
                    style: context.textTheme.bodySmall?.copyWith(
                      color: isOfflineMode ? Colors.amber.shade700 : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                Transform.scale(
                  scale: isPhone ? 0.75 : 1.0,
                  child: Switch(
                    value: isOfflineMode,
                    onChanged: (val) => ref
                        .read(OfflineModeNotifier.provider.notifier)
                        .setMode(val),
                    activeColor: Colors.amber.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 4),

            // ── User avatar + name (name hidden on phone) ─────────────────
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with pending-sync badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: isPhone ? 16 : 20,
                          child: Icon(
                            Icons.person,
                            size: isPhone ? 16 : 20,
                          ),
                        ),
                        if (syncVM.pendingCount > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${syncVM.pendingCount}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Hide name on phone to save space
                    if (!isPhone && userName.isNotEmpty) ...[
                      SizedBox(width: context.minorSpace),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          userName,
                          style: context.textTheme.labelLarge,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    final topPadding = WidgetsBinding
            .instance.platformDispatcher.views.first.padding.top /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return Size.fromHeight(kToolbarHeight + topPadding);
  }
}
