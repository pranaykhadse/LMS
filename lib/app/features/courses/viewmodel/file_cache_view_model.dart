import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as http;
import 'package:flutter/foundation.dart';
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
    final manifestFile = await _hlsManifestFile(url);
    _checking.remove(url);
    cachedState[url] = manifestFile.existsSync()
        ? FileCacheState(url: url, file: manifestFile)
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
      _hlsLocalDir(url).then((d) {
        if (d.existsSync()) d.deleteSync(recursive: true);
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
    final file = File(fileInfo.file.path);
    await _hideFromFileExplorer(file.path);
    cachedState[url] = FileCacheState(url: url, file: file);
    notifyListeners();
  }

  /// Best-effort: mark a downloaded file/directory as OS-hidden so it
  /// doesn't show up in normal File Explorer/Finder browsing. Doesn't
  /// change the file's path or content, so it's safe to call on files
  /// flutter_cache_manager still owns and tracks internally.
  static Future<void> _hideFromFileExplorer(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('attrib', ['+h', path]);
      } else if (Platform.isMacOS) {
        await Process.run('chflags', ['hidden', path]);
      }
    } catch (_) {}
  }

  // ── HLS download: manifest → individual segment files + local manifest ─────
  //
  // Each segment is saved as its own file, and a local .m3u8 playlist is
  // written referencing them by relative filename — mirroring the original
  // remote HLS structure exactly (same segment count, same per-segment
  // EXTINF durations). media_kit's player opens this local playlist file
  // directly and resolves the relative segment paths itself, no local HTTP
  // server needed.

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

      // 3. Parse segment URLs + their durations
      final segments = _parseSegments(manifest, baseUrl);
      if (segments.isEmpty) throw Exception('No segments in HLS manifest');

      // 4. Download each segment to its own local file
      final dir = await _hlsLocalDir(hlsUrl);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        await _hideFromFileExplorer(dir.path);
      }

      final localPlaylist = StringBuffer()
        ..writeln('#EXTM3U')
        ..writeln('#EXT-X-VERSION:3')
        ..writeln('#EXT-X-PLAYLIST-TYPE:VOD')
        ..writeln(
          '#EXT-X-TARGETDURATION:'
          '${segments.map((s) => s.duration).reduce((a, b) => a > b ? a : b).ceil()}',
        );

      for (int i = 0; i < segments.length; i++) {
        final segResp = await _dio.get<List<int>>(
          segments[i].url,
          options: http.Options(responseType: http.ResponseType.bytes),
        );
        final segmentName = 'segment_${i.toString().padLeft(5, '0')}.ts';
        if (segResp.data != null) {
          await File('${dir.path}/$segmentName').writeAsBytes(segResp.data!);
        }
        localPlaylist
          ..writeln('#EXTINF:${segments[i].duration},')
          ..writeln(segmentName);
        if (!progressController.isClosed) {
          progressController.add((i + 1) / segments.length);
        }
      }
      localPlaylist.writeln('#EXT-X-ENDLIST');

      final manifestFile = File('${dir.path}/playlist.m3u8');
      await manifestFile.writeAsString(localPlaylist.toString());
      progressController.close();

      cachedState[hlsUrl] = FileCacheState(url: hlsUrl, file: manifestFile);
      notifyListeners();
    } catch (e) {
      if (!progressController.isClosed) progressController.close();
      final dir = await _hlsLocalDir(hlsUrl);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
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

  static List<_HlsSegment> _parseSegments(String manifest, String base) {
    final segments = <_HlsSegment>[];
    double pendingDuration = 6.0;
    for (final raw in manifest.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF:')) {
        final durStr = line.substring(8).split(',').first;
        pendingDuration = double.tryParse(durStr) ?? pendingDuration;
        continue;
      }
      if (line.startsWith('#')) continue;
      segments.add(_HlsSegment(url: _resolve(line, base), duration: pendingDuration));
    }
    return segments;
  }

  static Future<Directory> _hlsLocalDir(String hlsUrl) async {
    // Application *support* dir (not Documents) — Documents is a
    // user-visible, easily-browsable folder on desktop platforms, which let
    // downloaded segments/playlists show up in File Explorer/Finder and be
    // opened directly outside the app.
    final dir = await getApplicationSupportDirectory();
    return Directory('${dir.path}/hls_${hlsUrl.hashCode.abs()}');
  }

  static Future<File> _hlsManifestFile(String hlsUrl) async {
    final dir = await _hlsLocalDir(hlsUrl);
    return File('${dir.path}/playlist.m3u8');
  }
}

class _HlsSegment {
  const _HlsSegment({required this.url, required this.duration});
  final String url;
  final double duration;
}

class FileCacheState {
  final String url;
  final Stream<double>? progress;
  // dart:io File — works for both flutter_cache_manager downloads and the
  // local HLS playlist.m3u8 (its sibling segment files live alongside it).
  File? file;

  FileCacheState({required this.url, this.file, this.progress});
}
