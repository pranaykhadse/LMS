import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lms/app/core/core.dart';
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
    final userProfile = ref.watch(AuthStateNotifier.provider)?.userProfile;
    final syncVM = ref.watch(SyncViewModel.provider);
    final topPadding = MediaQuery.of(context).padding.top;

    final userName =
        '${userProfile?.firstname ?? ''} ${(userProfile?.middlename ?? '').trim()} ${userProfile?.lastname ?? ''}'
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');

    return PrimaryCard(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // ── Back button OR leading space ────────────────────────────
            if (enableBack)
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
              )
            else
              const SizedBox(width: 16),

            // ── Title — Flexible so it shrinks before anything else ─────
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),

            // ── "OFFLINE" chip (physical network loss indicator) ────────
            ConnectionAwareWidget(
              offlineChild: Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

            // ── Push action items to the right ──────────────────────────
            const Spacer(),

            // ── User avatar with popup menu ─────────────────────────────
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              itemBuilder: (_) => [
                // Show user name at the top of the menu (non-tappable)
                if (userName.isNotEmpty)
                  PopupMenuItem<String>(
                    enabled: false,
                    height: 36,
                    child: Text(
                      userName,
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18),
                      const SizedBox(width: 8),
                      const Text('Logout'),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                if (val == 'logout') {
                  ref.read(AuthStateNotifier.provider.notifier).logout();
                  Modular.to.navigate('/');
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      child: Icon(Icons.person, size: 18),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    final topPadding =
        WidgetsBinding.instance.platformDispatcher.views.first.padding.top /
            WidgetsBinding
                .instance.platformDispatcher.views.first.devicePixelRatio;
    return Size.fromHeight(kToolbarHeight + topPadding);
  }
}
