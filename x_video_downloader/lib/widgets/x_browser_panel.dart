import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:x_video_downloader/models/app_settings.dart';
import 'package:x_video_downloader/theme.dart';

enum BrowserTab { x, youtube, custom }

class BrowserRequest {
  const BrowserRequest({
    required this.sequence,
    required this.tab,
    required this.url,
  });

  final int sequence;
  final BrowserTab tab;
  final String url;
}

class BrowserPhotoDetection {
  const BrowserPhotoDetection({
    required this.pageUrl,
    required this.imageUrl,
  });

  final String pageUrl;
  final String imageUrl;
}

class XBrowserPanel extends StatefulWidget {
  const XBrowserPanel({
    super.key,
    this.width = 860,
    this.request,
    this.onClose,
    this.onVideoDetected,
    this.onPhotoDetected,
    this.autoDetect = true,
    this.settings,
  });

  final double width;
  final BrowserRequest? request;
  final VoidCallback? onClose;
  final ValueChanged<String>? onVideoDetected;
  final ValueChanged<BrowserPhotoDetection>? onPhotoDetected;
  final bool autoDetect;
  final AppSettings? settings;

  @override
  State<XBrowserPanel> createState() => _XBrowserPanelState();
}

class _XBrowserPanelState extends State<XBrowserPanel> {
  late final WebViewController _controller;
  int _progress = 0;
  String _title = 'X.com';
  bool _canGoBack = false;
  bool _canGoForward = false;
  BrowserTab _activeTab = BrowserTab.x;
  int _lastHandledSequence = -1;
  bool _autoScrollEnabled = false;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CronosDetector',
        onMessageReceived: (message) {
          final payload = message.message;
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map<String, dynamic>) {
              final type = decoded['type'];
              if (type == 'photo' && widget.onPhotoDetected != null) {
                final pageUrl = decoded['pageUrl'] as String?;
                final imageUrl = decoded['imageUrl'] as String?;
                if (pageUrl != null && imageUrl != null) {
                  widget.onPhotoDetected!(
                    BrowserPhotoDetection(pageUrl: pageUrl, imageUrl: imageUrl),
                  );
                }
                return;
              }
            }
          } catch (_) {}
          if (widget.onVideoDetected != null) {
            widget.onVideoDetected!(payload);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _progress = 0);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) async {
            final title = await _controller.getTitle();
            final canBack = await _controller.canGoBack();
            final canForward = await _controller.canGoForward();
            final currentUrl = await _controller.currentUrl();
            if (!mounted) return;
            setState(() {
              _title = (title == null || title.trim().isEmpty) ? 'Browser' : title.trim();
              _canGoBack = canBack;
              _canGoForward = canForward;
              if (currentUrl != null) {
                if (currentUrl.contains('youtube.com') || currentUrl.contains('youtu.be')) {
                  _activeTab = BrowserTab.youtube;
                } else if (currentUrl.contains('x.com') || currentUrl.contains('twitter.com')) {
                  _activeTab = BrowserTab.x;
                } else {
                  _activeTab = BrowserTab.custom;
                }
              }
              _progress = 100;
            });
            
            // Inject aggressive video detector
            if (widget.autoDetect) {
              _controller.runJavaScript('''
                (function() {
                  // ── Track all detected URLs so we never send duplicates ──
                  const detectedUrls = new Set();
                  const sentPhotos = new Set();
                  
                  // ── Normalize photo URLs ──
                  function normalizePhotoUrl(rawUrl) {
                    try {
                      const parsed = new URL(rawUrl, window.location.href);
                      if (!parsed.hostname.includes('twimg.com')) return null;
                      const format = parsed.searchParams.get('format');
                      if (!format) {
                        const match = parsed.pathname.match(/\\.([a-zA-Z0-9]+)\$/);
                        if (match) {
                          parsed.searchParams.set('format', match[1]);
                        }
                      }
                      parsed.searchParams.set('name', 'orig');
                      return parsed.toString();
                    } catch (e) {
                      return null;
                    }
                  }
                  
                  // ── Scan for YouTube video links ──
                  function scanForYoutubeVideos() {
                    if (!(window.location.href.includes('youtube.com') || window.location.href.includes('youtu.be'))) {
                      return;
                    }
                    
                    // Strategy 1: Find video watch links on the current page (search results, home page, etc.)
                    const videoLinks = document.querySelectorAll('a[href*="/watch?v="], a[href*="/shorts/"]');
                    videoLinks.forEach(function(link) {
                      if (!link.href) return;
                      const cleanUrl = link.href.split('&')[0].split('?')[0];
                      // Reconstruct as proper watch URL
                      const videoIdMatch = cleanUrl.match(/(?:watch\\?v=|shorts\\/)([A-Za-z0-9_-]{11})/);
                      if (!videoIdMatch) return;
                      const watchUrl = 'https://www.youtube.com/watch?v=' + videoIdMatch[1];
                      if (detectedUrls.has(watchUrl)) return;
                      detectedUrls.add(watchUrl);
                      CronosDetector.postMessage(watchUrl);
                    });
                    
                    // Strategy 2: Check if we're on a video watch page itself
                    const currentVideoId = window.location.href.match(/(?:watch\\?v=|shorts\\/)([A-Za-z0-9_-]{11})/);
                    if (currentVideoId) {
                      const watchUrl = 'https://www.youtube.com/watch?v=' + currentVideoId[1];
                      if (!detectedUrls.has(watchUrl)) {
                        detectedUrls.add(watchUrl);
                        CronosDetector.postMessage(watchUrl);
                      }
                    }
                    
                    // Strategy 3: Look for video renderer elements (rich grid items)
                    const videoRenderers = document.querySelectorAll('ytd-video-renderer, ytd-grid-video-renderer, ytd-compact-video-renderer, ytd-rich-item-renderer');
                    videoRenderers.forEach(function(renderer) {
                      const link = renderer.querySelector('a[href*="/watch?v="], a[href*="/shorts/"]');
                      if (!link || !link.href) return;
                      const videoIdMatch = link.href.match(/(?:watch\\?v=|shorts\\/)([A-Za-z0-9_-]{11})/);
                      if (!videoIdMatch) return;
                      const watchUrl = 'https://www.youtube.com/watch?v=' + videoIdMatch[1];
                      if (detectedUrls.has(watchUrl)) return;
                      detectedUrls.add(watchUrl);
                      CronosDetector.postMessage(watchUrl);
                    });
                  }
                  
                  // ── Scan for tweet status links that contain videos ──
                  function scanForTweetVideos() {
                    if (!(window.location.href.includes('x.com') || window.location.href.includes('twitter.com'))) {
                      return;
                    }
                    
                    // Strategy 1: Find all article elements and look for status links with video indicators
                    const articles = document.querySelectorAll('article');
                    articles.forEach(function(article) {
                      // Find the status link within this article
                      const statusLink = article.querySelector('a[href*="/status/"]');
                      if (!statusLink || !statusLink.href) return;
                      
                      // Clean the URL (remove query params, tracking, etc.)
                      const cleanUrl = statusLink.href.split('?')[0].split('#')[0];
                      if (detectedUrls.has(cleanUrl)) return;
                      
                      // Check if this article has video content
                      const hasVideo = article.querySelector('video') !== null;
                      const hasVideoPlayer = article.querySelector('[data-testid="videoComponent"], [data-testid="videoPlayer"]') !== null;
                      const hasPlayButton = article.querySelector('[aria-label*="Play"], [data-testid="playButton"]') !== null;
                      const hasVideoCard = article.querySelector('[data-testid="card.wrapper"]') !== null && 
                                           (article.querySelector('video') !== null || 
                                            article.innerText.toLowerCase().includes('video'));
                      
                      if (hasVideo || hasVideoPlayer || hasPlayButton || hasVideoCard) {
                        detectedUrls.add(cleanUrl);
                        CronosDetector.postMessage(cleanUrl);
                      }
                    });
                    
                    // Strategy 2: Look for standalone video player elements with status links
                    const videoPlayers = document.querySelectorAll('[data-testid="videoComponent"], [data-testid="videoPlayer"]');
                    videoPlayers.forEach(function(player) {
                      const link = player.closest('a[href*="/status/"]') || 
                                   player.querySelector('a[href*="/status/"]') ||
                                   player.closest('article')?.querySelector('a[href*="/status/"]');
                      if (link && link.href) {
                        const cleanUrl = link.href.split('?')[0].split('#')[0];
                        if (!detectedUrls.has(cleanUrl)) {
                          detectedUrls.add(cleanUrl);
                          CronosDetector.postMessage(cleanUrl);
                        }
                      }
                    });
                    
                    // Strategy 3: Directly find all status links and check for video indicators nearby
                    const allStatusLinks = document.querySelectorAll('a[href*="/status/"]');
                    allStatusLinks.forEach(function(link) {
                      if (!link.href) return;
                      const cleanUrl = link.href.split('?')[0].split('#')[0];
                      if (detectedUrls.has(cleanUrl)) return;
                      
                      // Check if this link or its parent has video-related content
                      const parent = link.closest('article') || link.parentElement;
                      if (parent) {
                        const hasVideo = parent.querySelector('video') !== null;
                        const hasVideoIndicator = parent.querySelector('[data-testid="videoComponent"], [data-testid="videoPlayer"], [aria-label*="Play"]') !== null;
                        const hasVideoIcon = parent.querySelector('svg[aria-label*="video"], svg[aria-label*="play"]') !== null;
                        
                        if (hasVideo || hasVideoIndicator || hasVideoIcon) {
                          detectedUrls.add(cleanUrl);
                          CronosDetector.postMessage(cleanUrl);
                        }
                      }
                    });
                  }
                  
                  // ── Scan for photos ──
                  function scanPhotos() {
                    if (!(window.location.href.includes('x.com') || window.location.href.includes('twitter.com'))) {
                      return;
                    }
                    const photoLinks = document.querySelectorAll('a[href*="/photo/"]');
                    photoLinks.forEach(function(link) {
                      if (
                        link.closest('[data-testid="videoComponent"]') ||
                        link.closest('[data-testid="videoPlayer"]') ||
                        link.querySelector('video')
                      ) {
                        return;
                      }
                      const img = link.querySelector('img');
                      if (!img) return;
                      const normalized = normalizePhotoUrl(img.currentSrc || img.src);
                      if (!normalized || sentPhotos.has(normalized)) return;
                      sentPhotos.add(normalized);
                      CronosDetector.postMessage(JSON.stringify({
                        type: 'photo',
                        pageUrl: window.location.href,
                        imageUrl: normalized,
                      }));
                    });
                  }
                  
                  // ── Aggressive scan that runs everything ──
                  function aggressiveScan() {
                    scanForTweetVideos();
                    scanForYoutubeVideos();
                    scanPhotos();
                  }
                  
                  // ── Set up MutationObserver to catch dynamically loaded content ──
                  const observer = new MutationObserver(function(mutations) {
                    // Only scan if new nodes were added (content loaded by scrolling)
                    let hasNewNodes = false;
                    for (let i = 0; i < mutations.length; i++) {
                      if (mutations[i].addedNodes.length > 0) {
                        hasNewNodes = true;
                        break;
                      }
                    }
                    if (hasNewNodes) {
                      // Scan immediately when new content appears
                      aggressiveScan();
                    }
                  });
                  
                  // Start observing the document body for DOM changes
                  observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: false,
                    characterData: false
                  });
                  
                  // ── Run aggressive scan on a fast interval (every 300ms) ──
                  setInterval(aggressiveScan, 300);
                  
                  // ── Also run on scroll events ──
                  let scrollTimeout = null;
                  document.addEventListener('scroll', function() {
                    if (scrollTimeout) return;
                    scrollTimeout = setTimeout(function() {
                      scrollTimeout = null;
                      aggressiveScan();
                    }, 100);
                  }, { passive: true });
                  
                  // ── Initial scan ──
                  aggressiveScan();
                })();
              ''');
            }
          },
        ),
      );
    _openTab(BrowserTab.x, 'https://x.com');
    _applyRequestIfAny();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant XBrowserPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyRequestIfAny();
  }

  void _applyRequestIfAny() {
    final request = widget.request;
    if (request == null) return;
    if (request.sequence == _lastHandledSequence) return;
    _lastHandledSequence = request.sequence;
    _openTab(request.tab, request.url);
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScrollEnabled = !_autoScrollEnabled;
    });

    if (_autoScrollEnabled) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    // Scroll faster and more aggressively to ensure content loads
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _controller.runJavaScript('''
        window.scrollBy({
          top: 300,
          behavior: 'instant'
        });
      ''');
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      color: AppColors.surfaceContainerLowest,
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 500 && widget.onClose != null) {
                widget.onClose!();
              }
            },
            child: Container(
              color: AppColors.surfaceContainerLowest,
              child: Column(
                children: [
                  if (widget.onClose != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.surfaceContainerHigh),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 18),
                          onPressed: _canGoBack ? () => _controller.goBack() : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          onPressed: _canGoForward ? () => _controller.goForward() : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          onPressed: () => _controller.reload(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _autoScrollEnabled ? Icons.pause : Icons.play_arrow,
                            size: 18,
                            color: _autoScrollEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
                          ),
                          tooltip: _autoScrollEnabled ? 'Stop auto-scroll' : 'Start auto-scroll',
                          onPressed: _toggleAutoScroll,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _browserTab(
                  label: 'X.com',
                  isActive: _activeTab == BrowserTab.x,
                  onTap: () => _openTab(BrowserTab.x, 'https://x.com'),
                ),
                const SizedBox(width: 8),
                _browserTab(
                  label: 'YouTube',
                  isActive: _activeTab == BrowserTab.youtube,
                  onTap: () => _openTab(BrowserTab.youtube, 'https://www.youtube.com'),
                ),
                const SizedBox(width: 8),
                _browserTab(
                  label: 'Custom',
                  isActive: _activeTab == BrowserTab.custom,
                  onTap: () => _openTab(BrowserTab.custom, 'https://xvideos.com'),
                ),
                const Spacer(),
                if (_autoScrollEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-scroll',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 2,
              color: AppColors.primary,
            ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }

  Widget _browserTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _openTab(BrowserTab tab, String url) {
    setState(() => _activeTab = tab);
    
    // Check if we should enable VPN for this URL
    if (widget.settings != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final host = uri.host.toLowerCase();
        
        // Check if this is an adult site that should trigger auto-VPN
        if (widget.settings!.autoVpnForAdultSites && 
            (host.contains('pornhub.com') || host.contains('luxuretv.com'))) {
          // Auto-enable VPN and set location to Canada
          if (!widget.settings!.enableVpn || widget.settings!.vpnLocation != 'Canada') {
            // We would need to update settings here, but we don't have a callback
            // This would require passing a callback to update settings
            print('VPN should be enabled for $host - location set to Canada');
            // Note: In a real implementation, we would call a callback to update settings
            // For now, we just log the message
          }
        }
      }
    }
    
    _controller.loadRequest(Uri.parse(url));
  }
}