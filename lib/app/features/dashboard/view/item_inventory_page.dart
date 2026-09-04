import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/courses/view/lms_app_bar.dart'
    show watchIsOnline;
import 'package:lms/app/features/dashboard/model/inventory_item.dart';
import 'package:lms/app/features/dashboard/view/redeem_history_page.dart';
import 'package:lms/app/features/dashboard/view/widgets/offline_courses_section.dart'
    show isEffectivelyOffline;
import 'package:lms/app/features/dashboard/viewmodel/item_inventory_view_model.dart';

// ─── Staging exact tokens (backend/views/item-inventory/inventory.php <style> on staging) — overridden to brand #693D94 per request (was #5C52D4 / #6A60DC) ──
const _indigo = Color(0xFF693D94); // inventory primary — was #5C52D4
const _indigoDark = Color(0xFF5A3480);
const _indigoLight = Color(0xFF9A7AC0);
const _bodyBg = Color(0xFFF4F6FB); // staging body bg
const _cardBorder = Color(0xFFF3F4F6);
const _cardBorderHover = Color(0xFFE5E7EB);
const _borderInput = Color(0xFFD1D5DB);
const _textMain = Color(0xFF111827);
const _textSecondary = Color(0xFF6B7280);
const _textMuted = Color(0xFF9CA3AF);
const _badgeBg = Color(0xFFF5F3FF);
const _btnViewBg = Color(0xFFF3F4F6);
const _btnViewText = Color(0xFF374151);
const _fallbackBg = Color(0xFFF9FAFB);
const _modalBorder = Color(0xFFF3F4F6);

int _inventoryColumnsFor(double width) {
  if (width >= 992) return 4;
  if (width >= 576) return 2;
  return 1;
}

class ItemInventoryPage extends ConsumerStatefulWidget {
  const ItemInventoryPage({super.key});

  @override
  ConsumerState<ItemInventoryPage> createState() => _ItemInventoryPageState();
}

class _ItemInventoryPageState extends ConsumerState<ItemInventoryPage> {
  final _searchController = TextEditingController();

  void _handleSubmitted() {
    if (isEffectivelyOffline(ref)) return;
    ref
        .read(ItemInventoryViewModel.provider.notifier)
        .search(_searchController.text);
  }

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
      backgroundColor: _bodyBg,
      title: 'Redeem your Points',
      selectedSubLabel: 'Redeem your Points',
      onRefresh: () => notifier.fetch(page: state.page, search: state.query),
      body: _Body(
        state: state,
        onRetry: notifier.fetch,
        notifier: notifier,
        searchController: _searchController,
        onSearch: _handleSubmitted,
        onClearSearch: () {
          _searchController.clear();
          notifier.clearSearch();
        },
        onPageChanged: (page) => _goToPage(context, notifier, page),
      ),
    );
  }

  void _goToPage(
    BuildContext context,
    ItemInventoryViewModel notifier,
    int page,
  ) {
    notifier.goToPage(page).then((error) {
      if (error != null && context.mounted) Toast.error(context, error);
    });
  }
}

