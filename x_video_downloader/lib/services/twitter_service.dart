import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tweet_video.dart';

class TwitterService {
  // fxtwitter (FixTweet) is the primary API — stable, no auth required.
  // vxtwitter is kept as a fallback.
  static const String _fxBase = 'https://api.fxtwitter.com';
  static const String _vxBase = 'https://api.vxtwitter.com';

  static final _urlRegex = RegExp(
    r'https?://(?:(?:www\.|mobile\.|m\.)?(?:twitter|x)\.com|'
    r'(?:www\.)?(?:vxtwitter|fxtwitter|fixupx|nitter\.\w+)\.com)'
    r'/\w+/status[es]*/(\d+)',
    caseSensitive: false,
  );

  static String? extractTweetId(String url) {
    final cleaned = url.trim().split('?').first.split('#').first;
    return _urlRegex.firstMatch(cleaned)?.group(1);
  }

  /// Parses a block of text and returns all unique, valid tweet URLs found.
  static List<String> parseUrls(String rawText) {
    // Collect every token (split on whitespace/commas/newlines)
    final tokens = rawText.split(RegExp(r'[\s,\n]+'));
    final seen = <String>{};
    final result = <String>[];
    for (final token in tokens) {
      final t = token.trim();
      if (t.isEmpty) continue;
      final id = extractTweetId(t);
      if (id != null && seen.add(id)) {
        result.add(t);
      }
    }
    return result;
  }

  Future<TweetVideo> fetchTweetInfo(String inputUrl) async {
    final tweetId = extractTweetId(inputUrl);
    if (tweetId == null) {
      throw Exception('Could not extract tweet ID from URL');
    }

    // Try fxtwitter first, fall back to vxtwitter
    try {
      return await _fetchFromFxTwitter(tweetId, inputUrl);
    } catch (primaryError) {
      try {
        return await _fetchFromVxTwitter(tweetId, inputUrl);
      } catch (_) {
        // Re-throw the original (more descriptive) error
        rethrow;
      }
    }
  }

  // ── fxtwitter (primary) ────────────────────────────────────────────────────

