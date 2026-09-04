import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/core/views/elements/connection_aware_widget.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
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
    final isOfflineMode = ref.watch(OfflineModeNotifier.provider);
    final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;
    // macOS has no status bar — use zero top padding and center items vertically.
    final topPadding = isMacOS ? 0.0 : MediaQuery.of(context).padding.top;

    return PrimaryCard(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: isMacOS ? 0 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // ── Back button OR leading space ────────────────────────────
            if (enableBack)
              IconButton(
                onPressed: () => safePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
              )
            else
              const SizedBox(width: 16),

            // ── Title + OFFLINE chip ────────────────────────────────────
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // "OFFLINE" chip (physical network loss indicator)
                  ConnectionAwareWidget(
                    offlineChild: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'OFFLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onlineChild: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // ── Gap between title section and offline toggle ───────────
            const SizedBox(width: 8),

            // ── Offline toggle (wifi icon + Switch) ────────────────────
            // NOTE: no user avatar here by design — viewer screens
            // (the only FlatAppBar consumers) keep a chrome-free header.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOfflineMode
                      ? Icons.wifi_off_rounded
                      : Icons.wifi_rounded,
                  size: 18,
                  color: isOfflineMode
                      ? Colors.amber.shade700
                      : context.textTheme.bodySmall?.color,
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isOfflineMode,
                    onChanged: (val) {
                      ref
                          .read(OfflineModeNotifier.provider.notifier)
                          .setMode(val);
                      // When switching back to online, flush the sync queue.
                      if (!val) {
                        ref.read(SyncViewModel.provider).onManualOnline();
                      }
                    },
                    activeThumbColor: Colors.amber.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    // macOS has no status bar and no bottom padding — use a flat toolbar height.
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return const Size.fromHeight(kToolbarHeight);
    }
    final topPadding =
        WidgetsBinding.instance.platformDispatcher.views.first.padding.top /
            WidgetsBinding
                .instance.platformDispatcher.views.first.devicePixelRatio;
    return Size.fromHeight(kToolbarHeight + topPadding + 10);
  }
}
