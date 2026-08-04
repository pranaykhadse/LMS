import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/authentication/model/auth_state.dart';
import 'package:lms/app/features/dashboard/model/badge.dart';
import 'package:lms/app/features/dashboard/repository/badges_repository.dart';

class BadgesState {
  const BadgesState({
    this.providerState = DataProviderState.idle,
    this.result,
    this.error,
  });

  final DataProviderState providerState;
  final BadgesResult? result;
  final String? error;

  BadgesState copyWith({
    DataProviderState? providerState,
    BadgesResult? result,
    String? error,
  }) => BadgesState(
    providerState: providerState ?? this.providerState,
    result: result ?? this.result,
    error: error,
  );
}

class BadgesViewModel extends StateNotifier<BadgesState> {
  BadgesViewModel({required this.repository, required this.userId})
    : super(const BadgesState()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
    BadgesViewModel,
    BadgesState
  >((ref) {
    final auth = ref.watch(AuthStateNotifier.provider);
    return BadgesViewModel(
      repository: ref.watch(BadgesRepository.provider),
      userId: _loggedInUserId(auth),
    );
  });

  final BadgesRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: 'The logged-in user ID is unavailable.',
      );
      return;
    }
    state = state.copyWith(providerState: DataProviderState.loading);
    try {
      final result = await repository.fetch(userId: userId!);
      if (!mounted) return;
      state = state.copyWith(
        providerState: DataProviderState.data,
        result: result,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: error.toString(),
      );
    }
  }
}

int? _loggedInUserId(AuthState? auth) =>
    auth?.userProfile?.userId ?? auth?.user?.id;
