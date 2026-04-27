import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:x_video_downloader/models/browser_photo.dart';
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/theme.dart';

class PhotosScreen extends StatelessWidget {
  const PhotosScreen({
    super.key,
    required this.photos,
    required this.photoDirectory,
    required this.onDownloadAll,
    required this.onDownloadOne,
    required this.onOpenFile,
    required this.onShowInFolder,
  });

  final List<BrowserPhoto> photos;
  final String photoDirectory;
  final VoidCallback onDownloadAll;
  final ValueChanged<BrowserPhoto> onDownloadOne;
  final Future<void> Function(String path) onOpenFile;
  final Future<void> Function(String path) onShowInFolder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        final horizontalPadding = isMobile ? 16.0 : 40.0;
        final pending = photos
            .where((photo) =>
                photo.status == DownloadStatus.idle ||
                photo.status == DownloadStatus.error)
            .length;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photos', style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '${photos.length} photo${photos.length == 1 ? '' : 's'} captured from X.com browser sessions',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Photo folder: $photoDirectory',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (pending > 0)
                      FilledButton.icon(
                        onPressed: onDownloadAll,
                        icon: const Icon(Icons.download),
                        label: Text('Download All ($pending)'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (photos.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Open the X.com browser panel and browse tweets with images. Detected photos will appear here.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: photos.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile
                        ? (constraints.maxWidth > 400 ? 2 : 1)
                        : (constraints.maxWidth >= 1320
                            ? 4
                            : constraints.maxWidth >= 980
                                ? 3
                                : 2),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isMobile ? 0.78 : 0.84,
                  ),
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return _PhotoCard(
                      photo: photo,
                      onDownload: () => onDownloadOne(photo),
                      onOpen: photo.savedPath != null ? () => onOpenFile(photo.savedPath!) : null,
                      onShowInFolder: photo.savedPath != null
                          ? () => onShowInFolder(photo.savedPath!)
                          : null,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.onDownload,
    this.onOpen,
    this.onShowInFolder,
  });

  final BrowserPhoto photo;
  final VoidCallback onDownload;
  final VoidCallback? onOpen;
  final VoidCallback? onShowInFolder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                color: AppColors.surfaceContainerHighest,
                child: photo.savedPath != null && File(photo.savedPath!).existsSync()
                    ? Image.file(
                        File(photo.savedPath!),
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        photo.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: AppColors.onSurfaceVariant),
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.savedPath != null ? p.basename(photo.savedPath!) : p.basename(photo.imageUrl),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(photo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: _statusColor(photo),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (photo.status == DownloadStatus.downloading) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: photo.downloadProgress),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (photo.savedPath == null)
                      FilledButton.icon(
                        onPressed: photo.status == DownloadStatus.downloading ? null : onDownload,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Save'),
                      ),
                    if (onOpen != null)
                      OutlinedButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open'),
                      ),
                    if (onShowInFolder != null)
                      OutlinedButton.icon(
                        onPressed: onShowInFolder,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Show'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(BrowserPhoto photo) {
    return switch (photo.status) {
      DownloadStatus.idle => 'Ready to save',
      DownloadStatus.fetching => 'Detected from browser',
      DownloadStatus.downloading =>
        'Saving ${(photo.downloadProgress * 100).toStringAsFixed(0)}%',
      DownloadStatus.done => 'Saved',
      DownloadStatus.error => photo.errorMessage ?? 'Save failed',
    };
  }

  Color _statusColor(BrowserPhoto photo) {
    return switch (photo.status) {
      DownloadStatus.done => Colors.green,
      DownloadStatus.error => Colors.red,
      DownloadStatus.downloading => Colors.orange,
      _ => AppColors.onSurfaceVariant,
    };
  }
}
