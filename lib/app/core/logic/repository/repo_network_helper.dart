import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../provider/internet_connection_provider.dart';
import '../../provider/request_cache_provider.dart';
import 'error.dart';

class TypeSerializer<T> {
  Future<dynamic> Function(T data) serializer;
  TypeSerializer({required this.serializer});

  Type get type => T;

  bool canSerialize(dynamic data) {
    return data is T;
  }

  Future<dynamic> serialize(dynamic data) async {
    if (canSerialize(data)) {
      return serializer(data as T);
    }
    return null;
  }
}

enum RequestCacheType { fetch, post, none }

class RepoNetworkConfig {
  final String url;
  final String? authToken;
  final InternetConnectionProvider connectionProvider;
  final RequestCacheProvider? requestCacheProvider;
  RepoNetworkConfig({
    required this.url,
    this.authToken,
    required this.connectionProvider,
    this.requestCacheProvider,
  });

  String get baseUrl => url.endsWith("/") ? url : "$url/";

  Map<String, String> get header {
    var map = {"content-type": "application/json"};
    if (authToken?.isNotEmpty ?? false) {
      map["Authorization"] = "Bearer $authToken";
    }
    return map;
  }
}

mixin RepoNetworkHelper {
  RepoNetworkConfig get config;
  String get baseUrl => config.baseUrl;
  Map<String, String> get header => config.header;
  Dio get dio => Dio(BaseOptions(baseUrl: baseUrl, headers: header));
  bool get isOffline => config.connectionProvider.isConnected == false;
  @protected
  Future<dynamic> convertToNetworkBody(dynamic data) async {
    final converted = await serializeToNetwork(data);

    bool shouldWrap = shouldUseFormData(converted);

    if (shouldWrap) {
      prepareFormData(converted);
      return FormData.fromMap(converted);
    }
    return converted;
  }

  void prepareFormData(data) {
    if (data is Map) {
      for (var key in data.keys.toList()) {
        final value = data[key];

        if (value is Iterable) {
          for (var i = 0; i < value.length; i++) {
            data[key + "[$i]"] = value.elementAt(i);
          }
          data[key] = null;
        }
      }
    }
  }

  @protected
  bool shouldUseFormData(dynamic data) {
    if (data is MultipartFile) return true;

    if (data is Map) {
      // bool shouldUse = false;
      for (var key in data.keys) {
        final shouldUse = shouldUseFormData(data[key]);
        if (shouldUse) return true;
      }
    }

    if (data is Iterable) {
      for (var element in data) {
        final shouldUse = shouldUseFormData(element);
        if (shouldUse) return true;
      }
    }
    return false;
  }

  @protected
  Future<dynamic> serializeToNetwork(dynamic data) async {
    if (data == null) return data;
    if (data is Map) {
      final keys = data.keys.toList();
      for (var element in keys) {
        final value = data[element];
        {
          var value2 = await serializeToNetwork(value);
          // if (value2 != null) {
          if (value2 != data[element]) {
            data[element] = value2;
          }
          // }
        }
      }

      // data.removeWhere((key, value) => value == null);
    }

    if (data is Iterable) {
      final newList = [];
      for (var i = 0; i < data.length; i++) {
        var value = await serializeToNetwork(data.elementAt(i));
        if (value != null) {
          newList.add(value);
        }
      }
      return newList.isEmpty ? [] : newList;
    }
    var serializer = typeSerializers.firstWhereOrNull(
      (element) => element.canSerialize(data),
    );
    return (serializer == null ? data : serializer.serialize(data));
  }

  List<TypeSerializer<dynamic>> get typeSerializers => [
    TypeSerializer<DateTime>(
      serializer: (data) async {
        return data.toIso8601String();
      },
    ),
  ];

  Future<void> cacheRequest(
    CachableRequest request,
    RequestCacheType type,
  ) async {
    if (config.requestCacheProvider != null) {
      switch (type) {
        case RequestCacheType.fetch:
          await config.requestCacheProvider!.cacheGetRequest(request);
          break;
        case RequestCacheType.post:
          await config.requestCacheProvider!.cacheStoreRequest(request);
          break;
        default:
          break;
      }
    }
  }

  Future<dynamic> performOfflineRequest(
    CachableRequest request,
    RequestCacheType type,
  ) async {
    if (type == RequestCacheType.none) throw Exception("No Internet");
    if (config.requestCacheProvider != null) {
      switch (type) {
        case RequestCacheType.fetch:
          final cachedResponse = await config.requestCacheProvider!
              .getCachedGetRequest(request.path);
          if (cachedResponse?.response != null) {
            return cachedResponse?.response;
          } else {
            throw Exception("No Internet");
          }
        case RequestCacheType.post:
          // final cachedResponse =
          await config.requestCacheProvider!.cacheStoreRequest(request);
          return null;
        //  cachedResponse;
        // } else {
        // }
        default:
          throw Exception("No Internet");
      }
    }
  }

  // @protected
  Future<dynamic> post(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    RequestCacheType cacheType = RequestCacheType.fetch,
  }) async {
    try {
      if (isOffline) {
        return performOfflineRequest(
          CachableRequest(
            path: url,
            params: queryParameters,
            body: data,
            response: null,
          ),
          cacheType,
        );
        // if (cacheType == RequestCacheType.fetch &&
        //     config.requestCacheProvider != null) {
        //   final cachedResponse =
        //       await config.requestCacheProvider!.getCachedGetRequest(url);
        //   if (cachedResponse != null) {
        //     return cachedResponse.response;
        //   } else {
        //     throw Exception("No Internet");
        //   }
        // }
      }
      final body = await convertToNetworkBody(data);
      final response = await dio.post(
        url,
        data: body,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      await cacheRequest(
        CachableRequest(
          path: url,
          params: queryParameters,
          body: body,
          response: response.data,
        ),
        cacheType,
      );
      return response.data;
    } catch (e) {
      handelException(e);
      rethrow;
    }
  }

  // @protected
  Future<dynamic> getRequest(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    RequestCacheType cacheType = RequestCacheType.none,
  }) async {
    if (isOffline) {
      return performOfflineRequest(
        CachableRequest(
          path: url,
          params: queryParameters,
          body: null,
          response: null,
        ),
        cacheType,
      );
    }
    try {
      final response = await dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      await cacheRequest(
        CachableRequest(
          path: url,
          params: queryParameters,
          body: null,
          response: response.data,
        ),
        cacheType,
      );
      return response.data;
    } catch (e) {
      handelException(e);
      rethrow;
    }
  }

  // @protected
  Future<dynamic> put(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    RequestCacheType cacheType = RequestCacheType.none,
  }) async {
    try {
      final body = await convertToNetworkBody(data);
      final response = await dio.put(
        url,
        data: body,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data;
    } catch (e) {
      handelException(e);
      rethrow;
    }
  }

  // @protected
  Future<dynamic> deleteRequest(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      final body = await convertToNetworkBody(data);
      final response = await dio.delete(
        url,
        data: body,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data;
    } catch (e) {
      handelException(e);
      rethrow;
    }
  }

  // @protected
  Future<dynamic> patch(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    RequestCacheType cacheType = RequestCacheType.none,
  }) async {
    try {
      final body = await convertToNetworkBody(data);
      final response = await dio.patch(
        url,
        data: body,
        queryParameters: {}..addAll(queryParameters ?? {}),
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response.data;
    } catch (e) {
      handelException(e);
      rethrow;
    }
  }
}
