import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/logic/data_state/data_state.dart';
import 'package:lms/app/features/authentication/app_state/auth_state_provider.dart';
import 'package:lms/app/features/dashboard/model/inventory_item.dart';
import 'package:lms/app/features/dashboard/repository/item_inventory_repository.dart';

const _perPage = 10;

class ItemInventoryState {
  const ItemInventoryState({
    this.result,
    this.providerState = DataProviderState.idle,
    this.error,
    this.redeemingId,
    this.page = 1,
    this.query = '',
  });
  final InventoryResult? result;
  final DataProviderState providerState;
  final String? error;
  final int? redeemingId;
  final int page;
  final String query;

  int get totalPages =>
      result == null || result!.total == 0 ? 1 : ((result!.total + _perPage - 1) ~/ _perPage);

  ItemInventoryState copyWith({
    InventoryResult? result,
    DataProviderState? providerState,
    String? error,
    int? redeemingId,
    bool clearRedeeming = false,
    int? page,
    String? query,
  }) {
    return ItemInventoryState(
      result: result ?? this.result,
      providerState: providerState ?? this.providerState,
      error: error ?? this.error,
      redeemingId: clearRedeeming ? null : redeemingId ?? this.redeemingId,
      page: page ?? this.page,
      query: query ?? this.query,
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

  Future<String?> fetch({int page = 1, String? search}) async {
    final userId = _userId;
    if (userId == null) return null;
    final query = search ?? state.query;
    final hasData = state.providerState == DataProviderState.data;
    if (!hasData) {
      state = state.copyWith(providerState: DataProviderState.loading, page: page, query: query);
    }
    try {
      final result = await _repo.fetch(
        userId: userId,
        page: page,
        perPage: _perPage,
        search: query,
      );
      state = state.copyWith(
        result: result,
        providerState: DataProviderState.data,
        page: page,
        query: query,
      );
      return null;
    } catch (e) {
      final message = e.toString();
      if (!hasData) {
        state = state.copyWith(
          providerState: DataProviderState.error,
          error: message,
        );
      }
      return message;
    }
  }

  Future<String?> search(String query) => fetch(page: 1, search: query);

  Future<String?> clearSearch() => fetch(page: 1, search: '');

  Future<String?> goToPage(int page) {
    if (page >= 1 && page <= state.totalPages) {
      return fetch(page: page, search: state.query);
    }
    return Future.value(null);
  }

  Future<bool> redeem(int itemId, {required String address, String? note}) async {
    final userId = _userId;
    if (userId == null) return false;
    state = state.copyWith(redeemingId: itemId);
    try {
      await _repo.redeem(userId: userId, itemId: itemId, address: address, note: note);
      await fetch(page: state.page, search: state.query);
      state = state.copyWith(clearRedeeming: true);
      return true;
    } catch (e) {
      state = state.copyWith(clearRedeeming: true);
      return false;
    }
  }
}
