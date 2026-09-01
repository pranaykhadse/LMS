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

bool _alwaysFalse() => false;

class RepoNetworkConfig {
  final String url;
  final String? authToken;
  final InternetConnectionProvider connectionProvider;
  final RequestCacheProvider? requestCacheProvider;
  /// Reads the current value of the user-facing "Offline Mode" toggle at
  /// call time. When true, the app behaves as offline for its own API calls
  /// regardless of real device connectivity. A getter rather than a frozen
  /// bool so the config object doesn't need to be rebuilt (tearing down
  /// already-successful repositories/viewmodels) every time the toggle
  /// flips — only the next request checks it.
  final bool Function() isManualOffline;

  /// Called when a request comes back 401 - should attempt to obtain a
  /// fresh access token (e.g. via the auto-login API) and return it, or
  /// return null/throw if that isn't possible (e.g. the auto-login token
  /// itself has expired). Null means "give up" - the original 401 is left
  /// to propagate as a normal UnauthorizedException, which is what drives
  /// the app's existing "session expired, log in again" screens.
  final Future<String?> Function()? refreshToken;

  RepoNetworkConfig({
    required this.url,
    this.authToken,
    required this.connectionProvider,
    this.requestCacheProvider,
    bool Function()? isManualOffline,
    this.refreshToken,
  }) : isManualOffline = isManualOffline ?? _alwaysFalse;

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
  // No timeout was ever configured here, so a request that never gets a
  // response (server hang, dropped connection, etc.) left the UI stuck on
  // its loading spinner indefinitely instead of surfacing an error.
  Dio get dio {
    final client = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: header,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
    ));

    final refreshToken = config.refreshToken;
    if (refreshToken != null) {
      client.interceptors.add(InterceptorsWrapper(
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          // Only ever retried once per request - if the retried call also
          // comes back 401 (the refreshed token turned out invalid too, or
          // the refresh silently returned a stale one), don't loop forever.
          final alreadyRetried =
              error.requestOptions.extra['_retriedAfterTokenRefresh'] == true;
          if (!isUnauthorized || alreadyRetried) {
            return handler.next(error);
          }

          String? newToken;
          try {
            newToken = await refreshToken();
          } catch (_) {
            newToken = null;
          }
          if (newToken == null || newToken.isEmpty) {
            return handler.next(error);
          }

          try {
            final retryOptions = error.requestOptions;
            retryOptions.extra['_retriedAfterTokenRefresh'] = true;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await client.fetch(retryOptions);
            return handler.resolve(response);
          } catch (_) {
            return handler.next(error);
          }
        },
      ));
    }

    return client;
  }
  bool get isOffline =>
      config.isManualOffline() || config.connectionProvider.isConnected == false;
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

  /// RepoNetworkConfig.header always bakes in "content-type:
  /// application/json" at the Dio-instance level, for every request - fine
  /// for the JSON bodies every endpoint sent until now, but once a body
  /// becomes FormData (a multipart upload), that stale json content-type
  /// header survives and Dio's transformer tries to JSON-encode/cast the
  /// FormData object as a Map, throwing "type 'FormData' is not a subtype
  /// of type 'Map<dynamic, dynamic>?'" before the request ever reaches the
  /// network. Per-request Options.contentType (built from the FormData's
  /// own boundary) takes precedence over that baked-in header and fixes it.
  @protected
  Options? optionsFor(dynamic body, Options? options) {
    if (body is! FormData) return options;
    return (options ?? Options()).copyWith(
      contentType: 'multipart/form-data; boundary=${body.boundary}',
    );
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
    if (type == RequestCacheType.none) {
      throw Exception("No Internet");
    }
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
        options: optionsFor(body, options),
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      await cacheRequest(
        CachableRequest(
          path: url,
          params: queryParameters,
          // CachableRequest.body is Map<dynamic, dynamic>? - a FormData
          // body (any multipart request, e.g. a file upload) isn't a Map
          // and blows up right at this constructor call with "type
          // 'FormData' is not a subtype of type 'Map<dynamic, dynamic>?'",
          // even when cacheType is none and the cache is never actually
          // written. FormData also isn't meaningfully offline-cacheable
          // (it holds raw file bytes, not JSON), so it's dropped here
          // rather than cached.
          body: body is Map ? body : null,
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
        options: optionsFor(body, options),
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
        options: optionsFor(body, options),
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
        options: optionsFor(body, options),
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
