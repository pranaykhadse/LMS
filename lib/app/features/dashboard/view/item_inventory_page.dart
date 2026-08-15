import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/pagination_widget.dart';
import 'package:lms/app/core/views/elements/per_page_badge.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';
import 'package:lms/app/features/dashboard/view/redeem_history_page.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart'
    show isEffectivelyOffline;
import 'package:lms/app/features/dashboard/viewmodel/item_inventory_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;

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
      onRefresh: () => notifier.fetch(page: state.page, search: state.query),
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
        return _ErrorView(
            message: friendlyErrorMessage(state.error, 'Unable to load inventory.'),
            onRetry: onRetry);
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
        // ── White card: title + search + item grid, all in one box ──────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title row: folder icon + title + subtitle + Redeem History ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // folder icon
                      const Icon(Icons.folder_outlined, color: _purple, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inventory',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Items available to redeem with your points',
                              style: TextStyle(color: _muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Redeem History button
                      SizedBox(
                        height: 36,
                        child: HoverBuilder(
                          builder: (context, hovering) => ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RedeemHistoryPage()),
                            ),
                            icon: const Icon(Icons.history_rounded, size: 15),
                            label: const Text('Redeem History'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  hovering ? FigmaTokens.purpleHover : _purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Search bar with prefix icon ──
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          enabled: !offline,
                          onSubmitted: (_) => onSearch(),
                          decoration: InputDecoration(
                            hintText:
                                offline ? "You're offline" : 'Search items...',
                            hintStyle:
                                const TextStyle(color: _muted, fontSize: 14),
                            filled: true,
                            fillColor: Colors.white,
                            // prefix search icon
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: _muted, size: 20),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: FigmaTokens.cardBorders),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: FigmaTokens.cardBorders),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: HoverBuilder(
                          builder: (context, hovering) => ElevatedButton(
                            onPressed: offline ? null : onSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  hovering ? FigmaTokens.purpleHover : _purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child:
                                const Icon(Icons.search_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.query.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ResetButton(onTap: offline ? null : onClearSearch),
                  ],
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: state.query.isNotEmpty
                          ? const _NoSearchResults()
                          : const _EmptyState(),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ItemCard(
                        item: items[index],
                        isRedeeming: state.redeemingId == items[index].id,
                        onRedeem: () =>
                            _showRedeemDialog(context, items[index], notifier),
                        onView: () => _showDetail(context, items[index]),
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
                    const SizedBox(height: 8),
                    PerPageBadge(perPage: _perPage),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (items.isNotEmpty)
          SliverToBoxAdapter(
            child: PaginationWidget(
              page: state.page,
              pages: state.totalPages,
              onPage: onPageChanged,
            ),
          ),
        const SliverToBoxAdapter(child: _PointSystemExplainer()),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [FigmaTokens.primaryPurple, FigmaTokens.gradientEnd],
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
      ),
    );
  }
}

// ─── Point system explainer ───────────────────────────────────────────────────

const _explainerTitle = Color(0xFFB0006D);

class _PointSystemExplainer extends StatelessWidget {
  const _PointSystemExplainer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          child: Column(
            children: [
              const Text(
                'How does the point system work?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _explainerTitle,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  const height = 190.0;
                  // Fractional x-position and y-offset (0 = top, 1 = bottom)
                  // for each step, forming the zigzag "staircase" layout.
                  const steps = [
                    _Step(Icons.how_to_reg_rounded, 'Register for\na course', 0.10, 0.78),
                    _Step(Icons.school_outlined, 'Complete learning\nevents', 0.37, 0.78),
                    _Step(Icons.emoji_events_outlined, 'Earn Points', 0.64, 0.18),
                    _Step(Icons.redeem_outlined, 'Get rewards for\nyour points', 0.90, 0.78),
                  ];
                  final points = [
                    for (final s in steps) Offset(s.xFraction * width, s.yFraction * height)
                  ];
                  return SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _StepConnectorPainter(points)),
                        ),
                        for (var i = 0; i < steps.length; i++)
                          Positioned(
                            left: points[i].dx - 60,
                            top: points[i].dy - 28,
                            width: 120,
                            child: _StepBadge(
                              icon: steps[i].icon,
                              label: steps[i].label,
                              labelAbove: steps[i].yFraction < 0.5,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step {
  const _Step(this.icon, this.label, this.xFraction, this.yFraction);
  final IconData icon;
  final String label;
  final double xFraction;
  final double yFraction;
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.icon, required this.label, required this.labelAbove});
  final IconData icon;
  final String label;
  final bool labelAbove;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE4D9EF), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: _purple, size: 24),
    );
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: labelAbove
          ? [text, const SizedBox(height: 8), circle]
          : [circle, const SizedBox(height: 8), text],
    );
  }
}

/// Right-angle dashed connectors between consecutive step centers, matching
/// the staircase layout of the reference diagram.
class _StepConnectorPainter extends CustomPainter {
  _StepConnectorPainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD9CBEA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final corner = Offset(b.dx, a.dy);
      _drawDashedLine(canvas, paint, a, corner);
      _drawDashedLine(canvas, paint, corner, b);
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset a, Offset b) {
    const dashWidth = 5.0;
    const gapWidth = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final direction = (b - a) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segmentEnd = (drawn + dashWidth).clamp(0.0, total);
      canvas.drawLine(a + direction * drawn, a + direction * segmentEnd, paint);
      drawn += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _StepConnectorPainter oldDelegate) => oldDelegate.points != points;
}

/// Dashed rounded-rectangle border used around the explainer panel, since
/// Flutter has no built-in dashed BoxBorder.
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = FigmaTokens.cardBorders
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 5.0;
      const gapWidth = 4.0;
      while (distance < metric.length) {
        final segmentEnd = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, segmentEnd), paint);
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
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
          // ── Item name ──
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
          // ── Points chip (task 5) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${item.points} pts',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // ── View / Redeem buttons (task 4) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Row(
              children: [
                // View button — outlined with eye icon
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                      foregroundColor: _muted,
                      side: const BorderSide(color: FigmaTokens.cardBorders),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Redeem button — filled with redeem icon; disabled when redeemed
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isOnline = watchIsOnline(ref);
                      final canAct = item.canRedeem &&
                          !item.isRedeemed &&
                          !isRedeeming &&
                          isOnline;
                      return HoverBuilder(
                        builder: (context, hovering) => ElevatedButton.icon(
                          onPressed: canAct ? onRedeem : null,
                          icon: isRedeeming
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  item.isRedeemed
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.redeem_rounded,
                                  size: 14,
                                ),
                          label: Text(
                            item.isRedeemed
                                ? 'Redeemed'
                                : (!isOnline && item.canRedeem
                                    ? 'Offline'
                                    : 'Redeem'),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 32),
                            backgroundColor:
                                hovering ? FigmaTokens.purpleHover : _purple,
                            foregroundColor: Colors.white,
                            // greyed out when redeemed / offline / can't redeem
                            disabledBackgroundColor: const Color(0xFFB0AFD4),
                            disabledForegroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
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
                  side: const BorderSide(color: FigmaTokens.cardBorders),
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
                    borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FigmaTokens.cardBorders),
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
                    borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: FigmaTokens.cardBorders),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: HoverBuilder(
                  builder: (context, hovering) => ElevatedButton(
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
                      backgroundColor:
                          hovering ? FigmaTokens.purpleHover : _purple,
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
              RetryButton(onRetry: onRetry!, errorMessage: message),
            ],
          ],
        ),
      ),
    );
  }
}

