import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/dashboard/model/redeem_history_item.dart';
import 'package:lms/app/features/dashboard/viewmodel/redeem_history_view_model.dart';

// CSS ref, confirmed against `origin/staging`'s dist/app.css.
const _rhPurple = FigmaTokens.primaryPurple; // var(--primary-first) #693D94
// .redeem-title h2 color — var(--primary-second)
const _rhMagenta = Color(0xFFA20067);
// .redeem-title p color
const _rhTitleGray = Color(0xFF484848);
// .redeem-history a color
const _rhHistoryGray = Color(0xFF979797);
const _rhCardBg = Color(0xFFF3F3F3);
const _rhCardBorder = Color(0xFF979797);
// .redeem-block border
const _rhBlockBorder = Color(0xFFE7E4FF);
const _rhInk = FigmaTokens.cardTitles;
const _rhMuted = FigmaTokens.noteBodyText;
const _rhBg = FigmaTokens.pageBackground;

/// CSS ref, confirmed against `origin/staging`'s item-inventory/
/// redeem-history-user.php: each item is `col-lg-3 col-md-6 col-sm-12
/// col-12` — 4 per row at ≥992px, 2 per row at 768-991px, 1 per row below
/// that — not the shared `Responsive` helper's generic 700/1024
/// thresholds (which this screen was wrongly using: phone:2/tablet:4/
/// desktop:5).
int _redeemHistoryColumnsFor(double width) {
  if (width >= 992) return 4;
  if (width >= 768) return 2;
  return 1;
}

class RedeemHistoryPage extends ConsumerWidget {
  const RedeemHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(RedeemHistoryViewModel.provider);

    return AppScaffold(
      backgroundColor: _rhBg,
      onRefresh:
          () => ref.read(RedeemHistoryViewModel.provider.notifier).fetch(),
      body: switch (state.state) {
        DataProviderState.idle || DataProviderState.loading => const Center(
          child: CircularProgressIndicator(color: _rhPurple),
        ),
        DataProviderState.error => _ErrorView(
          message: friendlyErrorMessage(
            state.error,
            'Unable to load your redeem history.',
          ),
          onRetry:
              () => ref.read(RedeemHistoryViewModel.provider.notifier).fetch(),
        ),
        DataProviderState.data =>
          state.data == null
              ? const _ErrorView(message: 'No redeem history found.')
              : _Body(result: state.data!),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.result});
  final RedeemHistoryResult result;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // CSS ref: `.redeem-block` base padding 20px; at max-width:640px it
    // drops to 5px and its margin to `20px 0 10px` (base `30px 0 10px`).
    final isCompact = width <= 640;
    final blockPad = isCompact ? 5.0 : 20.0;
    final blockTopMargin = isCompact ? 20.0 : 30.0;
    final cols = _redeemHistoryColumnsFor(width);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          // CSS ref: `.container` wraps `.redeem-block`; match the app's
          // shared desktop gutter so the block doesn't touch the screen
          // edges (Item Inventory uses the same 12–16px outer padding).
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width <= 576 ? 8 : (width <= 768 ? 12 : 16),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _rhBlockBorder),
              ),
              padding: EdgeInsets.all(blockPad),
              margin: EdgeInsets.only(top: blockTopMargin, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TitleRow(
                    isCompact: isCompact,
                    onRedeemPoints: () => safePop(context),
                  ),
                  if (result.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: _EmptyState(),
                    )
                  else
                    _AutoHeightGrid(
                      items: result.items,
                      cols: cols,
                      isCompact: isCompact,
                      // .content-block2 padding drop 12→7px applies at
                      // ≤991.98px, i.e. any width below the 992×4-col
                      // breakpoint.
                      reduceContentPad: width < 992,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }
}

