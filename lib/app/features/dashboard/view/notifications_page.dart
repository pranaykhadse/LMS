import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart'
    show readIsOnline;
import 'package:lms/app/features/dashboard/model/notification_model.dart';
import 'package:lms/app/features/dashboard/viewmodel/notifications_view_model.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/features/courses/view/content_viewer/in_app_webview_page.dart';

// CSS ref, confirmed against `origin/staging`'s notification/index.php:
// `--notif-primary: #5c52d4`. User override: every accent the web paints
// with that indigo is rendered with the app's theme purple instead —
// `FigmaTokens.primaryPurple` (#693D94), hover #5A3480.
const _nPurple = FigmaTokens.primaryPurple;
const _nPurpleHover = FigmaTokens.purpleHover;
const _nBg = FigmaTokens.pageBackground;

/// The web page's cards run on Yii's default `ActiveDataProvider` page
/// size (20), which is also why its LinkPager only renders from the 21st
/// item up — see NotificationController::actionIndex.
const _nPageSize = 20;

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(NotificationsViewModel.provider);
    final items = state.notifications;
    final pages = ((items.length + _nPageSize - 1) ~/ _nPageSize).clamp(1, 1 << 30);
    final page = _page.clamp(1, pages);
    final start = (page - 1) * _nPageSize;
    final end = (start + _nPageSize).clamp(0, items.length);
    final w = MediaQuery.sizeOf(context).width;
    final hPad = w <= 576 ? 12.0 : 16.0;

    // Same shared header (height, logo, date/time, wifi/offline toggle,
    // notification bell, profile menu, ...) every other screen uses.
    return AppScaffold(
      backgroundColor: _nBg,
      title: 'Notifications',
      onRefresh:
          () => ref.read(NotificationsViewModel.provider.notifier).fetch(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _NotificationsHero(),
          Center(
            child: ConstrainedBox(
              // CSS ref: `.notif-page-container` — max-width 820px,
              // centered, padding 0 16px (0 12px on ≤576). The 30px (20px
              // ≤576) top padding is the hero's `margin-bottom`.
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  w <= 576 ? 20 : 30,
                  hPad,
                  24,
                ),
                child:
                    state.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: CircularProgressIndicator(color: _nPurple),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _StatsBar(state: state, ref: ref),
                              const SizedBox(height: 24),
                              if (items.isEmpty)
                                const _EmptyState()
                              else ...[
                                for (var i = start; i < end; i++)
                                  _NotifCard(item: items[i], ref: ref),
                                // Cards each carry a 10px bottom margin
                                // (the web's 10px list gap), so the pager
                                // gets 20 here to honour
                                // `.notif-pagination-wrap`'s margin-top 30.
                                if (items.length > _nPageSize) ...[
                                  const SizedBox(height: 20),
                                  PaginationWidget(
                                    page: page,
                                    pages: pages,
                                    onPage: (p) => setState(() => _page = p),
                                  ),
                                ],
                              ],
                            ],
                          ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const AppFooter(),
        ],
      ),
    );
  }
}

// ── Page hero ─────────────────────────────────────────────────────────────────

// CSS ref (notification/index.php): .notif-page-hero — full-bleed,
// linear-gradient over the theme purple, padding 36px 24px 40px (28px
// 16px 32px ≤576); h1 26px/800 white (22px ≤576), letter-spacing -0.5px;
// p 15px rgba(255,255,255,.8) (13px ≤576); `::after` — a 24px page-bg
// band with 24px rounded top corners sitting on the hero's bottom edge
// (the inward curve). Gradient colors follow the user's purge-blue
// override: `#5c52d4→#7c73e6` becomes the app's `heroGradient`
// (#693D94 → #AA399F).
class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero();

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width <= 576;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 16 : 24,
        isNarrow ? 28 : 36,
        isNarrow ? 16 : 24,
        isNarrow ? 32 : 40,
      ),
      decoration: const BoxDecoration(gradient: FigmaTokens.heroGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: isNarrow ? 22 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stay updated with your latest activities',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: isNarrow ? 13 : 15,
              fontWeight: FontWeight.w400,
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
    final isNarrow = MediaQuery.sizeOf(context).width <= 576;
    // CSS ref: .notif-stats-bar — radius 16px, padding 16px 20px (12px
    // 16px on ≤576), border 1px #F3F4F6, shadow 0 1px 3px
    // rgba(0,0,0,.02), margin-bottom 24px. On ≤576 the bar stacks: the
    // pills row spreads space-between and the mark-all button drops to a
    // flex-end row below.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : 20,
        vertical: isNarrow ? 12 : 16,
      ),
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
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _UnreadBadge(count: state.unreadCount),
                    const Spacer(),
                    _TotalBadge(count: state.notifications.length),
                  ],
                ),
                if (state.unreadCount > 0) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _MarkAllButton(ref: ref),
                  ),
                ],
              ],
            )
          : Row(
              children: [
                _UnreadBadge(count: state.unreadCount),
                const SizedBox(width: 16),
                _TotalBadge(count: state.notifications.length),
                const Spacer(),
                // CSS ref: the "Mark all read" link only renders when
                // $unreadCount > 0.
                if (state.unreadCount > 0) _MarkAllButton(ref: ref),
              ],
            ),
    );
  }
}

