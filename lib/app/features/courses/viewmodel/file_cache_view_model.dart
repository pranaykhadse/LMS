import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class FileCacheViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider<FileCacheViewModel>((ref) {
    return FileCacheViewModel();
  });

  final Map<String, FileCacheState> cachedState = {};
  final Map<String, bool> _checking = {};
  final _dio = http.Dio();

  // ── Public API ─────────────────────────────────────────────────────────────

  FileCacheState? getSync(String url) => cachedState[url];

  void ensureChecked(String url) {
    if (cachedState.containsKey(url) || (_checking[url] ?? false)) return;
    _checking[url] = true;

    if (_isHls(url)) {
      _checkHlsCache(url);
      return;
    }

    DefaultCacheManager().getFileFromCache(url).then((info) {
      _checking.remove(url);
      cachedState[url] = info != null
          // Convert package:file/File → dart:io File via path.
          ? FileCacheState(url: url, file: File(info.file.path))
          : FileCacheState(url: url);
      notifyListeners();
    });
  }

  Future<void> _checkHlsCache(String url) async {
    final localFile = await _hlsLocalFile(url);
    _checking.remove(url);
    cachedState[url] = localFile.existsSync()
        ? FileCacheState(url: url, file: localFile)
        : FileCacheState(url: url);
    notifyListeners();
  }

  Future<void> downloadFile(String url) async {
    if (url.isEmpty) return;
    if (_isHls(url)) {
      await _downloadHls(url);
    } else {
      await _downloadRegular(url);
    }
  }

  void delete(String url) {
    if (_isHls(url)) {
      _hlsLocalFile(url).then((f) {
        if (f.existsSync()) f.deleteSync();
      });
    } else {
      DefaultCacheManager().removeFile(url);
    }
    cachedState.remove(url);
    notifyListeners();
  }

  // ── Regular (non-HLS) download ─────────────────────────────────────────────

  Future<void> _downloadRegular(String url) async {
    final downloadStream = DefaultCacheManager()
        .getFileStream(url, withProgress: true)
        .asBroadcastStream();
    cachedState[url] = FileCacheState(
      url: url,
      progress: downloadStream.map(
        (e) => (e is DownloadProgress)
            ? e.downloaded / (e.totalSize ?? e.downloaded)
            : 1.0,
      ),
    );
    notifyListeners();
    final fileInfo =
        await downloadStream.firstWhere((r) => r is FileInfo) as FileInfo;
    // Convert package:file/File → dart:io File via path.
    cachedState[url] = FileCacheState(url: url, file: File(fileInfo.file.path));
    notifyListeners();
  }

  // ── HLS download: manifest → segments → local .ts file ─────────────────────

  Future<void> _downloadHls(String hlsUrl) async {
    final progressController = StreamController<double>.broadcast();
    cachedState[hlsUrl] = FileCacheState(
      url: hlsUrl,
      progress: progressController.stream,
    );
    notifyListeners();

    try {
      // 1. Fetch the manifest
      final manifestResp = await _dio.get<String>(
        hlsUrl,
        options: http.Options(responseType: http.ResponseType.plain),
      );
      String manifest = manifestResp.data ?? '';
      String baseUrl = _hlsBaseUrl(hlsUrl);

      // 2. Master playlist → pick highest-bandwidth variant
      if (manifest.contains('#EXT-X-STREAM-INF')) {
        final variantUrl = _highestBandwidthVariant(manifest, baseUrl);
        if (variantUrl != null) {
          final variantResp = await _dio.get<String>(
            variantUrl,
            options: http.Options(responseType: http.ResponseType.plain),
          );
          manifest = variantResp.data ?? '';
          baseUrl = _hlsBaseUrl(variantUrl);
        }
      }

      // 3. Parse .ts segment URLs
      final segments = _parseSegments(manifest, baseUrl);
      if (segments.isEmpty) throw Exception('No segments in HLS manifest');

      // 4. Download + concatenate into one local .ts file
      final outputFile = await _hlsLocalFile(hlsUrl);
      final sink = outputFile.openWrite();

      for (int i = 0; i < segments.length; i++) {
        final segResp = await _dio.get<List<int>>(
          segments[i],
          options: http.Options(responseType: http.ResponseType.bytes),
        );
        if (segResp.data != null) sink.add(segResp.data!);
        if (!progressController.isClosed) {
          progressController.add((i + 1) / segments.length);
        }
      }

      await sink.flush();
      await sink.close();
      progressController.close();

      cachedState[hlsUrl] = FileCacheState(url: hlsUrl, file: outputFile);
      notifyListeners();
    } catch (e) {
      progressController.close();
      cachedState.remove(hlsUrl);
      notifyListeners();
    }
  }

  // ── HLS helpers ─────────────────────────────────────────────────────────────

  static bool _isHls(String url) => url.toLowerCase().contains('.m3u8');

  static String _hlsBaseUrl(String url) {
    final i = url.lastIndexOf('/');
    return i > 0 ? url.substring(0, i + 1) : url;
  }

  static String _resolve(String seg, String base) =>
      seg.startsWith('http') ? seg : '$base${seg.trim()}';

  static String? _highestBandwidthVariant(String manifest, String base) {
    int? maxBw;
    String? best;
    final lines = manifest.split('\n');
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF')) continue;
      final next = lines[i + 1].trim();
      if (next.isEmpty || next.startsWith('#')) continue;
      final bw = int.tryParse(
        RegExp(r'BANDWIDTH=(\d+)').firstMatch(line)?.group(1) ?? '',
      );
      if (maxBw == null || (bw != null && bw > maxBw)) {
        maxBw = bw ?? 0;
        best = _resolve(next, base);
      }
    }
    return best;
  }

  static List<String> _parseSegments(String manifest, String base) =>
      manifest
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .map((l) => _resolve(l, base))
          .toList();

  static Future<File> _hlsLocalFile(String hlsUrl) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/hls_${hlsUrl.hashCode.abs()}.ts');
  }
}

class FileCacheState {
  final String url;
  final Stream<double>? progress;
  // dart:io File — works for both flutter_cache_manager downloads and HLS .ts output.
  File? file;

  FileCacheState({required this.url, this.file, this.progress});
}
