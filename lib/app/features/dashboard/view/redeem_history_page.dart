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

const _rhPurple = FigmaTokens.primaryPurple;
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
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Redeemed items',
                  style: TextStyle(
                    color: _rhPurple,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Items redeemed by you',
                  style: TextStyle(color: _rhMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => safePop(context),
                    child: const Text(
                      'Redeem Points',
                      style: TextStyle(
                        color: _rhPurple,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: _rhPurple,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (result.items.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _RedeemedItemCard(item: result.items[index]),
                childCount: result.items.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _redeemHistoryColumnsFor(
                  MediaQuery.sizeOf(context).width,
                ),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                // The real page has no fixed card aspect ratio at all
                // (auto height) — loosened from 0.85 to give the now-
                // taller purple content block (20px 2-line name + 28px/
                // 22px points block) room without squeezing the image
                // area to nothing.
                childAspectRatio: 0.62,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }
}

class _RedeemedItemCard extends StatelessWidget {
  const _RedeemedItemCard({required this.item});
  final RedeemHistoryItem item;

  @override
  Widget build(BuildContext context) {
    // CSS ref, confirmed against `origin/staging`'s dist/app.css:
    // `.point-card` — this screen uses an older, distinct card style
    // (light gray bg, near-square corners) from the "modern" cards used
    // on My Courses/Item Inventory — bg #F3F3F3, border 1px solid
    // #979797, radius 3px. Was wrongly built as a white/shadowed/radius-14
    // "modern" card.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF979797)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CSS ref: .point-card-img — centered, min-height 175px.
          Expanded(child: _ItemImage(imageUrl: item.image)),
          // CSS ref: .point-card-content — flex row, bg var(--primary-
          // first) i.e. the app's usual purple, padding 15px.
          Container(
            padding: const EdgeInsets.all(15),
            color: _rhPurple,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CSS ref: .content-block1 h2 — 20px/weight400/lh20,
                // white, 2-line clamp, margin-bottom 15.
                // .contentblock-action a ("View") — 15px, white.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // CSS ref: .content-block2 — border-left 1px solid white,
                // padding 12px 0 0 8px, centered; h1 (number) 28px/700/
                // lh27 white; h2 ("Points") 22px/400/lh27 white.
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 27 / 28,
                        ),
                      ),
                      const Text(
                        'Points',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w400,
                          height: 27 / 22,
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
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
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
