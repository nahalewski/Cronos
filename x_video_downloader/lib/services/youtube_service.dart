import 'dart:convert';
import 'dart:io';

import 'package:x_video_downloader/models/tweet_video.dart';

class YtVideoInfo {
  const YtVideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.variants,
    required this.selectedVariant,
  });

  final String id;
  final String? title;
  final String? author;
  final String? thumbnailUrl;
  final List<VideoVariant> variants;
  final VideoVariant? selectedVariant;
}

class YoutubeService {
  static final RegExp _youtubeIdRegex = RegExp(
    r'^(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/|youtube\.com\/live\/)([A-Za-z0-9_-]{11})',
    caseSensitive: false,
  );

  static bool isXUrl(String url) => RegExp(r'https?://(?:www\.)?(?:x|twitter)\.com/', caseSensitive: false)
      .hasMatch(url.trim());

  static bool isYoutubeUrl(String url) => extractVideoId(url) != null;
  static bool isXvideosUrl(String url) =>
      RegExp(r'https?://(?:[a-z0-9-]+\.)?xvideos\.com/', caseSensitive: false).hasMatch(url.trim());
  static bool isXhamsterUrl(String url) =>
      RegExp(r'https?://(?:[a-z0-9-]+\.)?xhamster\.com/', caseSensitive: false).hasMatch(url.trim());
  static bool isHentaihavenUrl(String url) =>
      RegExp(r'https?://(?:[a-z0-9-]+\.)?hentaihaven\.xxx/', caseSensitive: false).hasMatch(url.trim());
  static bool isHanimeUrl(String url) =>
      RegExp(r'https?://(?:[a-z0-9-]+\.)?hanime\.tv/', caseSensitive: false).hasMatch(url.trim());
  static bool isRule34videoUrl(String url) =>
      RegExp(r'https?://(?:[a-z0-9-]+\.)?rule34video\.com/', caseSensitive: false).hasMatch(url.trim());