// ─── Body ───────────────────────────────────────────────────────────────────

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
          message: friendlyErrorMessage(
            state.error,
            'Unable to load inventory.',
          ),
          onRetry: onRetry,
        );
      }
      return const Center(child: CircularProgressIndicator(color: _indigo));
    }
    final result = state.result!;
    return _buildList(context, ref, result);
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    InventoryResult result,
  ) {
    final w = MediaQuery.sizeOf(context).width;
    // Staging container padding: <=576 => 8, <=768 => 12, desktop => 16 (gutter so cards don't touch screen edges)
    final isPhone = w <= 768;
    final isSmallPhone = w <= 576;
    final outerHPad = isSmallPhone ? 8.0 : (isPhone ? 12.0 : 16.0);
    // inventory-wrap padding: staging #inventory-wrap { padding: 0 } + container 0 12/8
    // We add top gap 12 on mobile via CustomScrollView padding
    final offline = isEffectivelyOffline(ref);
    final items = result.items;

    return CustomScrollView(
      slivers: [
        // Points card — staging #inventory-wrap .points-card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              outerHPad,
              isPhone ? 12 : 16,
              outerHPad,
              0,
            ),
            child: _PointsCard(
              points: result.userPoints,
              isPhone: isPhone,
              isSmallPhone: isSmallPhone,
            ),
          ),
        ),
        // Main inventory-card — staging .inventory-card
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              outerHPad,
              isPhone ? 12 : 24,
              outerHPad,
              isPhone ? 12 : 24,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                isSmallPhone ? 16 : (isPhone ? 20 : 32),
                isSmallPhone ? 12 : (isPhone ? 16 : 28),
                isSmallPhone ? 16 : (isPhone ? 20 : 32),
                isSmallPhone ? 12 : (isPhone ? 16 : 28),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isPhone ? 12 : 16),
                border: Border.all(color: _cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // inventory-header
                  _InventoryHeader(isPhone: isPhone),
                  const SizedBox(height: 20),
                  // search — both onSubmitted (Enter) immediate + onChanged debounced (400ms)
                  _SearchField(
                    controller: searchController,
                    offline: offline,
                    onSearch: onSearch,
                    isPhone: isPhone,
                    notifier: notifier,
                  ),
                  if (state.query.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ResetButton(onTap: offline ? null : onClearSearch),
                  ],
                  const SizedBox(height: 24),
                  if (items.isEmpty)
                    state.query.isNotEmpty
                        ? const _NoSearchResults()
                        : const _EmptyState()
                  else ...[
                    // inventory-grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = _inventoryColumnsFor(w);
                        // inventory-row margin -8 (-6 phone, -4 small)
                        final rowMargin =
                            isSmallPhone ? -4.0 : (isPhone ? -6.0 : -8.0);
                        final colPad =
                            isSmallPhone ? 4.0 : (isPhone ? 6.0 : 8.0);
                        return Padding(
                          padding: EdgeInsets.all(-rowMargin),
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: colPad * 2,
                                  crossAxisSpacing: colPad * 2,
                                  childAspectRatio: _cardAspectForWidth(w),
                                ),
                            itemBuilder:
                                (context, index) => Padding(
                                  padding: EdgeInsets.all(colPad),
                                  child: _ItemCard(
                                    item: items[index],
                                    isPhone: isPhone,
                                    isSmallPhone: isSmallPhone,
                                    isRedeeming:
                                        state.redeemingId == items[index].id,
                                    onRedeem:
                                        () => _showRedeemDialog(
                                          context,
                                          items[index],
                                          notifier,
                                        ),
                                    onView:
                                        () =>
                                            _showDetail(context, items[index]),
                                  ),
                                ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    // pagination-wrap
                    _WebPaginationRow(
                      page: state.page,
                      pages: state.totalPages,
                      onPage: onPageChanged,
                      isPhone: isPhone,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Second inventory-card with point-system explainer (staging inventory-card text-center img)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              outerHPad,
              0,
              outerHPad,
              isPhone ? 12 : 16,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                isSmallPhone ? 16 : (isPhone ? 20 : 32),
                isSmallPhone ? 12 : (isPhone ? 16 : 28),
                isSmallPhone ? 16 : (isPhone ? 20 : 32),
                isSmallPhone ? 12 : (isPhone ? 16 : 28),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isPhone ? 12 : 16),
                border: Border.all(color: _cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const _PointSystemExplainer(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: AppFooter()),
      ],
    );
  }

  double _cardAspectForWidth(double w) {
    // Web 363.5×338.2 → 1.075, but Flutter text metrics add ~5px → use 1.02 to give 5px breathing room
    if (w >= 992) return 1.02;
    if (w >= 576) return 1.28;
    return 1.45;
  }

  void _showDetail(BuildContext context, InventoryItem item) {
    showDialog(context: context, builder: (_) => _ItemDetailDialog(item: item));
  }

  void _showRedeemDialog(
    BuildContext context,
    InventoryItem item,
    ItemInventoryViewModel notifier,
  ) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => _RedeemDialog(
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
                Toast.success(
                  context,
                  result.message ?? 'Item redeemed successfully.',
                );
              } else {
                Toast.error(
                  context,
                  result.message ?? 'Failed to redeem. Please try again.',
                );
              }
            },
          ),
    );
  }
}

// ─── Points card (staging) ──────────────────────────────────────────────────

class _PointsCard extends StatelessWidget {
  const _PointsCard({
    required this.points,
    required this.isPhone,
    required this.isSmallPhone,
  });
  final int points;
  final bool isPhone;
  final bool isSmallPhone;

