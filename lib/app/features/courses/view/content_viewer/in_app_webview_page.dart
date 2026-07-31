import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _webviewPurple = Color(0xFF5756C9);

/// Opens a URL inside the app itself (a real embedded WebView, not the
/// system browser or an SFSafariViewController/Custom Tab hand-off) - used
/// for Attend Class so the virtual session launches without ever leaving
/// the app, carrying over whatever auto-login token is embedded in the
/// session link exactly like it would in an external browser.
class InAppWebViewPage extends StatefulWidget {
  const InAppWebViewPage({super.key, required this.url, this.title});
  final String url;
  final String? title;

  // webview_flutter's macOS embedding doesn't implement the platform-view
  // "opaque" hit-test property yet, which throws UnimplementedError as soon
  // as a WebViewWidget builds there (github.com/flutter/flutter/issues/
  // 128854 and similar). macOS here is only ever a local dev/testing
  // target - the app actually ships on iOS - so fall back to the system
  // browser there instead of crashing.
  static bool get _supportsEmbeddedWebView =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static Future<void> show(
    BuildContext context, {
    required String url,
    String? title,
  }) async {
    if (!_supportsEmbeddedWebView) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppWebViewPage(url: url, title: title),
      ),
    );
  }

  @override
  State<InAppWebViewPage> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _webviewPurple,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Virtual Class'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null) WebViewWidget(controller: _controller),
          if (_error != null) _ErrorView(message: _error!, onRetry: () {
            setState(() => _error = null);
            _controller.reload();
          }),
          if (_loading && _error == null)
            const Center(child: CircularProgressIndicator(color: _webviewPurple)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

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
              'Could not load session',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _webviewPurple, foregroundColor: Colors.white),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
