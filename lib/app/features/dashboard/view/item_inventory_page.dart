import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';
import 'package:lms/app/features/dashboard/view/app_drawer.dart';
import 'package:lms/app/features/dashboard/viewmodel/item_inventory_view_model.dart';

const _purple = Color(0xFF5756C9);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);
const _bg = Color(0xFFF5F7FC);

class ItemInventoryPage extends ConsumerWidget {
  const ItemInventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ItemInventoryViewModel.provider);
    final notifier = ref.read(ItemInventoryViewModel.provider.notifier);

    return Scaffold(
      backgroundColor: _bg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 106,
        leading: Builder(
          builder: (ctx) => Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AppBarBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  _AppBarBtn(
                    icon: Icons.menu_rounded,
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: const Text(
          'Redeem your Points',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: _Body(state: state, onRetry: notifier.fetch, notifier: notifier),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.onRetry,
    required this.notifier,
  });
  final ItemInventoryState state;
  final VoidCallback onRetry;
  final ItemInventoryViewModel notifier;

  @override
  Widget build(BuildContext context) {
    if (state.providerState == DataProviderState.loading ||
        state.providerState == DataProviderState.idle) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    if (state.providerState == DataProviderState.error) {
      return _ErrorView(message: state.error ?? 'Unable to load inventory.', onRetry: onRetry);
    }
    final result = state.result!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PointsBanner(points: result.userPoints)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Items available to redeem with your points',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ItemCard(
                  item: result.items[index],
                  isRedeeming: state.redeemingId == result.items[index].id,
                  onRedeem: () async {
                    final ok = await notifier.redeem(result.items[index].id);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to redeem. Please try again.')),
                      );
                    }
                  },
                  onView: () => _showDetail(context, result.items[index]),
                ),
                childCount: result.items.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 760 ? 4 : 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
            ),
          ),
      ],
    );
  }

  void _showDetail(BuildContext context, InventoryItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetailSheet(item: item),
    );
  }
}

// ─── Points banner ────────────────────────────────────────────────────────────

class _PointsBanner extends StatelessWidget {
  const _PointsBanner({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B5FD6), Color(0xFF4845B0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$points',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Available Points',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Item card ────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.isRedeeming,
    required this.onRedeem,
    required this.onView,
  });
  final InventoryItem item;
  final bool isRedeeming;
  final VoidCallback onRedeem;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ItemImage(imageUrl: item.image),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Text(
              '${item.points} pts',
              style: const TextStyle(
                color: _purple,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      side: const BorderSide(color: Color(0xFFD0CFE8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: item.canRedeem && !isRedeeming ? onRedeem : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB0AFD4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isRedeeming
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            item.isRedeemed ? 'Redeemed' : 'Redeem',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      child: const Icon(Icons.redeem_outlined, color: _purple, size: 48),
    );
    if (imageUrl == null) return fallback;
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null
              ? child
              : Container(
                  color: const Color(0xFFF0ECFF),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _purple,
                  ),
                ),
    );
  }
}

// ─── Detail bottom sheet ──────────────────────────────────────────────────────

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${item.points} pts',
                    style: const TextStyle(
                      color: _purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.description,
                style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(0, 46),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

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
              child: const Icon(Icons.redeem_outlined, color: _purple, size: 52),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Items Available',
              style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            const Text(
              'Redeemable items will appear here once available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

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
            const Icon(Icons.error_outline, color: _muted, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: _purple),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── AppBar button ────────────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  const _AppBarBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
