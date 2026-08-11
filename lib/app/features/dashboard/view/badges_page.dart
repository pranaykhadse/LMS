import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/features/dashboard/model/badge.dart';
import 'package:lms/app/features/dashboard/viewmodel/badges_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
const _bg = FigmaTokens.pageBackground;
const _gold = Color(0xFFFFC107);

class BadgesPage extends ConsumerWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(BadgesViewModel.provider);
    final notifier = ref.read(BadgesViewModel.provider.notifier);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Badges',
      selectedSubLabel: 'Badges',
      onRefresh: notifier.fetch,
      body: _Body(state: state, onRetry: notifier.fetch),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onRetry});
  final BadgesState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.providerState) {
      case DataProviderState.loading:
      case DataProviderState.idle:
        return const Center(child: CircularProgressIndicator(color: _purple));
      case DataProviderState.error:
        return _ErrorView(
          message: state.error ?? 'Unable to load badges.',
          onRetry: onRetry,
        );
      case DataProviderState.data:
        final result = state.result!;
        return RefreshIndicator(
          color: _purple,
          onRefresh: () async => onRetry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Earned badges ────────────────────────────────────────
              _SectionHeader(
                title: 'Your Badges',
                count: result.earnedCount,
                color: _gold,
                icon: Icons.emoji_events_rounded,
              ),
              const SizedBox(height: 12),
              // White card wrapping earned badges
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: result.earned.isEmpty
                    ? _EmptySection(
                        message: 'You have not earned any badges yet.',
                        icon: Icons.emoji_events_outlined,
                      )
                    : _BadgeGrid(badges: result.earned, earned: true),
              ),

              const SizedBox(height: 24),

              // ── Available badges ──────────────────────────────────────
              _SectionHeader(
                title: 'Available Badges',
                count: result.notEarnedCount,
                color: _muted,
                icon: Icons.military_tech_outlined,
              ),
              const SizedBox(height: 12),
              // White card wrapping available badges
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: result.notEarned.isEmpty
                    ? _EmptySection(
                        message: 'No additional badges available.',
                        icon: Icons.military_tech_outlined,
                      )
                    : _BadgeGrid(badges: result.notEarned, earned: false),
              ),
              const AppFooter(),
            ],
          ),
        );
    }
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color == _muted ? _muted : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Badge grid ───────────────────────────────────────────────────────────────

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges, required this.earned});
  final List<UserBadge> badges;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.columns(
          context,
          phone: 3,
          tablet: 5,
          desktop: 6,
        ),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: badges.length,
      itemBuilder: (ctx, i) => _BadgeCard(badge: badges[i], earned: earned),
    );
  }
}

// ─── Badge card ───────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.earned});
  final UserBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: earned
          ? () => showDialog(
                context: context,
                builder: (_) => _BadgeDetailDialog(badge: badge),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: earned
              ? Border.all(color: _gold.withValues(alpha: .6), width: 1.5)
              : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area ─────────────────────────────────────────────
            Expanded(
              flex: 7,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _BadgeImage(imageUrl: badge.image, earned: earned),
                ),
              ),
            ),
            // ── Divider ────────────────────────────────────────────────
            const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            // ── Name + earned chip ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badge.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: earned ? _ink : _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (earned) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: _gold, size: 12),
                          SizedBox(width: 3),
                          Text(
                            'Earned',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Badge detail dialog ──────────────────────────────────────────────────────

class _BadgeDetailDialog extends StatelessWidget {
  const _BadgeDetailDialog({required this.badge});
  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 90,
              child: _BadgeImage(imageUrl: badge.image, earned: true),
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
                children: [
                  const TextSpan(text: 'You earned this badge for successfully completing the course '),
                  TextSpan(
                    text: "'${badge.title}'",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Congratulations!',
              style: TextStyle(
                color: _purple,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeImage extends StatelessWidget {
  const _BadgeImage({this.imageUrl, required this.earned});
  final String? imageUrl;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return ColorFiltered(
        colorFilter: earned
            ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
            : const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0,      0,      0,      1, 0,
              ]),
        child: Icon(
          Icons.military_tech_rounded,
          size: 60,
          color: earned ? const Color(0xFFFFC107) : _muted,
        ),
      );
    }
    return ColorFiltered(
      colorFilter: earned
          ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
          : const ColorFilter.matrix([
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      0.5, 0,
            ]),
      child: Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.military_tech_rounded,
          size: 60,
          color: earned ? const Color(0xFFFFC107) : _muted,
        ),
      ),
    );
  }
}

// ─── Empty section ────────────────────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(color: _muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
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
              RetryButton(onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
