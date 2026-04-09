import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/courses/model/course.dart';
import 'package:lms/app/features/payment/viewmodel/iap_viewmodel.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// PurchasePage
///
/// Displayed when a user taps "Buy Course" on a paid course card.
/// Fetches the App Store product details, shows the price, and lets the user:
///   • Purchase the course (triggers native Apple/Google payment sheet)
///   • Restore previous purchases
///
/// Returns `true` via [Modular.to.pop] when the purchase succeeds so that
/// [CourseCard] can immediately unlock the course without a full page reload.
/// ─────────────────────────────────────────────────────────────────────────────
class PurchasePage extends ConsumerStatefulWidget {
  const PurchasePage({super.key, required this.course});

  final Course course;

  @override
  ConsumerState<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends ConsumerState<PurchasePage> {
  @override
  void initState() {
    super.initState();
    // Fetch product from the App Store after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.course.id != null) {
        ref
            .read(IAPViewModel.provider)
            .fetchProductForCourse(widget.course.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // React to purchase success / error changes.
    ref.listen<IAPViewModel>(IAPViewModel.provider, (_, vm) {
      if (!mounted) return;

      if (vm.purchaseSuccess) {
        Toast.success(
          context,
          'Purchase successful! You can now access this course.',
        );
        vm.clearPurchaseSuccess();
        Modular.to.pop(true); // true = purchased
      }

      if (vm.error != null) {
        Toast.error(context, vm.error!);
        vm.clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Course'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.smallSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CourseInfoCard(course: widget.course),
              SizedBox(height: context.smallSpace),
              _ProductSection(course: widget.course),
              SizedBox(height: context.minorSpace),
              _RestoreButton(),
              SizedBox(height: context.smallSpace),
              _LegalNote(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CourseInfoCard extends StatelessWidget {
  const _CourseInfoCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    return PrimaryCard(
      padding: EdgeInsets.all(context.smallSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appColorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(context.minorRadius),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: context.appColorScheme.primary,
                  size: 26,
                ),
              ),
              SizedBox(width: context.minorSpace),
              Expanded(
                child: Text(
                  course.name ?? 'Course',
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Description
          if (course.description?.isNotEmpty == true) ...[
            SizedBox(height: context.minorSpace),
            Text(
              course.description!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Objective
          if (course.objective?.isNotEmpty == true) ...[
            SizedBox(height: context.minorSpace),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 15,
                  color: context.appColorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    course.objective!,
                    style: context.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Product section ──────────────────────────────────────────────────────────

class _ProductSection extends ConsumerWidget {
  const _ProductSection({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(IAPViewModel.provider);
    final state = vm.currentProduct;

    // Loading
    if (state.state == DataProviderState.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Error
    if (state.state == DataProviderState.error) {
      return PrimaryCard(
        padding: EdgeInsets.all(context.smallSpace),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 44),
            SizedBox(height: context.minorSpace),
            Text(
              state.error ?? 'Could not load product details.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
            SizedBox(height: context.smallSpace),
            OutlinedButton.icon(
              onPressed: () {
                if (course.id != null) {
                  ref
                      .read(IAPViewModel.provider)
                      .fetchProductForCourse(course.id!);
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Product ready
    final product = state.data;
    if (product == null) return const SizedBox.shrink();
    return _PurchaseCard(product: product);
  }
}

// ─── Purchase card ────────────────────────────────────────────────────────────

class _PurchaseCard extends ConsumerWidget {
  const _PurchaseCard({required this.product});
  final ProductDetails product;

  static const _features = [
    'Full course access',
    'Video & PDF content',
    'Offline download support',
    'Progress tracking',
    'Completion certificate',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(IAPViewModel.provider);

    return PrimaryCard(
      padding: EdgeInsets.all(context.smallSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Price row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Premium Access',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.smallSpace,
                  vertical: context.minorSpace,
                ),
                decoration: BoxDecoration(
                  color: context.appColorScheme.primary,
                  borderRadius: BorderRadius.circular(context.smallRadius),
                ),
                child: Text(
                  product.price,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: context.minorSpace),

          Text(
            product.description,
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),

          const Divider(height: 24),

          // Feature list
          ..._features.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: context.appColorScheme.success,
                  ),
                  const SizedBox(width: 8),
                  Text(f, style: context.textTheme.bodySmall),
                ],
              ),
            ),
          ),

          SizedBox(height: context.smallSpace),

          // Buy button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.smallRadius),
                ),
              ),
              onPressed: vm.isPurchasing
                  ? null
                  : () => ref.read(IAPViewModel.provider).purchase(product),
              icon: vm.isPurchasing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_rounded),
              label: Text(
                vm.isPurchasing ? 'Processing…' : 'Buy for ${product.price}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Restore button ───────────────────────────────────────────────────────────

class _RestoreButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(IAPViewModel.provider);
    return Center(
      child: TextButton.icon(
        onPressed: vm.isRestoring
            ? null
            : () => ref.read(IAPViewModel.provider).restorePurchases(),
        icon: vm.isRestoring
            ? const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.restore_rounded, size: 18),
        label: Text(
          vm.isRestoring ? 'Restoring…' : 'Restore Previous Purchases',
        ),
      ),
    );
  }
}

// ─── Legal disclaimer ─────────────────────────────────────────────────────────

class _LegalNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '• Payment will be charged to your Apple ID account at confirmation.\n'
      '• This is a one-time purchase — no subscriptions.\n'
      '• Purchases are non-refundable once course access is granted.\n'
      '• Manage your purchases in iPhone Settings → Apple ID.',
      style: context.textTheme.bodySmall?.copyWith(
        color: Colors.grey[500],
        fontSize: 11,
        height: 1.6,
      ),
    );
  }
}
