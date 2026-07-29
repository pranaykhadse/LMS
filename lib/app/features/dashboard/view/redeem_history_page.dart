import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/features/dashboard/model/redeem_history_item.dart';
import 'package:lms/app/features/dashboard/viewmodel/redeem_history_view_model.dart';

const _rhPurple = Color(0xFF5756C9);
const _rhInk = Color(0xFF172033);
const _rhMuted = Color(0xFF7C879D);
const _rhBg = Color(0xFFF5F7FC);

class RedeemHistoryPage extends ConsumerWidget {
  const RedeemHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(RedeemHistoryViewModel.provider);

    return AppScaffold(
      backgroundColor: _rhBg,
      body: switch (state.state) {
        DataProviderState.idle ||
        DataProviderState.loading =>
          const Center(child: CircularProgressIndicator(color: _rhPurple)),
        DataProviderState.error => _ErrorView(
            message: state.error ?? 'Unable to load your redeem history.',
            onRetry: () =>
                ref.read(RedeemHistoryViewModel.provider.notifier).fetch(),
          ),
        DataProviderState.data => state.data == null
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
                  style: TextStyle(color: _rhPurple, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Items redeemed by you',
                  style: TextStyle(color: _rhMuted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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
                (context, index) => _RedeemedItemCard(item: result.items[index]),
                childCount: result.items.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Responsive.columns(
                  context,
                  phone: 2,
                  tablet: 4,
                  desktop: 5,
                ),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.85,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ItemImage(imageUrl: item.image)),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: _rhPurple,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: () => _showDetail(context, item),
                        child: const Text(
                          'View',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.pointsSpent}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'Points',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, RedeemHistoryItem item) {
    showDialog(context: context, builder: (_) => _RedeemedItemDetailDialog(item: item));
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
      child: const Icon(Icons.emoji_events_outlined, color: _rhPurple, size: 40),
    );
    if (imageUrl == null) return fallback;
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: const Color(0xFFF0ECFF),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2, color: _rhPurple),
            ),
    );
  }
}

class _RedeemedItemDetailDialog extends StatelessWidget {
  const _RedeemedItemDetailDialog({required this.item});
  final RedeemHistoryItem item;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

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
                    style: TextStyle(color: _rhInk, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _rhMuted, size: 20),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(label: 'Name:', value: item.itemName),
                      if (item.managedBy != null) _DetailRow(label: 'Managed by:', value: item.managedBy!),
                      _DetailRow(label: 'Points spent:', value: '${item.pointsSpent}'),
                      if (item.redeemedAt != null)
                        _DetailRow(label: 'Redeemed on:', value: _formatDate(item.redeemedAt)),
                      if (item.address != null) _DetailRow(label: 'Address:', value: item.address!),
                      if (item.note != null) _DetailRow(label: 'Note:', value: item.note!),
                      if ((item.description ?? '').isNotEmpty)
                        _DetailRow(label: 'Description:', value: item.description!),
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
                  side: const BorderSide(color: Color(0xFFD0CFE8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                ),
                child: const Text('Close', style: TextStyle(color: _rhMuted, fontWeight: FontWeight.w600)),
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
              style: const TextStyle(color: _rhInk, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: _rhMuted, fontSize: 13, height: 1.4),
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
              child: const Icon(Icons.history_rounded, color: _rhPurple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Redeemed Items Yet',
              style: TextStyle(color: _rhInk, fontSize: 20, fontWeight: FontWeight.w900),
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
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _rhMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              RetryButton(
                onRetry: onRetry!,
                style: ElevatedButton.styleFrom(backgroundColor: _rhPurple),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
