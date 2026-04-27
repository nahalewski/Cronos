import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'download_service.dart';

class FailureLoggingService {
  Future<void> logFailure({
    required String url,
    required String source,
    required String error,
  }) async {
    try {
      final baseDir = await DownloadService.getEffectiveDirectory();
      final logFile = File(p.join(baseDir, 'failed_downloads.log'));
      
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final logEntry = '[$timestamp] [$source] $url - Error: $error\n';
      
      await logFile.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      // If logging fails, we don't want to crash the app, but we can print to console
      print('Failed to write to failure log: $e');
    }
  }
}