/// CSS ref: `.redeem-title` — flex row. Left: `h2 "Redeemed items"`
/// (24px/28, 400, var(--primary-second)) over `p "Items redeemed by you"`
/// (16px/20, #484848). Right: `.redeem-history a "Redeem Points"`
/// (24px/28 underlined #979797). At max-width:640px the container becomes
/// `display:block`, the h2 drops to 22px/24 and the link to 20px/24, and
/// `.redeem-history` gets `margin: 20px 0 0 auto`.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.isCompact, required this.onRedeemPoints});
  final bool isCompact;
  final VoidCallback onRedeemPoints;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Redeemed items',
      style: TextStyle(
        color: _rhMagenta,
        fontSize: isCompact ? 22 : 24,
        fontWeight: FontWeight.w400,
        height: isCompact ? 24 / 22 : 28 / 24,
      ),
    );
    final subtitle = const Text(
      'Items redeemed by you',
      style: TextStyle(color: _rhTitleGray, fontSize: 16, height: 20 / 16),
    );
    final link = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onRedeemPoints,
        child: Text(
          'Redeem Points',
          style: TextStyle(
            color: _rhHistoryGray,
            fontSize: isCompact ? 20 : 24,
            height: isCompact ? 24 / 20 : 28 / 24,
            decoration: TextDecoration.underline,
            decorationColor: _rhHistoryGray,
          ),
        ),
      ),
    );

    if (isCompact) {
      // max-width:640px — .redeem-title is display:block; title stacks and
      // the link sits below it with a 20px top margin.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 2),
          subtitle,
          const SizedBox(height: 20),
          link,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30), // .redeem-title h2 margin-top
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 4), subtitle],
              ),
            ),
            // .redeem-history — margin: 30px 0 0 auto
            Padding(
              padding: const EdgeInsets.only(top: 30, left: 16),
              child: link,
            ),
          ],
        ),
      ],
    );
  }
}

/// Reproduces the web's auto-height grid rows: each row is a Bootstrap
/// `.col-*` gutter (15px each side ⇒ 30px between cards) and every card is
/// only as tall as its own image-area + content (no fixed aspect ratio),
/// exactly like `.point-card` in `redeem-history-user.php`.
class _AutoHeightGrid extends StatelessWidget {
  const _AutoHeightGrid({
    required this.items,
    required this.cols,
    required this.isCompact,
    required this.reduceContentPad,
  });
  final List<RedeemHistoryItem> items;
  final int cols;
  final bool isCompact;
  final bool reduceContentPad;

