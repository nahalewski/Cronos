import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/services/library_metadata_service.dart';
import 'package:x_video_downloader/theme.dart';

enum LibrarySort { date, size, name }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.videos,
    required this.downloadDirectory,
    required this.metadataByPath,
    required this.onOpenFile,
    required this.onShowInFolder,
    required this.onDeleteFile,
  });

  final List<TweetVideo> videos;
  final String? downloadDirectory;
  final Map<String, LibraryMetadata> metadataByPath;
  final Future<void> Function(String path) onOpenFile;
  final Future<void> Function(String path) onShowInFolder;
  final Future<void> Function(String path) onDeleteFile;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  LibrarySort _sort = LibrarySort.date;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final query = _searchController.text.trim().toLowerCase();
    final items = _loadLibraryItems(widget.downloadDirectory, widget.videos);

    final filtered = items.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.author.toLowerCase().contains(query) ||
          item.fileName.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case LibrarySort.date:
          return b.modified.compareTo(a.modified);
        case LibrarySort.size:
          return b.sizeBytes.compareTo(a.sizeBytes);
        case LibrarySort.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        final horizontalPadding = isMobile ? 16.0 : 40.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                Text('Video Library', style: textTheme.headlineSmall),
                if (widget.downloadDirectory != null && widget.downloadDirectory!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACTIVE FOLDER',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  widget.downloadDirectory!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search library...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceContainer,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Video Library', style: textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            '${filtered.length} file${filtered.length == 1 ? '' : 's'} in library folder',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (widget.downloadDirectory != null && widget.downloadDirectory!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder_open, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Folder: ${widget.downloadDirectory!}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search library...',
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          border: OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _sortChip('Date', LibrarySort.date),
                  _sortChip('Size', LibrarySort.size),
                  _sortChip('Name', LibrarySort.name),
                ],
              ),
              const SizedBox(height: 24),
              if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.downloadDirectory == null || widget.downloadDirectory!.isEmpty
                        ? 'No library folder configured.'
                        : 'No media found in the library folder.',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile
                      ? (constraints.maxWidth > 400 ? 2 : 1)
                      : 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? (constraints.maxWidth > 400 ? 0.8 : 1.1) : 0.85,
                ),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _LibraryCard(
                    item: item,
                    onOpen: () => widget.onOpenFile(item.path),
                    onShowInFolder: () => widget.onShowInFolder(item.path),
                    onRemove: () async {
                      await widget.onDeleteFile(item.path);
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sortChip(String label, LibrarySort value) {
    final selected = _sort == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _sort = value),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  List<_LibraryItemVM> _loadLibraryItems(String? directory, List<TweetVideo> videos) {
    if (directory == null || directory.isEmpty) return const [];
    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return const [];

      final byPath = <String, TweetVideo>{};
      for (final video in videos) {
        final path = video.savedPath;
        if (path != null && path.isNotEmpty) {
          byPath[path] = video;
        }
      }

      // Performance: Limit recursive depth to avoid blocking UI on large directories
      // Only scan 2 levels deep max for performance
      final entries = <_LibraryItemVM>[];
      _listFilesRecursive(dir, byPath, entries, 0, 2);
      return entries;
    } catch (e) {
      debugPrint('Error listing library items: $e');
      return const [];
    }
  }

  void _listFilesRecursive(
    Directory dir,
    Map<String, TweetVideo> byPath,
    List<_LibraryItemVM> entries,
    int depth,
    int maxDepth,
  ) {
    if (depth > maxDepth) return;
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if ({'.mp4', '.mov', '.m4v', '.webm', '.mkv'}.contains(ext)) {
            entries.add(_LibraryItemVM.fromFile(
              entity,
              byPath[entity.path],
              widget.metadataByPath[entity.path],
            ));
          }
        } else if (entity is Directory) {
          _listFilesRecursive(entity, byPath, entries, depth + 1, maxDepth);
        }
      }
    } catch (_) {}
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.item,
    required this.onOpen,
    required this.onShowInFolder,
    required this.onRemove,
  });

  final _LibraryItemVM item;
  final VoidCallback onOpen;
  final VoidCallback onShowInFolder;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.thumbnailUrl == null
                    ? Container(
                        color: AppColors.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.movie,
                          color: AppColors.onSurfaceVariant,
                        ),
                      )
                    : Image.network(
                        item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surfaceContainerHigh,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '@${item.author} • ${item.sizeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Open'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Show in folder',
                          onPressed: onShowInFolder,
                          icon: const Icon(Icons.folder_open, size: 20),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Delete file',
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryItemVM {
  const _LibraryItemVM({
    required this.path,
    required this.fileName,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.sizeBytes,
    required this.sizeLabel,
    required this.modified,
  });

  final String path;
  final String fileName;
  final String title;
  final String author;
  final String? thumbnailUrl;
  final int sizeBytes;
  final String sizeLabel;
  final DateTime modified;

  factory _LibraryItemVM.fromFile(
    File file,
    TweetVideo? video,
    LibraryMetadata? metadata,
  ) {
    final stat = file.statSync();
    final size = stat.size;
    return _LibraryItemVM(
      path: file.path,
      fileName: p.basename(file.path),
      title: video?.tweetText?.trim().isNotEmpty == true
          ? video!.tweetText!.trim()
          : (metadata?.title?.trim().isNotEmpty == true
              ? metadata!.title!.trim()
              : p.basenameWithoutExtension(file.path)),
      author: (video?.authorName?.trim().isNotEmpty == true)
          ? video!.authorName!.trim()
          : ((metadata?.author?.trim().isNotEmpty == true) ? metadata!.author!.trim() : 'unknown'),
      thumbnailUrl: video?.thumbnailUrl ?? metadata?.thumbnailUrl,
      sizeBytes: size,
      sizeLabel: _formatBytes(size),
      modified: stat.modified,
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final fixed = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$fixed ${units[unitIndex]}';
  }
}
