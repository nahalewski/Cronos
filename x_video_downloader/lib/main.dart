import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:x_video_downloader/models/app_settings.dart';
import 'package:x_video_downloader/models/browser_photo.dart';
import 'package:x_video_downloader/models/tweet_video.dart';
import 'package:x_video_downloader/screens/dashboard_screen.dart';
import 'package:x_video_downloader/screens/downloads_screen.dart';
import 'package:x_video_downloader/screens/library_screen.dart';
import 'package:x_video_downloader/screens/photos_screen.dart';
import 'package:x_video_downloader/screens/player_screen.dart';
import 'package:x_video_downloader/screens/settings_screen.dart';
import 'package:x_video_downloader/screens/music_screen.dart';
import 'package:x_video_downloader/services/app_settings_service.dart';
import 'package:x_video_downloader/services/download_service.dart';
import 'package:x_video_downloader/services/library_metadata_service.dart';
import 'package:x_video_downloader/services/twitter_service.dart';
import 'package:x_video_downloader/services/youtube_service.dart';
import 'package:x_video_downloader/services/youtube_android_service.dart';
import 'package:x_video_downloader/services/failure_logging_service.dart';
import 'package:x_video_downloader/services/generic_video_service.dart';
import 'package:x_video_downloader/services/notification_service.dart';
import 'package:x_video_downloader/services/pornhub_service.dart';
import 'package:x_video_downloader/services/luxuretv_service.dart';
import 'package:x_video_downloader/services/link_log_service.dart';
import 'package:x_video_downloader/services/download_queue_service.dart';
import 'package:x_video_downloader/theme.dart';
import 'package:x_video_downloader/widgets/side_nav_bar.dart';
import 'package:x_video_downloader/widgets/top_nav_bar.dart';
import 'package:x_video_downloader/widgets/x_browser_panel.dart';
import 'package:x_video_downloader/widgets/notification_bubble.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable Impeller rendering engine for Android - much smoother GPU rendering
  if (Platform.isAndroid) {
    try {
      // Impeller is enabled via AndroidManifest metadata or flutter build flags
      // We set it here as a runtime hint
      debugPrint('Running on Android - Impeller rendering enabled');
    } catch (_) {}
  }
  
  if (Platform.isMacOS) {
    await _configureDesktopWindow();
  }
  runApp(const MyApp());
}

Future<void> _configureDesktopWindow() async {
  // window_size is macOS-only - use conditional import pattern
  try {
    // ignore: depend_on_referenced_packages
    final windowSize = await _importWindowSize();
    if (windowSize != null) {
      windowSize.setWindowTitle('Cronos');
      windowSize.setWindowMinSize(const Size(1180, 760));
      windowSize.setWindowMaxSize(Size.infinite);
    }
  } catch (_) {
    // window_size not available on this platform
  }
}

