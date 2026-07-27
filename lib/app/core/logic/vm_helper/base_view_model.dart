import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/logic/data_state/paginated_data.dart';
import 'package:lms/app/core/logic/repository/listing_repo_helper.dart';
import 'package:lms/app/core/model/page_info.dart';

abstract class BaseViewModel<T> extends StateNotifier<PaginatedState<T>> {
  BaseViewModel({required this.repository})
    : super(PaginatedState(data: DataState.idle(), pageInfo: null)) {
    fetch(0);
  }

  final ListingRepoHelper<T> repository;

  Future<String?> fetch(int page) async {
    // Keep whatever is already on screen while a page change is in flight
    // instead of flashing back to a full-screen spinner; only show the
    // spinner when there's nothing on screen yet (first load / after error).
    final hasData = state.data.state == DataProviderState.data;
    if (!hasData) {
      state = state.copyWith(
        data: DataState.loading(),
        pageInfo: (state.pageInfo ?? PageInfo(page: 1, pages: 1)).copyWith(
          page: page,
        ),
      );
    }
    try {
      final data = await repository.getData(page, queryParams: queryParams);
      state = PaginatedState(
        data: DataState.onData(data.data),
        pageInfo: data.pageInfo,
      );
      return null;
    } catch (e) {
      final message = e.toString();
      // Leave the previously shown page/data untouched on failure so the
      // pagination widget keeps highlighting the page that's actually shown.
      if (!hasData) {
        state = state.copyWith(data: DataState.onError(message));
      }
      return message;
    }
  }

  Map<String, dynamic> get queryParams => {};
}
