import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class LinkLogService {
  static const String _logFileName = 'link_history.json';
  static File? _logFile;
  
  /// Gets the log file path
  static Future<String> _getLogFilePath() async {
    final directory = await _getLogDirectory();
    return p.join(directory, _logFileName);
  }
  
  /// Gets the directory for storing logs
  static Future<String> _getLogDirectory() async {
    final appDir = await _getAppDirectory();
    final logsDir = p.join(appDir, 'logs');
    await Directory(logsDir).create(recursive: true);
    return logsDir;
  }
  
  /// Gets the application directory
  static Future<String> _getAppDirectory() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      return p.join(home, 'Library', 'Application Support', 'Cronos');
    } else if (Platform.isAndroid) {
      final externalDir = Directory('/storage/emulated/0/Download/Cronos');
      if (await externalDir.exists()) {
        return externalDir.path;
      }
      final internalDir = Directory('/data/data/com.example.cronos/files');
      return internalDir.path;
    } else {
      final currentDir = Directory.current.path;
      return p.join(currentDir, '.cronos');
    }
  }
  
  /// Logs a link to the history file
  static Future<void> logLink({
    required String url,
    required String source,
    required DateTime timestamp,
    String? title,
    String? author,
    bool? success,
    String? error,
  }) async {
    try {
      final logFile = await _ensureLogFile();
      final logs = await _readLogs();
      
      final entry = {
        'url': url,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
        'title': title,
        'author': author,
        'success': success,
        'error': error,
      };
      
      // Add to beginning of list (most recent first)
      logs.insert(0, entry);
      
      // Keep only last 1000 entries to prevent file from growing too large
      if (logs.length > 1000) {
        logs.removeRange(1000, logs.length);
      }
      
      await logFile.writeAsString(jsonEncode(logs));
    } catch (e) {
      print('Error logging link: $e');
    }
  }
  
  /// Checks if a link has already been logged (to prevent duplicates)
  static Future<bool> isLinkLogged(String url) async {
    try {
      final logs = await _readLogs();
      return logs.any((entry) => entry['url'] == url);
    } catch (e) {
      return false;
    }
  }
  
  /// Gets all logged links
  static Future<List<Map<String, dynamic>>> getLoggedLinks() async {
    return await _readLogs();
  }
  
  /// Clears the link log
  static Future<void> clearLogs() async {
    try {
      final logFile = await _ensureLogFile();
      await logFile.writeAsString('[]');
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }
  
  /// Ensures the log file exists and returns it
  static Future<File> _ensureLogFile() async {
    if (_logFile != null) return _logFile!;
    
    final logPath = await _getLogFilePath();
    _logFile = File(logPath);
    
    if (!await _logFile!.exists()) {
      await _logFile!.writeAsString('[]');
    }
    
    return _logFile!;
  }
  
  /// Reads all logs from the file
  static Future<List<Map<String, dynamic>>> _readLogs() async {
    try {
      final logFile = await _ensureLogFile();
      final content = await logFile.readAsString();
      if (content.trim().isEmpty) return [];
      
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (e) {
      print('Error reading logs: $e');
      return [];
    }
  }
  
  /// Logs a successful video fetch
  static Future<void> logVideoFetchSuccess({
    required String url,
    required String source,
    String? title,
    String? author,
  }) async {
    await logLink(
      url: url,
      source: source,
      timestamp: DateTime.now(),
      title: title,
      author: author,
      success: true,
    );
  }
  
  /// Logs a failed video fetch
  static Future<void> logVideoFetchFailure({
    required String url,
    required String source,
    String? error,
  }) async {
    await logLink(
      url: url,
      source: source,
      timestamp: DateTime.now(),
      success: false,
      error: error,
    );
  }
  
  /// Logs a download completion
  static Future<void> logDownloadComplete({
    required String url,
    required String source,
    String? title,
    String? author,
    String? savedPath,
  }) async {
    await logLink(
      url: url,
      source: source,
      timestamp: DateTime.now(),
      title: title,
      author: author,
      success: true,
    );
    
    // Also log to a separate downloads log if needed
    await _logToDownloadsLog(url, source, title, savedPath);
  }
  
  /// Logs to a separate downloads log file
  static Future<void> _logToDownloadsLog(
    String url,
    String source,
    String? title,
    String? savedPath,
  ) async {
    try {
      final downloadsLogPath = p.join(
        await _getLogDirectory(),
        'downloads_history.json',
      );
      final downloadsLogFile = File(downloadsLogPath);
      
      List<Map<String, dynamic>> downloads = [];
      if (await downloadsLogFile.exists()) {
        final content = await downloadsLogFile.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is List) {
            downloads = decoded.cast<Map<String, dynamic>>().toList();
          }
        }
      }
      
      downloads.insert(0, {
        'url': url,
        'source': source,
        'title': title,
        'savedPath': savedPath,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Keep only last 500 downloads
      if (downloads.length > 500) {
        downloads.removeRange(500, downloads.length);
      }
      
      await downloadsLogFile.writeAsString(jsonEncode(downloads));
    } catch (e) {
      print('Error logging to downloads log: $e');
    }
  }
  
  /// Gets download history
  static Future<List<Map<String, dynamic>>> getDownloadHistory() async {
    try {
      final downloadsLogPath = p.join(
        await _getLogDirectory(),
        'downloads_history.json',
      );
      final downloadsLogFile = File(downloadsLogPath);
      
      if (!await downloadsLogFile.exists()) return [];
      
      final content = await downloadsLogFile.readAsString();
      if (content.trim().isEmpty) return [];
      
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (e) {
      print('Error reading download history: $e');
      return [];
    }
  }
}