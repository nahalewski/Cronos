import 'package:flutter/material.dart';
import 'package:x_video_downloader/theme.dart';

enum AppSection { dashboard, library, photos, player, downloads, music, settings }

class SideNavBar extends StatelessWidget {
  const SideNavBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: AppColors.surfaceContainerLowest, // bg-slate-50/70
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cronos',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  'The Digital Curator',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 2.0, // tracking-widest
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavLink(
                  context,
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  isActive: selected == AppSection.dashboard,
                  onTap: () => onSelect(AppSection.dashboard),
                ),
                _buildNavLink(
                  context,
                  icon: Icons.video_library,
                  label: 'Library',
                  isActive: selected == AppSection.library,
                  onTap: () => onSelect(AppSection.library),
                ),
                _buildNavLink(
                  context,
                  icon: Icons.photo_library,
                  label: 'Photos',
                  isActive: selected == AppSection.photos,
                  onTap: () => onSelect(AppSection.photos),
                ),
                _buildNavLink(
                  context,
                  icon: Icons.ondemand_video,
                  label: 'Player',
                  isActive: selected == AppSection.player,
                  onTap: () => onSelect(AppSection.player),
                ),
                _buildNavLink(
                  context,
                  icon: Icons.download,
                  label: 'Downloads',
                  isActive: selected == AppSection.downloads,
                  onTap: () => onSelect(AppSection.downloads),
                ),
                _buildNavLink(
                  context,
                  icon: Icons.music_note,
                  label: 'Music',
                  isActive: selected == AppSection.music,
                  onTap: () => onSelect(AppSection.music),
                ),
                _buildNavLink(
                  context,
                  icon: Icons.settings,
                  label: 'Settings',
                  isActive: selected == AppSection.settings,
                  onTap: () => onSelect(AppSection.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
        hoverColor: isActive
            ? AppColors.surfaceContainerHigh.withValues(alpha: 0.5)
            : AppColors.surfaceContainerLow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.0), // rounded-lg
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.surfaceContainerHighest.withValues(alpha: 0.5) // bg-slate-200/50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0), // rounded-lg
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0), // px-3 py-2.5
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? colorScheme.primary : AppColors.secondary, // text-blue-700 / text-slate-600
                  size: 22, // text-[22px]
                ),
                const SizedBox(width: 12), // mr-3
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color: isActive ? colorScheme.primary : AppColors.secondary, // text-blue-700 / text-slate-600
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    letterSpacing: -0.2, // tracking-tight
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
