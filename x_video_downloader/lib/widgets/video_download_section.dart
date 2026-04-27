import 'package:flutter/material.dart';
import 'package:x_video_downloader/theme.dart';

class VideoDownloadSection extends StatelessWidget {
  const VideoDownloadSection({
    super.key,
    required this.controller,
    required this.onAddUrls,
    required this.onPaste,
    required this.addingUrls,
  });

  final TextEditingController controller;
  final VoidCallback onAddUrls;
  final VoidCallback onPaste;
  final bool addingUrls;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(48.0), // p-12 and mb-16 (bottom padding will be handled by parent)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero / Paste Section
          Container(
            margin: const EdgeInsets.only(bottom: 40.0), // mb-10
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back.',
                  style: textTheme.headlineLarge?.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 36, // text-4xl - adjusted for better fit
                  ),
                ),
                Text(
                  'Ready to curate your next video collection?',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Input and Button Section
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest, // bg-surface-container-lowest
              borderRadius: BorderRadius.circular(16.0), // rounded-2xl
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ), // shadow-xl shadow-on-surface/5
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0), // p-2
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0), // px-4
                    child: Icon(
                      Icons.link,
                      color: AppColors.primary.withValues(alpha: 0.6), // text-primary/60
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Paste links from X, YouTube, XVideos, and more',
                        hintStyle: textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        suffixIcon: IconButton(
                          onPressed: onPaste,
                          tooltip: 'Paste from clipboard',
                          icon: const Icon(Icons.content_paste),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16.0), // py-4
                      ),
                      style: textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ), // bg-gradient-to-br from-primary to-primary-container
                      borderRadius: BorderRadius.circular(12.0), // rounded-xl
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ), // shadow-lg shadow-primary/20
                      ],
                    ),
                    child: MaterialButton(
                      onPressed: addingUrls ? null : onAddUrls,
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0), // px-8 py-4
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        children: [
                          addingUrls
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.onPrimary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.add,
                                  color: AppColors.onPrimary,
                                  size: 24,
                                ), // text-on-primary
                          const SizedBox(width: 8), // mr-2
                          Text(
                            addingUrls ? 'Adding...' : 'Add URLs',
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2, // tracking-tight
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
