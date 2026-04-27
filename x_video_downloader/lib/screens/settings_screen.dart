import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:x_video_downloader/models/app_settings.dart';
import 'package:x_video_downloader/services/vpn_service.dart';
import 'package:x_video_downloader/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onBrowserIntegrationChanged,
    required this.onDesktopNotificationsChanged,
    required this.onPickDownloadDirectory,
    required this.onPickPhotoDirectory,
    required this.onPickXVideoDirectory,
    required this.onPickYoutubeVideoDirectory,
    required this.onPickYoutubeMp3Directory,
    required this.onPickXvideosDirectory,
    required this.onPickXhamsterDirectory,
    required this.onPickHentaihavenDirectory,
    required this.onPickHanimeDirectory,
    required this.onPickRule34videoDirectory,
    required this.onUnifiedFolderToggle,
    required this.onPickUnifiedDirectory,
    required this.onMigrateInternalDownloads,
    required this.onEnableVpnChanged,
    required this.onAutoVpnForAdultSitesChanged,
    required this.onVpnLocationChanged,
  });

  final AppSettings settings;
  final ValueChanged<bool> onBrowserIntegrationChanged;
  final ValueChanged<bool> onDesktopNotificationsChanged;
  final VoidCallback onPickDownloadDirectory;
  final VoidCallback onPickPhotoDirectory;
  final VoidCallback onPickXVideoDirectory;
  final VoidCallback onPickYoutubeVideoDirectory;
  final VoidCallback onPickYoutubeMp3Directory;
  final VoidCallback onPickXvideosDirectory;
  final VoidCallback onPickXhamsterDirectory;
  final VoidCallback onPickHentaihavenDirectory;
  final VoidCallback onPickHanimeDirectory;
  final VoidCallback onPickRule34videoDirectory;
  final ValueChanged<bool> onUnifiedFolderToggle;
  final VoidCallback onPickUnifiedDirectory;
  final VoidCallback onMigrateInternalDownloads;
  final ValueChanged<bool> onEnableVpnChanged;
  final ValueChanged<bool> onAutoVpnForAdultSitesChanged;
  final ValueChanged<String> onVpnLocationChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _tunnelblickInstalled = false;
  bool _vpnConnected = false;
  bool _connecting = false;
  List<Map<String, String>> _tunnelblickConfigs = [];
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkTunnelblick();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkTunnelblick() async {
    final installed = await Directory('/Applications/Tunnelblick.app').exists();
    setState(() => _tunnelblickInstalled = installed);
    if (installed) {
      await _refreshVpnStatus();
      _statusTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _refreshVpnStatus(),
      );
    }
  }

  Future<void> _refreshVpnStatus() async {
    final connected = await VpnService.checkVpnConnected();
    final configs = await VpnService.getConfigurations();
    if (mounted) {
      setState(() {
        _vpnConnected = connected;
        _tunnelblickConfigs = configs;
      });
    }
  }

  Future<void> _toggleVpn() async {
    setState(() => _connecting = true);
    try {
      if (_vpnConnected) {
        await VpnService.disconnect();
      } else {
        // Connect to the first available configuration, or prompt user
        if (_tunnelblickConfigs.isNotEmpty) {
          await VpnService.connect(_tunnelblickConfigs.first['name']!);
        }
      }
      await Future.delayed(const Duration(seconds: 2));
      await _refreshVpnStatus();
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _importOvpnConfig() async {
    try {
      // Use file picker to select .ovpn file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ovpn'],
      );
      if (result == null || result.files.isEmpty) return;
      
      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final configName = result.files.first.name.replaceAll('.ovpn', '');
      
      final success = await VpnService.installConfiguration(configName, content);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported VPN config: $configName')),
          );
          await _refreshVpnStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import VPN config')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing config: $e')),
        );
      }
    }
  }

  Future<void> _autoDownloadOvpnConfigs() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading free VPN configs...')),
    );
    try {
      final installed = await VpnService.autoDownloadConfigs();
      if (mounted) {
        if (installed.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded ${installed.length} VPN config(s): ${installed.join(", ")}')),
          );
          await _refreshVpnStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No configs could be downloaded. Check your internet connection.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading configs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = widget.settings;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure folders and storage for your video collection.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _panel(
            title: 'Storage & Library',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _toggleRow(
                  'Unified Download Mode',
                  'One folder for all sites (auto-organized)',
                  s.useUnifiedFolder,
                  widget.onUnifiedFolderToggle,
                ),
                const SizedBox(height: 16),
                if (s.useUnifiedFolder) ...[
                  _folderRow(
                    label: 'ROOT DOWNLOAD FOLDER',
                    value: s.unifiedDownloadDirectory ?? 'Pick a root folder for all site subfolders',
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickUnifiedDirectory,
                  ),
                  const SizedBox(height: 12),
                  _folderRow(
                    label: 'PHOTO FOLDER',
                    value: s.photoDownloadDirectory ??
                        ((s.unifiedDownloadDirectory?.isNotEmpty == true)
                            ? '${s.unifiedDownloadDirectory!}/photos'
                            : 'Uses Root Folder/photos'),
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickPhotoDirectory,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Videos will be saved to subfolders like /X, /YouTube, etc.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onMigrateInternalDownloads,
                      icon: const Icon(Icons.sync_alt, size: 18),
                      label: const Text('Move Internal Videos to SD Card'),
                    ),
                  ),
                ] else ...[
                  _folderRow(
                    label: 'LIBRARY FOLDER (DEFAULT)',
                    value: s.downloadDirectory ??
                        'Using default Downloads/X Downloads folder',
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickDownloadDirectory,
                  ),
                  const SizedBox(height: 12),
                  _folderRow(
                    label: 'PHOTO FOLDER',
                    value: s.photoDownloadDirectory ??
                        ((s.downloadDirectory?.isNotEmpty == true)
                            ? '${s.downloadDirectory!}/photos'
                            : 'Uses Library Folder/photos'),
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickPhotoDirectory,
                  ),
                  const SizedBox(height: 12),
                  _folderRow(
                    label: 'X/TWITTER VIDEO FOLDER',
                    value: s.xVideoDownloadDirectory ?? s.downloadDirectory ?? 'Uses Library Folder',
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickXVideoDirectory,
                  ),
                  const SizedBox(height: 12),
                  _folderRow(
                    label: 'YOUTUBE VIDEO FOLDER',
                    value: s.youtubeVideoDownloadDirectory ??
                        s.downloadDirectory ??
                        'Uses Library Folder',
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickYoutubeVideoDirectory,
                  ),
                  const SizedBox(height: 12),
                  _folderRow(
                    label: 'YOUTUBE MP3 FOLDER',
                    value: s.youtubeMp3DownloadDirectory ??
                        s.youtubeVideoDownloadDirectory ??
                        s.downloadDirectory ??
                        'Uses Library Folder',
                    enabled: Platform.isMacOS || Platform.isAndroid,
                    onPick: widget.onPickYoutubeMp3Directory,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            title: 'Integration & Behavior',
            child: Column(
              children: [
                _toggleRow(
                  'Auto-Detect Videos',
                  'Automatically detect video links while browsing all sites',
                  s.browserIntegration,
                  widget.onBrowserIntegrationChanged,
                ),
                _toggleRow(
                  'Desktop Notifications',
                  'Alert when downloads finish',
                  s.desktopNotifications,
                  widget.onDesktopNotificationsChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            title: 'Privacy & VPN',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _toggleRow(
                  'Enable VPN for App',
                  'Route all app network traffic through VPN (Canada location)',
                  s.enableVpn,
                  widget.onEnableVpnChanged,
                ),
                if (s.enableVpn) ...[
                  const SizedBox(height: 8),
                  _toggleRow(
                    'Auto-VPN for Adult Sites',
                    'Automatically enable VPN when visiting pornhub.com or luxuretv.com',
                    s.autoVpnForAdultSites,
                    widget.onAutoVpnForAdultSitesChanged,
                  ),
                  const SizedBox(height: 16),
                  _DropdownRow(
                    label: 'VPN LOCATION',
                    value: s.vpnLocation,
                    options: const ['Canada', 'USA', 'Germany', 'Netherlands', 'Japan', 'Singapore'],
                    onChanged: widget.onVpnLocationChanged,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'VPN routes only this app\'s traffic. Free service with Canadian servers.',
                    style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  // ── Tunnelblick Integration ──
                  if (Platform.isMacOS) ...[
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.surfaceContainerHigh),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _tunnelblickInstalled ? Icons.check_circle : Icons.info_outline,
                          size: 18,
                          color: _tunnelblickInstalled
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _tunnelblickInstalled
                              ? 'Tunnelblick detected'
                              : 'Tunnelblick not installed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _tunnelblickInstalled
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (!_tunnelblickInstalled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Install Tunnelblick from tunnelblick.net for real OpenVPN support.\n'
                        'Without it, the app uses free proxy servers (limited locations).',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                    if (_tunnelblickInstalled) ...[
                      const SizedBox(height: 12),
                      // Connection status
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _vpnConnected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _vpnConnected
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : AppColors.surfaceContainerHigh,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _vpnConnected ? AppColors.primary : AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _vpnConnected
                                    ? 'VPN Connected'
                                    : 'VPN Disconnected',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _vpnConnected
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_connecting)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              FilledButton.tonal(
                                onPressed: _tunnelblickConfigs.isNotEmpty ? _toggleVpn : null,
                                child: Text(_vpnConnected ? 'Disconnect' : 'Connect'),
                              ),
                          ],
                        ),
                      ),
                      // Configurations list
                      if (_tunnelblickConfigs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'CONFIGURATIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ..._tunnelblickConfigs.map((config) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                config['state'] == 'CONNECTED'
                                    ? Icons.link
                                    : Icons.link_off,
                                size: 14,
                                color: config['state'] == 'CONNECTED'
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                config['name'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const Spacer(),
                              Text(
                                config['state'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: config['state'] == 'CONNECTED'
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'No VPN configurations found. Import an .ovpn file to get started.',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _importOvpnConfig,
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('Import .ovpn Configuration'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _autoDownloadOvpnConfigs,
                          icon: const Icon(Icons.cloud_download_outlined, size: 18),
                          label: const Text('Auto-Download Free VPN Configs'),
                        ),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Changes are saved automatically',
              style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _folderRow({
    required String label,
    required String value,
    required bool enabled,
    required VoidCallback onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: enabled ? onPick : null,
              child: const Text('Change...'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panel({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(borderSide: BorderSide.none),
          ),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
