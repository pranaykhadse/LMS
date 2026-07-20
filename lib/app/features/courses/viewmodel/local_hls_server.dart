import 'dart:io';

/// Serves a downloaded HLS playlist + its sibling segment files over a
/// loopback HTTP server, exactly mirroring the original remote structure.
///
/// iOS AVFoundation refuses to open local `.ts`/`.m3u8` files directly via
/// `VideoPlayerController.file()` — its HLS engine only accepts content
/// delivered over HTTP as part of a playlist. Serving the exact same files
/// back over `http://127.0.0.1:<port>/` satisfies that requirement even
/// though the data never leaves the device, letting downloaded HLS videos
/// actually play while offline.
class LocalHlsServer {
  LocalHlsServer._(this._server, this.playlistUrl);

  final HttpServer _server;
  final String playlistUrl;

  /// [manifestFile] is the local playlist.m3u8; its segment files (referenced
  /// by relative filename inside it) must live in the same directory.
  static Future<LocalHlsServer> serve(File manifestFile) async {
    final dir = manifestFile.parent;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((request) async {
      final response = request.response;
      try {
        final name = request.uri.pathSegments.isNotEmpty
            ? request.uri.pathSegments.last
            : '';
        final target = File('${dir.path}/$name');
        if (name.isEmpty || !target.existsSync()) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        response.headers.contentType = name.endsWith('.m3u8')
            ? ContentType('application', 'vnd.apple.mpegurl')
            : ContentType('video', 'mp2t');
        response.headers.contentLength = await target.length();
        await response.addStream(target.openRead());
      } finally {
        await response.close();
      }
    });

    return LocalHlsServer._(
      server,
      'http://127.0.0.1:${server.port}/${manifestFile.uri.pathSegments.last}',
    );
  }

  Future<void> close() => _server.close(force: true);
}
