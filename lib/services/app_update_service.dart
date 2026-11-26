import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppReleaseInfo {
  final String version;
  final String tagName;
  final String releaseNotes;
  final String apkDownloadUrl;
  final String apkFileName;
  final int? apkSizeBytes;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkFileName,
    this.apkSizeBytes,
  });
}

/// Zero-dependency GitHub Releases in-app auto-updater for Android.
class AppUpdateService {
  static const _channel = MethodChannel('app_updater');
  final String repoOwner;
  final String repoName;

  const AppUpdateService({
    required this.repoOwner,
    required this.repoName,
  });

  static const calorieTracker = AppUpdateService(
    repoOwner: 'LucaPezzato',
    repoName: 'calorie-tracker-ai',
  );

  static Future<String> getInstalledVersion() async {
    try {
      final v = await _channel.invokeMethod<String>('getAppVersion');
      if (v != null && v.trim().isNotEmpty) return v.trim();
    } catch (_) {}
    return '0.0.0';
  }

  /// Compares two semantic version strings (e.g. "0.1.19" > "0.1.18").
  static bool isNewerVersion(String remote, String current) {
    List<int> parse(String raw) {
      final clean = raw.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first.split('-').first;
      return clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    }

    final r = parse(remote);
    final c = parse(current);
    final len = r.length > c.length ? r.length : c.length;
    for (int i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  /// Checks GitHub Releases API for a newer APK release.
  Future<AppReleaseInfo?> checkForUpdate() async {
    final installed = await getInstalledVersion();
    final uri = Uri.parse(
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
    );
    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': '$repoName-android-updater',
      },
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] ?? '').toString().trim();
    if (tag.isEmpty || !isNewerVersion(tag, installed)) return null;

    final assets = (data['assets'] as List<dynamic>? ?? []);
    Map<String, dynamic>? apkAsset;
    for (final a in assets) {
      if (a is Map<String, dynamic>) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        if (name.endsWith('.apk')) {
          apkAsset = a;
          break;
        }
      }
    }
    if (apkAsset == null) return null;

    final downloadUrl = (apkAsset['browser_download_url'] ?? '').toString();
    if (downloadUrl.isEmpty) return null;

    return AppReleaseInfo(
      version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
      tagName: tag,
      releaseNotes: (data['body'] ?? '').toString().trim(),
      apkDownloadUrl: downloadUrl,
      apkFileName: (apkAsset['name'] ?? 'update.apk').toString(),
      apkSizeBytes: (apkAsset['size'] as num?)?.toInt(),
    );
  }

  Future<String> _downloadApk(
    AppReleaseInfo release, {
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final updatesDir = Directory(p.join(cacheDir.path, 'updates'));
    if (!updatesDir.existsSync()) {
      await updatesDir.create(recursive: true);
    }
    final apkFile = File(p.join(updatesDir.path, release.apkFileName));

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(release.apkDownloadUrl));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download fallito (HTTP ${response.statusCode})');
      }
      final total = response.contentLength ?? release.apkSizeBytes ?? 0;
      int received = 0;
      final sink = apkFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          final pct = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
          onProgress(pct, received, total);
        }
      } finally {
        await sink.close();
      }
      return apkFile.path;
    } finally {
      client.close();
    }
  }

  Future<String> _triggerInstall(String apkPath) async {
    final res = await _channel.invokeMethod<String>(
      'installApk',
      {'path': apkPath},
    );
    return res ?? 'started';
  }

  Future<void> checkAndPrompt(
    BuildContext context, {
    bool silent = true,
  }) async {
    try {
      final release = await checkForUpdate();
      if (!context.mounted) return;
      if (release == null) {
        if (!silent) {
          final current = await getInstalledVersion();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App già aggiornata (v$current) ✓'),
            ),
          );
        }
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _UpdateDialog(
          service: this,
          release: release,
        ),
      );
    } catch (e) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossibile controllare aggiornamenti: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
          ),
        );
      }
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateService service;
  final AppReleaseInfo release;

  const _UpdateDialog({
    required this.service,
    required this.release,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _downloadedPath;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _error = null;
      _statusText = 'Avvio download...';
    });

    try {
      final path = _downloadedPath ??
          await widget.service._downloadApk(
            widget.release,
            onProgress: (pct, rec, tot) {
              if (!mounted) return;
              final recMb = (rec / (1024 * 1024)).toStringAsFixed(1);
              final totMb =
                  tot > 0 ? ' / ${(tot / (1024 * 1024)).toStringAsFixed(1)} MB' : ' MB';
              setState(() {
                _progress = pct;
                _statusText = 'Download: $recMb$totMb (${(pct * 100).round()}%)';
              });
            },
          );
      _downloadedPath = path;

      if (!mounted) return;
      setState(() => _statusText = 'Apertura installer Android...');
      final result = await widget.service._triggerInstall(path);
      if (!mounted) return;

      if (result == 'needs_permission') {
        setState(() {
          _downloading = false;
          _statusText =
              'Abilita "Consenti da questa origine" e poi tocca di nuovo "Installa APK".';
        });
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      icon: Icon(Symbols.system_update_rounded, color: cs.primary, size: 32),
      title: Text('Nuovo aggiornamento ${widget.release.tagName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.release.releaseNotes.isNotEmpty) ...[
              Text(
                widget.release.releaseNotes
                    .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
                    .replaceAll('**', '')
                    .replaceAll('`', ''),
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 14),
            ],
            if (_downloading || _statusText.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Più tardi'),
          ),
        FilledButton.icon(
          onPressed: _downloading ? null : _startUpdate,
          icon: const Icon(Symbols.download_rounded, size: 18),
          label: Text(_downloadedPath != null ? 'Installa APK' : 'Aggiorna ora'),
        ),
      ],
    );
  }
}
