import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';
import 'package:lms/app/features/dashboard/view/redeem_history_page.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart'
    show isEffectivelyOffline;
import 'package:lms/app/features/dashboard/viewmodel/item_inventory_view_model.dart';

const _purple = Color(0xFF5756C9);
const _ink = Color(0xFF172033);
const _muted = Color(0xFF7C879D);
const _bg = Color(0xFFF5F7FC);

class ItemInventoryPage extends ConsumerStatefulWidget {
  const ItemInventoryPage({super.key});

  @override
  ConsumerState<ItemInventoryPage> createState() => _ItemInventoryPageState();
}

class _ItemInventoryPageState extends ConsumerState<ItemInventoryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ItemInventoryViewModel.provider);
    final notifier = ref.read(ItemInventoryViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Redeem your Points',
      selectedSubLabel: 'Redeem your Points',
      body: _Body(
        state: state,
        onRetry: notifier.fetch,
        notifier: notifier,
        searchController: _searchController,
        onSearch: () => notifier.search(_searchController.text),
        onClearSearch: () {
          _searchController.clear();
          notifier.clearSearch();
        },
        onPageChanged: (page) => _goToPage(context, notifier, page),
      ),
    );
  }

  void _goToPage(BuildContext context, ItemInventoryViewModel notifier, int page) {
    notifier.goToPage(page).then((error) {
      if (error != null && context.mounted) Toast.error(context, error);
    });
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({
    required this.state,
    required this.onRetry,
    required this.notifier,
    required this.searchController,
    required this.onSearch,
    required this.onClearSearch,
    required this.onPageChanged,
  });
  final ItemInventoryState state;
  final VoidCallback onRetry;
  final ItemInventoryViewModel notifier;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onPageChanged;

  static const _perPage = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.result == null) {
      if (state.providerState == DataProviderState.error) {
        return _ErrorView(message: state.error ?? 'Unable to load inventory.', onRetry: onRetry);
      }
      return const Center(child: CircularProgressIndicator(color: _purple));
    }
    final result = state.result!;
    final items = result.items;
    return _buildList(context, ref, items);
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<InventoryItem> items) {
    final result = state.result!;
    // Search/clear-search both hit the live API with no offline fallback -
    // offering them while there's no real connection just invites a tap
    // that can only fail, the same reasoning as RetryButton.
    final offline = isEffectivelyOffline(ref);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PointsBanner(points: result.userPoints)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Items available to redeem with your points',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RedeemHistoryPage()),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Redeem History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        enabled: !offline,
                        onSubmitted: (_) => onSearch(),
                        decoration: InputDecoration(
                          hintText: offline ? "You're offline" : 'Search items...',
                          hintStyle: const TextStyle(color: _muted, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE3E7EF)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE3E7EF)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: offline ? null : onSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
                if (state.query.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ResetButton(onTap: offline ? null : onClearSearch),
                ],
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            child: state.query.isNotEmpty
                ? const _NoSearchResults()
                : const _EmptyState(),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ItemCard(
                  item: items[index],
                  isRedeeming: state.redeemingId == items[index].id,
                  onRedeem: () => _showRedeemDialog(context, items[index], notifier),
                  onView: () => _showDetail(context, items[index]),
                ),
                childCount: items.length,
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
                childAspectRatio: 0.72,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: PerPageBadge(perPage: _perPage),
            ),
          ),
          SliverToBoxAdapter(
            child: PaginationWidget(
              page: state.page,
              pages: state.totalPages,
              onPage: onPageChanged,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }

  void _showDetail(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (_) => _ItemDetailDialog(item: item),
    );
  }

  void _showRedeemDialog(
    BuildContext context,
    InventoryItem item,
    ItemInventoryViewModel notifier,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => _RedeemDialog(
        item: item,
        onConfirm: (address, note) async {
          final result = await notifier.redeem(
            item.id,
            address: address,
            note: note.isNotEmpty ? note : null,
          );
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          if (!context.mounted) return;
          if (result.success) {
            Toast.success(context, result.message ?? 'Item redeemed successfully.');
          } else {
            Toast.error(context, result.message ?? 'Failed to redeem. Please try again.');
          }
        },
      ),
    );
  }
}

// ─── Reset button ───────────────────────────────────────────────────────────

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: onTap == null ? _muted.withValues(alpha: 0.4) : _purple,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.undo_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
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
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isOnline = watchIsOnline(ref);
                      return ElevatedButton(
                        onPressed: item.canRedeem &&
                                !item.isRedeemed &&
                                !isRedeeming &&
                                isOnline
                            ? onRedeem
                            : null,
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
                                item.isRedeemed
                                    ? 'Redeemed'
                                    : (!isOnline && item.canRedeem
                                        ? 'Offline'
                                        : 'Redeem'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      );
                    },
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

// ─── Item detail dialog ───────────────────────────────────────────────────────

class _ItemDetailDialog extends StatelessWidget {
  const _ItemDetailDialog({required this.item});
  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Item Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: -6,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: item.image != null
                    ? Image.network(
                        item.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _DialogImageFallback(),
                      )
                    : const _DialogImageFallback(),
              ),
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Name:', value: item.name),
            if (item.groupName != null)
              _DetailRow(label: 'Group:', value: item.groupName!),
            if (item.managedBy != null)
              _DetailRow(label: 'Managed by:', value: item.managedBy!),
            _DetailRow(label: 'Points required:', value: '${item.points}'),
            if (item.description.isNotEmpty)
              _DetailRow(label: 'Description:', value: item.description),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD0CFE8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _DialogImageFallback extends StatelessWidget {
  const _DialogImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0ECFF),
      alignment: Alignment.center,
      child: const Icon(Icons.redeem_outlined, color: _purple, size: 56),
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
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Redeem dialog ────────────────────────────────────────────────────────────

class _RedeemDialog extends StatefulWidget {
  const _RedeemDialog({required this.item, required this.onConfirm});
  final InventoryItem item;
  final Future<void> Function(String address, String note) onConfirm;

  @override
  State<_RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<_RedeemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter details and confirm to redeem',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Address *',
                style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 3,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Address is required' : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0CFE8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0CFE8)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Note',
                style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0CFE8)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0CFE8)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _submitting = true);
                          await widget.onConfirm(
                            _addressCtrl.text.trim(),
                            _noteCtrl.text.trim(),
                          );
                          if (mounted) setState(() => _submitting = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: _purple.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Text(
          'No items match your search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 14),
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
              RetryButton(
                onRetry: onRetry!,
                style: ElevatedButton.styleFrom(backgroundColor: _purple),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

