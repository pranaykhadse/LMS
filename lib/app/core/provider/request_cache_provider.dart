import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/local_storage_provider.dart';

import '../logic/repository/cached_request_repository.dart';

class RequestCacheProvider {
  static final provider = Provider<RequestCacheProvider>((ref) {
    return RequestCacheProvider(
      localStorage: ref.watch(LocalStorage.provider),
      connectionProvider: ref.watch(InternetConnectionProvider.provider),
      ref: ref,
    );
  });

  final LocalStorage localStorage;
  final InternetConnectionProvider connectionProvider;
  final Ref ref;

  RequestCacheProvider({
    required this.localStorage,
    required this.connectionProvider,
    required this.ref,
  }) {
    connectionProvider.addListener(onConnectivityChanged);
  }

  dispose() {
    connectionProvider.removeListener(onConnectivityChanged);
  }

  Future<void> cacheGetRequest(CachableRequest request) async {
    await localStorage.setString("get_cache_${request.path}", request.toJson());
  }

  Future<CachableRequest?> getCachedGetRequest(String path) async {
    final cachedData = await localStorage.getString("get_cache_$path");
    if (cachedData != null) {
      return CachableRequest.fromJson(cachedData);
    }
    return null;
  }

  Future<List<CachableRequest>> getCachedStoreRequest() async {
    final cachedData = await localStorage.getString("store_cache");
    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList.map((json) => CachableRequest.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> cacheStoreRequest(CachableRequest request) async {
    final currentCache = await getCachedStoreRequest();
    currentCache.add(request);
    final List<String> jsonList =
        currentCache.map((request) => request.toJson()).toList();
    await localStorage.setString("store_cache", jsonEncode(jsonList));
  }

  Future<void> onConnectivityChanged(bool isConnected) async {
    if (!isConnected) return;
    final cachedData = await getCachedStoreRequest();
    final failedRequest = <CachableRequest>[];
    for (var request in cachedData) {
      try {
        await ref
            .read(CachedRequestRepository.provider)
            .sendCachedRequest(request);
      } catch (e) {}
    }
    await localStorage.setString(
      "store_cache",
      jsonEncode(failedRequest.map((e) => e.toJson()).toList()),
    );
  }
}

class CachableRequest {
  final String path;
  final Map<dynamic, dynamic>? params;
  final Map<dynamic, dynamic>? body;
  final dynamic response;

  CachableRequest({
    required this.path,
    this.params,
    this.body,
    required this.response,
  });

  String toJson() {
    return jsonEncode({
      'path': path,
      'params': params,
      'body': body,
      'response': response,
    });
  }

  factory CachableRequest.fromJson(String jsonString) {
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    return CachableRequest(
      path: jsonMap['path'],
      params:
          jsonMap['params'] != null
              ? Map<String, dynamic>.from(jsonMap['params'])
              : null,
      body:
          jsonMap['body'] != null
              ? Map<String, dynamic>.from(jsonMap['body'])
              : null,
      response: jsonMap['response'],
    );
  }
}
