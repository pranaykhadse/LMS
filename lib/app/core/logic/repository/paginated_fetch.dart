/// Repeatedly calls [fetchPage] with increasing page numbers, accumulating
/// results until a page returns fewer than [perPage] items (last page) or an
/// empty page — with a [maxPages] safety cap in case a backend endpoint
/// silently ignores the page parameter and would otherwise loop forever.
Future<List<T>> fetchAllPages<T>({
  required Future<List<T>> Function(int page, int perPage) fetchPage,
  int perPage = 50,
  int maxPages = 20,
}) async {
  final all = <T>[];
  for (var page = 1; page <= maxPages; page++) {
    final items = await fetchPage(page, perPage);
    if (items.isEmpty) break;
    all.addAll(items);
    if (items.length < perPage) break;
  }
  return all;
}
