import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:x_video_downloader/models/tweet_video.dart';

/// Persists and restores the download queue so it survives app restarts.
class DownloadQueueService {
  static const String _queueFileName = 'download_queue.json';

  static Future<String> _getAppDirectory() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'Library', 'Application Support', 'Cronos');
    } else if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/Cronos';
    } else {
      return p.join(Directory.current.path, '.cronos');
    }
  }

  static Future<String> _getQueueFilePath() async {
    final dir = await _getAppDirectory();
    await Directory(dir).create(recursive: true);
    return p.join(dir, _queueFileName);
  }

  /// Save the current download queue to disk.
  static Future<void> saveQueue(List<TweetVideo> videos) async {
    try {
      final path = await _getQueueFilePath();
      final data = videos.map((v) {
        // When saving, reset "downloading" to "idle" so it resumes on next launch
        final effectiveStatus = v.status == DownloadStatus.downloading
            ? DownloadStatus.idle
            : v.status;
        return {
          'id': v.id,
          'inputUrl': v.inputUrl,
          'source': v.source.name,
          'tweetText': v.tweetText,
          'authorName': v.authorName,
          'thumbnailUrl': v.thumbnailUrl,
          'variants': v.variants.map((v2) => {
            'url': v2.url,
            'bitrate': v2.bitrate,
            'resolution': v2.resolution,
            'formatId': v2.formatId,
            'audioOnly': v2.audioOnly,
            'customLabel': v2.customLabel,
          }).toList(),
          'selectedVariantIndex': v.selectedVariant != null
              ? v.variants.indexOf(v.selectedVariant!)
              : -1,
          'status': effectiveStatus.name,
          'downloadProgress': v.downloadProgress,
          'errorMessage': v.errorMessage,
          'savedPath': v.savedPath,
          'retryCount': v.retryCount,
        };
      }).toList();
      await File(path).writeAsString(jsonEncode(data));
    } catch (e) {
      print('[QueueService] Error saving queue: $e');
    }
  }

  /// Load the download queue from disk.
  static Future<List<TweetVideo>> loadQueue() async {
    try {
      final path = await _getQueueFilePath();
      final file = File(path);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> data = jsonDecode(content);
      return data.map((item) {
        final map = item as Map<String, dynamic>;
        final variants = (map['variants'] as List? ?? [])
            .map((v) => VideoVariant(
                  url: v['url'] as String? ?? '',
                  bitrate: v['bitrate'] as int?,
                  resolution: v['resolution'] as String?,
                  formatId: v['formatId'] as String?,
                  audioOnly: v['audioOnly'] as bool? ?? false,
                  customLabel: v['customLabel'] as String?,
                ))
            .toList();

        final selectedIndex = map['selectedVariantIndex'] as int? ?? -1;

        return TweetVideo(
          id: map['id'] as String? ?? '',
          inputUrl: map['inputUrl'] as String? ?? '',
          source: VideoSource.values.firstWhere(
            (s) => s.name == (map['source'] as String? ?? ''),
            orElse: () => VideoSource.other,
          ),
          tweetText: map['tweetText'] as String?,
          authorName: map['authorName'] as String?,
          thumbnailUrl: map['thumbnailUrl'] as String?,
          variants: variants,
          selectedVariant:
              selectedIndex >= 0 && selectedIndex < variants.length
                  ? variants[selectedIndex]
                  : null,
          status: DownloadStatus.values.firstWhere(
            (s) => s.name == (map['status'] as String? ?? 'idle'),
            orElse: () => DownloadStatus.idle,
          ),
          downloadProgress: (map['downloadProgress'] as num?)?.toDouble() ?? 0.0,
          errorMessage: map['errorMessage'] as String?,
          savedPath: map['savedPath'] as String?,
        );
      }).toList();
    } catch (e) {
      print('[QueueService] Error loading queue: $e');
      return [];
    }
  }

  /// Clear the saved queue from disk.
  static Future<void> clearQueue() async {
    try {
      final path = await _getQueueFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('[QueueService] Error clearing queue: $e');
    }
  }
}
