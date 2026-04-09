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
  ChewieController? chewieController;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.file.file != null) {
      _videoController = VideoPlayerController.file(widget.file.file!);
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.file.url),
      );
    }
    await _videoController!.initialize();
    chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      autoInitialize: true,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (chewieController == null) {
      return Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: chewieController!);
  }
}
