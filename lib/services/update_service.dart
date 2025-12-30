import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_theme.dart';

class UpdateService {
  // GitHub Releases URL for version.json
  static const String _versionCheckUrl = 
      'https://raw.githubusercontent.com/saadkhan2003/Committee_App/main/version.json';

  // Get the local APK file path in app's external storage
  static Future<String> _getLocalApkPath(String version) async {
    final directory = await getExternalStorageDirectory();
    return '${directory?.path}/Committee-$version.apk';
  }

  // Check if APK is already downloaded
  static Future<bool> _isApkCached(String version) async {
    try {
      final path = await _getLocalApkPath(version);
      final file = File(path);
      final exists = await file.exists();
      if (exists) {
        // Check file size is reasonable (> 10MB)
        final size = await file.length();
        debugPrint('Cached APK found: $path (${(size / 1024 / 1024).toStringAsFixed(1)} MB)');
        return size > 10 * 1024 * 1024;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking cached APK: $e');
      return false;
    }
  }

  // Delete cached APK
  static Future<void> clearCachedApk(String version) async {
    try {
      final path = await _getLocalApkPath(version);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted cached APK: $path');
      }
    } catch (e) {
      debugPrint('Failed to delete cached APK: $e');
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
    final apkFileName = 'Committee-$version.apk';

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
              onPressed: () async {
                Navigator.pop(context);
                await _installFromCache(context, version, apkUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              icon: const Icon(Icons.install_mobile, size: 18),
              label: const Text('Install Now'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDownloadProgress(context, apkUrl, version);
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(isForced ? 'Update Required' : 'Download Update'),
            ),
        ],
      ),
    );
  }

  // Install from cached APK
  static Future<void> _installFromCache(BuildContext context, String version, String apkUrl) async {
    final path = await _getLocalApkPath(version);
    final file = File(path);
    
    if (!await file.exists()) {
      // File was deleted, re-download
      if (context.mounted) {
        _showDownloadProgress(context, apkUrl, version);
      }
      return;
    }

    // Show installing dialog
    if (!context.mounted) return;
    
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
              'Tap "Install" when prompted.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Try to install using Android intent
    try {
      // Use url_launcher to open the APK file
      final uri = Uri.parse('file://$path');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: show manual install instructions
        if (context.mounted) {
          Navigator.of(context).pop();
          _showManualInstallDialog(context, version, apkUrl);
        }
        return;
      }
      
      // Close dialog after a delay
      await Future.delayed(const Duration(seconds: 1));
      if (context.mounted) {
        Navigator.of(context).pop();
        _showPostInstallDialog(context, version, apkUrl);
      }
    } catch (e) {
      debugPrint('Install error: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _showManualInstallDialog(context, version, apkUrl);
      }
    }
  }

  // Show dialog after installation attempt
  static void _showPostInstallDialog(BuildContext context, String version, String apkUrl) {
    final apkFileName = 'Committee-$version.apk';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Installation Started', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'If installation failed or was interrupted:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              '1. Tap "Retry Install" below',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '2. Or open File Manager → Android → data → com.committee.committee_app → files',
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
            onPressed: () async {
              Navigator.pop(context);
              await _installFromCache(context, version, apkUrl);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry Install'),
          ),
        ],
      ),
    );
  }

  // Show manual install instructions
  static void _showManualInstallDialog(BuildContext context, String version, String apkUrl) {
    final apkFileName = 'Committee-$version.apk';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Manual Installation', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.folder_open, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            const Text(
              'The update is downloaded. Install manually:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              '1. Open your File Manager app',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            Text(
              '2. Go to: Android → data → com.committee.committee_app → files',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            Text(
              '3. Tap on the APK file to install:',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.android, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    apkFileName,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'If "Package conflicts" error shows, uninstall the old app first.',
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
            onPressed: () async {
              Navigator.pop(context);
              // Try to open file manager
              final uri = Uri.parse('content://com.android.externalstorage.documents/document/primary');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Open Files'),
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
        onComplete: (path) async {
          if (context.mounted) {
            await _installFromCache(context, version, apkUrl);
          }
        },
        onError: (error) {
          if (context.mounted) {
            _showDownloadErrorDialog(context, apkUrl, version, error);
          }
        },
      ),
    );
  }

  // Show download error dialog
  static void _showDownloadErrorDialog(BuildContext context, String apkUrl, String version, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Download Failed', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Failed to download the update. Please check your internet connection.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $error',
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showDownloadProgress(context, apkUrl, version);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(apkUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('Browser'),
          ),
        ],
      ),
    );
  }
}

// Stateful widget for download progress with manual HTTP download
class _DownloadProgressDialog extends StatefulWidget {
  final String apkUrl;
  final String version;
  final Function(String) onComplete;
  final Function(String) onError;

  const _DownloadProgressDialog({
    required this.apkUrl,
    required this.version,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = 'Connecting...';
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  bool _isDownloading = true;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() async {
    try {
      final localPath = await UpdateService._getLocalApkPath(widget.version);
      final file = File(localPath);
      
      debugPrint('Downloading APK to: $localPath');
      
      // Create HTTP client for streaming download
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.apkUrl));
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      _totalBytes = response.contentLength ?? 0;
      _downloadedBytes = 0;
      
      // Open file for writing
      final sink = file.openWrite();
      
      await for (final chunk in response.stream) {
        if (!_isDownloading) break;
        
        sink.add(chunk);
        _downloadedBytes += chunk.length;
        
        if (mounted) {
          setState(() {
            if (_totalBytes > 0) {
              _progress = _downloadedBytes / _totalBytes;
              final mbDownloaded = (_downloadedBytes / 1024 / 1024).toStringAsFixed(1);
              final mbTotal = (_totalBytes / 1024 / 1024).toStringAsFixed(1);
              _status = 'Downloading... $mbDownloaded / $mbTotal MB';
            } else {
              final mbDownloaded = (_downloadedBytes / 1024 / 1024).toStringAsFixed(1);
              _status = 'Downloading... $mbDownloaded MB';
            }
          });
        }
      }
      
      await sink.close();
      client.close();
      
      if (!_isDownloading) return;
      
      // Verify file was downloaded
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('Download complete: ${(size / 1024 / 1024).toStringAsFixed(1)} MB');
        
        if (mounted) {
          Navigator.of(context).pop();
          widget.onComplete(localPath);
        }
      } else {
        throw Exception('File not saved');
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        Navigator.of(context).pop();
        widget.onError(e.toString());
      }
    }
  }

  @override
  void dispose() {
    _isDownloading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apkFileName = 'Committee-${widget.version}.apk';
    final percentText = _totalBytes > 0 ? '${(_progress * 100).toInt()}%' : '';
    
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
          if (percentText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              percentText,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
        ],
      ),
    );
  }
}
