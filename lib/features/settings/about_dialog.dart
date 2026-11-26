import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/l10n.dart';
import '../../core/update/app_update_service.dart';

/// Диалог «О программе» с проверкой обновлений и их установкой.
Future<void> showAboutAppDialog(
  BuildContext context, {
  AppUpdateService? updateService,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AboutAppDialog(
        service: updateService ?? AppUpdateService(),
      ),
    );

class _AboutAppDialog extends StatefulWidget {
  const _AboutAppDialog({required this.service});

  final AppUpdateService service;

  @override
  State<_AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<_AboutAppDialog> {
  bool _loading = true;
  ReleaseInfo? _latestRelease;
  bool _hasUpdate = false;
  String? _errorMessage;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _downloadSuccess = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final info = await widget.service.checkLatestRelease();
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _loading = false;
          _errorMessage = context.l10n.updateCheckFailed;
        });
        return;
      }

      final hasUpdate = AppUpdateService.isNewer(
        info.version,
        widget.service.currentVersion,
      );

      setState(() {
        _loading = false;
        _latestRelease = info;
        _hasUpdate = hasUpdate;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = context.l10n.updateCheckFailed;
      });
    }
  }

  Future<void> _startUpdate(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _errorMessage = null;
    });

    try {
      final Stream<double> stream;
      switch (widget.service.platform) {
        case UpdatePlatform.appImage:
          stream = widget.service.downloadAndApplyAppImage(url);
          break;
        case UpdatePlatform.windows:
          stream = widget.service.downloadWindowsInstaller(
            url,
            version: _latestRelease?.version,
          );
          break;
        case UpdatePlatform.android:
          stream = widget.service.downloadAndroidApk(url);
          break;
        case UpdatePlatform.other:
          throw StateError('Auto-update is not supported on this platform');
      }

      await for (final progress in stream) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress;
        });
      }
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadSuccess = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Widget _buildRestartOrInstallButton(AppLocalizations l) {
    switch (widget.service.platform) {
      case UpdatePlatform.appImage:
        return FilledButton.icon(
          onPressed: () => widget.service.restartAppImage(),
          icon: const Icon(Icons.restart_alt),
          label: Text(l.restartNow),
        );
      case UpdatePlatform.windows:
        return FilledButton.icon(
          onPressed: () => widget.service.runWindowsInstaller(
            version: _latestRelease?.version,
          ),
          icon: const Icon(Icons.system_update_rounded),
          label: Text(l.installAndRestart),
        );
      case UpdatePlatform.android:
        return FilledButton.icon(
          onPressed: () => widget.service.installAndroidApk(),
          icon: const Icon(Icons.system_update_rounded),
          label: Text(l.installUpdate),
        );
      case UpdatePlatform.other:
        return const SizedBox.shrink();
    }
  }

  String _getSuccessMessage(AppLocalizations l) {
    if (widget.service.platform == UpdatePlatform.android) {
      return l.updateSuccessReady;
    }
    return l.updateSuccessRestart;
  }

  Future<void> _openReleaseUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final downloadUrl = _latestRelease != null
        ? widget.service.getDownloadUrlForCurrentPlatform(_latestRelease!)
        : null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.send_rounded,
            size: 36,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transmitter',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                l.appVersionLabel(widget.service.currentVersion),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l.checkingForUpdates,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isDownloading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.downloadingUpdate((_downloadProgress * 100).toInt()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _downloadProgress.clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_downloadSuccess) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _getSuccessMessage(l),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRestartOrInstallButton(l),
                  ],
                ),
              ),
            ] else if (_hasUpdate && _latestRelease != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.system_update_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.updateAvailable(_latestRelease!.version),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (downloadUrl != null) ...[
                      FilledButton.icon(
                        onPressed: () => _startUpdate(downloadUrl),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l.updateAppAction),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () => _openReleaseUrl(
                          _latestRelease!.releaseUrl,
                        ),
                        icon: const Icon(Icons.open_in_browser),
                        label: Text(l.viewReleaseNotes),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.latestVersionInstalled,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
      actions: [
        if (!_loading && !_isDownloading && !_downloadSuccess)
          TextButton(
            onPressed: _checkForUpdates,
            child: Text(l.checkForUpdates),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
      ],
    );
  }
}
