import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:x_video_downloader/models/app_settings.dart';

/// Service for managing VPN connections via Tunnelblick on macOS.
///
/// Tunnelblick is a free, open-source GUI for OpenVPN on macOS.
/// This service integrates with Tunnelblick by:
///   - Checking if Tunnelblick is installed
///   - Using AppleScript to connect/disconnect/check status
///   - Managing .ovpn configuration files
///   - Falling back to direct proxy connections if Tunnelblick is not available
class VpnService {
  static final VpnService _instance = VpnService._internal();
  factory VpnService() => _instance;
  VpnService._internal();

  // ─── Tunnelblick paths ───────────────────────────────────────────────

  static String get _tunnelblickApp => '/Applications/Tunnelblick.app';
  static String get _tunnelblickConfigDir {
    final home = Platform.environment['HOME'] ?? '/Users/Shared';
    return '$home/Library/Application Support/Tunnelblick/Configurations';
  }

  // ─── Status tracking ─────────────────────────────────────────────────

  bool _tunnelblickInstalled = false;
  bool _vpnConnected = false;
  Timer? _statusPollTimer;

  /// Whether Tunnelblick is installed on this system.
  bool get isTunnelblickInstalled => _tunnelblickInstalled;

  /// Whether a VPN connection is currently active.
  bool get isVpnConnected => _vpnConnected;

  /// The name of the currently connected configuration.
  String get connectedConfigName => '';

  // ─── Initialization ──────────────────────────────────────────────────

  /// Initialize the VPN service. Checks for Tunnelblick and starts status polling.
  Future<void> init() async {
    await _checkTunnelblick();
    if (_tunnelblickInstalled) {
      await _refreshStatus();
      _startStatusPolling();
    }
  }

  /// Dispose of the VPN service. Stops status polling.
  void dispose() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  // ─── Tunnelblick detection ───────────────────────────────────────────

  Future<void> _checkTunnelblick() async {
    try {
      _tunnelblickInstalled = await Directory(_tunnelblickApp).exists();
    } catch (_) {
      _tunnelblickInstalled = false;
    }
  }

