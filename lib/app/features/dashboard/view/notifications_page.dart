import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';

const _nPurple = FigmaTokens.primaryPurple;
const _nNavy = FigmaTokens.cardTitles;
const _nMuted = FigmaTokens.noteBodyText;
const _nBg = FigmaTokens.pageBackground;

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(NotificationsViewModel.provider);

    // Same shared header (height, logo, date/time, wifi/offline toggle,
    // notification bell, profile menu, ...) every other screen uses,
    // instead of this page's own custom purple banner.
    return AppScaffold(
      backgroundColor: _nBg,
      title: 'Notifications',
      onRefresh: () => ref.read(NotificationsViewModel.provider.notifier).fetch(),
      body: Column(
        children: [
          _StatsBar(state: state, ref: ref),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: _nPurple))
                : state.notifications.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: state.notifications.length,
                        itemBuilder: (ctx, i) {
                          final item = state.notifications[i];
                          return _NotifCard(item: item, ref: ref);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.state, required this.ref});
  final NotificationsState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Unread pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _nPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _nPurple, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  '${state.unreadCount} Unread',
                  style: const TextStyle(
                    color: _nPurple,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_outlined, size: 14, color: _nMuted),
                const SizedBox(width: 4),
                Text(
                  '${state.notifications.length} Total',
                  style: const TextStyle(color: _nMuted, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Mark all read
          if (state.unreadCount > 0)
            GestureDetector(
              onTap: () => ref.read(NotificationsViewModel.provider.notifier).markAllAsRead(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _nPurple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_outline, size: 16, color: _nPurple),
                    SizedBox(width: 4),
                    Text(
                      'Mark all read',
                      style: TextStyle(
                        color: _nPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

// ── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.item, required this.ref});
  final NotificationItem item;
  final WidgetRef ref;

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours >= 1) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: item.isRead ? Colors.transparent : _nPurple,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(NotificationsViewModel.provider.notifier).markOneAsRead(item.id);
          final url = item.redirectUrl;
          if (url != null && url.isNotEmpty) {
            if (!readIsOnline(ref)) {
              Toast.info(context, 'Internet required to open this link.');
              return;
            }
            final uri = Uri.tryParse(url);
            if (uri != null) {
              InAppWebViewPage.showWithAuth(context, ref,
                  url: url, title: item.title.isNotEmpty ? item.title : 'Notification');
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bell avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _nPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_rounded, color: _nPurple, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: item.isRead ? _nMuted : _nNavy,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _nMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _timeAgo(item.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: _nMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right column: unread dot + menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!item.isRead)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 2, bottom: 6),
                      decoration: const BoxDecoration(color: _nPurple, shape: BoxShape.circle),
                    )
                  else
                    const SizedBox(height: 17),
                  // Nudged down a bit further from the unread dot / title row above.
                  const SizedBox(height: 10),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'read',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 16, color: _nNavy),
                            SizedBox(width: 10),
                            Text('Mark Read'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: _nNavy),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      final notifier = ref.read(NotificationsViewModel.provider.notifier);
                      if (value == 'read') {
                        notifier.markOneAsRead(item.id);
                      } else if (value == 'delete') {
                        notifier.deleteOne(item.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _nPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, color: _nPurple, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            "You're all caught up!",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _nNavy),
          ),
          const SizedBox(height: 6),
          const Text(
            'No new notifications',
            style: TextStyle(fontSize: 13, color: _nMuted),
          ),
        ],
      ),
    );
  }
}
