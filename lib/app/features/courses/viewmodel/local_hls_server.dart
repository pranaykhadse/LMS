import 'dart:convert';
import 'dart:io';

/// Serves a single downloaded MPEG-TS segment file as a minimal, single-entry
/// HLS playlist over a loopback HTTP server.
///
/// iOS AVFoundation refuses to open a raw concatenated `.ts` file directly
/// via `VideoPlayerController.file()` (OSStatus -12847: "media format not
/// supported") — its HLS engine only accepts MPEG-TS segments delivered over
/// HTTP as part of a playlist, never as a local file path. Serving the exact
/// same bytes back over `http://127.0.0.1:<port>/` satisfies that requirement
/// even though the data never leaves the device, letting downloaded HLS
/// videos actually play while offline.
class LocalHlsServer {
  LocalHlsServer._(this._server, this.playlistUrl);

  final HttpServer _server;
  final String playlistUrl;

  static Future<LocalHlsServer> serve(File segmentFile) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    final playlist = '#EXTM3U\n'
        '#EXT-X-VERSION:3\n'
        '#EXT-X-TARGETDURATION:86400\n'
        '#EXT-X-PLAYLIST-TYPE:VOD\n'
        '#EXTINF:86400.0,\n'
        'segment.ts\n'
        '#EXT-X-ENDLIST\n';
    final playlistBytes = utf8.encode(playlist);

    server.listen((request) async {
      final response = request.response;
      try {
        if (request.uri.path == '/segment.ts') {
          response.headers.contentType = ContentType('video', 'mp2t');
          response.headers.contentLength = await segmentFile.length();
          await response.addStream(segmentFile.openRead());
        } else {
          response.headers.contentType =
              ContentType('application', 'vnd.apple.mpegurl');
          response.headers.contentLength = playlistBytes.length;
          response.add(playlistBytes);
        }
      } finally {
        await response.close();
      }
    });

    return LocalHlsServer._(
      server,
      'http://127.0.0.1:${server.port}/playlist.m3u8',
    );
  }

  Future<void> close() => _server.close(force: true);
}
