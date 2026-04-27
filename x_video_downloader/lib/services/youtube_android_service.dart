import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/services/youtube_service.dart';

/// Android-compatible YouTube download service.
///
/// Uses YouTube's InnerTube API directly via HTTP requests instead of
/// requiring the yt-dlp binary (which is not available on Android).
///
/// This extracts video/audio stream URLs by:
/// 1. Fetching the YouTube watch page to get initial player data
/// 2. Using the InnerTube API to get streaming data
/// 3. Parsing the streaming formats to build VideoVariant options
class YoutubeAndroidService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    },
  ));

  /// Fetches video info from YouTube using the InnerTube API.
  /// Returns null if the video cannot be extracted.
  Future<YtVideoInfo?> fetchInfo(String url) async {
    final videoId = _extractVideoId(url);
    if (videoId == null) return null;

    try {
      // First try: InnerTube API (most reliable)
      final info = await _fetchFromInnertube(videoId);
      if (info != null) return info;

      // Second try: Scrape the watch page
      final info2 = await _fetchFromWatchPage(videoId);
      if (info2 != null) return info2;

      return null;
    } catch (e) {
      debugPrint('[YoutubeAndroidService] Error fetching $videoId: $e');
      return null;
    }
  }

  String? _extractVideoId(String url) {
    final trimmed = url.trim();
    if (!trimmed.contains('youtube.com') && !trimmed.contains('youtu.be')) {
      return null;
    }

    final directMatch = RegExp(
      r'(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/|youtube\.com/live/|youtube\.com/embed/)([A-Za-z0-9_-]{11})',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (directMatch != null) return directMatch.group(1);

    final queryMatch = RegExp(r'youtube\.com/.*[?&]v=([A-Za-z0-9_-]{11})', caseSensitive: false)
        .firstMatch(trimmed);
    return queryMatch?.group(1);
  }

  /// Fetches video info using the InnerTube API.
  Future<YtVideoInfo?> _fetchFromInnertube(String videoId) async {
    try {
      // Step 1: Get the watch page to extract API key and context
      final pageResponse = await _dio.get(
        'https://www.youtube.com/watch?v=$videoId',
        options: Options(
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      final pageHtml = pageResponse.data as String;

      // Extract ytcfg which contains the API key and context
      final apiKey = _extractInnerTubeApiKey(pageHtml);
      final context = _extractInnerTubeContext(pageHtml);

      if (apiKey == null || context == null) {
        debugPrint('[YoutubeAndroidService] Could not extract API key or context');
        return null;
      }

      // Step 2: Call the InnerTube player endpoint
      final playerResponse = await _dio.post(
        'https://www.youtube.com/youtubei/v1/player?key=$apiKey',
        data: jsonEncode({
          'context': context,
          'videoId': videoId,
          'playbackContext': {
            'contentPlaybackContext': {
              'html5Preference': 'HTML5_PREF_WANTS',
              'signatureTimestamp': _getSignatureTimestamp(pageHtml),
            },
          },
          'racyCheckOk': true,
          'contentCheckOk': true,
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final data = playerResponse.data as Map<String, dynamic>;
      return _parsePlayerResponse(data, videoId);
    } catch (e) {
      debugPrint('[YoutubeAndroidService] InnerTube API error: $e');
      return null;
    }
  }

  /// Fetches video info by scraping the watch page directly.
  /// This is a fallback when the InnerTube API fails.
  Future<YtVideoInfo?> _fetchFromWatchPage(String videoId) async {
    try {
      final response = await _dio.get(
        'https://www.youtube.com/watch?v=$videoId',
        options: Options(
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      final html = response.data as String;

      // Try to extract ytInitialPlayerResponse from the page
      final playerResponseMatch = RegExp(
        r'ytInitialPlayerResponse\s*=\s*({.*?});',
        dotAll: true,
      ).firstMatch(html);

      if (playerResponseMatch != null) {
        try {
          final playerData = jsonDecode(playerResponseMatch.group(1)!) as Map<String, dynamic>;
          final info = _parsePlayerResponse(playerData, videoId);
          if (info != null) return info;
        } catch (_) {}
      }

      // Try to extract ytInitialData
      final initialDataMatch = RegExp(
        r'ytInitialData\s*=\s*({.*?});',
        dotAll: true,
      ).firstMatch(html);

      if (initialDataMatch != null) {
        try {
          final data = jsonDecode(initialDataMatch.group(1)!) as Map<String, dynamic>;
          return _parseInitialData(data, videoId, html);
        } catch (_) {}
      }

      return null;
    } catch (e) {
      debugPrint('[YoutubeAndroidService] Watch page scrape error: $e');
      return null;
    }
  }

  /// Parses the player response from InnerTube or ytInitialPlayerResponse.
  YtVideoInfo? _parsePlayerResponse(Map<String, dynamic> data, String videoId) {
    final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
    if (videoDetails == null) return null;

    final title = videoDetails['title'] as String?;
    final author = videoDetails['author'] as String?;
    final thumbnail = _getBestThumbnail(videoDetails['thumbnail'] as Map<String, dynamic>?);

    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) return null;

    final variants = <VideoVariant>[];
    final seenUrls = <String>{};

    // Process adaptive formats (video-only and audio-only streams)
    final adaptiveFormats = streamingData['adaptiveFormats'] as List<dynamic>? ?? [];
    final videoFormats = <Map<String, dynamic>>[];
    final audioFormats = <Map<String, dynamic>>[];

    for (final format in adaptiveFormats.cast<Map<String, dynamic>>()) {
      final mimeType = (format['mimeType'] as String? ?? '').toLowerCase();
      if (mimeType.contains('video')) {
        videoFormats.add(format);
      } else if (mimeType.contains('audio')) {
        audioFormats.add(format);
      }
    }

    // Process regular formats (combined video+audio)
    final formats = streamingData['formats'] as List<dynamic>? ?? [];
    for (final format in formats.cast<Map<String, dynamic>>()) {
      final url = _extractStreamUrl(format);
      if (url == null || seenUrls.contains(url)) continue;
      seenUrls.add(url);

      final qualityLabel = format['qualityLabel'] as String? ?? format['quality'] as String? ?? 'Unknown';
      final width = (format['width'] as num?)?.toInt();
      final height = (format['height'] as num?)?.toInt();
      final fps = (format['fps'] as num?)?.toInt();
      final bitrate = (format['bitrate'] as num?)?.toInt();
      final resolution = (width != null && height != null) ? '${width}x$height' : null;

      final labelParts = <String>[qualityLabel];
      if (fps != null && fps > 30) labelParts.add('${fps}fps');
      if (bitrate != null) labelParts.add('~${(bitrate / 1000).round()} kbps');

      variants.add(VideoVariant(
        url: url,
        resolution: resolution,
        bitrate: bitrate,
        customLabel: labelParts.join(' • '),
      ));
    }

    // Add video-only streams (will be merged with audio)
    for (final format in videoFormats) {
      final url = _extractStreamUrl(format);
      if (url == null || seenUrls.contains(url)) continue;
      seenUrls.add(url);

      final qualityLabel = format['qualityLabel'] as String? ?? 'Unknown';
      final width = (format['width'] as num?)?.toInt();
      final height = (format['height'] as num?)?.toInt();
      final fps = (format['fps'] as num?)?.toInt();
      final bitrate = (format['bitrate'] as num?)?.toInt();
      final resolution = (width != null && height != null) ? '${width}x$height' : null;

      final labelParts = <String>[qualityLabel];
      if (fps != null && fps > 30) labelParts.add('${fps}fps');
      if (bitrate != null) labelParts.add('~${(bitrate / 1000).round()} kbps');
      labelParts.add('(video only)');

      variants.add(VideoVariant(
        url: url,
        resolution: resolution,
        bitrate: bitrate,
        customLabel: labelParts.join(' • '),
      ));
    }

    // Add audio-only streams
    for (final format in audioFormats) {
      final url = _extractStreamUrl(format);
      if (url == null || seenUrls.contains(url)) continue;
      seenUrls.add(url);

      final bitrate = (format['bitrate'] as num?)?.toInt();
      final sampleRate = (format['audioSampleRate'] as String?) ?? '';
      final audioChannels = (format['audioChannels'] as num?)?.toInt();
      final labelParts = <String>['Audio'];
      if (bitrate != null) labelParts.add('${(bitrate / 1000).round()} kbps');
      if (sampleRate.isNotEmpty) labelParts.add('${sampleRate}Hz');
      if (audioChannels != null) labelParts.add(audioChannels == 1 ? 'Mono' : 'Stereo');

      variants.add(VideoVariant(
        url: url,
        bitrate: bitrate,
        audioOnly: true,
        customLabel: labelParts.join(' • '),
      ));
    }

    // Add best quality convenience option
    variants.insert(0, VideoVariant(
      url: '',
      formatId: 'best',
      customLabel: 'Best quality (auto-select)',
    ));

    // Add MP3 audio option (use best audio stream)
    if (audioFormats.isNotEmpty) {
      final bestAudio = audioFormats.first;
      final bestAudioUrl = _extractStreamUrl(bestAudio);
      if (bestAudioUrl != null) {
        variants.add(VideoVariant(
          url: bestAudioUrl,
          audioOnly: true,
          customLabel: 'MP3 audio (best)',
        ));
      }
    }

    if (variants.isEmpty) return null;

    return YtVideoInfo(
      id: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnail,
      variants: variants,
      selectedVariant: variants.first,
    );
  }

  /// Parses ytInitialData as a fallback.
  YtVideoInfo? _parseInitialData(Map<String, dynamic> data, String videoId, String html) {
    // Extract basic info from the page metadata
    final title = RegExp(r'<title>(.+?)</title>', dotAll: true)
        .firstMatch(html)
        ?.group(1)
        ?.replaceAll(' - YouTube', '')
        .trim();

    final author = RegExp(r'"ownerChannelName":"([^"]+)"')
        .firstMatch(html)
        ?.group(1);

    final thumbnail = 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg';

    // We need streaming data - try to get it from the page
    // This is a limited fallback; the InnerTube approach is preferred
    return YtVideoInfo(
      id: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnail,
      variants: [
        VideoVariant(
          url: '',
          formatId: 'best',
          customLabel: 'Best quality (auto-select)',
        ),
      ],
      selectedVariant: null,
    );
  }

  /// Extracts the stream URL from a format object, handling cipher/ signatureCipher.
  String? _extractStreamUrl(Map<String, dynamic> format) {
    // Direct URL
    final url = format['url'] as String?;
    if (url != null && url.isNotEmpty) return url;

    // Ciphered URL (needs to be decoded)
    final cipher = format['cipher'] as String?;
    if (cipher != null && cipher.isNotEmpty) {
      return _decodeCipherUrl(cipher);
    }

    final signatureCipher = format['signatureCipher'] as String?;
    if (signatureCipher != null && signatureCipher.isNotEmpty) {
      return _decodeCipherUrl(signatureCipher);
    }

    return null;
  }

  /// Decodes a ciphered URL by extracting the URL and signature parameters.
  String? _decodeCipherUrl(String cipher) {
    try {
      // Parse the cipher string which is URL-encoded query parameters
      final decoded = Uri.decodeFull(cipher);
      final params = Uri.splitQueryString(decoded);

      final url = params['url'];
      if (url == null) return null;

      final sig = params['s'] ?? params['sig'] ?? params['signature'];
      final sp = params['sp'] ?? 'signature';

      if (sig != null) {
        final uri = Uri.parse(url);
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams[sp] = sig;
        return uri.replace(queryParameters: queryParams).toString();
      }

      return url;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the InnerTube API key from the page HTML.
  String? _extractInnerTubeApiKey(String html) {
    // Try ytcfg pattern
    final ytcfgMatch = RegExp(r'ytcfg\.set\s*\(\s*({.*?})\s*\)\s*;', dotAll: true).firstMatch(html);
    if (ytcfgMatch != null) {
      try {
        final ytcfg = jsonDecode(ytcfgMatch.group(1)!) as Map<String, dynamic>;
        final apiKey = ytcfg['INNERTUBE_API_KEY'] as String?;
        if (apiKey != null) return apiKey;
      } catch (_) {}
    }

    // Try direct INNERTUBE_API_KEY pattern
    final keyMatch = RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"').firstMatch(html);
    return keyMatch?.group(1);
  }

  /// Extracts the InnerTube context from the page HTML.
  Map<String, dynamic>? _extractInnerTubeContext(String html) {
    // Try ytcfg pattern
    final ytcfgMatch = RegExp(r'ytcfg\.set\s*\(\s*({.*?})\s*\)\s*;', dotAll: true).firstMatch(html);
    if (ytcfgMatch != null) {
      try {
        final ytcfg = jsonDecode(ytcfgMatch.group(1)!) as Map<String, dynamic>;
        final context = ytcfg['INNERTUBE_CONTEXT'] as Map<String, dynamic>?;
        if (context != null) return context;
      } catch (_) {}
    }

    // Try direct INNERTUBE_CONTEXT pattern
    final contextMatch = RegExp(r'"INNERTUBE_CONTEXT"\s*:\s*({.*?})(?:,\s*"[A-Z]|})', dotAll: true)
        .firstMatch(html);
    if (contextMatch != null) {
      try {
        return jsonDecode(contextMatch.group(1)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Build a default context
    return {
      'client': {
        'clientName': 'ANDROID',
        'clientVersion': '19.09.37',
        'androidSdkVersion': 34,
        'osName': 'Android',
        'osVersion': '14',
        'platform': 'MOBILE',
        'acceptHeader': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    };
  }

  /// Gets the signature timestamp from the page.
  int _getSignatureTimestamp(String html) {
    final match = RegExp(r'"signatureTimestamp"\s*:\s*(\d+)').firstMatch(html);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Gets the best available thumbnail URL.
  String? _getBestThumbnail(Map<String, dynamic>? thumbnailData) {
    if (thumbnailData == null) return null;
    final thumbnails = thumbnailData['thumbnails'] as List<dynamic>?;
    if (thumbnails == null || thumbnails.isEmpty) return null;

    // Return the highest resolution thumbnail
    Map<String, dynamic>? best;
    int bestSize = 0;
    for (final t in thumbnails.cast<Map<String, dynamic>>()) {
      final width = (t['width'] as num?)?.toInt() ?? 0;
      final height = (t['height'] as num?)?.toInt() ?? 0;
      final size = width * height;
      if (size > bestSize) {
        best = t;
        bestSize = size;
      }
    }
    return best?['url'] as String?;
  }

  /// Downloads a YouTube video on Android.
  ///
  /// Since we can't use yt-dlp on Android, this downloads the selected
  /// stream URL directly. For "best quality" (formatId == 'best'), it
  /// selects the highest quality video+audio combined stream.
  Future<String> download({
    required String pageUrl,
    required VideoVariant variant,
    required String outputDirectory,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await Directory(outputDirectory).create(recursive: true);

    String downloadUrl;
    String extension;

    if (variant.url.isNotEmpty && variant.url.startsWith('http')) {
      // Direct stream URL
      downloadUrl = variant.url;
      extension = variant.audioOnly ? 'mp3' : 'mp4';
    } else if (variant.formatId == 'best') {
      // Need to fetch the best stream
      final videoId = _extractVideoId(pageUrl);
      if (videoId == null) throw Exception('Could not extract video ID from URL');

      final info = await fetchInfo(pageUrl);
      if (info == null || info.variants.isEmpty) {
        throw Exception('Could not fetch video info for download');
      }

      // Find the best combined format (not audio-only, not video-only)
      final bestVariant = info.variants.firstWhere(
        (v) => v.url.isNotEmpty && !v.audioOnly && v.url.startsWith('http'),
        orElse: () => info.variants.firstWhere(
          (v) => v.url.isNotEmpty && v.url.startsWith('http'),
          orElse: () => throw Exception('No downloadable stream found'),
        ),
      );

      downloadUrl = bestVariant.url;
      extension = bestVariant.audioOnly ? 'mp3' : 'mp4';
    } else {
      throw Exception('No valid download URL for this variant');
    }

    // Generate a filename from the video ID
    final videoId = _extractVideoId(pageUrl) ?? DateTime.now().millisecondsSinceEpoch.toString();
    final filename = 'yt_$videoId.$extension';
    final filePath = '${outputDirectory}/$filename';

    // Download the file
    await _dio.download(
      downloadUrl,
      filePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Range': 'bytes=0-',
        },
        receiveTimeout: const Duration(minutes: 10),
      ),
    );

    if (onProgress != null) onProgress(1.0);
    return filePath;
  }
}
