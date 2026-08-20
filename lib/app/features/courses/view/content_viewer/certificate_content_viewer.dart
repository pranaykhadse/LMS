import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';

/// Renders a downloaded certificate's raw HTML (saved as-is by
/// FileCacheViewModel.saveContent, no network fetch involved) - same
/// downloaded-file viewer role as PdfContentViewer/VideoContentViewer, just
/// for HTML instead of a PDF/video file.
class CertificateContentViewer extends StatelessWidget {
  const CertificateContentViewer({super.key, required this.file});
  final FileCacheState file;

  @override
  Widget build(BuildContext context) {
    final path = file.file?.path;
    if (path == null) {
      return const Center(child: Text('Unable to load certificate.'));
    }
    final html = File(path).readAsStringSync();
    return InAppWebView(
      initialData: InAppWebViewInitialData(data: html),
    );
  }
}
