import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'settings_download_directory';

class DownloadService {
  final Dio _dio = Dio();

  static bool get isMacOS => Platform.isMacOS;
  static bool get isAndroid => Platform.isAndroid;

  /// Returns the stored download directory.
  static Future<String?> getSavedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored == null) return null;

    try {
      final dir = Directory(stored);
      if (dir.existsSync()) return stored;
      
      // On some Android versions/devices, even with permission, existsSync() can be picky 
      // about custom paths until a write is attempted or after a reboot.
      // We'll trust the stored path if it's an absolute path on Android.
      if (isAndroid && stored.startsWith('/storage/')) {
        return stored; 
      }
    } catch (e) {
      debugPrint('Error checking directory $stored: $e');
    }
    return null;
  }

  /// Returns the effective download directory.
  static Future<String> getEffectiveDirectory() async {
    final saved = await getSavedDirectory();
    if (saved != null) return saved;

    if (isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final fallback = p.join(home, 'Downloads', 'x downloads');
      await Directory(fallback).create(recursive: true);
      return fallback;
    }

    // Android/iOS fallback
    final base = await getApplicationDocumentsDirectory();
    final fallback = p.join(base.path, 'x_downloads');
    await Directory(fallback).create(recursive: true);
    return fallback;
  }

  static Future<void> saveDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, path);
  }

  /// Builds a deterministic filename from tweet ID and optional resolution.
  /// Appends a numeric suffix if a different file already exists at that path.
  static String buildFilename(String tweetId, String? resolution) {
    final quality = resolution?.replaceAll('x', 'x') ?? 'best';
    return 'x_${tweetId}_$quality.mp4';
  }

  /// Returns a non-colliding file path.
  /// - If the file doesn't exist → use it as-is.
  /// - If the file exists and has content → reuse it (idempotent re-download).
  /// - If the file exists but is empty (interrupted download) → try _2, _3 …
  static String _uniquePath(String dir, String filename) {
    final base = p.basenameWithoutExtension(filename);
    final ext = p.extension(filename);
    var candidate = p.join(dir, filename);
    var counter = 2;
    while (File(candidate).existsSync() && File(candidate).lengthSync() == 0) {
      candidate = p.join(dir, '${base}_$counter$ext');
      counter++;
    }
    return candidate;
  }

  Future<String> downloadVideo({
    required String url,
    required String filename,
    String? saveDirectory,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final filePath = await downloadFile(
      url: url,
      filename: filename,
      saveDirectory: saveDirectory,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );

    // On iOS/Android, we also save to Gallery for convenience if it's not a custom path
    if (!isMacOS && saveDirectory == null) {
      await Gal.putVideo(filePath, album: 'X Downloads');
    }
    
    return filePath;
  }

  Future<String> downloadFile({
    required String url,
    required String filename,
    String? saveDirectory,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = saveDirectory ?? await getEffectiveDirectory();
    await Directory(dir).create(recursive: true);
    final filePath = _uniquePath(dir, filename);

    if (File(filePath).existsSync() && File(filePath).lengthSync() > 0) {
      onProgress?.call(1.0);
      return filePath;
    }

    await _dio.download(
      url,
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
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        },
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    return filePath;
  }

  /// Moves videos from internal app storage to a destination directory.
  Future<int> migrateInternalToExternal(String destination) async {
    final base = await getApplicationDocumentsDirectory();
    final internalDir = Directory(p.join(base.path, 'x_downloads'));
    if (!internalDir.existsSync()) return 0;

    final destDir = Directory(destination);
    if (!destDir.existsSync()) await destDir.create(recursive: true);

    var movedCount = 0;
    final files = internalDir.listSync().whereType<File>();

    for (final file in files) {
      try {
        final filename = p.basename(file.path);
        final destPath = p.join(destination, filename);
        
        // Copy then delete (rename doesn't work across partitions on Android)
        await file.copy(destPath);
        await file.delete();
        movedCount++;
      } catch (e) {
        debugPrint('Failed to migrate ${file.path}: $e');
      }
    }
    return movedCount;
  }
}
