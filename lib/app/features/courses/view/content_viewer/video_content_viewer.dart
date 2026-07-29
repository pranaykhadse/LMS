import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';

class VideoContentViewer extends StatefulWidget {
  const VideoContentViewer({super.key, required this.file});
  final FileCacheState file;
  @override
  State<VideoContentViewer> createState() => _VideoContentViewerState();
}

class _VideoContentViewerState extends State<VideoContentViewer> {
  late final Player _player;
  late final VideoController _controller;
  StreamSubscription<String>? _errorSub;
  String? _error;
  bool _mutedFallbackAttempted = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _errorSub = _player.stream.error.listen(_onPlayerError);
    _initialize();
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String get _source {
    final localFile = widget.file.file;
    return localFile != null ? localFile.path : widget.file.url;
  }

  Future<void> _initialize() async {
    if (kDebugMode) {
      final localFile = widget.file.file;
      debugPrint('[VideoContentViewer] url=${widget.file.url}');
      debugPrint('[VideoContentViewer] source=$_source (isLocalFile=${localFile != null})');
      if (localFile != null) {
        final exists = localFile.existsSync();
        debugPrint('[VideoContentViewer] local file exists=$exists');
        if (exists) {
          final length = localFile.lengthSync();
          final headBytes = localFile.openSync().readSync(16);
          debugPrint('[VideoContentViewer] local file length=$length bytes');
          debugPrint('[VideoContentViewer] local file first 16 bytes (hex)='
              '${headBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        }
      }
    }
    try {
      // media_kit (libmpv) decodes every format this app serves — MP4,
      // WebM/VP9, and HLS (.m3u8, whether remote or a locally downloaded
      // manifest + segments) — through the same unified API, on every
      // platform including iOS, where AVFoundation supports none of the
      // WebM content and only remote HLS.
      await _player.open(Media(_source));
    } catch (e) {
      if (kDebugMode) debugPrint('[VideoContentViewer] open() threw: $e');
      _handleError(e.toString());
    }
  }

  void _onPlayerError(String message) {
    if (kDebugMode) debugPrint('[VideoContentViewer] player error stream: $message');
    _handleError(message);
  }

  void _handleError(String message) {
    // iOS Simulator's virtual audio device fails to initialize (confirmed
    // media_kit issue, real devices are unaffected). Rather than show a
    // hard error for something that's actually a working video, retry once
    // with audio disabled so playback still works (silently) wherever the
    // audio device genuinely can't be opened.
    if (!_mutedFallbackAttempted &&
        message.toLowerCase().contains('audio device')) {
      _mutedFallbackAttempted = true;
      _retryMuted();
      return;
    }
    if (mounted) setState(() => _error = message);
  }

  Future<void> _retryMuted() async {
    try {
      await _player.setAudioTrack(AudioTrack.no());
      await _player.open(Media(_source));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _ErrorView(message: _error!);
    return Video(controller: _controller);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Could not play video',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
