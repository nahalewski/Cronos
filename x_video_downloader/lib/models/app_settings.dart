class AppSettings {
  const AppSettings({
    required this.browserIntegration,
    required this.desktopNotifications,
    this.downloadDirectory,
    this.photoDownloadDirectory,
    this.xVideoDownloadDirectory,
    this.youtubeVideoDownloadDirectory,
    this.youtubeMp3DownloadDirectory,
    this.xvideosDownloadDirectory,
    this.xhamsterDownloadDirectory,
    this.hentaihavenDownloadDirectory,
    this.hanimeDownloadDirectory,
    this.rule34videoDownloadDirectory,
    this.useUnifiedFolder = false,
    this.unifiedDownloadDirectory,
    this.preventDuplicateDownloads = true,
    this.enableVpn = false,
    this.autoVpnForAdultSites = true,
    this.vpnLocation = 'Canada',
  });

  final bool browserIntegration;
  final bool desktopNotifications;
  final String? downloadDirectory;
  final String? photoDownloadDirectory;
  final String? xVideoDownloadDirectory;
  final String? youtubeVideoDownloadDirectory;
  final String? youtubeMp3DownloadDirectory;
  final String? xvideosDownloadDirectory;
  final String? xhamsterDownloadDirectory;
  final String? hentaihavenDownloadDirectory;
  final String? hanimeDownloadDirectory;
  final String? rule34videoDownloadDirectory;
  final bool useUnifiedFolder;
  final String? unifiedDownloadDirectory;
  final bool preventDuplicateDownloads;
  final bool enableVpn;
  final bool autoVpnForAdultSites;
  final String vpnLocation;

  factory AppSettings.defaults() {
    return const AppSettings(
      browserIntegration: true,
      desktopNotifications: false,
      downloadDirectory: null,
      photoDownloadDirectory: null,
      xVideoDownloadDirectory: null,
      youtubeVideoDownloadDirectory: null,
      youtubeMp3DownloadDirectory: null,
      xvideosDownloadDirectory: null,
      xhamsterDownloadDirectory: null,
      hentaihavenDownloadDirectory: null,
      hanimeDownloadDirectory: null,
      rule34videoDownloadDirectory: null,
      useUnifiedFolder: false,
      unifiedDownloadDirectory: null,
      preventDuplicateDownloads: true,
      enableVpn: false,
      autoVpnForAdultSites: true,
      vpnLocation: 'Canada',
    );
  }

  AppSettings copyWith({
    bool? browserIntegration,
    bool? desktopNotifications,
    bool? preventDuplicateDownloads,
    bool? enableVpn,
    bool? autoVpnForAdultSites,
    String? vpnLocation,
    String? downloadDirectory,
    String? photoDownloadDirectory,
    String? xVideoDownloadDirectory,
    String? youtubeVideoDownloadDirectory,
    String? youtubeMp3DownloadDirectory,
    String? xvideosDownloadDirectory,
    String? xhamsterDownloadDirectory,
    String? hentaihavenDownloadDirectory,
    String? hanimeDownloadDirectory,
    String? rule34videoDownloadDirectory,
    bool? useUnifiedFolder,
    String? unifiedDownloadDirectory,
    bool clearDownloadDirectory = false,
    bool clearPhotoDownloadDirectory = false,
    bool clearXVideoDownloadDirectory = false,
    bool clearYoutubeVideoDownloadDirectory = false,
    bool clearYoutubeMp3DownloadDirectory = false,
    bool clearXvideosDownloadDirectory = false,
    bool clearXhamsterDownloadDirectory = false,
    bool clearHentaihavenDownloadDirectory = false,
    bool clearHanimeDownloadDirectory = false,
    bool clearRule34videoDownloadDirectory = false,
    bool clearUnifiedDownloadDirectory = false,
  }) {
    return AppSettings(
      browserIntegration: browserIntegration ?? this.browserIntegration,
      desktopNotifications: desktopNotifications ?? this.desktopNotifications,
      preventDuplicateDownloads: preventDuplicateDownloads ?? this.preventDuplicateDownloads,
      enableVpn: enableVpn ?? this.enableVpn,
      autoVpnForAdultSites: autoVpnForAdultSites ?? this.autoVpnForAdultSites,
      vpnLocation: vpnLocation ?? this.vpnLocation,
      downloadDirectory:
          clearDownloadDirectory ? null : (downloadDirectory ?? this.downloadDirectory),
      photoDownloadDirectory: clearPhotoDownloadDirectory
          ? null
          : (photoDownloadDirectory ?? this.photoDownloadDirectory),
      xVideoDownloadDirectory: clearXVideoDownloadDirectory
          ? null
          : (xVideoDownloadDirectory ?? this.xVideoDownloadDirectory),
      youtubeVideoDownloadDirectory: clearYoutubeVideoDownloadDirectory
          ? null
          : (youtubeVideoDownloadDirectory ?? this.youtubeVideoDownloadDirectory),
      youtubeMp3DownloadDirectory: clearYoutubeMp3DownloadDirectory
          ? null
          : (youtubeMp3DownloadDirectory ?? this.youtubeMp3DownloadDirectory),
      xvideosDownloadDirectory: clearXvideosDownloadDirectory
          ? null
          : (xvideosDownloadDirectory ?? this.xvideosDownloadDirectory),
      xhamsterDownloadDirectory: clearXhamsterDownloadDirectory
          ? null
          : (xhamsterDownloadDirectory ?? this.xhamsterDownloadDirectory),
      hentaihavenDownloadDirectory: clearHentaihavenDownloadDirectory
          ? null
          : (hentaihavenDownloadDirectory ?? this.hentaihavenDownloadDirectory),
      hanimeDownloadDirectory:
          clearHanimeDownloadDirectory ? null : (hanimeDownloadDirectory ?? this.hanimeDownloadDirectory),
      rule34videoDownloadDirectory: clearRule34videoDownloadDirectory
          ? null
          : (rule34videoDownloadDirectory ?? this.rule34videoDownloadDirectory),
      useUnifiedFolder: useUnifiedFolder ?? this.useUnifiedFolder,
      unifiedDownloadDirectory: clearUnifiedDownloadDirectory
          ? null
          : (unifiedDownloadDirectory ?? this.unifiedDownloadDirectory),
    );
  }
}
