import 'package:flutter/material.dart';
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/theme.dart';
import 'package:x_video_downloader/widgets/video_card.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({
    super.key,
    required this.videos,
    required this.onDownloadAll,
    required this.onDownloadOne,
    required this.onRemoveVideo,
    required this.onVariantChanged,
    this.onClearCompleted,
  });

  final List<TweetVideo> videos;
  final VoidCallback onDownloadAll;
  final ValueChanged<TweetVideo> onDownloadOne;
  final ValueChanged<String> onRemoveVideo;
  final void Function(TweetVideo video, VideoVariant variant) onVariantChanged;
  final VoidCallback? onClearCompleted;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final queueItems = videos.where((v) => v.status != DownloadStatus.done).toList();
    final finishedItems = videos.where((v) => v.status == DownloadStatus.done).toList();
    final pending = videos
        .where((v) => v.status == DownloadStatus.idle || v.status == DownloadStatus.error)
        .length;
    final downloading = videos.where((v) => v.status == DownloadStatus.downloading).length;
    final done = videos.where((v) => v.status == DownloadStatus.done).length;
    final failed = videos.where((v) => v.status == DownloadStatus.error).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header section (non-scrollable)
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Downloads', style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Manage active queue and completed items.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _MetricCard(label: 'Queued', value: '$pending', unit: 'items')),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(label: 'Downloading', value: '$downloading', unit: 'items')),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(label: 'Completed', value: '$done', unit: 'items')),
                  const SizedBox(width: 12),
                  Expanded(child: _MetricCard(label: 'Failed', value: '$failed', unit: 'items')),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Download Queue', style: textTheme.titleLarge),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: pending > 0 ? onDownloadAll : null,
                    icon: const Icon(Icons.download_for_offline),
                    label: Text('Download All ($pending)'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // Scrollable queue list
        Expanded(
          child: queueItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No active links in queue.',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 12),
                  itemCount: queueItems.length,
                  itemBuilder: (context, index) {
                    final video = queueItems[index];
                    return VideoCard(
                      key: ValueKey(video.id),
                      video: video,
                      onDownload: (video.status == DownloadStatus.idle ||
                              video.status == DownloadStatus.error)
                          ? () => onDownloadOne(video)
                          : null,
                      onRemove: () => onRemoveVideo(video.id),
                      onVariantChanged: (variant) => onVariantChanged(video, variant),
                    );
                  },
                ),
        ),
        // Finished section
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Divider(
                color: AppColors.surfaceContainerHigh,
                thickness: 1,
                height: 32,
              ),
              Row(
                children: [
                  Text('Finished Downloads', style: textTheme.titleLarge),
                  const Spacer(),
                  if (finishedItems.isNotEmpty && onClearCompleted != null)
                    OutlinedButton.icon(
                      onPressed: onClearCompleted,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // Finished items list
        Expanded(
          child: finishedItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Completed downloads will appear here.',
                      style: TextStyle(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  itemCount: finishedItems.length,
                  itemBuilder: (context, index) {
                    final video = finishedItems[index];
                    return VideoCard(
                      key: ValueKey('finished_${video.id}'),
                      video: video,
                      onDownload: null,
                      onRemove: () => onRemoveVideo(video.id),
                      onVariantChanged: (variant) => onVariantChanged(video, variant),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
