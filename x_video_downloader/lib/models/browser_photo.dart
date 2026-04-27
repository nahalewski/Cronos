import 'package:x_video_downloader/models/tweet_video.dart';

class BrowserPhoto {
  BrowserPhoto({
    required this.id,
    required this.pageUrl,
    required this.imageUrl,
    this.status = DownloadStatus.idle,
    this.downloadProgress = 0,
    this.errorMessage,
    this.savedPath,
  });

  final String id;
  final String pageUrl;
  final String imageUrl;
  DownloadStatus status;
  double downloadProgress;
  String? errorMessage;
  String? savedPath;
}