  Future<TweetVideo> _fetchFromFxTwitter(
      String tweetId, String inputUrl) async {
    final uri = Uri.parse('$_fxBase/i/status/$tweetId');
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1)',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw Exception('Rate limited — please wait a moment and retry');
    }
    if (response.statusCode != 200) {
      throw Exception(
          'API error (HTTP ${response.statusCode}) — tweet may be private or deleted');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if ((data['code'] as int?) != 200 || data['tweet'] == null) {
      final msg = data['message'] as String? ?? 'Unknown error';
      throw Exception('$msg — tweet may be private, deleted, or has no video');
    }

    final tweet = data['tweet'] as Map<String, dynamic>;
    final media = tweet['media'] as Map<String, dynamic>?;
    if (media == null) {
      throw Exception('No media found in this tweet');
    }

    final videos = (media['videos'] as List<dynamic>?) ?? [];
    if (videos.isEmpty) {
      throw Exception('No video found — tweet may contain only images');
    }

    final variants = <VideoVariant>[];
    String? thumbnailUrl;

    for (final video in videos) {
      thumbnailUrl ??= video['thumbnail_url'] as String?;
      final formats = (video['formats'] as List<dynamic>?) ?? [];

      // Prefer mp4 formats, filter out m3u8 (HLS streams — not directly saveable)
      final mp4Formats = formats
          .where((f) =>
              (f['container'] as String?) == 'mp4' ||
              (f['url'] as String? ?? '').contains('.mp4'))
          .toList();

      final usable = mp4Formats.isNotEmpty ? mp4Formats : formats;

      for (final f in usable) {
        final url = f['url'] as String?;
        if (url == null || url.contains('.m3u8')) continue;
        final w = (f['width'] as num?)?.toInt();
        final h = (f['height'] as num?)?.toInt();
        variants.add(VideoVariant(
          url: url,
          bitrate: (f['bitrate'] as num?)?.toInt(),
          resolution: (w != null && h != null) ? '${w}x$h' : null,
        ));
      }

      // If no format list, use the top-level url
      if (usable.isEmpty) {
        final url = video['url'] as String?;
        if (url != null) {
          final w = (video['width'] as num?)?.toInt();
          final h = (video['height'] as num?)?.toInt();
          variants.add(VideoVariant(
            url: url,
            resolution: (w != null && h != null) ? '${w}x$h' : null,
          ));
        }
      }
    }

    if (variants.isEmpty) {
      throw Exception('No downloadable MP4 found in this tweet');
    }

    // Deduplicate by URL, sort highest bitrate/resolution first
    final seen = <String>{};
    final deduped =
        variants.where((v) => seen.add(v.url)).toList();
    deduped.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));

    // Keep resolution clean (e.g. "1920x1080") — the VideoVariant.label getter
    // will handle appending bitrate info for display purposes.
    final formattedVariants = deduped.map((variant) {
      return VideoVariant(
        url: variant.url,
        bitrate: variant.bitrate,
        resolution: variant.resolution,
        audioOnly: variant.audioOnly,
      );
    }).toList();

    final author = tweet['author'] as Map<String, dynamic>?;

    return TweetVideo(
      id: tweetId,
      inputUrl: inputUrl,
      tweetText: tweet['text'] as String?,
      authorName: author?['screen_name'] as String?,
      thumbnailUrl: thumbnailUrl,
      variants: formattedVariants,
      selectedVariant: formattedVariants.first,
      status: DownloadStatus.idle,
    );
  }

  // ── vxtwitter (fallback) ───────────────────────────────────────────────────

  Future<TweetVideo> _fetchFromVxTwitter(
      String tweetId, String inputUrl) async {
    final uri = Uri.parse('$_vxBase/i/status/$tweetId');
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1)',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw Exception('Rate limited by both APIs — please try again later');
    }
    if (response.statusCode != 200) {
      throw Exception('API error (HTTP ${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw Exception(data['error'] as String);
    }

    final mediaList = (data['media_extended'] as List<dynamic>?) ?? [];
    final variants = <VideoVariant>[];

    for (final media in mediaList) {
      final type = media['type'] as String?;
      if (type != 'video' && type != 'gif') continue;

      final mediaVariants = (media['variants'] as List<dynamic>?) ?? [];
      if (mediaVariants.isNotEmpty) {
        for (final v in mediaVariants) {
          final url = v['url'] as String?;
          if (url == null || url.contains('.m3u8')) continue;
          variants.add(VideoVariant(
            url: url,
            bitrate: (v['bitrate'] as num?)?.toInt(),
            resolution: _extractResolution(url),
          ));
        }
      } else {
        final url = media['url'] as String?;
        if (url != null && !url.contains('.m3u8')) {
          variants.add(VideoVariant(
            url: url,
            bitrate: (media['bitrate'] as num?)?.toInt(),
            resolution: _extractResolution(url),
          ));
        }
      }
    }

    // Last-resort: mediaURLs array
    if (variants.isEmpty) {
      final mediaUrls = (data['mediaURLs'] as List<dynamic>?) ?? [];
      for (final url in mediaUrls.cast<String>()) {
        if (!url.contains('.m3u8')) {
          variants.add(VideoVariant(
              url: url, resolution: _extractResolution(url)));
        }
      }
    }

    if (variants.isEmpty) {
      throw Exception('No downloadable video found in this tweet');
    }

    final seen = <String>{};
    final deduped = variants.where((v) => seen.add(v.url)).toList();
    deduped.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));

    final thumbnailUrl =
        (mediaList.isNotEmpty ? mediaList.first['thumbnail_url'] as String? : null) ??
            data['user_profile_image_url'] as String?;

    return TweetVideo(
      id: tweetId,
      inputUrl: inputUrl,
      tweetText: data['text'] as String?,
      authorName: data['user_name'] as String?,
      thumbnailUrl: thumbnailUrl,
      variants: deduped,
      selectedVariant: deduped.first,
      status: DownloadStatus.idle,
    );
  }

  static String? _extractResolution(String url) {
    final match = RegExp(r'/(\d+x\d+)/').firstMatch(url);
    return match?.group(1);
  }
}
