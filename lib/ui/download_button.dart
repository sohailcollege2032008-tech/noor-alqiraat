import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Reusable download button with three visual states:
/// - Not downloaded: outlined download icon
/// - Downloading: circular progress indicator
/// - Downloaded: green device icon (long-press to delete)
class DownloadButton extends StatelessWidget {
  final bool isDownloaded;
  final double? activeProgress; // null = not downloading
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const DownloadButton({
    super.key,
    required this.isDownloaded,
    required this.activeProgress,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Downloads require a real file system — not available on web
    if (kIsWeb) return const SizedBox.shrink();

    if (activeProgress != null) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          value: activeProgress! > 0 ? activeProgress : null,
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (isDownloaded) {
      return GestureDetector(
        onLongPress: () => _confirmDelete(context),
        child: const Tooltip(
          message: 'اضغط مطولاً للحذف',
          child: Icon(Icons.phone_android, color: Colors.green, size: 22),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_outlined, size: 22),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: 'تحميل',
      onPressed: onDownload,
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملف'),
        content: const Text('هل تريد حذف الملف المحمّل من الجهاز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