  static VideoSource? detectSource(String url) {
    final trimmed = url.trim();
    if (isXUrl(trimmed)) return VideoSource.twitter;
    if (isYoutubeUrl(trimmed)) return VideoSource.youtube;
    if (isXvideosUrl(trimmed)) return VideoSource.xvideos;
    if (isXhamsterUrl(trimmed)) return VideoSource.xhamster;
    if (isHentaihavenUrl(trimmed)) return VideoSource.hentaihaven;
    if (isHanimeUrl(trimmed)) return VideoSource.hanime;
    if (isRule34videoUrl(trimmed)) return VideoSource.rule34video;

    // Fallback for any other valid URL the user might paste.
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return VideoSource.other;
    }
    return null;
  }

  static String? extractVideoId(String url) {
    final trimmed = url.trim();
    // Only process if it's actually a YouTube domain to avoid false positives with v= params
    if (!trimmed.contains('youtube.com') && !trimmed.contains('youtu.be')) {
      return null;
    }

    final directMatch = _youtubeIdRegex.firstMatch(trimmed);
    if (directMatch != null) return directMatch.group(1);
    
    final shortMatch = RegExp(r'youtu\.be\/([A-Za-z0-9_-]{11})', caseSensitive: false)
        .firstMatch(trimmed);
    if (shortMatch != null) return shortMatch.group(1);
    
    final queryMatch = RegExp(r'youtube\.com\/.*[?&]v=([A-Za-z0-9_-]{11})', caseSensitive: false)
        .firstMatch(trimmed);
    return queryMatch?.group(1);
  }

  Future<YtVideoInfo> fetchInfo(String url, {required VideoSource source}) async {
    if (source != VideoSource.youtube && source != VideoSource.xvideos) {
      throw Exception('yt-dlp use is restricted for ${source.name}. Use universal engine instead.');
    }
    final result = await Process.run('yt-dlp', ['-J', '--no-playlist', url]);
    if (result.exitCode != 0) {
      throw Exception('yt-dlp metadata failed: ${result.stderr.toString().trim()}');
    }
    final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final id = (data['id']?.toString() ?? '').trim();
    if (id.isEmpty) {
      throw Exception('Unable to determine media id');
    }
    final title = data['title'] as String?;
    final author = (data['uploader'] as String?) ?? (data['channel'] as String?);
    final thumbnail = data['thumbnail'] as String?;
    final formats = (data['formats'] as List<dynamic>? ?? <dynamic>[]);

    final variants = _buildVariants(formats, source: source);
    if (variants.isEmpty) {
      throw Exception('No downloadable formats found');
    }
    return YtVideoInfo(
      id: id,
      title: title,
      author: author,
      thumbnailUrl: thumbnail,
      variants: variants,
      selectedVariant: variants.first,
    );
  }

  List<VideoVariant> _buildVariants(List<dynamic> formats, {required VideoSource source}) {
    final variants = <VideoVariant>[];

    // Best quality convenience option first.
    variants.add(
      VideoVariant(
        url: '',
        formatId: 'bv*+ba/b',
        customLabel: 'Best quality (video + audio)',
      ),
    );

    final videoFormats = <Map<String, dynamic>>[];
    final audioFormats = <Map<String, dynamic>>[];
    for (final item in formats.cast<Map<String, dynamic>>()) {
      final formatId = item['format_id']?.toString();
      if (formatId == null || formatId.isEmpty) continue;
      final vcodec = item['vcodec']?.toString() ?? 'none';
      final acodec = item['acodec']?.toString() ?? 'none';
      if (vcodec != 'none') videoFormats.add(item);
      if (acodec != 'none' && vcodec == 'none') audioFormats.add(item);
    }

    for (final format in videoFormats) {
      final id = format['format_id']?.toString();
      if (id == null) continue;
      final height = (format['height'] as num?)?.toInt();
      final width = (format['width'] as num?)?.toInt();
      final fps = (format['fps'] as num?)?.toInt();
      final vcodec = format['vcodec']?.toString();
      final tbr = (format['tbr'] as num?)?.toDouble();
      final resolution = (width != null && height != null) ? '${width}x$height' : null;
      final bitrate = tbr != null ? (tbr * 1000).round() : null;
      final labelParts = <String>[];
      if (height != null) labelParts.add('${height}p');
      if (fps != null) labelParts.add('${fps}fps');
      if (vcodec != null && vcodec != 'none') labelParts.add(vcodec.split('.').first);
      if (bitrate != null) labelParts.add('~${(bitrate / 1000).round()} kbps');

      variants.add(
        VideoVariant(
          url: '',
          formatId: '$id+ba/b',
          resolution: resolution,
          bitrate: bitrate,
          customLabel: labelParts.isNotEmpty ? labelParts.join(' • ') : id,
        ),
      );
    }

    // MP3 option for YouTube
    if (source == VideoSource.youtube) {
      variants.add(
        VideoVariant(
          url: '',
          formatId: 'bestaudio',
          audioOnly: true,
          customLabel: 'MP3 audio (best)',
        ),
      );
    } else {
      // For X expose best audio only too.
      variants.add(
        VideoVariant(
          url: '',
          formatId: 'bestaudio',
          audioOnly: true,
          customLabel: 'Audio only (best)',
        ),
      );
    }

    // Deduplicate by label+formatId preserving order.
    final seen = <String>{};
    final deduped = variants.where((v) {
      final key = '${v.customLabel}|${v.formatId}|${v.audioOnly}';
      return seen.add(key);
    }).toList();
    return deduped;
  }

  Future<String> download({
    required String pageUrl,
    required VideoVariant variant,
    required String outputDirectory,
    void Function(double progress)? onProgress,
  }) async {
    await Directory(outputDirectory).create(recursive: true);
    final outputTemplate = '$outputDirectory/%(title).120s [%(id)s].%(ext)s';

    final args = <String>[
      '--no-playlist',
      '--newline',
      '-o',
      outputTemplate,
    ];
    if (variant.audioOnly) {
      args.addAll(['-x', '--audio-format', 'mp3', '--audio-quality', '0']);
    } else {
      args.addAll(['-f', variant.formatId?.isNotEmpty == true ? variant.formatId! : 'bv*+ba/b']);
      args.addAll(['--merge-output-format', 'mp4']);
    }
    args.add(pageUrl);

    final process = await Process.start('yt-dlp', args);
    String? destinationPath;
    final stderrLines = <String>[];

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final match = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(line);
      if (match != null && onProgress != null) {
        final value = double.tryParse(match.group(1)!);
        if (value != null) onProgress((value / 100).clamp(0, 1));
      }
      final extracted = _extractDestinationPath(line);
      if (extracted != null) destinationPath = extracted;
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrLines.add(line);
      final extracted = _extractDestinationPath(line);
      if (extracted != null) destinationPath = extracted;
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final tail = stderrLines.skip(stderrLines.length > 6 ? stderrLines.length - 6 : 0).join('\n');
      throw Exception('yt-dlp download failed:\n$tail');
    }

    if (destinationPath != null && File(destinationPath!).existsSync()) {
      onProgress?.call(1.0);
      return destinationPath!;
    }

    final files = Directory(outputDirectory)
        .listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    if (files.isNotEmpty) {
      onProgress?.call(1.0);
      return files.first.path;
    }
    throw Exception('yt-dlp finished but output file was not found');
  }

  String? _extractDestinationPath(String line) {
    const destinationPrefix = '[download] Destination: ';
    if (line.startsWith(destinationPrefix)) {
      return line.substring(destinationPrefix.length).trim();
    }
    const mergedPrefix = '[Merger] Merging formats into "';
    if (line.startsWith(mergedPrefix)) {
      final endIndex = line.lastIndexOf('"');
      if (endIndex > mergedPrefix.length) {
        return line.substring(mergedPrefix.length, endIndex);
      }
    }
    const extractedAudioPrefix = '[ExtractAudio] Destination: ';
    if (line.startsWith(extractedAudioPrefix)) {
      return line.substring(extractedAudioPrefix.length).trim();
    }
    return null;
  }
}