// CSS ref: .notif-stat-badge — 13px/600, padding 6px 14px, radius 20px,
// `i` icon 12px. `.unread-badge` bg #F5F3FF + primary; `.total-badge` bg
// #F3F4F6 + #6B7280.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _nPurple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count Unread',
            style: const TextStyle(
              color: _nPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_outlined,
            size: 12,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Text(
            '$count Total',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// CSS ref: .notif-mark-all-btn — 13px/600 primary, padding 8px 16px,
// radius 10px, bg #F5F3FF; hover bg rgba(92,82,212,.15) + #4A41AD.
class _MarkAllButton extends StatefulWidget {
  const _MarkAllButton({required this.ref});
  final WidgetRef ref;

  @override
  State<_MarkAllButton> createState() => _MarkAllButtonState();
}

class _MarkAllButtonState extends State<_MarkAllButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () =>
            widget.ref
                .read(NotificationsViewModel.provider.notifier)
                .markAllAsRead(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                _hover ? _nPurple.withValues(alpha: 0.15) : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all_rounded, size: 14, color: _nPurple),
              const SizedBox(width: 6),
              Text(
                'Mark all read',
                style: TextStyle(
                  color: _hover ? _nPurpleHover : _nPurple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notification card ─────────────────────────────────────────────────────────

class _NotifCard extends StatefulWidget {
  const _NotifCard({required this.item, required this.ref});
  final NotificationItem item;
  final WidgetRef ref;

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard> {
  bool _hover = false;

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inMinutes >= 1) return '${diff.inMinutes} min ago';
    return 'just now';
  }

  Future<void> _open() async {
    final item = widget.item;
    final error = await widget.ref
        .read(NotificationsViewModel.provider.notifier)
        .markOneAsRead(item.id);
    if (!mounted) return;
    if (error != null) {
      Toast.error(context, error);
      return;
    }
    final url = item.redirectUrl;
    if (url == null || url.isEmpty) return;
    if (!readIsOnline(widget.ref)) {
      Toast.info(context, 'Internet required to open this link.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      InAppWebViewPage.showWithAuth(
        context,
        widget.ref,
        url: url,
        title: 'Course Details',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isNarrow = MediaQuery.sizeOf(context).width <= 576;
    final borderColor =
        _hover ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6);
    // CSS ref: .notif-card — radius 16px (12px ≤576), padding 20px (16px),
    // border 1px #F3F4F6, shadow 0 1px 3px rgba(0,0,0,.02); hover →
    // translateY(-2px), shadow 0 8px 20px rgba(0,0,0,.06), border #E5E7EB.
    // .unread — left 4px (3px ≤576) indigo, bg #FAFAFF; on hover its left
    // border stays indigo (`.notif-card.unread` beats `:hover`).
    // Hover wrapper: AnimatedScale gives the visual "lift" without the
    // AnimatedContainer transform that caused invisible children on web.
    // Flutter does not allow borderRadius when Border sides differ in
    // color/width.  Workaround: uniform border + ClipRRect for the
    // rounded corners, then a Positioned left-bar for unread items.
    final radius = isNarrow ? 12.0 : 16.0;
    final leftBarW = isNarrow ? 3.0 : 4.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              children: [
                // Main card body – uniform border so borderRadius works.
                Container(
                  decoration: BoxDecoration(
                    color: item.isRead ? Colors.white : const Color(0xFFFAFAFF),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: _hover ? 0.06 : 0.02,
                        ),
                        blurRadius: _hover ? 20 : 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: _open,
                    child: Padding(
                      padding: EdgeInsets.all(isNarrow ? 16 : 20),
                      child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isNarrow ? 38 : 44,
                    height: isNarrow ? 38 : 44,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: item.isRead
                          ? const Color(0xFFF5F3FF)
                          : _nPurple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications_rounded,
                      color: _nPurple,
                      size: isNarrow ? 15 : 18,
                    ),
                  ),
                  SizedBox(width: isNarrow ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isNarrow ? 14 : 15,
                            color: const Color(0xFF111827),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style: TextStyle(
                            fontSize: isNarrow ? 13 : 14,
                            color: const Color(0xFF6B7280),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                  _NotifCardActions(item: item, ref: widget.ref),
                ],
                      ),
                    ),
                  ),
                ),
                // Unread left-bar indicator (mimics the CSS thick left
                // border on `.notif-card.unread`).
                if (!item.isRead)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: leftBarW,
                      decoration: BoxDecoration(
                        color: _nPurple,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(radius),
                          bottomLeft: Radius.circular(radius),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// CSS ref: the unread dot is `.notif-card.unread::before` — 8x8, primary,
// absolutely positioned top:20/right:20 relative to the card; the
// three-dot MenuButton maps to the card's Bootstrap dropdown (Mark
// Read/Mark Unread + Delete). Full page only — the bell dropdown has
// neither.
class _NotifCardActions extends StatelessWidget {
  const _NotifCardActions({required this.item, required this.ref});
  final NotificationItem item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
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
        const SizedBox(height: 10),
        // CSS/markup ref: the real dropdown's `.notif-toggle-read` item
        // always shows, flipping between "Mark Read"/"Mark Unread" (POST
        // `toggle-read`). FLAGGED, NOT IMPLEMENTED: this app's REST API
        // only exposes a one-way `/{id}/read` endpoint — no unread
        // endpoint to call — so the item still can't be un-hidden once
        // read without a backend addition; same category as the Completed
        // Courses "points" gap. `.dropdown-item` text color #374151; the
        // delete item is `.text-danger` — red.
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
              if (context.mounted && error != null) {
                Toast.error(context, error);
              }
            } else if (value == 'delete') {
              final error = await notifier.deleteOne(item.id);
              if (context.mounted && error != null) {
                Toast.error(context, error);
              }
            }
          },
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // CSS ref: .notif-empty-card — padding 60px 20px, border 1px #F3F4F6,
    // radius 16px, centered. `empty-icon` 48px #22C55E check (was a purple
    // bell-off); h4 18px/600/#111827 "You're all caught up!"; p 14px/
    // #6B7280 "No new notifications to show".
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
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