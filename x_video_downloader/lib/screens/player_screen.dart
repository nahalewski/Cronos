import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:x_video_downloader/services/library_metadata_service.dart';
import 'package:x_video_downloader/theme.dart';
import 'package:video_player/video_player.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.libraryDirectories,
    required this.metadataByPath,
  });

  final List<String> libraryDirectories;
  final Map<String, LibraryMetadata> metadataByPath;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final Set<String> _videoExtensions = const {
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.mkv',
  };
  List<_PlayerItem> _items = const [];
  VideoPlayerController? _controller;
  int _selectedIndex = -1;
  String? _error;
  bool _loading = false;
  int _openToken = 0;
  double _volume = 1.0;
  
  // Performance: Throttle controller tick updates to ~10fps instead of 60fps
  DateTime _lastTickUpdate = DateTime(2000);
  static const Duration _tickThrottle = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid blocking initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshItems();
    });
  }

  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDirs = oldWidget.libraryDirectories.toSet();
    final newDirs = widget.libraryDirectories.toSet();
    if (oldDirs.length != newDirs.length || !oldDirs.containsAll(newDirs)) {
      _refreshItems();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _refreshItems() async {
    final dirs = widget.libraryDirectories
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    final loaded = <_PlayerItem>[];
    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      // Performance: Use listSync on main thread is bad, but for now
      // we limit the scope. In production, this should use Isolate.
      final files = dir.listSync(recursive: true).whereType<File>().where((file) {
        final ext = p.extension(file.path).toLowerCase();
        return _videoExtensions.contains(ext);
      });
      for (final file in files) {
        final stat = file.statSync();
        final metadata = widget.metadataByPath[file.path];
        loaded.add(
          _PlayerItem(
            path: file.path,
            title: metadata?.title?.trim().isNotEmpty == true
                ? metadata!.title!.trim()
                : p.basenameWithoutExtension(file.path),
            subtitle: metadata?.author?.trim().isNotEmpty == true
                ? '@${metadata!.author!.trim()}'
                : p.basename(file.path),
            modified: stat.modified,
          ),
        );
      }
    }
    loaded.sort((a, b) => b.modified.compareTo(a.modified));
    if (!mounted) return;
    setState(() {
      _items = loaded;
      _error = null;
    });
    if (loaded.isEmpty) {
      await _disposeController();
      if (mounted) {
        setState(() => _selectedIndex = -1);
      }
      return;
    }
    if (_selectedIndex < 0 || _selectedIndex >= loaded.length) {
      await _openAt(0, autoPlay: false);
    }
  }

  Future<void> _disposeController() async {
    final old = _controller;
    if (old == null) return;
    old.removeListener(_onControllerTick);
    _controller = null;
    await old.dispose();
  }

  Future<void> _openAt(int index, {bool autoPlay = true}) async {
    if (index < 0 || index >= _items.length) return;
    final token = ++_openToken;
    setState(() {
      _loading = true;
      _error = null;
      _selectedIndex = index;
    });

    final controller = VideoPlayerController.file(File(_items[index].path));
    try {
      await controller.initialize();
      if (!mounted || token != _openToken) {
        await controller.dispose();
        return;
      }
      await _disposeController();
      controller.addListener(_onControllerTick);
      _controller = controller;
      await controller.setVolume(_volume);
      if (autoPlay) {
        await controller.play();
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      await controller.dispose();
      if (!mounted || token != _openToken) return;
      setState(() {
        _loading = false;
        _error = 'Unable to play this file';
      });
    }
  }

  void _onControllerTick() {
    if (!mounted) return;
    // Performance: Throttle to ~10fps instead of 60fps
    // This prevents 60 rebuilds per second for the slider position
    final now = DateTime.now();
    if (now.difference(_lastTickUpdate) < _tickThrottle) return;
    _lastTickUpdate = now;
    setState(() {});
  }

  Future<void> _playPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _stop() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.pause();
    await controller.seekTo(Duration.zero);
  }

  Future<void> _next() async {
    if (_items.isEmpty) return;
    final current = _selectedIndex < 0 ? 0 : _selectedIndex;
    final next = (current + 1) % _items.length;
    await _openAt(next);
  }

  Future<void> _previous() async {
    if (_items.isEmpty) return;
    final current = _selectedIndex < 0 ? 0 : _selectedIndex;
    final previous = (current - 1 + _items.length) % _items.length;
    await _openAt(previous);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final controller = _controller;
    final duration = controller?.value.duration ?? Duration.zero;
    final position = controller?.value.position ?? Duration.zero;
    final clampedPosition = position > duration ? duration : position;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        final playerPadding = isMobile ? const EdgeInsets.all(16) : const EdgeInsets.fromLTRB(32, 24, 32, 24);

        final playerWidget = Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Player', style: textTheme.headlineSmall),
              if (widget.libraryDirectories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_shared, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.libraryDirectories.length == 1
                              ? 'Folder: ${p.basename(widget.libraryDirectories.first)}'
                              : 'Scanning ${widget.libraryDirectories.length} folders',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              if (_loading)
                const LinearProgressIndicator(minHeight: 3)
              else
                const SizedBox(height: 3),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: controller != null && controller.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: controller.value.size.width,
                              height: controller.value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Select a video from the playlist',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 10),
              Slider(
                min: 0,
                max: duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                value: clampedPosition.inMilliseconds.toDouble().clamp(
                      0,
                      duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1,
                    ),
                onChanged: controller == null || !controller.value.isInitialized
                    ? null
                    : (value) => controller.seekTo(
                          Duration(milliseconds: value.round()),
                        ),
              ),
              Row(
                children: [
                  Text(
                    _formatDuration(clampedPosition),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(duration),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: isMobile ? MainAxisAlignment.spaceAround : MainAxisAlignment.start,
                children: [
                  IconButton(
                    iconSize: isMobile ? 32 : 24,
                    tooltip: 'Previous',
                    onPressed: _items.isEmpty ? null : _previous,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    iconSize: isMobile ? 48 : 24,
                    tooltip: (controller?.value.isPlaying ?? false) ? 'Pause' : 'Play',
                    onPressed: controller == null ? null : _playPause,
                    icon: Icon((controller?.value.isPlaying ?? false) ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    iconSize: isMobile ? 32 : 24,
                    tooltip: 'Stop',
                    onPressed: controller == null ? null : _stop,
                    icon: const Icon(Icons.stop),
                  ),
                  IconButton(
                    iconSize: isMobile ? 32 : 24,
                    tooltip: 'Next',
                    onPressed: _items.isEmpty ? null : _next,
                    icon: const Icon(Icons.skip_next),
                  ),
                  IconButton(
                    iconSize: isMobile ? 32 : 24,
                    tooltip: 'Fullscreen',
                    onPressed: controller == null || !controller.value.isInitialized
                        ? null
                        : () => _toggleFullscreen(context, controller),
                    icon: const Icon(Icons.fullscreen),
                  ),
                  if (!isMobile) ...[
                    const Spacer(),
                    const Icon(Icons.volume_down, size: 20, color: AppColors.onSurfaceVariant),
                    SizedBox(
                      width: 120,
                      child: Slider(
                        value: _volume,
                        min: 0,
                        max: 1.0,
                        onChanged: (value) {
                          setState(() => _volume = value);
                          _controller?.setVolume(value);
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up, size: 20, color: AppColors.onSurfaceVariant),
                  ],
                ],
              ),
              if (isMobile) 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_down, size: 20, color: AppColors.onSurfaceVariant),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0,
                          max: 1.0,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            _controller?.setVolume(value);
                          },
                        ),
                      ),
                      const Icon(Icons.volume_up, size: 20, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ),
            ],
          ),
        );

        final playlistWidget = Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Text(
                  'Playlist',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No videos in library folders.',
                          style: TextStyle(color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final selected = index == _selectedIndex;
                          return ListTile(
                            selected: selected,
                            selectedTileColor: AppColors.surfaceContainerHigh,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 14,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: selected ? const Icon(Icons.volume_up, size: 18) : null,
                            onTap: () => _openAt(index),
                          );
                        },
                      ),
              ),
            ],
          ),
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: playerPadding,
            child: Column(
              children: [
                playerWidget,
                const SizedBox(height: 16),
                SizedBox(
                  height: 400,
                  child: playlistWidget,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: playerPadding,
          child: Row(
            children: [
              Expanded(flex: 5, child: playerWidget),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: playlistWidget),
            ],
          ),
        );
      },
    );
  }

  void _toggleFullscreen(BuildContext context, VideoPlayerController controller) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenPlayer(controller: controller),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _FullScreenPlayer extends StatefulWidget {
  final VideoPlayerController controller;

  const _FullScreenPlayer({required this.controller});

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
          ),
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: widget.controller.value.position.inMilliseconds.toDouble(),
                      max: widget.controller.value.duration.inMilliseconds.toDouble(),
                      onChanged: (val) => widget.controller.seekTo(Duration(milliseconds: val.round())),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => widget.controller.value.isPlaying
                              ? widget.controller.pause()
                              : widget.controller.play(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_showControls)
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerItem {
  const _PlayerItem({
    required this.path,
    required this.title,
    required this.subtitle,
    required this.modified,
  });

  final String path;
  final String title;
  final String subtitle;
  final DateTime modified;
}