  @override
  Widget build(BuildContext context) {
    final rows = <List<RedeemHistoryItem>>[];
    for (var i = 0; i < items.length; i += cols) {
      rows.add(
        items.sublist(i, i + cols > items.length ? items.length : i + cols),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bootstrap vertical rhythm: each `.col` pads 15px top/bottom and
        // `.point-card` adds `margin: 10px 0`, so the first row's cards
        // start (15+10)=25px below the title and consecutive rows are
        // 15+10+10+15 = 50px apart.
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 25.0 : 50.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) const SizedBox(width: 30), // col gutter
                  Expanded(
                    child: _RedeemedItemCard(
                      item: rows[r][c],
                      isCompact: isCompact,
                      reduceContentPad: reduceContentPad,
                    ),
                  ),
                ],
                // Fill the remaining cells with empty flex boxes so a
                // partial last row doesn't stretch cards to equal height.
                for (var e = rows[r].length; e < cols; e++)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _RedeemedItemCard extends StatelessWidget {
  const _RedeemedItemCard({
    required this.item,
    required this.isCompact,
    required this.reduceContentPad,
  });
  final RedeemHistoryItem item;
  final bool isCompact;
  final bool reduceContentPad;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s dist/app.css:
    // `.point-card` — this screen uses an older, distinct card style
    // (light gray bg, near-square corners) from the "modern" cards used
    // on My Courses/Item Inventory — bg #F3F3F3, border 1px solid
    // #979797, radius 3px, margin 10px 0.
    return Container(
      decoration: BoxDecoration(
        color: _rhCardBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _rhCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemImage(imageUrl: item.image),
          // CSS ref: .point-card-content — flex row, bg var(--primary-
          // first) i.e. the app's usual purple, padding 15px.
          Container(
            padding: const EdgeInsets.all(15),
            color: _rhPurple,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CSS ref: .content-block1 h2 — 20px/weight400/lh20
                // (18px at max-width:640px), white, 2-line clamp,
                // margin-bottom 15, padding-right 10.
                // "View" — plain white text, no pill (border/fill/shadow
                // all removed per a live screenshot of the real site) and
                // no underline either, per explicit follow-up request.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 18 : 20,
                          fontWeight: FontWeight.w400,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 15),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _showDetail(context, item),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 18 / 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // CSS ref: .content-block2 — border-left 1px solid white,
                // padding 12px 0 0 8px (→ 7px 0 0 8px at max-width:
                // 991.98px), centered; h1 (number) 28px/700/lh27 white
                // (→ 22px/24 at ≤640), h2 ("Points") 22px/400/lh27 white
                // (→ 18px/24 at ≤640).
                Container(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    reduceContentPad ? 7 : 12,
                    0,
                    0,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${item.pointsSpent}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 22 : 28,
                          fontWeight: FontWeight.w700,
                          height: isCompact ? 24 / 22 : 27 / 28,
                        ),
                      ),
                      Text(
                        'Points',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isCompact ? 18 : 22,
                          fontWeight: FontWeight.w400,
                          height: isCompact ? 24 / 18 : 27 / 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, RedeemHistoryItem item) {
    showDialog(
      context: context,
      builder: (_) => _RedeemedItemDetailDialog(item: item),
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.emoji_events_outlined,
        color: _rhPurple,
        size: 40,
      ),
    );
    if (imageUrl == null) return fallback;
    // CSS ref: `.point-card-img` — centered, `min-height: 175px`,
    // `margin: 10px auto`; the `<img>` is `max-height: 175px` (img-fluid).
    // A min-height 175 area with BoxFit.contain keeps the image capped at
    // 175h and centered — and the same widget stays safe inside the
    // modal's fixed 90×90 box (tight parent constraints clamp the floor).
    return Container(
      constraints: const BoxConstraints(minHeight: 175),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 175),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder:
              (context, child, progress) =>
                  progress == null
                      ? child
                      : Container(
                        color: const Color(0xFFF0ECFF),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _rhPurple,
                        ),
                      ),
        ),
      ),
    );
  }
}

class _RedeemedItemDetailDialog extends StatelessWidget {
  const _RedeemedItemDetailDialog({required this.item});
  final RedeemHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Redeemed Item',
                    style: TextStyle(
                      color: _rhInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _rhMuted,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: _ItemImage(imageUrl: item.image),
                  ),
                ),
                const SizedBox(width: 16),
                // CSS/markup ref, confirmed against `origin/staging`'s
                // redeem-history-user.php's `#view-item` modal table: the
                // real field set is exactly Name of the Item / Group /
                // Managed by / Points required / Description — the API
                // does also send `address`/`note`/`redeemed_at` (for a
                // future use, or an admin-side view), but the real
                // learner-facing modal never displays them. Was showing
                // "Name:"/"Points spent:" (wrong labels) plus three
                // fields ("Redeemed on:"/"Address:"/"Note:") absent from
                // the real modal entirely.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        label: 'Name of the Item:',
                        value: item.itemName,
                      ),
                      if (item.managedBy != null)
                        _DetailRow(
                          label: 'Managed by:',
                          value: item.managedBy!,
                        ),
                      _DetailRow(
                        label: 'Points required:',
                        value: '${item.pointsSpent}',
                      ),
                      if ((item.description ?? '').isNotEmpty)
                        _DetailRow(
                          label: 'Description:',
                          value: item.description!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FigmaTokens.cardBorders),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: _rhMuted,
                    fontWeight: FontWeight.w600,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: _rhInk,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: _rhMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: _rhPurple,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Redeemed Items Yet',
              style: TextStyle(
                color: _rhInk,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Items you redeem with your points will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _rhMuted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _rhMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _rhMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(onRetry: onRetry!, errorMessage: message),
            ],
          ],
        ),
      ),
    );
  }
}
