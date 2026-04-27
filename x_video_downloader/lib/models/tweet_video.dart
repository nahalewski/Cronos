enum DownloadStatus { idle, fetching, downloading, done, error }
enum VideoSource { twitter, youtube, xvideos, xhamster, hentaihaven, hanime, rule34video, other }

class TweetVideo {
  final String id;
  final String inputUrl;
  final VideoSource source;
  String? tweetText;
  String? authorName;
  String? thumbnailUrl;
  List<VideoVariant> variants;
  VideoVariant? selectedVariant;
  DownloadStatus status;
  double downloadProgress;
  String? errorMessage;
  String? savedPath;
  int retryCount;

  TweetVideo({
    required this.id,
    required this.inputUrl,
    this.source = VideoSource.twitter,
    this.tweetText,
    this.authorName,
    this.thumbnailUrl,
    this.variants = const [],
    this.selectedVariant,
    this.status = DownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.savedPath,
    this.retryCount = 0,
  });
}

class VideoVariant {
  final String url;
  final int? bitrate;
  final String? resolution;
  final String? formatId;
  final bool audioOnly;
  final String? customLabel;

  VideoVariant({
    required this.url,
    this.bitrate,
    this.resolution,
    this.formatId,
    this.audioOnly = false,
    this.customLabel,
  });

  String get label {
    if (customLabel != null && customLabel!.isNotEmpty) return customLabel!;
    final hasResolution = resolution != null && resolution!.isNotEmpty;
    final hasBitrate = bitrate != null && bitrate! > 0;
    if (hasResolution && hasBitrate) {
      return '$resolution • ${(bitrate! / 1000).round()} kbps';
    }
    if (hasResolution) return resolution!;
    if (hasBitrate) return '${(bitrate! / 1000).round()} kbps';
    return 'Default';
  }
}
