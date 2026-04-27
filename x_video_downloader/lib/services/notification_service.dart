import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (Platform.isAndroid) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(initSettings);
      _isInitialized = true;
    } else if (Platform.isMacOS) {
      // macOS uses system notifications via flutter_local_notifications
      const macOSInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(macOS: macOSInit);
      await _plugin.initialize(initSettings);
      _isInitialized = true;
    }
    // For other platforms, don't initialize
  }

  Future<void> showProgress(int id, String title, int progress, String status) async {
    if (!_isInitialized) return;
    
    if (Platform.isAndroid) {
      try {
        final androidDetails = AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Ongoing downloads progress',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          ongoing: true,
        );
        final details = NotificationDetails(android: androidDetails);
        await _plugin.show(id, title, status, details);
      } catch (e) {
        print('Failed to show progress notification: $e');
      }
    } else if (Platform.isMacOS) {
      // macOS system notification for progress
      try {
        final macOSDetails = DarwinNotificationDetails(
          subtitle: '$progress% - $status',
          presentAlert: false,
          presentSound: false,
        );
        final details = NotificationDetails(macOS: macOSDetails);
        await _plugin.show(id, title, status, details);
      } catch (e) {
        print('Failed to show macOS notification: $e');
      }
    }
  }

  Future<void> showCompleted(int id, String title, String body) async {
    if (!_isInitialized) return;

    if (Platform.isAndroid) {
      try {
        final androidDetails = AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Download completed',
          importance: Importance.high,
          priority: Priority.high,
        );
        final details = NotificationDetails(android: androidDetails);
        await _plugin.show(id, title, body, details);
      } catch (e) {
        print('Failed to show completed notification: $e');
      }
    } else if (Platform.isMacOS) {
      // macOS system notification for completion
      try {
        final macOSDetails = DarwinNotificationDetails(
          subtitle: body,
          presentAlert: true,
          presentSound: true,
        );
        final details = NotificationDetails(macOS: macOSDetails);
        await _plugin.show(id, title, body, details);
      } catch (e) {
        print('Failed to show macOS notification: $e');
      }
    }
  }

  Future<void> cancel(int id) async {
    if (!_isInitialized) return;
    
    try {
      await _plugin.cancel(id);
    } catch (e) {
      print('Failed to cancel notification: $e');
    }
  }

  Future<void> showInfo(String title, String body) async {
    if (!_isInitialized) return;

    if (Platform.isAndroid) {
      try {
        final androidDetails = AndroidNotificationDetails(
          'info_channel',
          'Notifications',
          channelDescription: 'General app notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
        final details = NotificationDetails(android: androidDetails);
        await _plugin.show(
          DateTime.now().millisecondsSinceEpoch,
          title,
          body,
          details,
        );
      } catch (e) {
        print('Failed to show info notification: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        final macOSDetails = DarwinNotificationDetails(
          subtitle: body,
          presentAlert: true,
          presentSound: false,
        );
        final details = NotificationDetails(macOS: macOSDetails);
        await _plugin.show(
          DateTime.now().millisecondsSinceEpoch,
          title,
          body,
          details,
        );
      } catch (e) {
        print('Failed to show macOS notification: $e');
      }
    }
  }

  Future<void> showError(String title, String body) async {
    if (!_isInitialized) return;

    if (Platform.isAndroid) {
      try {
        final androidDetails = AndroidNotificationDetails(
          'error_channel',
          'Errors',
          channelDescription: 'Download errors',
          importance: Importance.high,
          priority: Priority.high,
        );
        final details = NotificationDetails(android: androidDetails);
        await _plugin.show(
          DateTime.now().millisecondsSinceEpoch,
          title,
          body,
          details,
        );
      } catch (e) {
        print('Failed to show error notification: $e');
      }
    } else if (Platform.isMacOS) {
      // macOS system notification for errors
      try {
        final macOSDetails = DarwinNotificationDetails(
          subtitle: body,
          presentAlert: true,
          presentSound: true,
        );
        final details = NotificationDetails(macOS: macOSDetails);
        await _plugin.show(
          DateTime.now().millisecondsSinceEpoch,
          title,
          body,
          details,
        );
      } catch (e) {
        print('Failed to show macOS notification: $e');
      }
    }
  }
}