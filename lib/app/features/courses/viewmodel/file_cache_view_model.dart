import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Per-content-item download + play widget — Netflix style.
///
/// States:
///  ① Online  + not downloaded  → [⬇ Download Video/PDF / Download Recording]
///  ② Downloading               → progress ring + % label
///  ③ Downloaded                → [▶ Play / 📄 Open]  🗑️ delete
///  ④ Offline  + not downloaded → disabled "Not available offline" pill
class FileCacheViewModel extends ChangeNotifier {
  static final provider = ChangeNotifierProvider<FileCacheViewModel>((ref) {
    return FileCacheViewModel();
  });

  final Map<String, FileCacheState> cachedState = {};

  // Tracks which URLs have an in-flight disk check so we never double-fire.
  final Map<String, bool> _checking = {};

  // Reusable Dio for HLS segment downloads — CloudFront is public, no auth needed.
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
          ? FileCacheState(url: url, file: info.file)
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
      // Delete the concatenated .ts file from the documents directory.
      _hlsLocalFile(url).then((f) {
        if (f.existsSync()) f.deleteSync();
      });
    } else {
      DefaultCacheManager().removeFile(url);
    }
    cachedState.remove(url);
    notifyListeners();
  }

  // ── Regular (non-HLS) download — unchanged ─────────────────────────────────

  Future<void> _downloadRegular(String url) async {
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

      // 2. If master playlist (multiple quality variants), use highest bandwidth
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

      // 3. Parse media segment URLs (.ts lines, skip all # lines)
      final segments = _parseSegments(manifest, baseUrl);
      if (segments.isEmpty) throw Exception('No segments found in HLS manifest');
      debugPrint('[FileCacheVM] HLS: downloading ${segments.length} segments for $hlsUrl');

      // 4. Download each segment and concatenate into one local .ts file
      final outputFile = await _hlsLocalFile(hlsUrl);
      final sink = outputFile.openWrite(); // truncates any existing file

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
      debugPrint('[FileCacheVM] HLS download complete → ${outputFile.path}');
    } catch (e) {
      debugPrint('[FileCacheVM] HLS download error: $e');
      progressController.close();
      cachedState.remove(hlsUrl);
      notifyListeners();
    }
  }

  // ── HLS static helpers ──────────────────────────────────────────────────────

  static bool _isHls(String url) => url.toLowerCase().contains('.m3u8');

  static String _hlsBaseUrl(String url) {
    final i = url.lastIndexOf('/');
    return i > 0 ? url.substring(0, i + 1) : url;
  }

  static String _resolve(String segment, String base) =>
      segment.startsWith('http') ? segment : '$base${segment.trim()}';

  /// Returns the variant URL with the highest BANDWIDTH from a master playlist.
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

  /// Extracts .ts segment URLs from a media playlist.
  static List<String> _parseSegments(String manifest, String base) =>
      manifest
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .map((l) => _resolve(l, base))
          .toList();

  /// Local file path for the downloaded HLS recording.
  /// Uses a hash of the URL so the same recording reuses the same file.
  static Future<File> _hlsLocalFile(String hlsUrl) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/hls_${hlsUrl.hashCode.abs()}.ts');
  }
}

class FileCacheState {
  final String url;
  final Stream<double>? progress;
  File? file;

  FileCacheState({required this.url, this.file, this.progress});
}
