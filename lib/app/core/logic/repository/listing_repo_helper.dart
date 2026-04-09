import 'package:lms/app/core/logic/repository/repo_network_helper.dart';
import 'package:lms/app/core/model/data_response.dart';

mixin ListingRepoHelper<T> on RepoNetworkHelper {
  Future<DataResponse<T>> getData(
    int pageNo, {
    Map<String, dynamic>? queryParams,
  }) async {
    var queryParameters =
        (queryParams ?? {})..addAll({"page": pageNo.toString()});
    var string =
        Uri(path: endPoint, queryParameters: queryParameters).toString();
    final response = await getRequest(
      // "$endPoint?page=$pageNo"
      string,
      cacheType: RequestCacheType.fetch,
    );

    return DataResponse.parse(response, fromMap);
  }

  String get endPoint;
  T Function(Map) get fromMap;
}
