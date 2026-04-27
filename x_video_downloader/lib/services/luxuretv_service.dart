import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:x_video_downloader/models/tweet_video.dart';

class LuxureTVService {
  static const String _baseUrl = 'https://en.luxuretv.com';

  /// Fetches video information from a LuxureTV page
  static Future<TweetVideo?> fetchVideoInfo(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return null;
      }

      final html = response.body;
      
      // Extract video title
      final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(html);
      final title = titleMatch?.group(1)?.trim() ?? 'LuxureTV Video';
      
      // Extract video description/meta
      final descriptionMatch = RegExp(r'<meta name="description" content="([^"]+)"').firstMatch(html);
      final description = descriptionMatch?.group(1)?.trim() ?? '';
      
      // Extract video thumbnail
      final thumbnailMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);
      final thumbnailUrl = thumbnailMatch?.group(1)?.trim();
      
      // Extract video sources - LuxureTV typically uses video.js or similar players
      final videoSources = _extractVideoSources(html);
      
      if (videoSources.isEmpty) {
        return null;
      }

      // Create variants from extracted sources
      final variants = videoSources.map((source) {
        final resolution = _extractResolutionFromUrl(source);
        return VideoVariant(
          url: source,
          resolution: resolution,
          bitrate: 0,
          audioOnly: false,
        );
      }).toList();

      // Sort variants by resolution (highest first)
      variants.sort((a, b) {
        final aRes = _parseResolution(a.resolution ?? '');
        final bRes = _parseResolution(b.resolution ?? '');
        return bRes.compareTo(aRes);
      });

      return TweetVideo(
        id: _buildVideoId(url),
        inputUrl: url,
        source: VideoSource.other,
        status: DownloadStatus.idle,
        tweetText: title,
        authorName: 'LuxureTV',
        thumbnailUrl: thumbnailUrl ?? '',
        variants: variants,
        selectedVariant: variants.isNotEmpty ? variants.first : null,
      );
    } catch (e) {
      print('Error fetching LuxureTV video: $e');
      return null;
    }
  }

  /// Extracts video source URLs from HTML
  static List<String> _extractVideoSources(String html) {
    final sources = <String>[];
    
    // Simple regex patterns - use simpler patterns to avoid syntax errors
    // Look for src: "..." patterns
    final srcPattern = RegExp(r'src:\s*"([^"]+\.mp4[^"]*)"', caseSensitive: false);
    for (final match in srcPattern.allMatches(html)) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty && !url.contains('placeholder')) {
        sources.add(_normalizeUrl(url));
      }
    }
    
    // Look for src: '...' patterns
    final srcPattern2 = RegExp(r"src:\s*'([^']+\.mp4[^']*)'", caseSensitive: false);
    for (final match in srcPattern2.allMatches(html)) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty && !url.contains('placeholder')) {
        sources.add(_normalizeUrl(url));
      }
    }
    
    // Look for <video src="..."> patterns
    final videoSrcPattern = RegExp(r'<video[^>]+src="([^"]+)"', caseSensitive: false);
    for (final match in videoSrcPattern.allMatches(html)) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty) {
        sources.add(_normalizeUrl(url));
      }
    }
    
    // Look for <source src="..."> patterns
    final sourceSrcPattern = RegExp(r'<source[^>]+src="([^"]+)"', caseSensitive: false);
    for (final match in sourceSrcPattern.allMatches(html)) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty) {
        sources.add(_normalizeUrl(url));
      }
    }
    
    // Look for data-video="..." patterns
    final dataVideoPattern = RegExp(r'data-video="([^"]+)"', caseSensitive: false);
    for (final match in dataVideoPattern.allMatches(html)) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty) {
        sources.add(_normalizeUrl(url));
      }
    }
    
    // Look for JSON-LD structured data
    final jsonLdMatches = RegExp(r'<script type="application/ld\+json">([^<]+)</script>').allMatches(html);
    for (final match in jsonLdMatches) {
      try {
        final json = jsonDecode(match.group(1)!);
        if (json is Map<String, dynamic>) {
          final contentUrl = json['contentUrl']?.toString();
          if (contentUrl != null && contentUrl.isNotEmpty) {
            sources.add(_normalizeUrl(contentUrl));
          }
          
          // Check for video object
          if (json['@type'] == 'VideoObject') {
            final embedUrl = json['embedUrl']?.toString();
            if (embedUrl != null && embedUrl.isNotEmpty) {
              sources.add(_normalizeUrl(embedUrl));
            }
          }
        }
      } catch (e) {
        // Ignore JSON parsing errors
      }
    }
    
    return sources.toSet().toList(); // Remove duplicates
  }

  /// Normalizes a URL (makes relative URLs absolute)
  static String _normalizeUrl(String url) {
    if (url.startsWith('http')) {
      return url;
    }
    
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    
    if (url.startsWith('/')) {
      return '$_baseUrl$url';
    }
    
    return '$_baseUrl/$url';
  }

  /// Extracts resolution from URL or filename
  static String _extractResolutionFromUrl(String url) {
    final lowerUrl = url.toLowerCase();
    
    // Check for common resolution patterns in URLs
    final resolutionMatch = RegExp(r'(\d{3,4})[xp]').firstMatch(lowerUrl);
    if (resolutionMatch != null) {
      return '${resolutionMatch.group(1)}p';
    }
    
    // Check for quality indicators
    if (lowerUrl.contains('1080')) return '1080p';
    if (lowerUrl.contains('720')) return '720p';
    if (lowerUrl.contains('480')) return '480p';
    if (lowerUrl.contains('360')) return '360p';
    if (lowerUrl.contains('240')) return '240p';
    
    return 'SD';
  }

  /// Parses resolution string to numeric value for sorting
  static int _parseResolution(String resolution) {
    final match = RegExp(r'(\d+)').firstMatch(resolution);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Builds a unique video ID from URL
  static String _buildVideoId(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';
    final slug = path
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'luxuretv_${slug.isNotEmpty ? slug : uri?.host ?? 'video'}';
  }
}