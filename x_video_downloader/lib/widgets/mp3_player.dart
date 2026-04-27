import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:x_video_downloader/theme.dart';

class MP3Player extends StatefulWidget {
  const MP3Player({
    super.key,
    required this.filePath,
    this.title,
    this.artist,
    this.onDelete,
  });

  final String filePath;
  final String? title;
  final String? artist;
  final VoidCallback? onDelete;

  @override
  State<MP3Player> createState() => _MP3PlayerState();
}

class _MP3PlayerState extends State<MP3Player> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _setupAudioPlayer() async {
    if (!File(widget.filePath).existsSync()) return;

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading = state == PlayerState.loading;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _playPause() async {
    if (_isLoading) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_position >= _duration) {
        await _audioPlayer.seek(Duration.zero);
      }
      await _audioPlayer.play(DeviceFileSource(widget.filePath));
    }
  }

  Future<void> _seek(double value) async {
    final position = Duration(milliseconds: (value * _duration.inMilliseconds).toInt());
    await _audioPlayer.seek(position);
  }

  Future<void> _setVolume(double value) async {
    await _audioPlayer.setVolume(value);
    setState(() => _volume = value);
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final fileExists = File(widget.filePath).existsSync();
    final fileName = widget.title ?? widget.filePath.split('/').last;
    final artistName = widget.artist ?? 'Unknown Artist';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: AppColors.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artistName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!fileExists)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.onErrorContainer),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'File not found',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Progress bar
                Slider(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0.0,
                  onChanged: _seek,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surfaceContainerHigh,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Volume
                    Icon(
                      _volume == 0 ? Icons.volume_off : Icons.volume_up,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Slider(
                        value: _volume,
                        onChanged: _setVolume,
                        min: 0.0,
                        max: 1.0,
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.surfaceContainerHigh,
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Stop button
                    IconButton(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop, size: 20),
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    
                    // Play/Pause button
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: IconButton(
                        onPressed: _playPause,
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: AppColors.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Skip forward 10 seconds
                    IconButton(
                      onPressed: () async {
                        final newPosition = _position + const Duration(seconds: 10);
                        if (newPosition <= _duration) {
                          await _audioPlayer.seek(newPosition);
                        }
                      },
                      icon: const Icon(Icons.forward_10, size: 20),
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}