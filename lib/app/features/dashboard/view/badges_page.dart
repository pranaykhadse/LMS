import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
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

/// CSS ref, confirmed against `origin/staging`'s user-badges/index.php:
/// each badge item is `col-lg-2 col-md-3 col-sm-6 col-6` — 6 per row at
/// ≥992px, 4 per row at 768-991px, 2 per row below that — not the shared
/// `Responsive` helper's generic 700/1024 thresholds (which this screen
/// was wrongly using: phone:3/tablet:5/desktop:6).
int _badgeColumnsFor(double width) {
  if (width >= 992) return 6;
  if (width >= 768) return 4;
  return 2;
}

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
      body: _Body(
        state: state,
        onRetry: notifier.fetch,
        userProfile: auth?.userProfile,
      ),
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
        // CSS ref: profile/badges only sit side-by-side at `col-lg-*`
        // (≥992px) — below that Bootstrap stacks them full-width, not at
        // the shared `Responsive.isDesktop` threshold (1024px).
        final isWide = MediaQuery.sizeOf(context).width >= 992;
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
    final firstInitial =
        (userProfile?.firstname?.isNotEmpty ?? false)
            ? userProfile!.firstname![0].toUpperCase()
            : '?';

    // CSS ref, confirmed against `origin/staging`'s user-badges/index.php:
    // .badges-profile — padding 24, radius 16, border 1px solid #F3F4F6
    // (was missing entirely), shadow 0 1px 3px rgba(0,0,0,.02).
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: _cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CSS ref: .badges-profile img — 120x120, radius 50%, border
          // 3px solid rgba(92,82,212,.1), object-fit cover.
          // .badges-profile span (no-avatar fallback) — 120x120, radius
          // 50%, gradient bg 135deg #5C52D4→#A20067, white initial letter
          // 32px/700 — was a generic gray circle + person icon.
          avatarUrl.isNotEmpty
              ? Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _lockIndigo.withValues(alpha: 0.1),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(avatarUrl),
                ),
              )
              : Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_lockIndigo, Color(0xFFA20067)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  firstInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          // CSS ref: .badges-block — padding 30, radius 16, border 1px
          // solid #F3F4F6 (was missing), shadow 0 1px 3px rgba(0,0,0,.02).
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: _cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Your Badges'),
              // CSS ref: h2 padding-bottom 12 + margin-bottom 20
              const SizedBox(
                height: 20,
              ), // CSS ref: .badges-block h2 margin-bottom 20px (padding-bottom 12px now lives inside _SectionHeader)
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
          // CSS ref: .badges-block — padding 30, radius 16, border 1px
          // solid #F3F4F6 (was missing), shadow 0 1px 3px rgba(0,0,0,.02).
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
            boxShadow: _cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(title: 'Available Badges'),
              // CSS ref: h2 padding-bottom 12 + margin-bottom 20
              const SizedBox(height: 20),
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
    // CSS ref: .badges-block h2 — 18px/700/#1E293B, border-bottom 2px
    // solid #F1F5F9, padding-bottom 12px — the underline was missing
    // entirely (only the combined 12+20 vertical gap was reproduced, via
    // the caller's SizedBox, with no rule drawn).
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 2)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
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
        crossAxisCount: _badgeColumnsFor(MediaQuery.sizeOf(context).width),
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
    // CSS ref: .badge-container — radius 16, padding 12, border 1px solid
    // #F1F5F9 (locked: #E2E8F0) — both were missing; earned bg white,
    // locked bg #F8FAFC.
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap:
          earned
              ? () => showDialog(
                context: context,
                builder: (_) => _BadgeDetailDialog(badge: badge),
              )
              : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: earned ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _BadgeImage(imageUrl: badge.image, earned: earned),
            // CSS ref: .lock-icon — 32x32, bg indigo@0.9, border 2px
            // solid white, positioned bottom:8/right:8 (was centered
            // on the whole card, and missing the white border).
            if (!earned)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _lockIndigo.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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
    );
  }
}

// ─── Badge detail dialog ──────────────────────────────────────────────────────

class _BadgeDetailDialog extends StatelessWidget {
  const _BadgeDetailDialog({required this.badge});
  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    // CSS/markup ref, confirmed against `origin/staging`'s user-badges/
    // index.php: `#earn-badges-modal` — modal-header is its own block
    // (bg #F8FAFC, border-bottom 1px #F1F5F9, padding 16/20, just the
    // close button, text-center) separate from modal-body (padding
    // 30/24). The image is capped at 110px wide, not a fixed 90px box.
    // The sentence and "Congratulations!" are ONE paragraph (`<br><br>
    // <strong>`), not two separately-styled text blocks — color #475569/
    // 15px/lh1.6 for the sentence, `<strong>` #5C52D4/18px (a distinct
    // indigo, not this app's usual purple).
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _muted, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: _BadgeImage(imageUrl: badge.image, earned: true),
                ),
                const SizedBox(height: 15),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 15,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'You earned this badge for successfully completing the course ‘${badge.title}’',
                      ),
                      const TextSpan(text: '\n\n'),
                      const TextSpan(
                        text: 'Congratulations!',
                        style: TextStyle(
                          color: Color(0xFF5C52D4),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
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
    return Container(color: Colors.white, child: _buildImage());
  }

  Widget _buildImage() {
    if (imageUrl == null) {
      return ColorFiltered(
        colorFilter:
            earned
                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : const ColorFilter.matrix([
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
        child: Icon(
          Icons.military_tech_rounded,
          size: 60,
          color: earned ? const Color(0xFFFFC107) : _muted,
        ),
      );
    }
    return ColorFiltered(
      colorFilter:
          earned
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : const ColorFilter.matrix([
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                0.5,
                0,
              ]),
      child: Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder:
            (_, __, ___) => Icon(
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
