import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' as http;
import 'package:flutter/foundation.dart';
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
    _checkRegularCache(url);
  }

  Future<void> _checkRegularCache(String url) async {
    final file = await _regularFile(url);
    _checking.remove(url);
    cachedState[url] = file.existsSync()
        ? FileCacheState(url: url, file: file)
        : FileCacheState(url: url);
    notifyListeners();
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
      _regularFile(url).then((f) {
        if (f.existsSync()) f.deleteSync();
      });
    }
    cachedState.remove(url);
    notifyListeners();
  }

  /// Decrypts the downloaded (encrypted, on-disk) content for [url] into a
  /// throwaway plaintext copy under the OS temp directory, for this app's
  /// own viewer to open. Returns null if [url] isn't downloaded. Call
  /// [cleanupViewing] once the viewer closes to remove the plaintext copy
  /// again - it must not linger on disk.
  Future<File?> prepareForViewing(String url) async {
    final cached = cachedState[url]?.file;
    if (cached == null || !cached.existsSync()) return null;
    if (_isHls(url)) return _decryptHlsForViewing(url);
    final encrypted = await cached.readAsBytes();
    final tempFile = await _viewingFile(url);
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsBytes(_OfflineCipher.apply(encrypted));
    return tempFile;
  }

  /// Deletes every plaintext copy ever created by [prepareForViewing],
  /// regardless of url - call once at app startup in case a previous run
  /// crashed/was force-quit before its own [cleanupViewing] ran.
  static Future<void> clearAllViewing() async {
    try {
      final dir = await getTemporaryDirectory();
      final viewingDir = Directory('${dir.path}/lms_viewing');
      if (viewingDir.existsSync()) await viewingDir.delete(recursive: true);
    } catch (_) {}
  }

  /// Deletes the plaintext copy created by [prepareForViewing] for [url].
  Future<void> cleanupViewing(String url) async {
    try {
      if (_isHls(url)) {
        final dir = await _hlsViewingDir(url);
        if (dir.existsSync()) await dir.delete(recursive: true);
      } else {
        final file = await _viewingFile(url);
        if (file.existsSync()) await file.delete();
      }
    } catch (_) {}
  }

  Future<File> _decryptHlsForViewing(String hlsUrl) async {
    final srcDir = await _hlsLocalDir(hlsUrl);
    final destDir = await _hlsViewingDir(hlsUrl);
    if (!destDir.existsSync()) destDir.createSync(recursive: true);
    await for (final entity in srcDir.list()) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final name = entity.uri.pathSegments.last;
      await File('${destDir.path}/$name').writeAsBytes(_OfflineCipher.apply(bytes));
    }
    return File('${destDir.path}/playlist.m3u8');
  }

  // ── Regular (non-HLS) download ─────────────────────────────────────────────
  //
  // Downloaded manually (not via flutter_cache_manager) so every byte written
  // to disk is encrypted first - the file is real and visible in a normal
  // file browser, but its contents are meaningless to any app other than
  // this one, which decrypts on demand via [prepareForViewing].

  Future<void> _downloadRegular(String url) async {
    final progressController = StreamController<double>.broadcast();
    cachedState[url] = FileCacheState(url: url, progress: progressController.stream);
    notifyListeners();

    try {
      final response = await _dio.get<List<int>>(
        url,
        options: http.Options(responseType: http.ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0 && !progressController.isClosed) {
            progressController.add(received / total);
          }
        },
      );
      final bytes = response.data ?? const <int>[];
      final file = await _regularFile(url);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(_OfflineCipher.apply(bytes));
      if (!progressController.isClosed) progressController.close();
      cachedState[url] = FileCacheState(url: url, file: file);
    } catch (_) {
      if (!progressController.isClosed) progressController.close();
      cachedState.remove(url);
    }
    notifyListeners();
  }

  static Future<File> _regularFile(String url) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/downloads/${url.hashCode.abs()}.enc');
  }

  static Future<File> _viewingFile(String url) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/lms_viewing/${url.hashCode.abs()}');
  }

  // ── HLS download: manifest → individual segment files + local manifest ─────
  //
  // Each segment is saved as its own encrypted file, and a local .m3u8
  // playlist is written referencing them by relative filename - mirroring
  // the original remote HLS structure exactly (same segment count, same
  // per-segment EXTINF durations).

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

      // 4. Download each segment, encrypted, to its own local file
      final dir = await _hlsLocalDir(hlsUrl);
      if (!dir.existsSync()) dir.createSync(recursive: true);

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
          await File('${dir.path}/$segmentName')
              .writeAsBytes(_OfflineCipher.apply(segResp.data!));
        }
        localPlaylist
          ..writeln('#EXTINF:${segments[i].duration},')
          ..writeln(segmentName);
        if (!progressController.isClosed) {
          progressController.add((i + 1) / segments.length);
        }
      }
      localPlaylist.writeln('#EXT-X-ENDLIST');

      // The manifest itself is encrypted too - it's only ever read back
      // through prepareForViewing's decrypt step, never played directly.
      final manifestFile = File('${dir.path}/playlist.m3u8');
      await manifestFile.writeAsBytes(
        _OfflineCipher.apply(utf8.encode(localPlaylist.toString())),
      );
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
    final dir = await getApplicationSupportDirectory();
    return Directory('${dir.path}/hls_${hlsUrl.hashCode.abs()}');
  }

  static Future<Directory> _hlsViewingDir(String hlsUrl) async {
    final dir = await getTemporaryDirectory();
    return Directory('${dir.path}/lms_viewing/hls_${hlsUrl.hashCode.abs()}');
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

/// Keyed XOR stream cipher applied to every byte written to disk for
/// offline content. It is the same operation both ways (encrypt/decrypt).
/// This is not meant to withstand a determined attacker inspecting app
/// binaries - it's meant to satisfy the actual requirement: a file opened
/// directly by an unrelated app (a video player, PDF reader, image viewer)
/// sees meaningless bytes and fails to render it, while this app decrypts
/// on demand for its own viewers.
class _OfflineCipher {
  static const List<int> _key = [
    0x4c, 0x4d, 0x53, 0x2d, 0x4f, 0x66, 0x66, 0x6c,
    0x69, 0x6e, 0x65, 0x2d, 0xa1, 0x3f, 0x7c, 0x92,
    0x5e, 0x11, 0xc4, 0x08, 0x6b, 0x2a, 0xd7, 0x99,
    0x33, 0xf0, 0x17, 0x84, 0x5d, 0x6c, 0xe2, 0x91,
  ];

  static Uint8List apply(List<int> bytes) {
    final out = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      out[i] = bytes[i] ^ _key[i % _key.length];
    }
    return out;
  }
}

class FileCacheState {
  final String url;
  final Stream<double>? progress;
  // dart:io File pointing at the *encrypted* on-disk copy. Never opened
  // directly by a viewer - see [FileCacheViewModel.prepareForViewing].
  File? file;

  FileCacheState({required this.url, this.file, this.progress});
}
