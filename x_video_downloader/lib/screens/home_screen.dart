import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/tweet_video.dart';
import '../services/download_service.dart';
import '../services/twitter_service.dart';
import '../widgets/video_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final List<TweetVideo> _videos = [];
  final TwitterService _twitterService = TwitterService();
  final DownloadService _downloadService = DownloadService();
  final Map<String, CancelToken> _cancelTokens = {};
  bool _addingUrls = false;
  String? _downloadDirectory;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS) {
      DownloadService.getEffectiveDirectory().then((dir) {
        if (mounted) setState(() => _downloadDirectory = dir);
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
    }
  }

  Future<void> _pickDownloadDirectory() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Select Download Folder',
    );
    if (path != null) {
      await DownloadService.saveDirectory(path);
      setState(() => _downloadDirectory = path);
      _showSnack('Download folder set: $path');
    }
  }

  Future<void> _addUrls() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;

    final urls = TwitterService.parseUrls(raw);
    if (urls.isEmpty) {
      _showSnack('No valid X/Twitter URLs found');
      return;
    }

    final existingIds = _videos.map((v) => v.id).toSet();
    final newUrls = urls.where((url) {
      final id = TwitterService.extractTweetId(url);
      return id != null && !existingIds.contains(id);
    }).toList();

    if (newUrls.isEmpty) {
      _showSnack('All URLs already added');
      return;
    }

    setState(() {
      _addingUrls = true;
      for (final url in newUrls) {
        final id = TwitterService.extractTweetId(url)!;
        _videos.add(TweetVideo(
          id: id,
          inputUrl: url,
          status: DownloadStatus.fetching,
        ));
      }
    });

    _urlController.clear();

    await Future.wait(newUrls.map(_fetchMetadata));
    setState(() => _addingUrls = false);
  }

  Future<void> _fetchMetadata(String url) async {
    final id = TwitterService.extractTweetId(url)!;
    try {
      final info = await _twitterService.fetchTweetInfo(url);
      _updateVideo(id, (v) {
        v.tweetText = info.tweetText;
        v.authorName = info.authorName;
        v.thumbnailUrl = info.thumbnailUrl;
        v.variants = info.variants;
        v.selectedVariant = info.selectedVariant;
        v.status = DownloadStatus.idle;
      });
    } catch (e) {
      _updateVideo(id, (v) {
        v.status = DownloadStatus.error;
        v.errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _downloadVideo(TweetVideo video) async {
    if (!Platform.isMacOS) {
      // Mobile: need Photos permission
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

    _updateVideo(video.id, (v) {
      v.status = DownloadStatus.downloading;
      v.downloadProgress = 0;
      v.errorMessage = null;
      v.savedPath = null;
    });

    try {
      final filename = DownloadService.buildFilename(
          video.id, variant.resolution);
      final savedPath = await _downloadService.downloadVideo(
        url: variant.url,
        filename: filename,
        saveDirectory: _downloadDirectory,
        cancelToken: cancelToken,
        onProgress: (p) {
          _updateVideo(video.id, (v) => v.downloadProgress = p);
        },
      );

      _updateVideo(video.id, (v) {
        v.status = DownloadStatus.done;
        v.downloadProgress = 1.0;
        v.savedPath = savedPath;
      });

      if (Platform.isMacOS) {
        _showSnack('Saved to: $savedPath');
      } else {
        _showSnack('Video saved to Photos!');
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _updateVideo(video.id, (v) {
        v.status = DownloadStatus.error;
        v.errorMessage = 'Download failed: ${e.message}';
      });
    } catch (e) {
      _updateVideo(video.id, (v) {
        v.status = DownloadStatus.error;
        v.errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _cancelTokens.remove(video.id);
    }
  }

  Future<bool> _requestAndroidStorage() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isDenied) {
      final result = await Permission.storage.request();
      return result.isGranted;
    }
    _showSnack('Storage permission denied — enable it in Settings');
    return false;
  }

  Future<void> _downloadAll() async {
    final pending = _videos
        .where((v) =>
            v.status == DownloadStatus.idle ||
            v.status == DownloadStatus.error)
        .toList();

    if (pending.isEmpty) {
      _showSnack('Nothing to download');
      return;
    }

    const concurrency = 3;
    for (var i = 0; i < pending.length; i += concurrency) {
      final batch = pending.skip(i).take(concurrency).toList();
      await Future.wait(batch.map(_downloadVideo));
    }
  }

  void _removeVideo(String id) {
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
    setState(() => _videos.removeWhere((v) => v.id == id));
  }

  void _clearAll() {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    _cancelTokens.clear();
    setState(() => _videos.clear());
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  int get _pendingCount => _videos
      .where((v) =>
          v.status == DownloadStatus.idle || v.status == DownloadStatus.error)
      .length;

  int get _doneCount =>
      _videos.where((v) => v.status == DownloadStatus.done).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Text('𝕏',
                style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Text('Video Downloader'),
          ],
        ),
        actions: [
          if (Platform.isMacOS)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Set download folder',
              onPressed: _pickDownloadDirectory,
            ),
          if (_videos.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear all',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildInputArea(),
          if (Platform.isMacOS && _downloadDirectory != null)
            _buildDirectoryBar(),
          if (_videos.isNotEmpty) _buildSummaryBar(),
          Expanded(
            child: _videos.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _videos.length,
                    itemBuilder: (context, i) {
                      final v = _videos[i];
                      return VideoCard(
                        key: ValueKey(v.id),
                        video: v,
                        onDownload: (v.status == DownloadStatus.idle ||
                                v.status == DownloadStatus.error)
                            ? () => _downloadVideo(v)
                            : null,
                        onRemove: () => _removeVideo(v.id),
                        onVariantChanged: (variant) {
                          _updateVideo(
                              v.id, (vid) => vid.selectedVariant = variant);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _pendingCount > 0
          ? FloatingActionButton.extended(
              onPressed: _downloadAll,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.download_for_offline),
              label: Text('Download all ($_pendingCount)'),
            )
          : null,
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              hintText:
                  'Paste one or more X/Twitter links\n(separate with spaces, commas, or newlines)',
              hintStyle:
                  TextStyle(fontSize: 13, color: Colors.grey.shade500),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.grey.shade50,
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: 'Paste from clipboard',
                onPressed: _pasteFromClipboard,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _addingUrls ? null : _addUrls,
            icon: _addingUrls
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add),
            label: Text(_addingUrls ? 'Adding…' : 'Add URLs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryBar() {
    return InkWell(
      onTap: _pickDownloadDirectory,
      child: Container(
        color: Colors.grey.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.folder, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _downloadDirectory!,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.edit, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('${_videos.length} video${_videos.length == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_doneCount > 0)
            Text('$_doneCount saved',
                style:
                    const TextStyle(color: Colors.green, fontSize: 13)),
          if (_pendingCount > 0 && _doneCount > 0)
            const Text('  ·  ',
                style: TextStyle(color: Colors.grey)),
          if (_pendingCount > 0)
            Text('$_pendingCount pending',
                style:
                    const TextStyle(color: Colors.orange, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('𝕏', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Paste X.com video links above',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Supports batch downloads — add as many links as you want',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          if (Platform.isMacOS) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickDownloadDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('Set download folder'),
            ),
          ],
        ],
      ),
    );
  }
}
