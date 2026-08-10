import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/hover_builder.dart';
import 'package:lms/app/core/views/elements/safe_pop.dart';
import 'package:lms/app/features/courses/repository/redirect_login_repository.dart';

const _webviewPurple = FigmaTokens.primaryPurple;

/// Opens a URL inside the app itself (a real embedded WebView, not the
/// system browser or an SFSafariViewController/Custom Tab hand-off) - used
/// for Attend Class so the virtual session launches without ever leaving
/// the app, carrying over whatever auto-login token is embedded in the
/// session link exactly like it would in an external browser. Backed by
/// flutter_inappwebview rather than webview_flutter, which has no working
/// macOS embedding as of this writing.
class InAppWebViewPage extends StatefulWidget {
  const InAppWebViewPage({super.key, required this.url, this.title});
  final String url;
  final String? title;

  /// Opens [url] in the in-app WebView directly (no auth redirect).
  /// Use [showWithAuth] instead when the destination requires the user
  /// to be logged in (i.e. anything on trainingpipeline.com).
  static Future<void> show(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppWebViewPage(url: url, title: title),
      ),
    );
  }

  /// Calls GET user-profile/redirect-login-link?redirectUrl=<url> first to
  /// get a pre-authenticated URL (same flow as Attend Class), then opens the
  /// result in the in-app WebView. Falls back to [url] directly if the API
  /// call fails, so the WebView still opens rather than silently doing nothing.
  ///
  /// Requires a [WidgetRef] so it can read [RedirectLoginRepository].
  static Future<void> showWithAuth(
    BuildContext context,
    WidgetRef ref, {
    required String url,
    String? title,
  }) async {
    final loginLink = await ref
        .read(RedirectLoginRepository.provider)
        .getLoginLink(url);
    if (!context.mounted) return;
    return show(context, url: loginLink ?? url, title: title);
  }

  @override
  State<InAppWebViewPage> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  InAppWebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    // Native platform-view WebViews on macOS are known to sometimes swallow
    // mouse hit-testing for the whole window - a rough edge of macOS's
    // still-maturing platform-view support, not present on iOS's much more
    // established embedding. A keyboard Escape binding gives a reliable way
    // to leave this screen either way, at no cost if the AppBar buttons
    // already work fine.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            safePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: _webviewPurple,
            foregroundColor: Colors.white,
            title: Text(widget.title ?? 'Loading…'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => safePop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _controller?.reload(),
              ),
            ],
          ),
          body: Stack(
            children: [
              if (_error == null)
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                  ),
                  onWebViewCreated: (controller) => _controller = controller,
                  onLoadStart: (controller, url) {
                    if (mounted) setState(() { _loading = true; _error = null; });
                  },
                  onLoadStop: (controller, url) {
                    if (mounted) setState(() => _loading = false);
                  },
                  onReceivedError: (controller, request, error) {
                    if (!mounted || request.isForMainFrame == false) return;
                    setState(() {
                      _loading = false;
                      _error = error.description;
                    });
                  },
                ),
              if (_error != null)
                _ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    _controller?.reload();
                  },
                ),
              if (_loading && _error == null)
                const Center(child: CircularProgressIndicator(color: _webviewPurple)),
            ],
          ),
        ),
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
            HoverBuilder(
              builder: (context, hovering) => ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hovering ? FigmaTokens.purpleHover : _webviewPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
