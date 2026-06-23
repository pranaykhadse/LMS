import 'package:flutter/widgets.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfContentViewer extends StatefulWidget {
  const PdfContentViewer({super.key, required this.file});
  final FileCacheState file;
  @override
  State<PdfContentViewer> createState() => _PdfContentViewerState();
}

class _PdfContentViewerState extends State<PdfContentViewer> {
  @override
  Widget build(BuildContext context) {
    var path2 = widget.file.file?.path;
    var pdfViewerParams = PdfViewerParams(
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        return Center(child: Text(error.toString()));
      },
    );
    if (path2 != null) return PdfViewer.file(path2, params: pdfViewerParams);
    return PdfViewer.uri(Uri.parse(widget.file.url), params: pdfViewerParams);
  }
}
