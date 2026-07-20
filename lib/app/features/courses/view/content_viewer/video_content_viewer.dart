import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/local_hls_server.dart';
import 'package:video_player/video_player.dart';

class VideoContentViewer extends StatefulWidget {
  const VideoContentViewer({super.key, required this.file});
  final FileCacheState file;
  @override
  State<VideoContentViewer> createState() => _VideoContentViewerState();
}

class _VideoContentViewerState extends State<VideoContentViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  LocalHlsServer? _localServer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _localServer?.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final isHls = widget.file.url.toLowerCase().contains('.m3u8');
      final localFile = widget.file.file;

      if (localFile != null && isHls) {
        await _initializeFromLocalHls(localFile);
      } else if (localFile != null) {
        // Non-HLS local file (.mp4 etc.) — play from disk.
        _videoController = VideoPlayerController.file(localFile);
        await _videoController!.initialize();
      } else {
        // No local copy: stream from network.
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.file.url),
        );
        await _videoController!.initialize();
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) =>
            _ErrorView(message: errorMessage),
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _initializeFromLocalHls(File localFile) async {
    try {
      // Serve the downloaded segment via a loopback HTTP server so iOS
      // AVFoundation's HLS engine can open it (it refuses raw local .ts
      // files, but plays the identical bytes fine over HTTP).
      _localServer = await LocalHlsServer.serve(localFile);
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(_localServer!.playlistUrl),
      );
      await _videoController!.initialize();
    } catch (_) {
      // Local playback failed for some other reason — fall back to
      // streaming the original URL (works if we're actually online).
      await _localServer?.close();
      _localServer = null;
      await _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.file.url),
      );
      await _videoController!.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _ErrorView(message: _error!);
    if (_chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewieController!);
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
