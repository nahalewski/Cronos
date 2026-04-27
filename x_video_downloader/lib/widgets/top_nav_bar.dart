import 'package:flutter/material.dart';
import 'package:x_video_downloader/theme.dart';

class TopNavBar extends StatelessWidget {
  const TopNavBar({
    super.key,
    this.searchHint = 'Search your library...',
    required this.showBrowserPanel,
    required this.onToggleBrowserPanel,
    this.onMenuPressed,
  });

  final String searchHint;
  final bool showBrowserPanel;
  final VoidCallback onToggleBrowserPanel;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 64, // h-16
      color: AppColors.surfaceContainerLowest, // bg-slate-50/70
      padding: EdgeInsets.only(
        left: onMenuPressed != null ? 8.0 : 32.0,
        right: 32.0,
      ), // px-8
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onMenuPressed != null)
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.secondary),
              onPressed: onMenuPressed,
            ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 448), // max-w-md (16 * 28 = 448)
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8.0), // rounded-lg
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ), // shadow-sm
                ],
                border: Border.all(
                  color: AppColors.onSurface.withValues(alpha: 0.05),
                  width: 1,
                ), // ring-1 ring-on-surface/5
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0), // px-3
                    child: Icon(
                      Icons.search,
                      color: AppColors.onSurfaceVariant,
                      size: 20, // text-lg
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: textTheme.bodyMedium, // text-sm
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: showBrowserPanel ? 'Hide X browser panel' : 'Show X browser panel',
                icon: Icon(
                  showBrowserPanel ? Icons.web_asset_off : Icons.web_asset,
                  color: AppColors.secondary,
                  size: 20,
                ),
                onPressed: onToggleBrowserPanel,
              ),
              IconButton(
                icon: Icon(Icons.help_outline, color: AppColors.secondary, size: 20), // text-[20px]
                onPressed: () {},
              ),
              const SizedBox(width: 16), // space-x-6 (for the buttons)
              IconButton(
                icon: Icon(Icons.account_circle, color: AppColors.secondary, size: 24), // text-[24px]
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
