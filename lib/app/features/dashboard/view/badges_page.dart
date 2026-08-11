import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
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
    final auth = ref.watch(AuthStateNotifier.provider);

    return AppScaffold(
      backgroundColor: _bg,
      title: 'Badges',
      selectedSubLabel: 'Badges',
      onRefresh: notifier.fetch,
      body: _Body(state: state, onRetry: notifier.fetch, userProfile: auth?.userProfile),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onRetry, this.userProfile});
  final BadgesState state;
  final VoidCallback onRetry;
  final UserProfile? userProfile;

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
        final isWide = Responsive.isDesktop(context);
        return RefreshIndicator(
          color: _purple,
          onRefresh: () async => onRetry(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Two-column layout on desktop ──────────────────────────
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: profile card — fixed width, natural height
                    SizedBox(
                      width: 160,
                      child: _ProfileCard(userProfile: userProfile),
                    ),
                    const SizedBox(width: 16),
                    // Right: badges content fills remaining width
                    Expanded(child: _BadgesContent(result: result)),
                  ],
                )
              else ...[
                // Mobile: profile card on top, badges below
                _ProfileCard(userProfile: userProfile),
                const SizedBox(height: 16),
                _BadgesContent(result: result),
              ],
              const AppFooter(),
            ],
          ),
        );
    }
  }
}

// ─── Profile card (left sidebar) ─────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({this.userProfile});
  final UserProfile? userProfile;

  @override
  Widget build(BuildContext context) {
    final name = [
      userProfile?.firstname ?? '',
      userProfile?.lastname ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    final avatarUrl = userProfile?.avatarUrl ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person_rounded, size: 40, color: _muted)
                : null,
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            name.isNotEmpty ? name : 'User',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _purple,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badges content (right side) ─────────────────────────────────────────────

class _BadgesContent extends StatelessWidget {
  const _BadgesContent({required this.result});
  final BadgesResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Earned badges ── title inside the white card ────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Your Badges'),
              const SizedBox(height: 14),
              result.earned.isEmpty
                  ? _EmptySection(
                      message: 'You have not earned any badges yet.',
                      icon: Icons.emoji_events_outlined,
                    )
                  : _BadgeGrid(badges: result.earned, earned: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // ── Available badges ── title inside the white card ──────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Available Badges'),
              const SizedBox(height: 14),
              result.notEarned.isEmpty
                  ? _EmptySection(
                      message: 'No additional badges available.',
                      icon: Icons.military_tech_outlined,
                    )
                  : _BadgeGrid(badges: result.notEarned, earned: false),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
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
        childAspectRatio: 1.0,
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
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image fills the full card ──────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _BadgeImage(imageUrl: badge.image, earned: earned),
                    ),
                  ),
                  // Lock icon overlay for not-earned badges
                  if (!earned)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: _purple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
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
    // Wrap in white so transparent PNG areas and the greyscale
    // semi-transparent overlay don't bleed through to the page background.
    return Container(
      color: Colors.white,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
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
