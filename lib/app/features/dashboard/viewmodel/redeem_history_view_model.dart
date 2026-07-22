import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/redeem_history_item.dart';
import 'package:lms/app/features/dashboard/repository/redeem_history_repository.dart';

class RedeemHistoryViewModel
    extends StateNotifier<DataState<RedeemHistoryResult>> {
  RedeemHistoryViewModel({
    required this.repository,
    required this.userId,
  }) : super(DataState.idle<RedeemHistoryResult>()) {
    fetch();
  }

  static final provider = StateNotifierProvider.autoDispose<
      RedeemHistoryViewModel, DataState<RedeemHistoryResult>>((ref) {
    final userId = ref.watch(AuthStateNotifier.provider)?.user?.id;
    return RedeemHistoryViewModel(
      repository: ref.watch(RedeemHistoryRepository.provider),
      userId: userId,
    );
  });

  final RedeemHistoryRepository repository;
  final int? userId;

  Future<void> fetch() async {
    if (userId == null) {
      state = DataState.onError('User not logged in.');
      return;
    }
    state = DataState.loading<RedeemHistoryResult>();
    try {
      final data = await repository.fetch(userId: userId!);
      state = DataState.onData(data);
    } catch (e) {
      state = DataState.onError(_friendly(e));
    }
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Session expired. Please log in again.';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Unable to load your redeem history. Please try again.';
  }
}
