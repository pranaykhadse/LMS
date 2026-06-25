import 'dart:convert';
import 'dart:developer' as dev;

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

    // LOG: raw API response for analysis
    final payload = response is Map ? response['payload'] : null;
    dev.log('[API:$endPoint] page=$pageNo total=${response is Map ? response['total'] : '?'} items=${payload is List ? payload.length : 0}', name: 'LMS');
    if (payload is List && payload.isNotEmpty) {
      dev.log('[API:$endPoint] FIRST ITEM: ${jsonEncode(payload.first)}', name: 'LMS');
      if (payload.length > 1) {
        dev.log('[API:$endPoint] SECOND ITEM: ${jsonEncode(payload[1])}', name: 'LMS');
      }
    }

    return DataResponse.parse(response, fromMap);
  }

  String get endPoint;
  T Function(Map) get fromMap;
}
