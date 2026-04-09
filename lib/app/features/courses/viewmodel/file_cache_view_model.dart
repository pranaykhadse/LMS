import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileCacheViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider<FileCacheViewModel>((ref) {
    return FileCacheViewModel();
  });

  final Map<String, FileCacheState> cachedState = {};

  Future<FileCacheState> getFor(String url) async {
    if (cachedState[url] != null) return cachedState[url]!;
    final info = await DefaultCacheManager().getFileFromCache(url);
    FileCacheState cacheInfo;
    if (info == null) {
      cacheInfo = FileCacheState(url: url);
    } else {
      cacheInfo = FileCacheState(url: url, file: info.file);
    }

    cachedState[url] = cacheInfo;
    return cacheInfo;
  }

  Future<void> downloadFile(String url) async {
    if (url.isEmpty) return;
    final downloadStream =
        DefaultCacheManager()
            .getFileStream(url, withProgress: true)
            .asBroadcastStream();
    cachedState[url] = FileCacheState(
      url: url,
      progress: downloadStream.map(
        (e) =>
            (e is DownloadProgress)
                ? e.downloaded / (e.totalSize ?? e.downloaded)
                : 1.0,
      ),
    );
    notifyListeners();
    final fileInfo =
        await downloadStream.firstWhere((r) => r is FileInfo) as FileInfo;
    cachedState[url] = FileCacheState(url: url, file: fileInfo.file);
    notifyListeners();
  }

  void delete(String url) {
    cachedState[url]?.file?.deleteSync();
    cachedState.remove(url);
    notifyListeners();
  }
}

class FileCacheState {
  final String url;

  final Stream<double>? progress;
  File? file;

  FileCacheState({required this.url, this.file, this.progress});
}
