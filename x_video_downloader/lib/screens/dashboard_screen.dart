import 'package:flutter/material.dart';
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/theme.dart';
import 'package:x_video_downloader/widgets/popular_sources_grid.dart';
import 'package:x_video_downloader/widgets/video_download_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.urlController,
    required this.onAddUrls,
    required this.onPaste,
    required this.addingUrls,
    required this.videos,
    required this.onDownloadAll,
    required this.onOpenDownloads,
    required this.onSourceTap,
  });

  final TextEditingController urlController;
  final VoidCallback onAddUrls;
  final VoidCallback onPaste;
  final bool addingUrls;
  final List<TweetVideo> videos;
  final VoidCallback onDownloadAll;
  final VoidCallback onOpenDownloads;
  final ValueChanged<String> onSourceTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        final horizontalPadding = isMobile ? 16.0 : 48.0;

        final downloading = videos.where((v) => v.status == DownloadStatus.downloading).length;
        final ready = videos
            .where((v) => v.status == DownloadStatus.idle || v.status == DownloadStatus.error)
            .length;
        final done = videos.where((v) => v.status == DownloadStatus.done).length;

        return SingleChildScrollView(
          child: Column(
            children: [
              VideoDownloadSection(
                controller: urlController,
                onAddUrls: onAddUrls,
                onPaste: onPaste,
                addingUrls: addingUrls,
              ),
              PopularSourcesGrid(onSourceTap: onSourceTap),
              
              // Responsive Stats
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, isMobile ? 24 : 48),
                child: isMobile
                    ? GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _statCard(label: 'Queued Links', value: videos.length.toString()),
                          _statCard(label: 'Ready', value: ready.toString()),
                          _statCard(label: 'Downloading', value: downloading.toString()),
                          _statCard(label: 'Completed', value: done.toString()),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _statCard(label: 'Queued Links', value: videos.length.toString())),
                          const SizedBox(width: 16),
                          Expanded(child: _statCard(label: 'Ready To Download', value: ready.toString())),
                          const SizedBox(width: 16),
                          Expanded(child: _statCard(label: 'Downloading', value: downloading.toString())),
                          const SizedBox(width: 16),
                          Expanded(child: _statCard(label: 'Completed', value: done.toString())),
                        ],
                      ),
              ),

              // Responsive Action Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 16),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: ready > 0 ? onDownloadAll : null,
                            icon: const Icon(Icons.download_for_offline),
                            label: Text('Download All Ready ($ready)'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onOpenDownloads,
                            icon: const Icon(Icons.queue),
                            label: const Text('Open Queue'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          FilledButton.icon(
                            onPressed: ready > 0 ? onDownloadAll : null,
                            icon: const Icon(Icons.download_for_offline),
                            label: Text('Download All Ready ($ready)'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: onOpenDownloads,
                            icon: const Icon(Icons.queue),
                            label: const Text('Open Queue'),
                          ),
                        ],
                      ),
              ),

              if (videos.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 48),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const ListTile(
                          title: Text(
                            'Recent Queue Activity',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...videos.take(5).map(
                              (video) => ListTile(
                                dense: true,
                                leading: Icon(
                                  switch (video.status) {
                                    DownloadStatus.downloading => Icons.downloading,
                                    DownloadStatus.done => Icons.check_circle,
                                    DownloadStatus.error => Icons.error_outline,
                                    DownloadStatus.fetching => Icons.sync,
                                    DownloadStatus.idle => Icons.download,
                                  },
                                  color: switch (video.status) {
                                    DownloadStatus.done => Colors.green,
                                    DownloadStatus.error => Colors.red,
                                    DownloadStatus.downloading => Colors.orange,
                                    _ => AppColors.onSurfaceVariant,
                                  },
                                ),
                                title: Text(
                                  video.tweetText?.trim().isNotEmpty == true
                                      ? video.tweetText!
                                      : video.inputUrl,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  switch (video.status) {
                                    DownloadStatus.downloading =>
                                      '${(video.downloadProgress * 100).toStringAsFixed(0)}%',
                                    DownloadStatus.done => 'Completed',
                                    DownloadStatus.error =>
                                      video.errorMessage ?? 'Failed',
                                    DownloadStatus.fetching => 'Fetching metadata',
                                    DownloadStatus.idle => 'Ready',
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
