import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/repository/item_inventory_repository.dart';

/// The user's live, currently-redeemable points balance for the "Redeem
/// your Points" nav badge — `null` until a real fetch has completed.
///
/// Deliberately NOT sourced from `AuthState.userProfile.points`, which is
/// only ever set once at login and never updates for the rest of the
/// session (the exact "badge shows 288, screen shows 359" mismatch fixed
/// earlier), and deliberately NOT defaulted to `0` or any other
/// placeholder — the badge itself only renders when this is non-null, so
/// it stays blank rather than showing a stale/wrong number until the real
/// balance is actually known.
///
/// Not `autoDispose`: this needs to survive across screens/navigation for
/// [fetchIfNeeded] (called once per app session, from [AuthGate]) to be
/// meaningful — an autoDispose provider would be torn down the moment
/// nothing was watching it and lose the fetched value.
class UserPointsViewModel extends StateNotifier<int?> {
  UserPointsViewModel(this._ref) : super(null);
  final Ref _ref;
  bool _fetching = false;

  static final provider = StateNotifierProvider<UserPointsViewModel, int?>((
    ref,
  ) {
    return UserPointsViewModel(ref);
  });

  /// Fetches the live balance if it isn't already known and a fetch isn't
  /// already in flight — called once at app open / right after login (see
  /// `AuthGate`), so the badge has a real number even if the user never
  /// opens Redeem Points or Dashboard this session.
  ///
  /// Uses the SAME `page`/`perPage` (1/10) as
  /// `ItemInventoryViewModel.fetch`'s own default request — an earlier
  /// version of this requested `perPage: 1` to keep the call cheap, but
  /// that's a different query than what the Redeem Points screen itself
  /// ever makes, and a mismatched-balance report (this badge showing a
  /// different number than that screen, for the same user, moments apart)
  /// is exactly the symptom of a backend response that isn't purely
  /// page-size-independent. Matching the real screen's own request
  /// exactly removes that as a possible cause, at the cost of a slightly
  /// larger response.
  Future<void> fetchIfNeeded() async {
    if (state != null || _fetching) return;
    final userId = _ref.read(AuthStateNotifier.provider)?.user?.id;
    if (userId == null) return;
    _fetching = true;
    try {
      final result = await _ref
          .read(ItemInventoryRepository.provider)
          .fetch(userId: userId, page: 1, perPage: 10);
      if (mounted) state = result.userPoints;
    } catch (_) {
      // Leave state null - a later screen visit (Redeem Points/Dashboard,
      // via their own `set` calls below) will populate it, or the next
      // app open retries.
    } finally {
      _fetching = false;
    }
  }

  /// Called by screens that already fetch a fresher balance themselves
  /// (Redeem Points' own inventory fetch, the Dashboard's rewards block)
  /// so this provider - and the nav badge reading it - stay in sync
  /// without a redundant extra network call.
  void set(int points) {
    if (state == points) return;
    state = points;
  }
}
