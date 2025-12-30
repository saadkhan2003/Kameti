import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ota_update/ota_update.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_theme.dart';

class UpdateService {
  // GitHub Releases URL for version.json
  static const String _versionCheckUrl = 
      'https://raw.githubusercontent.com/saadkhan2003/Committee_App/main/version.json';
  
  // Cached APK path for retry without re-download
  static String? _cachedApkPath;
  static String? _cachedVersion;

  // Get the local APK file path
  static Future<String> _getLocalApkPath(String version) async {
    final directory = await getExternalStorageDirectory();
    return '${directory?.path ?? "/storage/emulated/0/Download"}/Committee-$version.apk';
  }

  // Check if APK is already downloaded
  static Future<bool> _isApkCached(String version) async {
    final path = await _getLocalApkPath(version);
    final file = File(path);
    return file.existsSync();
  }

  // Delete cached APK
  static Future<void> clearCachedApk() async {
    if (_cachedApkPath != null) {
      try {
        final file = File(_cachedApkPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Deleted cached APK: $_cachedApkPath');
        }
      } catch (e) {
        debugPrint('Failed to delete cached APK: $e');
      }
      _cachedApkPath = null;
      _cachedVersion = null;
    }
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    // Only check on Android (not web)
    if (kIsWeb) {
      debugPrint('Update check: Skipping on web');
      return;
    }

    try {
      debugPrint('Update check: Starting...');
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      debugPrint('Update check: Current version = $currentVersion');

      // Fetch version info from server
      final response = await http.get(Uri.parse(_versionCheckUrl));
      debugPrint('Update check: Fetched version.json, status = ${response.statusCode}');
      if (response.statusCode != 200) return;

      final versionData = json.decode(response.body);
      final latestVersion = versionData['version'] as String;
      final apkUrl = versionData['apkUrl'] as String;
      final releaseNotes = versionData['releaseNotes'] as String? ?? 'Bug fixes';
      final forceUpdate = versionData['forceUpdate'] as bool? ?? false;
      final minVersion = versionData['minVersion'] as String? ?? '1.0.0';
      debugPrint('Update check: Latest version = $latestVersion, forceUpdate = $forceUpdate');

      // Check if force update is needed (current version is below minimum)
      final isForced = forceUpdate || _isNewerVersion(currentVersion, minVersion);

      // Compare versions
      if (_isNewerVersion(currentVersion, latestVersion)) {
        debugPrint('Update check: Update available! Forced: $isForced');
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, releaseNotes, apkUrl, isForced);
        }
      } else {
        debugPrint('Update check: Already up to date');
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String releaseNotes,
    String apkUrl,
    bool isForced,
  ) async {
    // Check if APK is already cached
    final isCached = await _isApkCached(version);
    if (isCached) {
      _cachedApkPath = await _getLocalApkPath(version);
      _cachedVersion = version;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Update Available', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version $version is available',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              releaseNotes,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            if (isCached) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[400], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Already downloaded',
                      style: TextStyle(color: Colors.green[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isForced)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
          if (isCached)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _retryInstall(context, apkUrl, version);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              icon: const Icon(Icons.install_mobile, size: 18),
              label: const Text('Retry Install'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDownloadProgress(context, apkUrl, version);
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(isForced ? 'Update Required' : 'Update Now'),
            ),
        ],
      ),
    );
  }

  // Retry installation from cached APK
  static void _retryInstall(BuildContext context, String apkUrl, String version) async {
    if (_cachedApkPath == null) {
      _showDownloadProgress(context, apkUrl, version);
      return;
    }

    final file = File(_cachedApkPath!);
    if (!await file.exists()) {
      _showDownloadProgress(context, apkUrl, version);
      return;
    }

    // Show installing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            const SizedBox(height: 20),
            const Text(
              'Opening installer...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'The installer will open. Please tap "Install" when prompted.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Use OTA update to install from local file
    try {
      OtaUpdate().execute('file://${_cachedApkPath!}').listen(
        (event) {
          debugPrint('Retry OTA Status: ${event.status}');
          if (event.status == OtaStatus.INSTALLING && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        onError: (e) {
          debugPrint('Retry install error: $e');
          if (context.mounted) {
            Navigator.of(context).pop();
            _showRetryDialog(context, apkUrl, version, e.toString());
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showRetryDialog(context, apkUrl, version, e.toString());
      }
    }
  }

  // Show retry dialog after failed installation
  static void _showRetryDialog(BuildContext context, String apkUrl, String version, String error) {
    final apkFileName = 'Committee-$version.apk';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Installation Interrupted', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'The update was downloaded but installation was interrupted.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'You have two options:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Tap "Retry Install" below',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '2. Open your file manager, go to Downloads folder, and tap:',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.android, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      apkFileName,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Note: If you see "Package conflicts" error, uninstall the old app first.',
              style: TextStyle(color: Colors.orange[300], fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _retryInstall(context, apkUrl, version);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry Install'),
          ),
        ],
      ),
    );
  }


  static void _showDownloadProgress(BuildContext context, String apkUrl, String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadProgressDialog(
        apkUrl: apkUrl,
        version: version,
        onError: (error) => _showRetryDialog(context, apkUrl, version, error),
        onSuccess: (path) {
          _cachedApkPath = path;
          _cachedVersion = version;
        },
      ),
    );
  }
}

// Stateful widget for download progress
class _DownloadProgressDialog extends StatefulWidget {
  final String apkUrl;
  final String version;
  final Function(String) onError;
  final Function(String) onSuccess;

  const _DownloadProgressDialog({
    required this.apkUrl,
    required this.version,
    required this.onError,
    required this.onSuccess,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = 'Starting download...';
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() async {
    try {
      // Get local path for saving
      final directory = await getExternalStorageDirectory();
      _localPath = '${directory?.path ?? "/storage/emulated/0/Download"}/Committee-${widget.version}.apk';

      OtaUpdate().execute(widget.apkUrl).listen(
        (event) {
          debugPrint('OTA Status: ${event.status}, Value: ${event.value}');
          
          if (!mounted) return;
          
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final progress = double.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _progress = progress / 100;
                _status = 'Downloading... ${progress.toInt()}%';
              });
              // Cache the path when download starts
              if (_localPath != null) {
                widget.onSuccess(_localPath!);
              }
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _progress = 1.0;
                _status = 'Opening installer...';
              });
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) Navigator.of(context).pop();
              });
              break;
            case OtaStatus.DOWNLOAD_ERROR:
              Navigator.of(context).pop();
              widget.onError(event.value ?? 'Download failed');
              break;
            default:
              break;
          }
        },
        onError: (e) {
          debugPrint('OTA Error: $e');
          if (mounted) {
            Navigator.of(context).pop();
            widget.onError(e.toString());
          }
        },
      );
    } catch (e) {
      debugPrint('OTA Exception: $e');
      if (mounted) {
        Navigator.of(context).pop();
        widget.onError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apkFileName = 'Committee-${widget.version}.apk';
    
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.download_rounded,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            _status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Saving as: $apkFileName',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'The installer will open automatically',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
