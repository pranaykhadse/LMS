import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';
import 'package:lms/app/features/dashboard/repository/item_inventory_repository.dart';

class ItemInventoryState {
  const ItemInventoryState({
    this.result,
    this.providerState = DataProviderState.idle,
    this.error,
    this.redeemingId,
  });
  final InventoryResult? result;
  final DataProviderState providerState;
  final String? error;
  final int? redeemingId;

  ItemInventoryState copyWith({
    InventoryResult? result,
    DataProviderState? providerState,
    String? error,
    int? redeemingId,
    bool clearRedeeming = false,
  }) {
    return ItemInventoryState(
      result: result ?? this.result,
      providerState: providerState ?? this.providerState,
      error: error ?? this.error,
      redeemingId: clearRedeeming ? null : redeemingId ?? this.redeemingId,
    );
  }
}

class ItemInventoryViewModel extends StateNotifier<ItemInventoryState> {
  ItemInventoryViewModel(this._repo, this._ref)
      : super(const ItemInventoryState()) {
    fetch();
  }

  final ItemInventoryRepository _repo;
  final Ref _ref;

  static final provider = StateNotifierProvider.autoDispose<
      ItemInventoryViewModel, ItemInventoryState>((ref) {
    return ItemInventoryViewModel(
      ref.watch(ItemInventoryRepository.provider),
      ref,
    );
  });

  int? get _userId => _ref.read(AuthStateNotifier.provider)?.user?.id;

  Future<void> fetch() async {
    final userId = _userId;
    if (userId == null) return;
    state = state.copyWith(providerState: DataProviderState.loading);
    try {
      final result = await _repo.fetch(userId: userId);
      state = state.copyWith(
        result: result,
        providerState: DataProviderState.data,
      );
    } catch (e) {
      state = state.copyWith(
        providerState: DataProviderState.error,
        error: e.toString(),
      );
    }
  }

  Future<bool> redeem(int itemId, {required String address, String? note}) async {
    final userId = _userId;
    if (userId == null) return false;
    state = state.copyWith(redeemingId: itemId);
    try {
      await _repo.redeem(userId: userId, itemId: itemId, address: address, note: note);
      await fetch();
      state = state.copyWith(clearRedeeming: true);
      return true;
    } catch (e) {
      state = state.copyWith(clearRedeeming: true);
      return false;
    }
  }
}
