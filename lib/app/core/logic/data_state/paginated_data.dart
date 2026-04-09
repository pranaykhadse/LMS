import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/model/page_info.dart';

class PaginatedState<T> {
  final DataState<List<T>> data;
  final PageInfo? pageInfo;

  PaginatedState({required this.data, required this.pageInfo});

  PaginatedState<T> copyWith({DataState<List<T>>? data, PageInfo? pageInfo}) {
    return PaginatedState<T>(
      data: data ?? this.data,
      pageInfo: pageInfo ?? this.pageInfo,
    );
  }
}
