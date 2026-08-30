import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart'
    show readIsOnline;
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';

// CSS ref, confirmed against `origin/staging`'s notification/index.php:
// `--notif-primary: #5c52d4` — a distinct indigo (also used on Badges'
// lock icon and Item Inventory's Redeem History button), not the app's
// usual `FigmaTokens.primaryPurple` (#693D94), which this screen was
// wrongly using throughout.
const _nPurple = Color(0xFF5C52D4);
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
      onRefresh:
          () => ref.read(NotificationsViewModel.provider.notifier).fetch(),
      body: Column(
        children: [
          _StatsBar(state: state, ref: ref),
          Expanded(
            child:
                state.isLoading
                    ? const Center(
                      child: CircularProgressIndicator(color: _nPurple),
                    )
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
    // CSS ref: .notif-stats-bar — radius 16px, padding 16px 20px, border
    // 1px #F3F4F6, shadow 0 1px 3px rgba(0,0,0,.02) (was radius 8, padding
    // 14/10, a heavier ad-hoc shadow, and no border).
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Unread pill — CSS ref: .unread-badge bg #F5F3FF.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _nPurple,
                    shape: BoxShape.circle,
                  ),
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
          // Total — CSS ref: .total-badge bg #F3F4F6, color #6B7280.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '${state.notifications.length} Total',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Mark all read
          if (state.unreadCount > 0)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final error =
                      await ref
                          .read(NotificationsViewModel.provider.notifier)
                          .markAllAsRead();
                  if (error != null && context.mounted) {
                    Toast.error(context, error);
                  }
                },
                // CSS ref: .notif-mark-all-btn — bg #F5F3FF, radius 10px,
                // padding 8px 16px (was a pill radius 20 with a lighter bg).
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: _nPurple,
                      ),
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
    if (diff.inDays >= 1)
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    if (diff.inHours >= 1)
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    // CSS ref: .notif-card — radius 16px, border 1px #F3F4F6, shadow
    // 0 1px 3px rgba(0,0,0,.02); .notif-card.unread — border-left 4px
    // (was 8px radius, no border, a heavier shadow, and a 3px left
    // border).
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : const Color(0xFFFAFAFF),
        borderRadius: BorderRadius.circular(16),
        // .notif-card's base border is 1px #F3F4F6 on every side;
        // .unread overrides only `border-left` to 4px indigo, leaving the
        // other three sides at the base 1px.
        border: Border(
          top: const BorderSide(color: Color(0xFFF3F4F6)),
          right: const BorderSide(color: Color(0xFFF3F4F6)),
          bottom: const BorderSide(color: Color(0xFFF3F4F6)),
          left:
              item.isRead
                  ? const BorderSide(color: Color(0xFFF3F4F6))
                  : const BorderSide(color: _nPurple, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final error = await ref
              .read(NotificationsViewModel.provider.notifier)
              .markOneAsRead(item.id);
          if (error != null && context.mounted) {
            Toast.error(context, error);
          }
          final url = item.redirectUrl;
          if (url != null && url.isNotEmpty) {
            if (!readIsOnline(ref)) {
              Toast.info(context, 'Internet required to open this link.');
              return;
            }
            final uri = Uri.tryParse(url);
            if (uri != null) {
              InAppWebViewPage.showWithAuth(
                context,
                ref,
                url: url,
                title: 'Course Details',
              );
            }
          }
        },
        // CSS ref: .notif-card-inner — padding 20px all sides (the card's
        // own `.notif-card { padding: 20px }`), gap 16px (was 14/14/12/14
        // padding, 12px gap).
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bell avatar — CSS ref: .notif-card-icon 44x44, radius
              // 12px, bg #F5F3FF (unread: rgba(92,82,212,.12)) (was
              // 40x40, radius 10, a flat purple@0.1 bg for both states).
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color:
                      item.isRead
                          ? const Color(0xFFF5F3FF)
                          : _nPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: _nPurple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CSS ref: .notif-card-title — 15px/600/#111827,
                    // line-height 1.4 — same color whether read or
                    // unread (was wrongly dimmed to muted when read).
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF111827),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // CSS ref: .notif-card-message — 14px/#6B7280/lh 1.6.
                    Text(
                      item.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // CSS ref: .notif-card-time — 12px/#9CA3AF with a
                    // clock icon.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(item.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right column: unread dot + menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // CSS ref: .notif-card.unread::before — 8x8 (was 9x9),
                  // absolutely positioned top:20/right:20 relative to the
                  // card (the card's own 20px padding, applied here via
                  // layout order instead, lands this dot at effectively
                  // the same spot).
                  if (!item.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 2, bottom: 6),
                      decoration: const BoxDecoration(
                        color: _nPurple,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                  // Nudged down a bit further from the unread dot / title row above.
                  const SizedBox(height: 10),
                  // CSS/markup ref: the real dropdown's `.notif-toggle-
                  // read` item always shows, flipping between "Mark
                  // Read"/"Mark Unread" (POST `toggle-read`). FLAGGED,
                  // NOT IMPLEMENTED: this app's REST API only exposes a
                  // one-way `/{id}/read` endpoint — no unread endpoint to
                  // call — so the item still can't be un-hidden once read
                  // without a backend addition; same category as the
                  // Completed Courses "points" gap. `.dropdown-item` text
                  // color #374151 (was _nNavy); the delete item is
                  // `.text-danger` — red (was navy too).
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                    itemBuilder:
                        (context) => [
                          if (!item.isRead)
                            const PopupMenuItem(
                              value: 'read',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: Color(0xFF374151),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Mark Read'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              ],
                            ),
                          ),
                        ],
                    onSelected: (value) async {
                      final notifier = ref.read(
                        NotificationsViewModel.provider.notifier,
                      );
                      if (value == 'read') {
                        final error = await notifier.markOneAsRead(item.id);
                        if (error != null && context.mounted) {
                          Toast.error(context, error);
                        }
                      } else if (value == 'delete') {
                        final error = await notifier.deleteOne(item.id);
                        if (error != null && context.mounted) {
                          Toast.error(context, error);
                        }
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
    // CSS ref: .notif-empty-card .empty-icon — 48px, color #22C55E (a
    // green checkmark, not a purple bell-off); h4 18px/600/#111827; p
    // "No new notifications to show" (was missing "to show"), 14px/
    // #6B7280.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF22C55E),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            "You're all caught up!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No new notifications to show',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