  @override
  Widget build(BuildContext context) {
    // staging: .points-card bg linear-gradient(135deg, #5c52d4 0%, #7c73e6 100%), radius 16 (12 phone), padding 28 32 (16 20 phone, 14 16 small), gap 20 (14 phone), icon 56 (44 phone) radius 14, value 32 (24 phone), label 14 (12 phone)
    final padding =
        isSmallPhone
            ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
            : (isPhone
                ? const EdgeInsets.fromLTRB(20, 16, 20, 16)
                : const EdgeInsets.fromLTRB(32, 28, 32, 28));
    final radius = isPhone ? 12.0 : 16.0;
    final gap = isPhone ? 14.0 : 20.0;
    final iconSize = isPhone ? 44.0 : 56.0;
    final iconRadius = 14.0;
    final valueSize = isPhone ? 24.0 : 32.0;
    final labelSize = isPhone ? 12.0 : 14.0;

    return Container(
      padding: padding,
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [_indigo, _indigoLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40693D94),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(iconRadius),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: isPhone ? 20 : 26,
            ),
          ),
          SizedBox(width: gap),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$points',
                style: GoogleFonts.roboto(
                  fontSize: valueSize,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Available Points',
                style: GoogleFonts.roboto(
                  fontSize: labelSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Inventory header (staging) ─────────────────────────────────────────────

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader({required this.isPhone});
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_outlined, size: 16, color: _indigo),
            const SizedBox(width: 10),
            Text(
              'Inventory',
              style: GoogleFonts.roboto(
                fontSize: isPhone ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: _textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Items available to redeem with your points',
          style: GoogleFonts.roboto(fontSize: 13, color: _textSecondary),
        ),
      ],
    );

