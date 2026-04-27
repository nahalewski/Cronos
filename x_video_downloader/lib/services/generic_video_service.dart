import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import '../models/tweet_video.dart';

class GenericVideoInfo {
  final String title;
  final String? thumbnailUrl;
  final List<VideoVariant> variants;

  GenericVideoInfo({
    required this.title,
    this.thumbnailUrl,
    required this.variants,
  });
}

class GenericVideoService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    },
  ));

  static const List<String> _blacklistedKeywords = [
    'preview', 'teaser', 'trailer', 'ad_', 'advert', 'short', 'sample'
  ];

  // ── Public entry points ───────────────────────────────────────────────────

  /// Dispatcher: routes to the right scraper based on detected source.
  Future<GenericVideoInfo?> fetchForSource(String url, VideoSource source) async {
    return switch (source) {
      VideoSource.xhamster => fetchXhamsterInfo(url),
      VideoSource.xvideos  => fetchXvideosInfo(url),
      _                    => fetchGenericInfo(url),
    };
  }

  /// XHamster-specific scraper — no yt-dlp, parses JS-embedded video config.
  Future<GenericVideoInfo?> fetchXhamsterInfo(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(headers: {
          'Referer': 'https://xhamster.com/',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        }),
      );
      if (response.data is! String) return null;
      final body = response.data as String;
      final document = html.parse(body);
      final title = _cleanTitle(document.querySelector('title')?.text ?? 'xHamster Video');
      String? thumbnail = document
          .querySelector('meta[property="og:image"]')
          ?.attributes['content'];

      final variants = <VideoVariant>[];
      final seenUrls = <String>{};

      void add(String u, String label) {
        if (u.isEmpty || seenUrls.contains(u)) return;
        if (_isBlacklisted(u)) return;
        seenUrls.add(u);
        variants.add(VideoVariant(url: u, customLabel: label));
      }

      // 1. JSON-LD contentUrl (most reliable when present)
      for (final script in document.querySelectorAll('script[type="application/ld+json"]')) {
        try {
          final decoded = jsonDecode(script.text);
          final objs = decoded is List ? decoded : [decoded];
          for (final obj in objs) {
            if (obj is! Map) continue;
            final contentUrl = obj['contentUrl'] as String?;
            if (contentUrl != null && contentUrl.contains('mp4')) {
              add(contentUrl, 'HD (JSON-LD)');
            }
            final thumbnail0 = obj['thumbnailUrl'];
            if (thumbnail == null && thumbnail0 is String) thumbnail = thumbnail0;
          }
        } catch (_) {}
      }

      // 2. xHamster embeds video data in a script block containing
      //    "sources" or "files" with resolution-keyed MP4 URLs.
      //    Patterns seen:
      //      {"360p":"https://...","720p":"https://..."}
      //      "sources":{"standard":[{"url":"https://...","quality":"1080p"},...]}
      //      window.xHamsterSettings = { ..., "sources": {...} }
      final scriptTags = document.querySelectorAll('script:not([src])');
      for (final script in scriptTags) {
        final text = script.text;
        if (!text.contains('mp4') && !text.contains('sources') && !text.contains('files')) {
          continue;
        }

        // Pattern A: quality-keyed dict  "720p":"https://cdn.../video.mp4"
        final qualityKeyedMatches = RegExp(
          r'"(\d+p)"\s*:\s*"(https?://[^"]+\.mp4[^"]*)"',
        ).allMatches(text);
        final qualityMap = <int, ({String url, String label})>{};
        for (final m in qualityKeyedMatches) {
          final label = m.group(1)!;
          final u = m.group(2)!;
          final height = int.tryParse(label.replaceAll('p', '')) ?? 0;
          if (!_isBlacklisted(u) && !seenUrls.contains(u)) {
            qualityMap[height] = (url: u, label: label);
          }
        }
        for (final entry in (qualityMap.entries.toList()..sort((a, b) => b.key.compareTo(a.key)))) {
          add(entry.value.url, entry.value.label);
        }

        // Pattern B: "url":"https://...mp4..." inside a sources/files array
        final urlMatches = RegExp(
          r'"url"\s*:\s*"(https?://[^"]+\.mp4[^"]*)"',
        ).allMatches(text);
        for (final m in urlMatches) {
          final u = m.group(1)!;
          if (!_isBlacklisted(u)) add(u, 'MP4');
        }

        // Pattern C: plain mp4 href/src strings not caught above
        final plainMp4 = RegExp(
          r'(https?://[a-z0-9._-]+\.xhamster[a-z0-9._-]*[^ "<>]+\.mp4[^ "<>]*)',
          caseSensitive: false,
        ).allMatches(text);
        for (final m in plainMp4) {
          add(m.group(1)!, 'MP4 (found)');
        }
      }

      // 3. OG video tag fallback
      final ogVideo = document
          .querySelector('meta[property="og:video:url"]')
          ?.attributes['content'] ??
          document
              .querySelector('meta[property="og:video"]')
              ?.attributes['content'];
      if (ogVideo != null) add(ogVideo, 'OG Video');

      if (variants.isEmpty) return null;

      return GenericVideoInfo(
        title: title,
        thumbnailUrl: thumbnail,
        variants: variants,
      );
    } catch (e) {
      return null;
    }
  }

  /// XVideos-specific scraper.
  Future<GenericVideoInfo?> fetchXvideosInfo(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.data is! String) return null;
      final body = response.data as String;
      final document = html.parse(body);
      final title = _cleanTitle(document.querySelector('title')?.text ?? 'XVideos');
      String? thumbnail = document
          .querySelector('meta[property="og:image"]')?.attributes['content'];

      final variants = <VideoVariant>[];
      final seenUrls = <String>{};

      void add(String u, String label) {
        if (u.isEmpty || seenUrls.contains(u)) return;
        if (_isBlacklisted(u)) return;
        seenUrls.add(u);
        variants.add(VideoVariant(url: u, customLabel: label));
      }

      for (final script in document.querySelectorAll('script:not([src])')) {
        final text = script.text;
        if (!text.contains('mp4') && !text.contains('setVideoHLS')) continue;

        // XVideos embeds: html5lib.setVideoHLS('...') or similar
        final hlsMatch = RegExp(r"setVideoHLS\('([^']+)'\)").firstMatch(text);
        if (hlsMatch != null) {
          // HLS is not directly downloadable; skip and rely on mp4 matches below
        }

        // html5player.setVideoUrlHigh('...') / setVideoUrlLow('...')
        for (final m in RegExp(r"setVideoUrl(?:High|Low)\('([^']+)'\)").allMatches(text)) {
          add(m.group(1)!, m.group(0)!.contains('High') ? 'High Quality' : 'Low Quality');
        }

        // Generic quoted mp4 URLs
        for (final m in RegExp(r"'(https?://[^']+\.mp4[^']*)'").allMatches(text)) {
          add(m.group(1)!, 'MP4');
        }
        for (final m in RegExp(r'"(https?://[^"]+\.mp4[^"]*)"').allMatches(text)) {
          add(m.group(1)!, 'MP4');
        }
      }

      // OG video fallback
      final ogVideo = document
          .querySelector('meta[property="og:video:url"]')?.attributes['content'] ??
          document.querySelector('meta[property="og:video"]')?.attributes['content'];
      if (ogVideo != null) add(ogVideo, 'OG Video');

      if (variants.isEmpty) return null;
      return GenericVideoInfo(title: title, thumbnailUrl: thumbnail, variants: variants);
    } catch (_) {
      return null;
    }
  }

  /// General-purpose HTML scraper for any other site.
  Future<GenericVideoInfo?> fetchGenericInfo(String url) async {
    try {
      final directLink = await _checkDirectLink(url);
      if (directLink != null) {
        return GenericVideoInfo(
          title: p.basenameWithoutExtension(Uri.parse(url).path),
          variants: [directLink],
        );
      }
      return await _scrapeHtml(url);
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<VideoVariant?> _checkDirectLink(String url) async {
    try {
      final uri = Uri.parse(url);
      final ext = p.extension(uri.path).toLowerCase();
      if (['.mp4', '.mkv', '.webm', '.mov', '.avi'].contains(ext)) {
        final response = await _dio.head(url);
        final contentType = response.headers.value('content-type')?.toLowerCase() ?? '';
        if (contentType.startsWith('video/')) {
          return VideoVariant(
            url: url,
            customLabel: 'Direct Video (${ext.substring(1).toUpperCase()})',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isBlacklisted(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return _blacklistedKeywords.any((k) => lower.contains(k));
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*[-|–]\s*(xHamster|XVideos|xvideos|Pornhub).*', caseSensitive: false), '')
        .trim();
  }

  Future<GenericVideoInfo?> _scrapeHtml(String url) async {
    try {
      final response = await _dio.get(url);
      if (response.data is! String) return null;

      final document = html.parse(response.data);
      final title = document.querySelector('title')?.text ?? 'Video';
      final variants = <VideoVariant>[];
      final seenUrls = <String>{};
      String? thumbnail;

      void add(String? src, String label) {
        if (src == null || src.isEmpty) return;
        final absolute = Uri.parse(url).resolve(src).toString();
        if (seenUrls.contains(absolute) || _isBlacklisted(absolute)) return;
        seenUrls.add(absolute);
        variants.add(VideoVariant(url: absolute, customLabel: label));
      }

      final ogVideo = document.querySelector('meta[property="og:video"]')?.attributes['content'] ??
          document.querySelector('meta[property="og:video:url"]')?.attributes['content'] ??
          document.querySelector('meta[property="og:video:secure_url"]')?.attributes['content'];
      add(ogVideo, 'Found via OG');

      thumbnail = document.querySelector('meta[property="og:image"]')?.attributes['content'];

      final twitterVideo =
          document.querySelector('meta[name="twitter:player:stream"]')?.attributes['content'];
      add(twitterVideo, 'Found via Twitter Player');

      for (final video in document.querySelectorAll('video')) {
        final src = video.attributes['src'] ?? video.querySelector('source')?.attributes['src'];
        add(src, 'Found via HTML5 Video');
      }

      if (variants.isEmpty) return null;
      return GenericVideoInfo(title: title.trim(), thumbnailUrl: thumbnail, variants: variants);
    } catch (_) {
      return null;
    }
  }
}
