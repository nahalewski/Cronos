import 'package:flutter/material.dart';
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/theme.dart';
import 'package:x_video_downloader/widgets/video_download_section.dart';

class MusicScreen extends StatelessWidget {
  const MusicScreen({
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
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Music Downloads',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Download YouTube videos as MP3 files. Files are saved to the YouTube MP3 folder in settings.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              VideoDownloadSection(
                controller: urlController,
                onAddUrls: onAddUrls,
                onPaste: onPaste,
                addingUrls: addingUrls,
              ),
              
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
                            icon: const Icon(Icons.list),
                            label: const Text('View All Downloads'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: ready > 0 ? onDownloadAll : null,
                              icon: const Icon(Icons.download_for_offline),
                              label: Text('Download All Ready ($ready)'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 54),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onOpenDownloads,
                              icon: const Icon(Icons.list),
                              label: const Text('View All Downloads'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 54),
                              ),
                            ),
                          ),
                        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}