import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/core/design/figma_tokens.dart';
import 'package:lms/app/core/views/elements/toast.dart';
import 'package:lms/app/features/courses/view/widgets/link_button.dart' show appActionChip;
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
    this.fullWidth = false,
  });

  final String? url;
  final String label;
  final IconData icon;
  // Nullable: participant-guide downloads have no associated lesson class.
  final CourseClass? courseClass;
  final Widget Function(BuildContext context, FileCacheState file) builder;
  final bool fullWidth;

  Future<void> _open(BuildContext context, WidgetRef ref, FileCacheState file) async {
    if (courseClass != null) {
      ref
          .read(RoasterViewModel.provider(courseClass!.courseId).notifier)
          .markAsRead(courseClass!);
    }
    // The on-disk copy is encrypted - decrypt it into a throwaway plaintext
    // file for this app's own viewer, and clean that copy up again once the
    // viewer is closed. Never pass the encrypted file straight to a viewer.
    final fileCacheVM = ref.read(FileCacheViewModel.provider);
    final decrypted = await fileCacheVM.prepareForViewing(file.url);
    if (decrypted == null) {
      if (context.mounted) {
        Toast.error(context, 'Unable to open $label - please re-download it.');
      }
      return;
    }
    if (!context.mounted) return;
    await ContentViewPage.show(
      context: context,
      courseClass: courseClass,
      child: builder(context, FileCacheState(url: file.url, file: decrypted)),
    );
    await fileCacheVM.cleanupViewing(file.url);
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

    // Show toast when a download transitions from in-progress → cached
    ref.listen<FileCacheViewModel>(FileCacheViewModel.provider, (prev, next) {
      if (url == null) return;
      final wasDownloading = prev?.getSync(url!)?.progress != null &&
          prev?.getSync(url!)?.file == null;
      final isNowCached = next.getSync(url!)?.file != null;
      if (wasDownloading && isNowCached && context.mounted) {
        Toast.success(context, '$label saved for offline access');
      }
    });

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
        onDelete: () {
          fileCacheVM.delete(data.url);
          Toast.info(context, 'Offline copy of $label removed');
        },
        fullWidth: fullWidth,
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
      fullWidth: fullWidth,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ① Download trigger button
// ─────────────────────────────────────────────────────────────────────────────
class _DownloadTriggerButton extends StatelessWidget {
  const _DownloadTriggerButton({
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final primary = FigmaTokens.primaryPurple;
    if (!fullWidth && defaultTargetPlatform == TargetPlatform.macOS) {
      return appActionChip(
        icon: Icons.download_outlined,
        label: "Download $label",
        fgColor: primary,
        bgColor: Colors.transparent,
        borderColor: primary,
        onPressed: onTap,
      );
    }
    if (fullWidth) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.download_outlined, size: 17),
          label: Text("Download $label"),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(39),
            elevation: 0,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.download_outlined, size: 13),
        label: Text("Download $label"),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: context.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
                color: FigmaTokens.primaryPurple,
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
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool fullWidth;

  bool get _isVideo =>
      label.toLowerCase().contains('video') ||
      label.toLowerCase().contains('recording');

  @override
  Widget build(BuildContext context) {
    final primary = FigmaTokens.primaryPurple;
    final playLabel = _isVideo ? "Play $label" : "Open $label";
    final playIcon = _isVideo ? Icons.play_arrow_rounded : Icons.open_in_new_rounded;

    if (fullWidth) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: Icon(playIcon, size: 17),
              label: Text(playLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(39),
                elevation: 0,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: "Remove offline copy",
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
              ),
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (defaultTargetPlatform == TargetPlatform.macOS)
          appActionChip(
            icon: playIcon,
            label: playLabel,
            fgColor: Colors.white,
            bgColor: primary,
            borderColor: primary,
            onPressed: onOpen,
          )
        else
          SizedBox(
            height: 30,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: Icon(playIcon, size: 13),
              label: Text(playLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: context.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
              child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade400),
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


