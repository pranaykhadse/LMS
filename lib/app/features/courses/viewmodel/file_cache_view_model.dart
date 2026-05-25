import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileCacheViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider<FileCacheViewModel>((ref) {
    return FileCacheViewModel();
  });

  final Map<String, FileCacheState> cachedState = {};

  // Tracks which URLs have an in-flight disk check so we never double-fire.
  final Map<String, bool> _checking = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the known [FileCacheState] for [url] synchronously, or `null`
  /// when the disk check has not completed yet.
  FileCacheState? getSync(String url) => cachedState[url];

  /// Kicks off an async disk-cache check for [url] if one is not already
  /// running.  Calls [notifyListeners] when the result is ready so every
  /// widget that watches this provider rebuilds with the correct state.
  ///
  /// Safe to call from `build()` — it is idempotent and never mutates state
  /// synchronously.
  void ensureChecked(String url) {
    if (cachedState.containsKey(url) || (_checking[url] ?? false)) return;
    _checking[url] = true;
    DefaultCacheManager().getFileFromCache(url).then((info) {
      _checking.remove(url);
      cachedState[url] = info != null
          ? FileCacheState(url: url, file: info.file)
          : FileCacheState(url: url);
      notifyListeners();
    });
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
    // Remove through the cache manager so its internal database stays in sync.
    // Fire-and-forget is fine here — the UI updates immediately.
    DefaultCacheManager().removeFile(url);
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
