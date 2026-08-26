import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/design/responsive.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/core/views/elements/app_footer.dart';
import 'package:lms/app/core/views/elements/app_scaffold.dart';
import 'package:lms/app/core/views/elements/retry_button.dart';
import 'package:lms/app/core/views/elements/unauthorized_handler.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/badge.dart';
import 'package:lms/app/features/dashboard/viewmodel/badges_view_model.dart';

const _purple = FigmaTokens.primaryPurple;
const _ink = FigmaTokens.cardTitles;
const _muted = FigmaTokens.noteBodyText;
// CSS ref: section bg #F4F6FB (page-specific, not the app's usual
// pageBackground #F4F5F7).
const _bg = Color(0xFFF4F6FB);
const _gold = Color(0xFFFFC107);
// CSS ref: .lock-icon bg rgba(92,82,212,0.9) - distinct indigo also used
// on the Redeem Points page, not the app's usual primaryPurple.
const _lockIndigo = Color(0xFF5C52D4);
const _cardShadow = [
  BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
];

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
          message: friendlyErrorMessage(state.error, 'Unable to load badges.'),
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
                    // (bumped for the 120px avatar + 24px padding each side)
                    SizedBox(
                      width: 176,
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

    // CSS ref: .badges-profile — padding 24, radius 16, shadow (not
    // border), avatar 120x120.
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person_rounded, size: 60, color: _muted)
                : null,
          ),
          const SizedBox(height: 12),
          // Name — CSS ref: h1.text-center 16px/weight700/#1E293B
          Text(
            name.isNotEmpty ? name : 'User',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 16,
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
          // CSS ref: .badges-block — padding 30, radius 16, shadow (not border)
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Your Badges'),
              // CSS ref: h2 padding-bottom 12 + margin-bottom 20
              const SizedBox(height: 32),
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
          // CSS ref: .badges-block — padding 30, radius 16, shadow (not border)
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Available Badges'),
              // CSS ref: h2 padding-bottom 12 + margin-bottom 20
              const SizedBox(height: 32),
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
    // CSS ref: h2.mb-3 — 18px, weight700, #1E293B
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 18,
        fontWeight: FontWeight.w700,
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
    // CSS ref: .badge-container — radius 16, shadow (not border); earned
    // bg white, locked bg #F8FAFC (distinct, was white for both).
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: earned
          ? () => showDialog(
                context: context,
                builder: (_) => _BadgeDetailDialog(badge: badge),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: earned ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
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
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _BadgeImage(imageUrl: badge.image, earned: earned),
                    ),
                  ),
                  // Lock icon overlay for not-earned badges — CSS ref:
                  // .lock-icon 32x32, bg indigo@0.9, centered
                  if (!earned)
                    Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _lockIndigo.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _lockIndigo.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 16,
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
              RetryButton(onRetry: onRetry!, errorMessage: message),
            ],
          ],
        ),
      ),
    );
  }
}
