import 'package:shared_preferences/shared_preferences.dart';
import 'package:x_video_downloader/models/app_settings.dart';

class AppSettingsService {
  static const _browserIntegrationKey = 'settings_browser_integration';
  static const _desktopNotificationsKey = 'settings_desktop_notifications';
  static const _downloadDirectoryKey = 'settings_download_directory';
  static const _photoDownloadDirectoryKey = 'settings_photo_download_directory';
  static const _xVideoDownloadDirectoryKey = 'settings_x_video_download_directory';
  static const _youtubeVideoDownloadDirectoryKey = 'settings_youtube_video_download_directory';
  static const _youtubeMp3DownloadDirectoryKey = 'settings_youtube_mp3_download_directory';
  static const _xvideosDownloadDirectoryKey = 'settings_xvideos_download_directory';
  static const _xhamsterDownloadDirectoryKey = 'settings_xhamster_download_directory';
  static const _hentaihavenDownloadDirectoryKey = 'settings_hentaihaven_download_directory';
  static const _hanimeDownloadDirectoryKey = 'settings_hanime_download_directory';
  static const _rule34videoDownloadDirectoryKey = 'settings_rule34video_download_directory';
  static const _useUnifiedFolderKey = 'settings_use_unified_folder';
  static const _unifiedDownloadDirectoryKey = 'settings_unified_download_directory';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AppSettings.defaults();
    return AppSettings(
      browserIntegration:
          prefs.getBool(_browserIntegrationKey) ?? defaults.browserIntegration,
      desktopNotifications:
          prefs.getBool(_desktopNotificationsKey) ?? defaults.desktopNotifications,
      downloadDirectory: prefs.getString(_downloadDirectoryKey),
      photoDownloadDirectory: prefs.getString(_photoDownloadDirectoryKey),
      xVideoDownloadDirectory: prefs.getString(_xVideoDownloadDirectoryKey),
      youtubeVideoDownloadDirectory: prefs.getString(_youtubeVideoDownloadDirectoryKey),
      youtubeMp3DownloadDirectory: prefs.getString(_youtubeMp3DownloadDirectoryKey),
      xvideosDownloadDirectory: prefs.getString(_xvideosDownloadDirectoryKey),
      xhamsterDownloadDirectory: prefs.getString(_xhamsterDownloadDirectoryKey),
      hentaihavenDownloadDirectory: prefs.getString(_hentaihavenDownloadDirectoryKey),
      hanimeDownloadDirectory: prefs.getString(_hanimeDownloadDirectoryKey),
      rule34videoDownloadDirectory: prefs.getString(_rule34videoDownloadDirectoryKey),
      useUnifiedFolder: prefs.getBool(_useUnifiedFolderKey) ?? defaults.useUnifiedFolder,
      unifiedDownloadDirectory: prefs.getString(_unifiedDownloadDirectoryKey),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_browserIntegrationKey, settings.browserIntegration);
    await prefs.setBool(_desktopNotificationsKey, settings.desktopNotifications);
    await prefs.setBool(_useUnifiedFolderKey, settings.useUnifiedFolder);
    await _saveOptional(prefs, _downloadDirectoryKey, settings.downloadDirectory);
    await _saveOptional(prefs, _photoDownloadDirectoryKey, settings.photoDownloadDirectory);
    await _saveOptional(prefs, _xVideoDownloadDirectoryKey, settings.xVideoDownloadDirectory);
    await _saveOptional(
      prefs,
      _youtubeVideoDownloadDirectoryKey,
      settings.youtubeVideoDownloadDirectory,
    );
    await _saveOptional(
      prefs,
      _youtubeMp3DownloadDirectoryKey,
      settings.youtubeMp3DownloadDirectory,
    );
    await _saveOptional(prefs, _xvideosDownloadDirectoryKey, settings.xvideosDownloadDirectory);
    await _saveOptional(prefs, _xhamsterDownloadDirectoryKey, settings.xhamsterDownloadDirectory);
    await _saveOptional(
      prefs,
      _hentaihavenDownloadDirectoryKey,
      settings.hentaihavenDownloadDirectory,
    );
    await _saveOptional(prefs, _hanimeDownloadDirectoryKey, settings.hanimeDownloadDirectory);
    await _saveOptional(
      prefs,
      _rule34videoDownloadDirectoryKey,
      settings.rule34videoDownloadDirectory,
    );
    await _saveOptional(
      prefs,
      _unifiedDownloadDirectoryKey,
      settings.unifiedDownloadDirectory,
    );
  }

  Future<void> _saveOptional(SharedPreferences prefs, String key, String? value) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}
