import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/tweet_video.dart';

class VideoCard extends StatelessWidget {
  final TweetVideo video;
  final VoidCallback? onDownload;
  final VoidCallback? onRemove;
  final void Function(VideoVariant)? onVariantChanged;

  const VideoCard({
    super.key,
    required this.video,
    this.onDownload,
    this.onRemove,
    this.onVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildThumbnail(),
                const SizedBox(width: 12),
                Expanded(child: _buildInfo(context)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (video.status == DownloadStatus.downloading)
              _buildProgressBar(),
            if (video.status == DownloadStatus.error)
              _buildError(),
            if (video.status == DownloadStatus.done)
              _buildDone(context),
            if (video.status == DownloadStatus.idle ||
                video.status == DownloadStatus.fetching)
              _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.grey.shade200,
        child: video.thumbnailUrl != null
            ? Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(Icons.movie, size: 32),
              )
            : const Icon(Icons.movie, size: 32, color: Colors.grey),
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (video.authorName != null)
          Text(
            '@${video.authorName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        if (video.tweetText != null)
          Text(
            video.tweetText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        const SizedBox(height: 4),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;
    IconData icon;

    switch (video.status) {
      case DownloadStatus.idle:
        color = Colors.blue;
        label = 'Ready';
        icon = Icons.download;
      case DownloadStatus.fetching:
        color = Colors.orange;
        label = 'Fetching…';
        icon = Icons.search;
      case DownloadStatus.downloading:
        color = Colors.orange;
        label = '${(video.downloadProgress * 100).toStringAsFixed(0)}%';
        icon = Icons.downloading;
      case DownloadStatus.done:
        color = Colors.green;
        label = 'Saved';
        icon = Icons.check_circle;
      case DownloadStatus.error:
        color = Colors.red;
        label = 'Error';
        icon = Icons.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: video.downloadProgress,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '${(video.downloadProgress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              video.errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final label = Platform.isMacOS && video.savedPath != null
        ? p.basename(video.savedPath!)
        : 'Saved to Photos';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.green, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (video.status == DownloadStatus.fetching) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Center(child: LinearProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (video.variants.length > 1 && video.selectedVariant != null)
            Expanded(
              child: DropdownButtonFormField<VideoVariant>(
                initialValue: video.selectedVariant,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Quality',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                items: video.variants
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                              v.label,
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onVariantChanged?.call(v);
                },
              ),
            ),
          if (video.variants.length > 1) const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed:
                video.status == DownloadStatus.idle ? onDownload : null,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