    final historyBtn = HoverBuilder(
      builder:
          (context, hovering) => SizedBox(
            height: 40,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(0, hovering ? -1 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow:
                    hovering
                        ? [
                          BoxShadow(
                            color: _indigo.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              child: ElevatedButton.icon(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RedeemHistoryPage(),
                      ),
                    ),
                icon: const Icon(Icons.history_rounded, size: 14),
                label: const Text('Redeem History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hovering ? _indigoDark : _indigo,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isPhone ? 16 : 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: historyBtn),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: title), const SizedBox(width: 12), historyBtn],
    );
  }
}

// ─── Search field (staging) ─────────────────────────────────────────────────

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({
    required this.controller,
    required this.offline,
    required this.onSearch,
    required this.isPhone,
    required this.notifier,
  });
  final TextEditingController controller;
  final bool offline;
  final VoidCallback onSearch;
  final bool isPhone;
  final ItemInventoryViewModel notifier;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  bool _focused = false;
  Timer? _debounce;

  void _onChanged(String value) {
    if (widget.offline) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      widget.notifier.search(value);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.isPhone ? double.infinity : 400,
      ),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                _focused && !widget.offline
                    ? [
                      BoxShadow(
                        color: _indigo.withValues(alpha: 0.12),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                    : null,
          ),
          child: TextField(
            controller: widget.controller,
            enabled: !widget.offline,
            onChanged: _onChanged,
            onSubmitted: (_) => widget.onSearch(),
            style: GoogleFonts.roboto(
              fontSize: widget.isPhone ? 14 : 15,
              color: _textMain,
            ),
            decoration: InputDecoration(
              hintText: widget.offline ? "You're offline" : 'Search items...',
              hintStyle: GoogleFonts.roboto(
                color: _textMuted,
                fontSize: widget.isPhone ? 14 : 15,
              ),
              filled: true,
              fillColor: Colors.white,
              hoverColor: Colors.transparent,
              contentPadding: EdgeInsets.fromLTRB(
                widget.isPhone ? 40 : 44,
                widget.isPhone ? 10 : 12,
                16,
                widget.isPhone ? 10 : 12,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _textMuted,
                size: 16,
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: widget.isPhone ? 40 : 44,
                minHeight: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderInput),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borderInput),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _indigo),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: onTap == null ? _textMuted.withValues(alpha: 0.4) : _indigo,
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

// ─── Item card (staging) ────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.isPhone,
    required this.isSmallPhone,
    required this.isRedeeming,
    required this.onRedeem,
    required this.onView,
  });
  final InventoryItem item;
  final bool isPhone;
  final bool isSmallPhone;
  final bool isRedeeming;
  final VoidCallback onRedeem;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final bodyPad =
        isPhone
            ? const EdgeInsets.fromLTRB(14, 12, 14, 14)
            : const EdgeInsets.fromLTRB(18, 16, 18, 18);
    final nameSize = isPhone ? 14.0 : 15.0;

    return HoverBuilder(
      builder: (context, hovering) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, hovering ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering ? _cardBorderHover : _cardBorder,
            ),
            boxShadow:
                hovering
                    ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ]
                    : const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // item-card-img — web: overflow hidden bg #f9fafb, img scale 1.05 on
              // hover. Image fills the remaining cell height (flexed) so the fixed
              // body below can never overflow the grid cell at any breakpoint.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final imgH = constraints.maxHeight;
                    return Container(
                      height: imgH,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(color: _fallbackBg),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        scale: hovering ? 1.05 : 1.0,
                        child: _ItemImage(imageUrl: item.image, height: imgH),
                      ),
                    );
                  },
                ),
              ),
              // item-card-body — web: padding 16 18 18 (12 14 14 phone)
              Padding(
                padding: bodyPad,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w600,
                        color: _textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.points} pts',
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _indigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: HoverBuilder(
                            builder:
                                (context, btnHover) => OutlinedButton.icon(
                                  onPressed: onView,
                                  icon: const Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 14,
                                  ),
                                  label: const Text('View'),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: isPhone ? 9 : 10,
                                    ),
                                    minimumSize: Size(0, isPhone ? 39 : 41),
                                    backgroundColor:
                                        btnHover
                                            ? const Color(0xFFE5E7EB)
                                            : _btnViewBg,
                                    foregroundColor:
                                        btnHover ? _textMain : _btnViewText,
                                    side: const BorderSide(
                                      color: _cardBorderHover,
                                      width: 0.8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: GoogleFonts.roboto(
                                      fontSize: isPhone ? 12 : 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                        SizedBox(width: isPhone ? 8 : 10),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final isOnline = watchIsOnline(ref);
                              final canAct =
                                  item.canRedeem &&
                                  !item.isRedeemed &&
                                  !isRedeeming &&
                                  isOnline;
                              final label =
                                  item.isRedeemed
                                      ? 'Redeemed'
                                      : (!isOnline && item.canRedeem
                                          ? 'Offline'
                                          : 'Redeem');
                              return HoverBuilder(
                                builder:
                                    (context, btnHover) => ElevatedButton.icon(
                                      onPressed: canAct ? onRedeem : null,
                                      icon:
                                          isRedeeming
                                              ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : Icon(
                                                item.isRedeemed
                                                    ? Icons
                                                        .check_circle_outline_rounded
                                                    : Icons
                                                        .card_giftcard_rounded,
                                                size: 14,
                                              ),
                                      label: Text(label),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: isPhone ? 9 : 10,
                                        ),
                                        minimumSize: Size(0, isPhone ? 39 : 41),
                                        backgroundColor:
                                            canAct && btnHover
                                                ? _indigoDark
                                                : _indigo,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(
                                          0xFFB0AFD4,
                                        ),
                                        disabledForegroundColor: Colors.white,
                                        elevation: canAct && btnHover ? 4 : 0,
                                        shadowColor: _indigo.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        side: BorderSide.none,
                                        textStyle: GoogleFonts.roboto(
                                          fontSize: isPhone ? 12 : 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({this.imageUrl, required this.height});
  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Matches the real site's own default item image exactly (per a live
    // screenshot): a small dark slate-blue rounded square with a white
    // trophy glyph, centered in the card's image area — was a bare
    // indigo gift-box icon with no box at all.
    final fallback = SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF475569),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return Image.network(
      imageUrl!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: height,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder:
          (context, child, progress) =>
              progress == null
                  ? child
                  : SizedBox(
                    height: height,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _indigo,
                      ),
                    ),
                  ),
    );
  }
}

// ─── Pagination (staging pagination-wrap) ───────────────────────────────────

