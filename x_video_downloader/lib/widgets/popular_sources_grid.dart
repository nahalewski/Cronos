import 'dart:io';

import 'package:flutter/material.dart';
import 'package:x_video_downloader/theme.dart';

class PopularSourcesGrid extends StatelessWidget {
  const PopularSourcesGrid({
    super.key,
    this.onSourceTap,
  });

  final ValueChanged<String>? onSourceTap;

  static const List<_SourceItem> _downloadSources = [
    _SourceItem(
      id: 'x',
      title: 'X / Twitter',
      subtitle: 'Queue links for download',
      domain: 'x.com',
      fallbackIcon: Icons.close,
    ),
    _SourceItem(
      id: 'youtube',
      title: 'YouTube',
      subtitle: 'Video and MP3 formats',
      domain: 'youtube.com',
      fallbackIcon: Icons.play_circle,
    ),
  ];

  static const List<_SourceItem> _browserSources = [
    _SourceItem(
      id: 'xvideos',
      title: 'XVideos',
      subtitle: 'Open in Custom tab',
      domain: 'xvideos.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'xhamster',
      title: 'xHamster',
      subtitle: 'Open in Custom tab',
      domain: 'xhamster.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'hentaihaven',
      title: 'HentaiHaven',
      subtitle: 'Open in Custom tab',
      domain: 'hentaihaven.xxx',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'hanime',
      title: 'hanime.tv',
      subtitle: 'Open in Custom tab',
      domain: 'hanime.tv',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'rule34video',
      title: 'Rule34Video',
      subtitle: 'Open in Custom tab',
      domain: 'rule34video.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'pornhub',
      title: 'PornHub',
      subtitle: 'Open in Custom tab',
      domain: 'pornhub.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'youporn',
      title: 'YouPorn',
      subtitle: 'Open in Custom tab',
      domain: 'youporn.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'redtube',
      title: 'RedTube',
      subtitle: 'Open in Custom tab',
      domain: 'redtube.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'spankbang',
      title: 'SpankBang',
      subtitle: 'Open in Custom tab',
      domain: 'spankbang.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'xnxx',
      title: 'XNXX',
      subtitle: 'Open in Custom tab',
      domain: 'xnxx.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'xhamsterlive',
      title: 'xHamster Live',
      subtitle: 'Open in Custom tab',
      domain: 'xhamsterlive.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'pornhubpremium',
      title: 'PornHub Premium',
      subtitle: 'Open in Custom tab',
      domain: 'pornhubpremium.com',
      fallbackIcon: Icons.public,
    ),
    _SourceItem(
      id: 'luxuretv',
      title: 'LuxureTV',
      subtitle: 'Open in Custom tab',
      domain: 'en.luxuretv.com',
      fallbackIcon: Icons.public,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isMacDesktop = Platform.isMacOS;
    final allSources = [..._downloadSources, ..._browserSources];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Popular Sources',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.surfaceContainerHigh,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isMacDesktop) ...[
            _iconGrid(context, allSources),
          ] else ...[
            _sectionHeader(context, 'DOWNLOAD SOURCES'),
            const SizedBox(height: 10),
            _sourcesGrid(context, _downloadSources),
            const SizedBox(height: 16),
            _sectionHeader(context, 'CUSTOM BROWSER SOURCES'),
            const SizedBox(height: 10),
            _sourcesGrid(context, _browserSources),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
    );
  }

  Widget _sourcesGrid(BuildContext context, List<_SourceItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 600 ? 4 : 4; // Force 4 columns on most mobile/desktop
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85, // Taller for vertical layout
          ),
          itemBuilder: (context, index) {
            final source = items[index];
            return _sourceCard(
              context,
              source: source,
              onTap: () => onSourceTap?.call(source.id),
            );
          },
        );
      },
    );
  }

  Widget _iconGrid(BuildContext context, List<_SourceItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = switch (width) {
          >= 1400 => 7,
          >= 1100 => 6,
          >= 800 => 5,
          _ => 4,
        };

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, index) {
            final source = items[index];
            return _iconTile(
              context,
              source: source,
              onTap: () => onSourceTap?.call(source.id),
            );
          },
        );
      },
    );
  }

  Widget _sourceCard(
    BuildContext context, {
    required _SourceItem source,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final logoUrl = 'https://www.google.com/s2/favicons?sz=128&domain=${source.domain}';

    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 40,
                  height: 40,
                  color: Colors.white,
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        source.fallbackIcon,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                source.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTile(
    BuildContext context, {
    required _SourceItem source,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final logoUrl = 'https://www.google.com/s2/favicons?sz=128&domain=${source.domain}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceContainerHigh),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Colors.white,
                      child: Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            source.fallbackIcon,
                            size: 24,
                            color: AppColors.onSurfaceVariant,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                source.title,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceItem {
  const _SourceItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.fallbackIcon,
  });

  final String id;
  final String title;
  final String subtitle;
  final String domain;
  final IconData fallbackIcon;
}
