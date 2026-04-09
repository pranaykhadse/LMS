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

  Future<void> fetch(int page) async {
    state = state.copyWith(
      data: DataState.loading(),
      pageInfo: (state.pageInfo ?? PageInfo(page: 1, pages: 1)).copyWith(
        page: page,
      ),
    );
    try {
      final data = await repository.getData(page,queryParams: queryParams);
      state = PaginatedState(
        data: DataState.onData(data.data),
        pageInfo: data.pageInfo,

      );
    } catch (e) {
      state = state.copyWith(data: DataState.onError(e.toString()));
    }
  }

  Map<String, dynamic> get queryParams => {};
}
