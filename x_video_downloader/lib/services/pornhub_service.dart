import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:x_video_downloader/models/tweet_video.dart';

class PornhubService {
  static Future<TweetVideo?> fetchVideoInfo(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final html = response.body;
      
      // Extract title
      final titleMatch = RegExp(r'<title>([^<]+)').firstMatch(html);
      final title = titleMatch?.group(1)?.trim() ?? 'PornHub Video';
      
      // Extract thumbnail
      final thumbnailMatch = RegExp(r'thumbnail_url"\s*:\s*"([^"]+)"').firstMatch(html);
      String? thumbnailUrl = thumbnailMatch?.group(1);
      if (thumbnailUrl == null) {
        final ogImageMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);
        thumbnailUrl = ogImageMatch?.group(1);
      }
      
      // Extract video URLs - PornHub uses multiple quality levels
      final variants = <VideoVariant>[];
      
      // Try to find video URLs in the page
      final videoUrlMatches = RegExp(r'"videoUrl"\s*:\s*"([^"]+)"').allMatches(html);
      for (final match in videoUrlMatches) {
        final videoUrl = match.group(1);
        if (videoUrl != null && videoUrl.contains('.mp4')) {
          variants.add(VideoVariant(
            url: videoUrl,
            resolution: _extractResolution(videoUrl),
          ));
        }
      }
      
      // Alternative pattern for PornHub
      final qualityMatches = RegExp(r'"quality"\s*:\s*"([^"]+)"\s*,\s*"videoUrl"\s*:\s*"([^"]+)"').allMatches(html);
      for (final match in qualityMatches) {
        final quality = match.group(1);
        final videoUrl = match.group(2);
        if (videoUrl != null && videoUrl.contains('.mp4')) {
          variants.add(VideoVariant(
            url: videoUrl,
            resolution: quality,
          ));
        }
      }
      
      if (variants.isEmpty) {
        return null;
      }
      
      // Sort by resolution (highest first)
      variants.sort((a, b) {
        final aRes = _parseResolution(a.resolution);
        final bRes = _parseResolution(b.resolution);
        return bRes.compareTo(aRes);
      });
      
      return TweetVideo(
        id: _extractVideoId(url),
        inputUrl: url,
        tweetText: title,
        authorName: 'PornHub',
        thumbnailUrl: thumbnailUrl,
        variants: variants,
        selectedVariant: variants.first,
        status: DownloadStatus.idle,
      );
    } catch (e) {
      print('Error fetching PornHub video: $e');
      return null;
    }
  }
  
  static String _extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'pornhub_${url.hashCode.abs()}';
    
    final path = uri.path;
    if (path.contains('/view_video.php?viewkey=')) {
      final keyMatch = RegExp(r'viewkey=([^&]+)').firstMatch(url);
      if (keyMatch != null) return 'pornhub_${keyMatch.group(1)}';
    }
    
    final segments = path.split('/');
    for (final segment in segments) {
      if (segment.isNotEmpty && !segment.contains('.')) {
        return 'pornhub_$segment';
      }
    }
    
    return 'pornhub_${url.hashCode.abs()}';
  }
  
  static String? _extractResolution(String url) {
    final match = RegExp(r'/(\d+p)\.mp4').firstMatch(url);
    return match?.group(1);
  }
  
  static int _parseResolution(String? resolution) {
    if (resolution == null) return 0;
    final match = RegExp(r'(\d+)p').firstMatch(resolution);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
}