Future<dynamic> _importWindowSize() async {
  // This function exists to allow conditional compilation
  // On macOS, the window_size package is available
  // On other platforms, this gracefully returns null
  try {
    // Use a deferred/dynamic approach
    // ignore: depend_on_referenced_packages
    return await Future.value(null);
  } catch (_) {
    return null;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.enableBrowserPanel = true,
    this.enableClipboardWatcher = true,
  });

  final bool enableBrowserPanel;
  final bool enableClipboardWatcher;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cronos',
      theme: buildVenturaSlateTheme(),
      home: HomePage(
        enableBrowserPanel: enableBrowserPanel,
        enableClipboardWatcher: enableClipboardWatcher,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.enableBrowserPanel = true,
    this.enableClipboardWatcher = true,
  });

  final bool enableBrowserPanel;
  final bool enableClipboardWatcher;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppSection _selected = AppSection.dashboard;
  final TextEditingController _urlController = TextEditingController();
  final List<TweetVideo> _videos = [];
  final List<BrowserPhoto> _photos = [];
  final TwitterService _twitterService = TwitterService();
  final YoutubeService _youtubeService = YoutubeService();
  final YoutubeAndroidService _youtubeAndroidService = YoutubeAndroidService();
  final DownloadService _downloadService = DownloadService();
  final AppSettingsService _settingsService = AppSettingsService();
  final LibraryMetadataService _libraryMetadataService = LibraryMetadataService();
  final FailureLoggingService _failureLoggingService = FailureLoggingService();
  final GenericVideoService _genericVideoService = GenericVideoService();
  final NotificationService _notificationService = NotificationService();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, LibraryMetadata> _libraryMetadataByPath = {};
  bool _queueUrlsRunning = false; // Prevents concurrent _queueUrls calls
  AppSettings _settings = AppSettings.defaults();
  bool _addingUrls = false;
  late bool _showBrowserPanel;
  BrowserRequest? _browserRequest;
  int _browserRequestSeq = 0;
  Timer? _clipboardTimer;
  String? _lastClipboardText;
  String? _downloadDirectory;
  bool _isBrowserMinimized = false;
  bool _isDashboardHidden = false;
  double? _desktopBrowserWidth;
  Timer? _queueProcessorTimer;
  bool _queueProcessing = false;

  @override
  void initState() {
    super.initState();
    _showBrowserPanel = widget.enableBrowserPanel;
    _notificationService.init();
    _loadSettings();
    _loadDownloadQueue();
    _startClipboardWatcher();
    _startQueueProcessor();
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _queueProcessorTimer?.cancel();
    _saveDownloadQueue();
    _urlController.dispose();
    super.dispose();
  }

  /// Load the download queue from disk on startup.
  Future<void> _loadDownloadQueue() async {
    final saved = await DownloadQueueService.loadQueue();
    if (saved.isEmpty) return;
    if (!mounted) return;
    setState(() {
      // Reset any "downloading" items to "idle" so they resume on next launch
      for (final video in saved) {
        if (video.status == DownloadStatus.downloading) {
          video.status = DownloadStatus.idle;
          video.downloadProgress = 0.0;
        }
      }
      _videos.addAll(saved);
    });
  }

  /// Save the download queue to disk.
  Future<void> _saveDownloadQueue() async {
    await DownloadQueueService.saveQueue(_videos);
  }

  /// Start a background timer that auto-processes the download queue.
  void _startQueueProcessor() {
    _queueProcessorTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _processQueue(),
    );
  }

  /// Auto-process the download queue: start up to 6 concurrent downloads.
  Future<void> _processQueue() async {
    if (_queueProcessing) return;
    _queueProcessing = true;

    try {
      // Count currently downloading
      final downloading = _videos.where((v) => v.status == DownloadStatus.downloading).length;
      final maxConcurrent = 6;
      final slotsAvailable = maxConcurrent - downloading;

      if (slotsAvailable <= 0) return;

      // Get pending items (idle or error)
      final pending = _videos
          .where((v) => v.status == DownloadStatus.idle || v.status == DownloadStatus.error)
          .take(slotsAvailable)
          .toList();

      if (pending.isEmpty) return;

      // Start downloads in parallel
      await Future.wait(pending.map((video) => _downloadVideo(video)));
    } finally {
      _queueProcessing = false;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  Future<void> _loadSettings() async {
    final loaded = await _settingsService.load();
    final metadata = await _libraryMetadataService.loadAll();
    String? resolvedDir = loaded.downloadDirectory;
    resolvedDir ??= await DownloadService.getEffectiveDirectory();
    if (!mounted) return;
    setState(() {
      _settings = loaded.copyWith(
        downloadDirectory: resolvedDir,
        photoDownloadDirectory: loaded.photoDownloadDirectory,
        xVideoDownloadDirectory: loaded.xVideoDownloadDirectory,
        youtubeVideoDownloadDirectory: loaded.youtubeVideoDownloadDirectory,
        youtubeMp3DownloadDirectory: loaded.youtubeMp3DownloadDirectory,
        xvideosDownloadDirectory: loaded.xvideosDownloadDirectory,
        xhamsterDownloadDirectory: loaded.xhamsterDownloadDirectory,
        hentaihavenDownloadDirectory: loaded.hentaihavenDownloadDirectory,
        hanimeDownloadDirectory: loaded.hanimeDownloadDirectory,
        rule34videoDownloadDirectory: loaded.rule34videoDownloadDirectory,
        useUnifiedFolder: loaded.useUnifiedFolder,
        unifiedDownloadDirectory: loaded.unifiedDownloadDirectory,
      );
      _downloadDirectory = resolvedDir;
      _libraryMetadataByPath
        ..clear()
        ..addAll(metadata);
    });
  }

  Future<void> _saveSettings() async {
    await _settingsService.save(_settings);
    await _loadSettings();
  }



  Future<String?> _pickDirectory(String? dialogTitle) async {
    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
    } catch (e) {
      debugPrint('Error picking directory: $e');
      return null;
    }
  }

  Future<void> _pickDownloadDirectory() async {
    final path = await _pickDirectory('Select Download Folder');
    if (path == null) return;
    await DownloadService.saveDirectory(path);
    setState(() {
      _downloadDirectory = path;
      _settings = _settings.copyWith(
        downloadDirectory: path,
        xVideoDownloadDirectory: _settings.xVideoDownloadDirectory,
        youtubeVideoDownloadDirectory: _settings.youtubeVideoDownloadDirectory,
        youtubeMp3DownloadDirectory: _settings.youtubeMp3DownloadDirectory,
        xvideosDownloadDirectory: _settings.xvideosDownloadDirectory,
        xhamsterDownloadDirectory: _settings.xhamsterDownloadDirectory,
        hentaihavenDownloadDirectory: _settings.hentaihavenDownloadDirectory,
        hanimeDownloadDirectory: _settings.hanimeDownloadDirectory,
        rule34videoDownloadDirectory: _settings.rule34videoDownloadDirectory,
      );
    });
    await _saveSettings();
    _showSnack('Download folder set');
  }

  Future<void> _pickXVideoDirectory() async {
    final path = await _pickDirectory('Select X Video Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(xVideoDownloadDirectory: path));
    await _saveSettings();
    _showSnack('X video folder updated');
  }

  Future<void> _pickPhotoDirectory() async {
    final path = await _pickDirectory('Select Photo Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(photoDownloadDirectory: path));
    await _saveSettings();
    _showSnack('Photo folder updated');
  }

  Future<void> _pickYoutubeVideoDirectory() async {
    final path = await _pickDirectory('Select YouTube Video Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(youtubeVideoDownloadDirectory: path));
    await _saveSettings();
    _showSnack('YouTube video folder updated');
  }

  Future<void> _pickYoutubeMp3Directory() async {
    final path = await _pickDirectory('Select YouTube MP3 Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(youtubeMp3DownloadDirectory: path));
    await _saveSettings();
    _showSnack('YouTube MP3 folder updated');
  }

  Future<void> _pickXvideosDirectory() async {
    final path = await _pickDirectory('Select XVideos Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(xvideosDownloadDirectory: path));
    await _saveSettings();
    _showSnack('XVideos folder updated');
  }

  Future<void> _pickXhamsterDirectory() async {
    final path = await _pickDirectory('Select xHamster Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(xhamsterDownloadDirectory: path));
    await _saveSettings();
    _showSnack('xHamster folder updated');
  }

  Future<void> _pickHentaihavenDirectory() async {
    final path = await _pickDirectory('Select HentaiHaven Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(hentaihavenDownloadDirectory: path));
    await _saveSettings();
    _showSnack('HentaiHaven folder updated');
  }

  Future<void> _pickHanimeDirectory() async {
    final path = await _pickDirectory('Select hanime.tv Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(hanimeDownloadDirectory: path));
    await _saveSettings();
    _showSnack('hanime.tv folder updated');
  }

  Future<void> _pickRule34videoDirectory() async {
    final path = await _pickDirectory('Select Rule34Video Folder');
    if (path == null) return;
    setState(() => _settings = _settings.copyWith(rule34videoDownloadDirectory: path));
    await _saveSettings();
    _showSnack('rule34video.com folder updated');
  }

  Future<void> _pickUnifiedDirectory() async {
    final path = await _pickDirectory('Select Root Download Folder');
    if (path != null) {
      setState(() => _settings = _settings.copyWith(unifiedDownloadDirectory: path));
      await _saveSettings();
      _showSnack('Unified folder root set');
    }
  }

  Future<void> _migrateInternalDownloads() async {
    if (_settings.unifiedDownloadDirectory == null) {
      _showSnack('Please set a Root Download Folder first');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Migrating videos... please wait')),
    );

    try {
      final moved = await _downloadService.migrateInternalToExternal(_settings.unifiedDownloadDirectory!);
      _showSnack('Successfully moved $moved videos to storage');
      // Refresh library metadata if needed
      await _loadSettings();
    } catch (e) {
      _showSnack('Migration failed: $e');
    }
  }

  Future<void> _addUrls() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;

    final urls = _parseSupportedUrls(raw);
    await _queueUrls(urls, source: 'input');
    _urlController.clear();
  }

  Future<void> _queueUrls(
    List<String> urls, {
    required String source,
    bool showFeedback = true,
  }) async {
    if (urls.isEmpty) {
      _showSnack('No supported URLs found');
      return;
    }

    // Prevent concurrent _queueUrls calls — if one is already running, queue
    // the URLs for the next call by simply returning; the browser will re-send
    // on the next scan cycle.
    if (_queueUrlsRunning) {
      debugPrint('[DEBUG] _queueUrls already running, skipping concurrent call');
      return;
    }
    _queueUrlsRunning = true;

    try {
      final existingKeys = _videos
          .map((v) => _buildDuplicateKey(v.inputUrl, v.source))
          .toSet();
      final parsed = <({String id, String url, VideoSource source})>[];
      for (final url in urls) {
        final detectedSource = YoutubeService.detectSource(url);
        if (detectedSource == null) continue;
        final normalizedUrl = _normalizeSupportedUrl(url, detectedSource);
        final duplicateKey = _buildDuplicateKey(normalizedUrl, detectedSource);
        final id = _buildVideoId(url, detectedSource);
        
        // Check if already in queue (checks _videos list)
        if (existingKeys.contains(duplicateKey)) continue;
        
        // Check if already logged in history (optional - can be enabled/disabled)
        final isLogged = await LinkLogService.isLinkLogged(normalizedUrl);
        if (isLogged && _settings.preventDuplicateDownloads) {
          if (showFeedback) {
            _showSnack('URL already downloaded previously: $normalizedUrl');
          }
          continue;
        }
        
        parsed.add((id: id, url: normalizedUrl, source: detectedSource));
        existingKeys.add(duplicateKey);
      }

      if (parsed.isEmpty) {
        _showSnack('All URLs already added or previously downloaded');
        return;
      }

      setState(() {
        _addingUrls = true;
        for (final item in parsed) {
          _videos.add(TweetVideo(
            id: item.id,
            inputUrl: item.url,
            source: item.source,
            status: DownloadStatus.fetching,
          ));
        }
      });

      for (final item in parsed) {
        try {
          await _fetchMetadata(item.id, item.url, item.source);
          // Log successful fetch
          await LinkLogService.logVideoFetchSuccess(
            url: item.url,
            source: item.source.name,
          );
        } catch (e) {
          debugPrint('Error fetching metadata for ${item.url}: $e');
          _updateVideo(item.id, (v) {
            v.status = DownloadStatus.error;
            v.errorMessage = e.toString();
          });
          unawaited(_failureLoggingService.logFailure(
            url: item.url,
            source: item.source.name,
            error: e.toString(),
          ));
          // Log failed fetch
          await LinkLogService.logVideoFetchFailure(
            url: item.url,
            source: item.source.name,
            error: e.toString(),
          );
        }
      }

      if (mounted) setState(() => _addingUrls = false);
      if (showFeedback) {
        _showSnack('Added ${parsed.length} link(s) from $source');
      }
      // Persist queue after adding new items
      await _saveDownloadQueue();
    } finally {
      _queueUrlsRunning = false;
    }
  }

  List<String> _parseSupportedUrls(String rawText) {
    final tokens = rawText.split(RegExp(r'[\s,\n]+')).map((t) => t.trim()).where((t) => t.isNotEmpty);
    final unique = <String>{};
    for (final token in tokens) {
      final source = YoutubeService.detectSource(token);
      if (source != null) {
        unique.add(_normalizeSupportedUrl(token, source));
      }
    }
    return unique.toList();
  }

  String _normalizeSupportedUrl(String url, VideoSource source) {
    final trimmed = url.trim();
    switch (source) {
      case VideoSource.twitter:
        final tweetId = TwitterService.extractTweetId(trimmed);
        if (tweetId != null) return 'https://x.com/i/status/$tweetId';
        return trimmed;
      case VideoSource.youtube:
        final videoId = YoutubeService.extractVideoId(trimmed);
        if (videoId != null) return 'https://www.youtube.com/watch?v=$videoId';
        return trimmed;
      case VideoSource.xvideos:
      case VideoSource.xhamster:
      case VideoSource.hentaihaven:
      case VideoSource.hanime:
      case VideoSource.rule34video:
      case VideoSource.other:
        final uri = Uri.tryParse(trimmed);
        if (uri == null) return trimmed;
        return uri.replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          fragment: '',
        ).toString();
    }
  }

  String _buildDuplicateKey(String url, VideoSource source) {
    switch (source) {
      case VideoSource.twitter:
        return 'x:${TwitterService.extractTweetId(url) ?? url.trim().toLowerCase()}';
      case VideoSource.youtube:
        return 'yt:${YoutubeService.extractVideoId(url) ?? url.trim().toLowerCase()}';
      case VideoSource.xvideos:
      case VideoSource.xhamster:
      case VideoSource.hentaihaven:
      case VideoSource.hanime:
      case VideoSource.rule34video:
      case VideoSource.other:
        final uri = Uri.tryParse(url.trim());
        if (uri == null) return '${source.name}:${url.trim().toLowerCase()}';
        final normalized = uri.replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          fragment: '',
        ).toString();
        return '${source.name}:$normalized';
    }
  }

  String _buildVideoId(String url, VideoSource source) {
    if (source == VideoSource.twitter) {
      final twitterId = TwitterService.extractTweetId(url);
      if (twitterId != null) return 'x_$twitterId';
    }
    if (source == VideoSource.youtube) {
      final youtubeId = YoutubeService.extractVideoId(url);
      if (youtubeId != null) return 'yt_$youtubeId';
    }
    
    final uri = Uri.tryParse(url.trim());
    final host = uri?.host ?? 'unknown_site';
    final path = uri?.path ?? '';
    final query = (uri?.hasQuery == true) ? '?${uri!.query}' : '';
    final normalized = '$host$path$query';
    
    final slug = normalized
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final safe = slug.isEmpty ? normalized.hashCode.abs().toString() : slug;
    return '${source.name}_$safe';
  }

  void _startClipboardWatcher() {
    if (!widget.enableClipboardWatcher) return;
    _clipboardTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) async {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text?.trim();
        if (text == null || text.isEmpty || text == _lastClipboardText) return;
        _lastClipboardText = text;
        final urls = _parseSupportedUrls(text);
        if (urls.isEmpty || !mounted) return;
        await _queueUrls(urls, source: 'clipboard', showFeedback: false);
      } catch (e) {
        debugPrint('Clipboard watcher error: $e');
      }
    });
  }

  Future<void> _handleSourceTap(String source) async {
    final (url, tab) = switch (source) {
      'x' || 'twitter' => ('https://x.com', BrowserTab.x),
      'youtube' => ('https://www.youtube.com', BrowserTab.youtube),
      'xvideos' => ('https://www.xvideos.com', BrowserTab.custom),
      'xhamster' => ('https://xhamster.com', BrowserTab.custom),
      'hentaihaven' => ('https://hentaihaven.xxx', BrowserTab.custom),
      'hanime' => ('https://hanime.tv/home', BrowserTab.custom),
      'rule34video' => ('https://rule34video.com', BrowserTab.custom),
      'pornhub' => ('https://pornhub.com', BrowserTab.custom),
      'youporn' => ('https://youporn.com', BrowserTab.custom),
      'redtube' => ('https://redtube.com', BrowserTab.custom),
      'spankbang' => ('https://spankbang.com', BrowserTab.custom),
      'xnxx' => ('https://xnxx.com', BrowserTab.custom),
      'xhamsterlive' => ('https://xhamsterlive.com', BrowserTab.custom),
      'pornhubpremium' => ('https://pornhubpremium.com', BrowserTab.custom),
      'luxuretv' => ('https://en.luxuretv.com', BrowserTab.custom),
      _ => ('', BrowserTab.custom),
    };
    if (url.isEmpty) return;
    setState(() {
      _showBrowserPanel = true;
      _browserRequestSeq += 1;
      _browserRequest = BrowserRequest(
        sequence: _browserRequestSeq,
        tab: tab,
        url: url,
      );
    });
  }

  void _handlePhotoDetected(BrowserPhotoDetection detection) {
    final id = _buildPhotoId(detection.imageUrl);
    if (_photos.any((photo) => photo.id == id)) return;
    setState(() {
      _photos.insert(
        0,
        BrowserPhoto(
          id: id,
          pageUrl: detection.pageUrl,
          imageUrl: detection.imageUrl,
        ),
      );
    });
  }

  Future<void> _fetchMetadata(String id, String url, VideoSource source) async {
    debugPrint('[DEBUG] Fetching metadata for $id - Source: ${source.name} - URL: $url');
    try {
      if (source == VideoSource.twitter) {
        final info = await _twitterService.fetchTweetInfo(url);
        final preferred = _selectPreferredVariant(info.variants);
        _updateVideo(id, (v) {
          v.tweetText = info.tweetText;
          v.authorName = info.authorName;
          v.thumbnailUrl = info.thumbnailUrl;
          v.variants = info.variants;
          v.selectedVariant = preferred ?? info.selectedVariant;
          v.status = DownloadStatus.idle;
        });
        return;
      }

      if (source == VideoSource.youtube) {
        if (Platform.isAndroid) {
          // Android: use InnerTube API instead of yt-dlp
          final info = await _youtubeAndroidService.fetchInfo(url);
          if (info != null) {
            final preferred = _selectPreferredVariant(info.variants);
            _updateVideo(id, (v) {
              v.tweetText = info.title;
              v.authorName = info.author;
              v.thumbnailUrl = info.thumbnailUrl;
              v.variants = info.variants;
              v.selectedVariant = preferred ?? info.selectedVariant;
              v.status = DownloadStatus.idle;
            });
            return;
          }
          throw Exception('Could not extract YouTube video info on Android');
        } else {
          // macOS: use yt-dlp
          final info = await _youtubeService.fetchInfo(url, source: source);
          final preferred = _selectPreferredVariant(info.variants);
          _updateVideo(id, (v) {
            v.tweetText = info.title;
            v.authorName = info.author;
            v.thumbnailUrl = info.thumbnailUrl;
            v.variants = info.variants;
            v.selectedVariant = preferred ?? info.selectedVariant;
            v.status = DownloadStatus.idle;
          });
          return;
        }
      }

      // XVideos: site-specific scraper → yt-dlp fallback
      if (source == VideoSource.xvideos) {
        final generic = await _genericVideoService.fetchXvideosInfo(url);
        if (generic != null && generic.variants.isNotEmpty) {
          _updateVideo(id, (v) {
            v.tweetText = generic.title;
            v.authorName = 'XVideos';
            v.thumbnailUrl = generic.thumbnailUrl;
            v.variants = generic.variants;
            v.selectedVariant = generic.variants.first;
            v.status = DownloadStatus.idle;
          });
          return;
        }
        // Fallback to yt-dlp only for XVideos
        final info = await _youtubeService.fetchInfo(url, source: source);
        final preferred = _selectPreferredVariant(info.variants);
        _updateVideo(id, (v) {
          v.tweetText = info.title;
          v.authorName = info.author;
          v.thumbnailUrl = info.thumbnailUrl;
          v.variants = info.variants;
          v.selectedVariant = preferred ?? info.selectedVariant;
          v.status = DownloadStatus.idle;
        });
        return;
      }

      // XHamster: same site-specific scraping approach as XVideos, no yt-dlp
      if (source == VideoSource.xhamster) {
        final generic = await _genericVideoService.fetchXhamsterInfo(url);
        if (generic != null && generic.variants.isNotEmpty) {
          _updateVideo(id, (v) {
            v.tweetText = generic.title;
            v.authorName = 'xHamster';
            v.thumbnailUrl = generic.thumbnailUrl;
            v.variants = generic.variants;
            v.selectedVariant = generic.variants.first;
            v.status = DownloadStatus.idle;
          });
          return;
        }
        throw Exception('Could not extract video from xHamster page — the video may be members-only or region-locked');
      }

      // PornHub specific scraper
      if (url.contains('pornhub.com')) {
        final pornhubVideo = await PornhubService.fetchVideoInfo(url);
        if (pornhubVideo != null) {
          _updateVideo(id, (v) {
            v.tweetText = pornhubVideo.tweetText;
            v.authorName = pornhubVideo.authorName;
            v.thumbnailUrl = pornhubVideo.thumbnailUrl;
            v.variants = pornhubVideo.variants;
            v.selectedVariant = pornhubVideo.selectedVariant;
            v.status = DownloadStatus.idle;
          });
          return;
        }
      }

      // LuxureTV specific scraper
      if (url.contains('luxuretv.com')) {
        final luxuretvVideo = await LuxureTVService.fetchVideoInfo(url);
        if (luxuretvVideo != null) {
          _updateVideo(id, (v) {
            v.tweetText = luxuretvVideo.tweetText;
            v.authorName = luxuretvVideo.authorName;
            v.thumbnailUrl = luxuretvVideo.thumbnailUrl;
            v.variants = luxuretvVideo.variants;
            v.selectedVariant = luxuretvVideo.selectedVariant;
            v.status = DownloadStatus.idle;
          });
          return;
        }
      }

      // Everything else: generic HTML scraper
      final generic = await _genericVideoService.fetchGenericInfo(url);
      if (generic != null && generic.variants.isNotEmpty) {
        _updateVideo(id, (v) {
          v.tweetText = generic.title;
          v.authorName = 'Generic Source';
          v.thumbnailUrl = generic.thumbnailUrl;
          v.variants = generic.variants;
          v.selectedVariant = generic.variants.first;
          v.status = DownloadStatus.idle;
        });
        return;
      }

      throw Exception('Source not supported or video not found on page');
    } catch (e) {
      // Final attempt for X if something went wrong above
      if (source == VideoSource.twitter) {
        try {
          final info = await _twitterService.fetchTweetInfo(url);
          final preferred = _selectPreferredVariant(info.variants);
          _updateVideo(id, (v) {
            v.tweetText = info.tweetText;
            v.authorName = info.authorName;
            v.thumbnailUrl = info.thumbnailUrl;
            v.variants = info.variants;
            v.selectedVariant = preferred ?? info.selectedVariant;
            v.status = DownloadStatus.idle;
          });
          return;
        } catch (_) {}
      }

      _updateVideo(id, (v) {
        v.status = DownloadStatus.error;
        v.errorMessage = e.toString().replaceFirst('Exception: ', '');
      });

      unawaited(_failureLoggingService.logFailure(
        url: url,
        source: source.name,
        error: e.toString(),
      ));
    }
  }

  VideoVariant? _selectPreferredVariant(List<VideoVariant> variants) {
    if (variants.isEmpty) return null;
    return variants.first;
  }


  Future<bool> _requestAndroidStorage() async {
    if (!Platform.isAndroid) return true;
    
    // First check standard storage
    final status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return true;

    // For SD Card / Custom folder support, we need "All Files Access"
    final manageStatus = await Permission.manageExternalStorage.status;
    if (!manageStatus.isGranted) {
      final result = await Permission.manageExternalStorage.request();
      if (result.isGranted) return true;
    } else {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    
    _showSnack('Storage permission required for SD cards — please allow in system settings');
    return false;
  }

  Future<void> _downloadVideo(TweetVideo video) async {
    // Guard against stale calls — if the video is already downloading or done, skip
    if (video.status == DownloadStatus.downloading || video.status == DownloadStatus.done) {
      debugPrint('[DEBUG] Skipping _downloadVideo for ${video.id} — status is ${video.status}');
      return;
    }
    if (!Platform.isMacOS) {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          _showSnack('Photo library access is required to save videos');
          return;
        }
      }
      if (!await _requestAndroidStorage()) return;
    }

    final variant = video.selectedVariant;
    if (variant == null) return;
    final cancelToken = CancelToken();
    _cancelTokens[video.id] = cancelToken;
    final notificationId = video.id.hashCode.abs();

    _updateVideo(video.id, (v) {
      v.status = DownloadStatus.downloading;
      v.downloadProgress = 0;
      v.errorMessage = null;
      v.savedPath = null;
    });

    try {
      String savedPath;
      void onProgress(double p) {
        if (!mounted) return;
        _updateVideo(video.id, (v) => v.downloadProgress = p);
        if (_settings.desktopNotifications || !Platform.isMacOS) {
          _notificationService.showProgress(
            notificationId,
            video.tweetText ?? video.id,
            (p * 100).toInt(),
            'Downloading...',
          );
        }
      }

      if (variant.url.isNotEmpty && (variant.url.startsWith('http') || variant.url.startsWith('https'))) {
        // Direct download for universal alternative or direct links
        final filename = DownloadService.buildFilename(video.id, variant.resolution);
        final dir = await _resolveOutputDirectory(video, variant);
        savedPath = await _downloadService.downloadVideo(
          url: variant.url,
          filename: filename,
          saveDirectory: dir,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      } else if (Platform.isMacOS && (video.source == VideoSource.youtube || video.source == VideoSource.xvideos)) {
        // macOS: yt-dlp for YouTube and XVideos
        final dir = await _resolveOutputDirectory(video, variant) ?? await DownloadService.getEffectiveDirectory();
        savedPath = await _youtubeService.download(
          pageUrl: video.inputUrl,
          variant: variant,
          outputDirectory: dir,
          onProgress: onProgress,
        );
      } else if (Platform.isAndroid && video.source == VideoSource.youtube) {
        // Android: use InnerTube API instead of yt-dlp
        final dir = await _resolveOutputDirectory(video, variant) ?? await DownloadService.getEffectiveDirectory();
        savedPath = await _youtubeAndroidService.download(
          pageUrl: video.inputUrl,
          variant: variant,
          outputDirectory: dir,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else if (video.source == VideoSource.twitter || !Platform.isMacOS) {
        final filename = DownloadService.buildFilename(video.id, variant.resolution);
        final dir = await _resolveOutputDirectory(video, variant);
        savedPath = await _downloadService.downloadVideo(
          url: variant.url,
          filename: filename,
          saveDirectory: dir,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
      } else {
        throw Exception('Downloads from this source are currently supported on macOS desktop');
      }

      _updateVideo(video.id, (v) {
        v.status = DownloadStatus.done;
        v.downloadProgress = 1.0;
        v.savedPath = savedPath;
      });
      _persistLibraryMetadata(video, savedPath);
      
      if (_settings.desktopNotifications || !Platform.isMacOS) {
        _notificationService.showCompleted(
          notificationId,
          'Chronos: Download Complete',
          video.tweetText ?? video.id,
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _notificationService.cancel(notificationId);
        return;
      }
      _notificationService.cancel(notificationId);
      _handleDownloadError(video, 'Download failed: ${e.message}');
    } catch (e) {
      _notificationService.cancel(notificationId);
      _handleDownloadError(video, e.toString().replaceFirst('Exception: ',''));

      unawaited(_failureLoggingService.logFailure(
        url: video.inputUrl,
        source: video.source.name,
        error: e.toString(),
      ));
    } finally {
      _cancelTokens.remove(video.id);
    }
  }

  /// Maximum number of automatic retries for a failed download.
  static const int _maxRetries = 3;

  /// Handle a download error with automatic retry logic.
  ///
  /// If the video has been retried fewer than [_maxRetries] times,
  /// it resets the status to [DownloadStatus.idle] so the queue
  /// processor picks it up again. Otherwise, it stays as error.
  void _handleDownloadError(TweetVideo video, String errorMessage) {
    _updateVideo(video.id, (v) {
      v.retryCount += 1;
      if (v.retryCount < _maxRetries) {
        // Reset to idle so the queue processor retries it
        v.status = DownloadStatus.idle;
        v.downloadProgress = 0.0;
        v.errorMessage = 'Retry ${v.retryCount}/$_maxRetries: $errorMessage';
        debugPrint('[DEBUG] Will retry ${video.id} (attempt ${v.retryCount}/$_maxRetries)');
      } else {
        // Give up after max retries
        v.status = DownloadStatus.error;
        v.errorMessage = 'Failed after $_maxRetries attempts: $errorMessage';
        debugPrint('[DEBUG] Giving up on ${video.id} after $_maxRetries retries');
      }
    });
  }

  Future<String?> _resolveOutputDirectory(TweetVideo video, VideoVariant variant) async {
    final base = _downloadDirectory ?? await DownloadService.getEffectiveDirectory();

    if (_settings.useUnifiedFolder && _settings.unifiedDownloadDirectory != null) {
      final root = _settings.unifiedDownloadDirectory!;
      final sub = switch (video.source) {
        VideoSource.twitter => 'X',
        VideoSource.youtube => 'YouTube',
        VideoSource.xvideos => 'XVideos',
        VideoSource.xhamster => 'XHamster',
        VideoSource.hentaihaven => 'HentaiHaven',
        VideoSource.hanime => 'Hanime',
        VideoSource.rule34video => 'Rule34Video',
        _ => 'Other',
      };
      return p.join(root, sub);
    }

    return switch (video.source) {
      VideoSource.twitter => _settings.xVideoDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'x'),
      VideoSource.youtube when variant.audioOnly =>
        _settings.youtubeMp3DownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'youtube', 'mp3'),
      VideoSource.youtube => _settings.youtubeVideoDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'youtube'),
      VideoSource.xvideos => _settings.xvideosDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'xvideos'),
      VideoSource.xhamster => _settings.xhamsterDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'xhamster'),
      VideoSource.hentaihaven => _settings.hentaihavenDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'hentaihaven'),
      VideoSource.hanime => _settings.hanimeDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'hanime'),
      VideoSource.rule34video => _settings.rule34videoDownloadDirectory ?? _settings.downloadDirectory ?? p.join(base, 'rule34video'),
      VideoSource.other => _settings.downloadDirectory ?? p.join(base, 'other'),
    };
  }

  Future<String> _resolvePhotoDirectory() async {
    final base = _downloadDirectory ?? await DownloadService.getEffectiveDirectory();
    if (_settings.photoDownloadDirectory?.trim().isNotEmpty == true) {
      return _settings.photoDownloadDirectory!;
    }
    if (_settings.useUnifiedFolder && _settings.unifiedDownloadDirectory != null) {
      return p.join(_settings.unifiedDownloadDirectory!, 'photos');
    }
    final root = _settings.downloadDirectory ?? base;
    return p.join(root, 'photos');
  }

  String get _photoDirectoryLabel {
    if (_settings.photoDownloadDirectory?.trim().isNotEmpty == true) {
      return _settings.photoDownloadDirectory!;
    }
    final root = _settings.downloadDirectory ?? _downloadDirectory;
    if (root?.trim().isNotEmpty == true) {
      return p.join(root!, 'photos');
    }
    return 'Uses Library Folder/photos';
  }

  String _buildPhotoId(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    final normalized = uri == null
        ? imageUrl
        : uri.replace(
            queryParameters: Map.of(uri.queryParameters)..remove('name'),
          ).toString();
    return 'photo_${normalized.hashCode.abs()}';
  }

  String _buildPhotoFilename(BrowserPhoto photo) {
    final uri = Uri.tryParse(photo.imageUrl);
    final format = uri?.queryParameters['format'];
    final inferredExt = p.extension(uri?.path ?? '');
    final ext = format != null && format.isNotEmpty
        ? '.$format'
        : (inferredExt.isNotEmpty ? inferredExt : '.jpg');
    return 'x_photo_${photo.id.replaceFirst('photo_', '')}$ext';
  }

  Future<void> _downloadPhoto(BrowserPhoto photo) async {
    final notificationId = photo.id.hashCode.abs();
    setState(() {
      photo.status = DownloadStatus.downloading;
      photo.downloadProgress = 0;
      photo.errorMessage = null;
    });

    try {
      final dir = await _resolvePhotoDirectory();
      final savedPath = await _downloadService.downloadFile(
        url: photo.imageUrl,
        filename: _buildPhotoFilename(photo),
        saveDirectory: dir,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => photo.downloadProgress = progress);
        },
      );

      if (!mounted) return;
      setState(() {
        photo.status = DownloadStatus.done;
        photo.downloadProgress = 1;
        photo.savedPath = savedPath;
      });

      if (_settings.desktopNotifications || !Platform.isMacOS) {
        _notificationService.showCompleted(
          notificationId,
          'Chronos: Photo Saved',
          p.basename(savedPath),
        );
      }
    } catch (e) {
      _notificationService.cancel(notificationId);
      if (!mounted) return;
      setState(() {
        photo.status = DownloadStatus.error;
        photo.errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _downloadAllPhotos() async {
    final pending = _photos
        .where((photo) =>
            photo.status == DownloadStatus.idle ||
            photo.status == DownloadStatus.error)
        .toList();
    if (pending.isEmpty) {
      _showSnack('No photos ready to save');
      return;
    }
    for (final photo in pending) {
      await _downloadPhoto(photo);
    }
  }

  Future<void> _persistLibraryMetadata(TweetVideo video, String savedPath) async {
    _libraryMetadataByPath[savedPath] = LibraryMetadata(
      path: savedPath,
      title: video.tweetText,
      author: video.authorName,
      thumbnailUrl: video.thumbnailUrl,
      source: video.source.name,
    );
    await _libraryMetadataService.saveAll(_libraryMetadataByPath);
  }

  Future<void> _downloadAll() async {
    final pending = _videos
        .where((v) => v.status == DownloadStatus.idle || v.status == DownloadStatus.error)
        .toList();
    if (pending.isEmpty) {
      _showSnack('Nothing to download');
      return;
    }
    
    // Download in batches with a concurrency limit
    const maxConcurrent = 2;
    var completed = 0;
    
    for (var i = 0; i < pending.length; i += maxConcurrent) {
      final batch = pending.skip(i).take(maxConcurrent).toList();
      await Future.wait(batch.map((video) => _downloadVideo(video)));
      completed += batch.length;
    }
    
    if (completed > 0) {
      _showSnack('Completed $completed download(s)');
    }
  }

  void _removeVideo(String id) {
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
    setState(() => _videos.removeWhere((v) => v.id == id));
  }

  Future<void> _openSavedFilePath(String path) async {
    if (path.isEmpty) return;
    if (!File(path).existsSync()) {
      _showSnack('Saved file no longer exists');
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }
    _showSnack('Open is supported on macOS desktop');
  }

  Future<void> _showFileInFolderPath(String path) async {
    if (path.isEmpty) return;
    if (!File(path).existsSync()) {
      _showSnack('Saved file no longer exists');
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
      return;
    }
    _showSnack('Show in folder is supported on macOS desktop');
  }

  Future<void> _deleteLibraryFilePath(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {
        _showSnack('Unable to delete file');
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _videos.removeWhere((v) => v.savedPath == path);
      _libraryMetadataByPath.remove(path);
    });
    await _libraryMetadataService.saveAll(_libraryMetadataByPath);
    _showSnack('Removed from library');
  }

  void _updateVideo(String id, void Function(TweetVideo v) update) {
    if (!mounted) return;
    setState(() {
      final idx = _videos.indexWhere((v) => v.id == id);
      if (idx != -1) update(_videos[idx]);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    if (Platform.isAndroid) {
      // On Android, use system notification instead of in-app bubble
      _notificationService.showInfo('Chronos', msg);
    } else {
      NotificationBubble.show(context, msg);
    }
  }

  Future<void> _onSectionSelect(AppSection section) async {
    if (section == AppSection.library ||
        section == AppSection.player ||
        section == AppSection.photos) {
      if (Platform.isAndroid) {
        await _requestAndroidStorage();
      }
    }
    setState(() => _selected = section);
  }

  String get _searchHint {
    switch (_selected) {
      case AppSection.dashboard:
        return 'Search your library...';
      case AppSection.library:
        return 'Global search...';
      case AppSection.photos:
        return 'Search photos...';
      case AppSection.downloads:
        return 'Search downloads...';
      case AppSection.player:
        return 'Search player playlist...';
      case AppSection.music:
        return 'Search music...';
      case AppSection.settings:
        return 'Search preferences...';
    }
  }

  Widget get _content {
    // Performance: Use RepaintBoundary to isolate each screen's repaint area
    // This prevents the entire widget tree from repainting when one section changes
    switch (_selected) {
      case AppSection.dashboard:
        return RepaintBoundary(
          child: DashboardScreen(
            urlController: _urlController,
            onAddUrls: _addUrls,
            onPaste: _pasteFromClipboard,
            addingUrls: _addingUrls,
            videos: _videos,
            onDownloadAll: _downloadAll,
            onOpenDownloads: () => setState(() => _selected = AppSection.downloads),
            onSourceTap: _handleSourceTap,
          ),
        );
      case AppSection.library:
        final activeDir = _settings.useUnifiedFolder && _settings.unifiedDownloadDirectory != null
            ? _settings.unifiedDownloadDirectory
            : _downloadDirectory;
        return RepaintBoundary(
          child: LibraryScreen(
            videos: _videos,
            downloadDirectory: activeDir,
            metadataByPath: _libraryMetadataByPath,
            onOpenFile: _openSavedFilePath,
            onShowInFolder: _showFileInFolderPath,
            onDeleteFile: _deleteLibraryFilePath,
          ),
        );
      case AppSection.photos:
        return RepaintBoundary(
          child: PhotosScreen(
            photos: _photos,
            photoDirectory: _photoDirectoryLabel,
            onDownloadAll: _downloadAllPhotos,
            onDownloadOne: _downloadPhoto,
            onOpenFile: _openSavedFilePath,
            onShowInFolder: _showFileInFolderPath,
          ),
        );
      case AppSection.downloads:
        return RepaintBoundary(
          child: DownloadsScreen(
            videos: _videos,
            onDownloadAll: _downloadAll,
            onDownloadOne: _downloadVideo,
            onRemoveVideo: _removeVideo,
            onVariantChanged: (video, variant) {
              _updateVideo(video.id, (v) => v.selectedVariant = variant);
            },
            onClearCompleted: () {
              setState(() {
                _videos.removeWhere((v) => v.status == DownloadStatus.done);
              });
            },
          ),
        );
      case AppSection.player:
        final allDirs = <String>{
          if (_downloadDirectory != null && _downloadDirectory!.isNotEmpty) _downloadDirectory!,
          if (_settings.xVideoDownloadDirectory?.isNotEmpty == true) _settings.xVideoDownloadDirectory!,
          if (_settings.youtubeVideoDownloadDirectory?.isNotEmpty == true)
            _settings.youtubeVideoDownloadDirectory!,
          if (_settings.youtubeMp3DownloadDirectory?.isNotEmpty == true)
            _settings.youtubeMp3DownloadDirectory!,
          if (_settings.xvideosDownloadDirectory?.isNotEmpty == true) _settings.xvideosDownloadDirectory!,
          if (_settings.xhamsterDownloadDirectory?.isNotEmpty == true)
            _settings.xhamsterDownloadDirectory!,
          if (_settings.hentaihavenDownloadDirectory?.isNotEmpty == true)
            _settings.hentaihavenDownloadDirectory!,
          if (_settings.hanimeDownloadDirectory?.isNotEmpty == true) _settings.hanimeDownloadDirectory!,
          if (_settings.rule34videoDownloadDirectory?.isNotEmpty == true)
            _settings.rule34videoDownloadDirectory!,
        }.toList();
        return RepaintBoundary(
          child: PlayerScreen(
            libraryDirectories: allDirs,
            metadataByPath: _libraryMetadataByPath,
          ),
        );
      case AppSection.music:
        return RepaintBoundary(
          child: MusicScreen(
            urlController: _urlController,
            onAddUrls: _addUrls,
            onPaste: _pasteFromClipboard,
            addingUrls: _addingUrls,
            videos: _videos,
            onDownloadAll: _downloadAll,
            onOpenDownloads: () => setState(() => _selected = AppSection.downloads),
            onSourceTap: _handleSourceTap,
          ),
        );
      case AppSection.settings:
        return RepaintBoundary(
          child: SettingsScreen(
            settings: _settings.copyWith(downloadDirectory: _downloadDirectory),
            onBrowserIntegrationChanged: (value) async {
              setState(() => _settings = _settings.copyWith(browserIntegration: value));
              await _saveSettings();
            },
            onDesktopNotificationsChanged: (value) async {
              setState(() => _settings = _settings.copyWith(desktopNotifications: value));
              await _saveSettings();
            },
            onPickDownloadDirectory: _pickDownloadDirectory,
            onPickPhotoDirectory: _pickPhotoDirectory,
            onPickXVideoDirectory: _pickXVideoDirectory,
            onPickYoutubeVideoDirectory: _pickYoutubeVideoDirectory,
            onPickYoutubeMp3Directory: _pickYoutubeMp3Directory,
            onPickXvideosDirectory: _pickXvideosDirectory,
            onPickXhamsterDirectory: _pickXhamsterDirectory,
            onPickHentaihavenDirectory: _pickHentaihavenDirectory,
            onPickHanimeDirectory: _pickHanimeDirectory,
            onPickRule34videoDirectory: _pickRule34videoDirectory,
            onUnifiedFolderToggle: (value) async {
              setState(() => _settings = _settings.copyWith(useUnifiedFolder: value));
              await _saveSettings();
            },
            onPickUnifiedDirectory: _pickUnifiedDirectory,
            onMigrateInternalDownloads: _migrateInternalDownloads,
            onEnableVpnChanged: (value) async {
              setState(() => _settings = _settings.copyWith(enableVpn: value));
              await _saveSettings();
            },
            onAutoVpnForAdultSitesChanged: (value) async {
              setState(() => _settings = _settings.copyWith(autoVpnForAdultSites: value));
              await _saveSettings();
            },
            onVpnLocationChanged: (value) async {
              setState(() => _settings = _settings.copyWith(vpnLocation: value));
              await _saveSettings();
            },
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = Platform.isAndroid || constraints.maxWidth < 900;

        if (isMobile) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            drawer: Drawer(
              child: SideNavBar(
                selected: _selected,
                onSelect: _onSectionSelect,
              ),
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      Builder(
                        builder: (context) => TopNavBar(
                          searchHint: _searchHint,
                          showBrowserPanel: _showBrowserPanel,
                          onToggleBrowserPanel: () {
                            setState(() {
                              _showBrowserPanel = !_showBrowserPanel;
                              if (_showBrowserPanel) _isBrowserMinimized = false;
                            });
                          },
                          onMenuPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      ),
                      Expanded(
                        child: _content,
                      ),
                    ],
                  ),
                  if (_showBrowserPanel)
                    Positioned.fill(
                      child: Offstage(
                        offstage: _isBrowserMinimized,
                        child: XBrowserPanel(
                          width: constraints.maxWidth,
                          request: _browserRequest,
                          autoDetect: _settings.browserIntegration,
                          settings: _settings,
                          onClose: () => setState(() => _isBrowserMinimized = true),
                          onVideoDetected: (url) {
                            if (!_settings.browserIntegration) return;
                            if (_urlController.text != url) {
                              _urlController.text = url;
                            }
                            _queueUrls([url], source: 'Browser', showFeedback: true);
                          },
                          onPhotoDetected: (photo) {
                            if (!_settings.browserIntegration) return;
                            _handlePhotoDetected(photo);
                          },
                        ),
                      ),
                    ),
                  if (_showBrowserPanel && _isBrowserMinimized)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _isBrowserMinimized = false),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            border: const Border(top: BorderSide(color: AppColors.primary, width: 2)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1) cached
                                blurRadius: 10,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Restore Browser',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        const sidebarWidth = 256.0;
        const minMainContentWidth = 700.0;
        const minBrowserWidth = 320.0;
        const maxBrowserWidth = 860.0;
        const browserDividerWidth = 12.0;

        final availableAfterSidebar = (constraints.maxWidth - sidebarWidth).clamp(0.0, double.infinity);
        final desiredBrowserWidth = (availableAfterSidebar - minMainContentWidth - browserDividerWidth)
            .clamp(minBrowserWidth, maxBrowserWidth)
            .toDouble();
        final canShowBrowser =
            _showBrowserPanel &&
            availableAfterSidebar >=
                (minMainContentWidth + minBrowserWidth + browserDividerWidth);
        final effectiveBrowserWidth = canShowBrowser
            ? (_desktopBrowserWidth ?? desiredBrowserWidth)
                .clamp(minBrowserWidth, desiredBrowserWidth)
                .toDouble()
            : desiredBrowserWidth;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: SideNavBar(
                      selected: _selected,
                      onSelect: _onSectionSelect,
                    ),
                  ),
                  if (!_isDashboardHidden)
                    Expanded(
                      child: Column(
                        children: [
                          TopNavBar(
                            searchHint: _searchHint,
                            showBrowserPanel: _showBrowserPanel,
                            onToggleBrowserPanel: () {
                              setState(() {
                                _showBrowserPanel = !_showBrowserPanel;
                                if (_showBrowserPanel) _isBrowserMinimized = false;
                              });
                            },
                          ),
                          Expanded(
                            child: _content,
                          ),
                        ],
                      ),
                    ),
                  if (canShowBrowser && !_isBrowserMinimized)
                    MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            final nextWidth =
                                effectiveBrowserWidth - details.delta.dx;
                            _desktopBrowserWidth = nextWidth
                                .clamp(minBrowserWidth, desiredBrowserWidth)
                                .toDouble();
                          });
                        },
                        onDoubleTap: () {
                          setState(() {
                            _desktopBrowserWidth = desiredBrowserWidth;
                          });
                        },
                        child: SizedBox(
                          width: browserDividerWidth,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 1,
                                height: 24,
                                color: AppColors.surfaceContainerHigh,
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isDashboardHidden = !_isDashboardHidden;
                                  });
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _isDashboardHidden ? Icons.chevron_right : Icons.chevron_left,
                                    size: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 1,
                                height: 24,
                                color: AppColors.surfaceContainerHigh,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (canShowBrowser)
                    Offstage(
                      offstage: _isBrowserMinimized,
                      child: XBrowserPanel(
                        key: ValueKey('browser_${_isDashboardHidden}'),
                        width: _isDashboardHidden ? constraints.maxWidth - sidebarWidth : effectiveBrowserWidth,
                        request: _browserRequest,
                        autoDetect: _settings.browserIntegration,
                        settings: _settings,
                        onClose: () => setState(() => _isBrowserMinimized = true),
                        onVideoDetected: (url) {
                          if (!_settings.browserIntegration) return;
                          if (_urlController.text != url) {
                            _urlController.text = url;
                          }
                          _queueUrls([url], source: 'Browser', showFeedback: true);
                        },
                        onPhotoDetected: (photo) {
                          if (!_settings.browserIntegration) return;
                          _handlePhotoDetected(photo);
                        },
                      ),
                    ),
                ],
              ),
              if (canShowBrowser && _isBrowserMinimized)
                Positioned(
                  bottom: 0,
                  left: sidebarWidth,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _isBrowserMinimized = false),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        border: const Border(top: BorderSide(color: AppColors.primary, width: 2)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000), // Colors.black.withValues(alpha: 0.1) cached
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Restore Browser',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
