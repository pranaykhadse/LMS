import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
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
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final url = widget.file.url;
      final isHls = url.toLowerCase().contains('.m3u8');

      if (widget.file.file != null && !isHls) {
        // Non-HLS file (e.g. MP4) — play from local cache for offline use.
        _videoController = VideoPlayerController.file(widget.file.file!);
      } else {
        // HLS (.m3u8) streams must always play from the network URL.
        // The manifest is a text playlist; the actual video segments live on
        // the CDN and cannot be played from the locally-saved manifest file.
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) => _ErrorView(message: errorMessage),
      );

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
