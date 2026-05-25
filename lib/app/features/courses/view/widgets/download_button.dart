import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/provider/internet_connection_provider.dart';
import 'package:lms/app/core/provider/offline_mode_provider.dart';
import 'package:lms/app/features/courses/model/course_class.dart';
import 'package:lms/app/features/courses/view/content_view_page.dart';
import 'package:lms/app/features/courses/viewmodel/file_cache_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/roaster_view_model.dart';
import 'package:lms/app/features/courses/viewmodel/sync_view_model.dart';

/// A per-content-item download + play widget — Netflix style.
///
/// States:
///  ① Online  + not downloaded  → [⬇ Download Video/PDF]
///  ② Downloading               → progress ring + % label
///  ③ Downloaded                → [▶ Play / 📄 Open]  🗑️ delete
///  ④ Offline  + not downloaded → disabled "Not available offline" pill
class DownloadButton extends ConsumerWidget {
  const DownloadButton({
    super.key,
    required this.icon,
    this.url,
    required this.label,
    required this.builder,
    required this.courseClass,
  });

  final String? url;
  final String label;
  final IconData icon;
  // Nullable: participant-guide downloads have no associated lesson class.
  final CourseClass? courseClass;
  final Widget Function(BuildContext context, FileCacheState file) builder;

  void _open(BuildContext context, WidgetRef ref, FileCacheState file) {
    if (courseClass != null) {
      ref
          .read(RoasterViewModel.provider(courseClass!.courseId).notifier)
          .markAsRead(courseClass!);
    }
    ContentViewPage.show(
      context: context,
      courseClass: courseClass,
      child: builder(context, file),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (url == null || url!.isEmpty) return const SizedBox.shrink();

    // Watch all three providers so this widget rebuilds whenever any of them
    // changes — no StreamBuilder needed.
    final fileCacheVM = ref.watch(FileCacheViewModel.provider);
    final isManualOffline = ref.watch(OfflineModeNotifier.provider);
    final connectionVM = ref.watch(InternetConnectionProvider.provider);
    // SyncViewModel notifies whenever physical connectivity changes, giving us
    // reactive rebuilds for real network drops/restores.
    ref.watch(SyncViewModel.provider);

    final isOnline = !isManualOffline && connectionVM.isConnected;

    // Kick off an async disk-cache check if not already known.
    // Idempotent — safe to call on every build.
    fileCacheVM.ensureChecked(url!);
    final data = fileCacheVM.getSync(url!);

    // ── Still checking disk cache ─────────────────────────────────────────
    if (data == null) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final isCached = data.file != null;
    final isDownloading = data.progress != null && !isCached;

    // ── ③ DOWNLOADED — always show Open/Play even when offline ───────────
    if (isCached) {
      return _DownloadedRow(
        label: label,
        onOpen: () => _open(context, ref, data),
        onDelete: () => fileCacheVM.delete(data.url),
      );
    }

    // ── ② DOWNLOADING ────────────────────────────────────────────────────
    if (isDownloading) {
      return _DownloadingRow(
        label: label,
        progress: data.progress ?? Stream.value(0.0),
      );
    }

    // ── ④ OFFLINE + NOT DOWNLOADED ───────────────────────────────────────
    if (!isOnline) {
      return const _NotAvailableOfflinePill();
    }

    // ── ① ONLINE + NOT DOWNLOADED ────────────────────────────────────────
    return _DownloadTriggerButton(
      label: label,
      onTap: () => fileCacheVM.downloadFile(url!),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① Download trigger button
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadTriggerButton extends StatelessWidget {
  const _DownloadTriggerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.download_outlined, size: 18),
      label: Text("Download $label"),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.appColorScheme.primary,
        side: BorderSide(color: context.appColorScheme.primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: context.textTheme.bodySmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ② Downloading — progress ring + percentage
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadingRow extends StatelessWidget {
  const _DownloadingRow({required this.label, required this.progress});

  final String label;
  final Stream<double> progress;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: progress,
      initialData: 0.0,
      builder: (context, snapshot) {
        final pct = (snapshot.data ?? 0.0).clamp(0.0, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: pct == 0.0 ? null : pct,
                strokeWidth: 3,
                color: context.appColorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Downloading $label…",
                  style: context.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  "${(pct * 100).toInt()}%",
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ③ Downloaded — Play/Open button + Delete icon
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadedRow extends StatelessWidget {
  const _DownloadedRow({
    required this.label,
    required this.onOpen,
    required this.onDelete,
  });

  final String label;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  bool get _isVideo => label.toLowerCase().contains('video');

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: onOpen,
          icon: Icon(
            _isVideo ? Icons.play_arrow_rounded : Icons.open_in_new_rounded,
            size: 18,
          ),
          label: Text(_isVideo ? "Play $label" : "Open $label"),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.appColorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: context.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        Tooltip(
          message: "Remove offline copy",
          child: InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: Colors.red.shade400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ④ Not available offline pill
// ─────────────────────────────────────────────────────────────────────────────
class _NotAvailableOfflinePill extends StatelessWidget {
  const _NotAvailableOfflinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 5),
          Text(
            "Not available offline",
            style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