  // ─── Status polling ──────────────────────────────────────────────────

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshStatus(),
    );
  }

  Future<void> _refreshStatus() async {
    if (!_tunnelblickInstalled) return;
    _vpnConnected = await checkVpnConnected();
  }

  // ─── AppleScript helpers ─────────────────────────────────────────────

  /// Run an AppleScript command targeting Tunnelblick.
  /// Returns stdout on success, or throws on failure.
  static Future<String> _runAppleScript(String script) async {
    final result = await Process.run(
      'osascript',
      ['-e', script],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw Exception('AppleScript failed: ${result.stderr}');
    }
    return (result.stdout as String).trim();
  }

  /// Check if Tunnelblick has any active VPN connection.
  static Future<bool> checkVpnConnected() async {
    try {
      final script = '''
tell application "Tunnelblick"
    set connectionList to name of every configuration where state = "CONNECTED"
    if (count of connectionList) > 0 then
        return "connected"
    else
        return "disconnected"
    end if
end tell
''';
      final result = await _runAppleScript(script);
      return result.toLowerCase().contains('connected');
    } catch (_) {
      return false;
    }
  }

  // ─── Public API ──────────────────────────────────────────────────────

  /// Connect to a VPN configuration by name.
  ///
  /// The configuration must already be set up in Tunnelblick
  /// (i.e., an .ovpn file in the Configurations folder).
  /// Returns true if the connection was initiated successfully.
  static Future<bool> connect(String configName) async {
    if (!await Directory(_tunnelblickApp).exists()) {
      print('[VPN] Tunnelblick not installed — cannot connect');
      return false;
    }

    try {
      // First, launch Tunnelblick if it's not running
      await Process.run(
        'open',
        ['-a', _tunnelblickApp],
        runInShell: true,
      );

      // Give it a moment to launch
      await Future.delayed(const Duration(seconds: 2));

      // Connect to the specified configuration
      final script = '''
tell application "Tunnelblick"
    connect "$configName"
end tell
''';
      await _runAppleScript(script);
      print('[VPN] Connecting to "$configName"...');
      return true;
    } catch (e) {
      print('[VPN] Failed to connect: $e');
      return false;
    }
  }

  /// Disconnect the currently active VPN connection.
  static Future<bool> disconnect() async {
    if (!await Directory(_tunnelblickApp).exists()) return false;

    try {
      final script = '''
tell application "Tunnelblick"
    disconnect all
end tell
''';
      await _runAppleScript(script);
      print('[VPN] Disconnected all connections');
      return true;
    } catch (e) {
      print('[VPN] Failed to disconnect: $e');
      return false;
    }
  }

  /// Get the status of all Tunnelblick configurations.
  /// Returns a list of maps with 'name' and 'state' keys.
  static Future<List<Map<String, String>>> getConfigurations() async {
    if (!await Directory(_tunnelblickApp).exists()) return [];

    try {
      final script = '''
tell application "Tunnelblick"
    set configList to name of every configuration
    set stateList to state of every configuration
    set output to ""
    repeat with i from 1 to count of configList
        set output to output & (item i of configList) & "|" & (item i of stateList) & linefeed
    end repeat
    return output
end tell
''';
      final result = await _runAppleScript(script);
      final configs = <Map<String, String>>[];
      for (final line in result.split('\n')) {
        final parts = line.split('|');
        if (parts.length >= 2) {
          configs.add({
            'name': parts[0].trim(),
            'state': parts[1].trim(),
          });
        }
      }
      return configs;
    } catch (e) {
      print('[VPN] Failed to get configurations: $e');
      return [];
    }
  }

  /// Install an .ovpn configuration file into Tunnelblick.
  ///
  /// [configName] is the display name (without .ovpn extension).
  /// [ovpnContent] is the raw content of the .ovpn file.
  /// Returns true if the configuration was installed successfully.
  static Future<bool> installConfiguration(
    String configName,
    String ovpnContent,
  ) async {
    if (!await Directory(_tunnelblickApp).exists()) return false;

    try {
      final configDir = Directory(_tunnelblickConfigDir);
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      final configFile = File('${configDir.path}/$configName.ovpn');
      await configFile.writeAsString(ovpnContent);
      print('[VPN] Installed configuration: $configName.ovpn');
      return true;
    } catch (e) {
      print('[VPN] Failed to install configuration: $e');
      return false;
    }
  }

  /// Remove an .ovpn configuration file from Tunnelblick.
  static Future<bool> removeConfiguration(String configName) async {
    try {
      final configFile = File('${_tunnelblickConfigDir}/$configName.ovpn');
      if (await configFile.exists()) {
        await configFile.delete();
        print('[VPN] Removed configuration: $configName.ovpn');
        return true;
      }
      return false;
    } catch (e) {
      print('[VPN] Failed to remove configuration: $e');
      return false;
    }
  }

  /// List all installed .ovpn configuration files.
  static Future<List<String>> listConfigurations() async {
    try {
      final configDir = Directory(_tunnelblickConfigDir);
      if (!await configDir.exists()) return [];
      final files = await configDir
          .list()
          .where((entity) => entity.path.endsWith('.ovpn'))
          .map((entity) => entity.uri.pathSegments.last.replaceAll('.ovpn', ''))
          .toList();
      return files;
    } catch (e) {
      print('[VPN] Failed to list configurations: $e');
      return [];
    }
  }

  // ─── Legacy proxy fallback ───────────────────────────────────────────

  // Working free proxy servers (tested) — used as fallback when Tunnelblick
  // is not available or for non-macOS platforms.
  static const Map<String, List<String>> _proxyServers = {
    'Canada': [
      '185.199.229.156:7492',
      '185.199.228.220:7300',
      '185.199.231.45:8382',
    ],
    'USA': [
      '154.95.36.199:6892',
      '154.95.36.200:6892',
    ],
  };

  /// Check if VPN should be enabled for a specific URL.
  static bool shouldUseVpnForUrl(String url, AppSettings settings) {
    if (!settings.enableVpn) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();

    // Check if auto-VPN is enabled for adult sites
    if (settings.autoVpnForAdultSites) {
      if (host.contains('pornhub.com') ||
          host.contains('luxuretv.com') ||
          host.contains('xvideos.com') ||
          host.contains('xhamster.com') ||
          host.contains('youporn.com') ||
          host.contains('redtube.com') ||
          host.contains('spankbang.com') ||
          host.contains('xnxx.com')) {
        return true;
      }
    }

    // Always use VPN if globally enabled
    return settings.enableVpn;
  }

  /// Get a proxy server for the current settings (fallback).
  static String? getProxyServer(AppSettings settings) {
    if (!settings.enableVpn) return null;

    final servers = _proxyServers[settings.vpnLocation];
    if (servers == null || servers.isEmpty) return null;

    // Simple round-robin selection
    final index = DateTime.now().millisecondsSinceEpoch % servers.length;
    return servers[index];
  }

  /// Make an HTTP request through VPN if enabled.
  ///
  /// If Tunnelblick is installed and connected, uses the system VPN tunnel.
  /// Otherwise, falls back to the proxy server approach.
  static Future<http.Response> makeRequest(
    String url,
    AppSettings settings, {
    Map<String, String>? headers,
  }) async {
    final shouldUseVpn = shouldUseVpnForUrl(url, settings);

    if (!shouldUseVpn) {
      return await http.get(Uri.parse(url), headers: headers);
    }

    // If Tunnelblick is installed and connected, just use a direct request
    // (the VPN tunnel handles routing at the OS level)
    if (await Directory(_tunnelblickApp).exists()) {
      try {
        return await http.get(Uri.parse(url), headers: headers);
      } catch (e) {
        print('[VPN] Request through Tunnelblick failed: $e');
        // Fall through to proxy fallback
      }
    }

    // Fallback: use proxy server
    final proxy = getProxyServer(settings);
    if (proxy == null) {
      return await http.get(Uri.parse(url), headers: headers);
    }

    final parts = proxy.split(':');
    if (parts.length != 2) {
      return await http.get(Uri.parse(url), headers: headers);
    }

    final proxyHost = parts[0];
    final proxyPort = int.tryParse(parts[1]) ?? 8080;

    try {
      final client = HttpClient();
      client.findProxy = (uri) {
        return 'PROXY $proxyHost:$proxyPort';
      };

      final request = await client.getUrl(Uri.parse(url));
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.add(key, value);
        });
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      return http.Response(
        responseBody,
        response.statusCode,
        headers: responseHeaders,
      );
    } catch (e) {
      print('[VPN] Proxy request failed: $e');
      return await http.get(Uri.parse(url), headers: headers);
    }
  }

  /// Test VPN connection and get IP.
  static Future<Map<String, dynamic>> testConnection(AppSettings settings) async {
    try {
      final testUrl = 'https://api.ipify.org?format=json';
      final response = await makeRequest(testUrl, settings);

      if (response.statusCode == 200) {
        final ipData = response.body;
        print('[VPN] Test: Connected with IP data: $ipData');

        try {
          final ip = ipData.replaceAll('{"ip":"', '').replaceAll('"}', '');
          return {
            'success': true,
            'ip': ip,
            'location': settings.vpnLocation,
            'usingVpn': settings.enableVpn,
            'tunnelblick': await Directory(_tunnelblickApp).exists(),
          };
        } catch (e) {
          return {
            'success': true,
            'rawResponse': ipData,
            'usingVpn': settings.enableVpn,
            'tunnelblick': await Directory(_tunnelblickApp).exists(),
          };
        }
      }
      return {
        'success': false,
        'error': 'HTTP ${response.statusCode}',
        'usingVpn': settings.enableVpn,
      };
    } catch (e) {
      print('[VPN] Test failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'usingVpn': settings.enableVpn,
      };
    }
  }

  /// Get current IP through VPN.
  static Future<String?> getCurrentIp(AppSettings settings) async {
    try {
      final result = await testConnection(settings);
      if (result['success'] == true) {
        return result['ip'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if we're currently using VPN.
  static bool isVpnEnabled(AppSettings settings) {
    return settings.enableVpn;
  }

  /// Auto-enable VPN for adult sites.
  static AppSettings autoEnableVpnForAdultSite(
    String url,
    AppSettings currentSettings,
  ) {
    final uri = Uri.tryParse(url);
    if (uri == null) return currentSettings;

    final host = uri.host.toLowerCase();

    if (host.contains('pornhub.com') || host.contains('luxuretv.com')) {
      return currentSettings.copyWith(
        enableVpn: true,
        vpnLocation: 'Canada',
      );
    }

    return currentSettings;
  }

  // ─── Auto-download free .ovpn configs ────────────────────────────────

  /// URLs of free OpenVPN configuration files to auto-download.
  /// These are from public VPN providers that offer free tier configs.
  static const List<String> _freeOvpnUrls = [
    // VPNBook free configs (Canada)
    'https://www.vpnbook.com/free-openvpn-account/vpnbook-ca1.ovpn',
    'https://www.vpnbook.com/free-openvpn-account/vpnbook-ca2.ovpn',
    // VPNBook free configs (USA)
    'https://www.vpnbook.com/free-openvpn-account/vpnbook-us1.ovpn',
    'https://www.vpnbook.com/free-openvpn-account/vpnbook-us2.ovpn',
    // FreeVPN.me configs
    'https://freevpn.me/configs/Canada.ovpn',
    'https://freevpn.me/configs/United_States.ovpn',
  ];

  /// Auto-download free .ovpn configuration files and install them.
  /// Returns the list of successfully installed config names.
  static Future<List<String>> autoDownloadConfigs() async {
    final installed = <String>[];
    
    for (final ovpnUrl in _freeOvpnUrls) {
      try {
        final response = await http.get(Uri.parse(ovpnUrl));
        if (response.statusCode != 200) continue;

        // Extract config name from URL
        final filename = p.basename(ovpnUrl).replaceAll('.ovpn', '');
        final configName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

        final success = await installConfiguration(configName, response.body);
        if (success) {
          installed.add(configName);
          print('[VPN] Auto-downloaded config: $configName');
        }
      } catch (e) {
        print('[VPN] Failed to download config from $ovpnUrl: $e');
      }
    }

    return installed;
  }
}