class _WebPaginationRow extends StatelessWidget {
  const _WebPaginationRow({
    required this.page,
    required this.pages,
    required this.onPage,
    required this.isPhone,
  });
  final int page;
  final int pages;
  final ValueChanged<int> onPage;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    final numbers = _pageNumbers(page, pages);
    if (numbers.length <= 1) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Center(
          child: Wrap(
            spacing: 3,
            children:
                numbers.map((p) {
                  if (p == -1) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: Text(
                        '...',
                        style: GoogleFonts.roboto(
                          color: _textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  final isCurrent = p == page;
                  return InkWell(
                    onTap: isCurrent ? null : () => onPage(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent ? _indigo : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCurrent ? _indigo : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        '$p',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isCurrent ? Colors.white : _btnViewText,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  static List<int> _pageNumbers(int current, int total) {
    if (total <= 1) return [1];
    final result = <int>[];
    var ellipsisPending = false;
    for (var p = 1; p <= total; p++) {
      final show = p == 1 || p == total || (p - current).abs() <= 2;
      if (show) {
        result.add(p);
        ellipsisPending = false;
      } else if (!ellipsisPending) {
        result.add(-1);
        ellipsisPending = true;
      }
    }
    return result;
  }
}

// ─── Point system explainer (staging second inventory-card) ─────────────────

// staging: second inventory-card (text-center) shows the centered
// point-system.svg image. The web asset is a Figma export that embeds the
// whole graphic as a raster PNG inside an SVG <pattern> fill (plus vector
// text on top), and the staging server sends no CORS headers — so neither
// flutter_svg (<pattern> unsupported) nor a runtime fetch (CORS-blocked
// without the local dev proxy, which isn't running on web) can render it
// reliably. Bash-loaded copy of the SVG rasterized with headless Chrome
// (1244x554, matches the web render including the vector text) and bundled
// as an asset, so it renders identically on every platform with no network
// dependency.
class _PointSystemExplainer extends StatelessWidget {
  const _PointSystemExplainer();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isPhone = w <= 768;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isPhone ? 12 : 20),
        child: Image.asset(
          'assets/images/point-system.png',
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

// ─── Dialogs (staging inventory-modal) ──────────────────────────────────────

class _ItemDetailDialog extends StatelessWidget {
  const _ItemDetailDialog({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isPhone = w <= 768;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 12 : 16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 40,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: isPhone ? 600 : 640,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // modal-header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _modalBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    'Item Details',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textMain,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isPhone ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Container(
                          color: _fallbackBg,
                          child:
                              item.image != null
                                  ? Image.network(
                                    item.image!,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            const _DialogImageFallback(),
                                  )
                                  : const _DialogImageFallback(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DetailRow(label: 'Name:', value: item.name),
                    if (item.groupName != null)
                      _DetailRow(label: 'Group:', value: item.groupName!),
                    if (item.managedBy != null)
                      _DetailRow(label: 'Managed by:', value: item.managedBy!),
                    _DetailRow(
                      label: 'Points required:',
                      value: '${item.points}',
                    ),
                    if (item.description.isNotEmpty)
                      _DetailRow(
                        label: 'Description:',
                        value: item.description,
                      ),
                  ],
                ),
              ),
            ),
            // modal-footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _modalBorder)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _btnViewBg,
                    foregroundColor: _btnViewText,
                    elevation: 0,
                    side: const BorderSide(color: _cardBorderHover),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    textStyle: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogImageFallback extends StatelessWidget {
  const _DialogImageFallback();
  @override
  Widget build(BuildContext context) {
    // Same default-image box as _ItemImage's own fallback, scaled up
    // slightly for this larger dialog image area.
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF475569),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.emoji_events_rounded,
          color: Colors.white,
          size: 32,
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
    final isPhone = MediaQuery.sizeOf(context).width <= 768;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isPhone ? 80 : 110,
            child: Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: isPhone ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(
                fontSize: isPhone ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: _textMain,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final w = MediaQuery.sizeOf(context).width;
    final isPhone = w <= 768;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isPhone ? 12 : 16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isPhone ? 12 : 40,
        vertical: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _modalBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Confirm Redemption',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textMain,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you would like to redeem this item for ${widget.item.points} points?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        color: _textSecondary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Address *',
                      style: GoogleFonts.roboto(
                        color: _textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 3,
                      validator:
                          (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Address is required'
                                  : null,
                      style: GoogleFonts.roboto(fontSize: 14, color: _textMain),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _fallbackBg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _indigo),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Note',
                      style: GoogleFonts.roboto(
                        color: _textMain,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _noteCtrl,
                      style: GoogleFonts.roboto(fontSize: 14, color: _textMain),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _fallbackBg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _indigo),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _modalBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _cardBorderHover),
                      backgroundColor: _btnViewBg,
                      foregroundColor: _btnViewText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _submitting
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
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(0, 40),
                    ),
                    child:
                        _submitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(
                              'Yes',
                              style: GoogleFonts.roboto(
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

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Text(
          'No items match your search.',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(color: _textSecondary, fontSize: 14),
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
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: _badgeBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.redeem_outlined,
                color: _indigo,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Items Available',
              style: GoogleFonts.roboto(
                color: _textMain,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Redeemable items will appear here once available.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                color: _textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
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
            const Icon(Icons.error_outline, color: _textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(color: _textSecondary),
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
