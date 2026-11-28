import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'offline_package.dart';
import 'offline_package_manager.dart';

class PackageDownloadScreen extends StatefulWidget {
  final OfflinePackageManifest manifest;

  const PackageDownloadScreen({
    super.key,
    required this.manifest,
  });

  @override
  State<PackageDownloadScreen> createState() =>
      _PackageDownloadScreenState();
}

class _PackageDownloadScreenState extends State<PackageDownloadScreen> {
  final OfflinePackageManager _manager = OfflinePackageManager();
  OfflinePackageState _state = const OfflinePackageState.initial();
  bool _checking = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPackage();
  }

  Future<void> _checkExistingPackage() async {
    final ready = await _manager.isReady(widget.manifest);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _state = ready
          ? const OfflinePackageState(
              status: OfflinePackageStatus.ready,
              downloadedBytes: 0,
              totalBytes: 0,
              message: 'Siap offline',
            )
          : const OfflinePackageState.initial();
    });
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _state = OfflinePackageState(
        status: OfflinePackageStatus.preparing,
        downloadedBytes: 0,
        totalBytes: widget.manifest.estimatedBytes,
        message: 'Memeriksa penyimpanan...',
      );
    });
    await _manager.download(
      manifest: widget.manifest,
      onState: (state) {
        if (!mounted) return;
        setState(() {
          _state = state;
          _isDownloading =
              state.status == OfflinePackageStatus.downloading ||
              state.status == OfflinePackageStatus.preparing ||
              state.status == OfflinePackageStatus.validating;
        });
      },
    );
  }

  void _cancelDownload() {
    _manager.cancel();
  }

  Future<void> _deletePackage() async {
    final deleted = await _manager.delete(widget.manifest);
    if (!mounted) return;
    setState(() {
      _state = deleted
          ? const OfflinePackageState.initial()
          : const OfflinePackageState(
              status: OfflinePackageStatus.failed,
              downloadedBytes: 0,
              totalBytes: 0,
              message: 'Paket gagal dihapus.',
            );
    });
  }

  Future<void> _openStorageSettings() async {
    await _manager.openStorageSettings();
  }

  String get _statusTitle {
    switch (_state.status) {
      case OfflinePackageStatus.ready:
        return 'Siap offline';
      case OfflinePackageStatus.downloading:
        return 'Mengunduh paket';
      case OfflinePackageStatus.preparing:
        return 'Menyiapkan';
      case OfflinePackageStatus.validating:
        return 'Memvalidasi paket';
      case OfflinePackageStatus.failed:
        return 'Unduhan gagal';
      case OfflinePackageStatus.corrupt:
        return 'Paket rusak';
      case OfflinePackageStatus.notDownloaded:
        return 'Belum diunduh';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _state.status == OfflinePackageStatus.ready;
    final canDownload = !_checking &&
        !_isDownloading &&
        !isReady;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unduh Paket'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.tonal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.landscape_rounded,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.manifest.areaName,
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ukuran paket: ${widget.manifest.estimatedSizeLabel}',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Daftar isi',
                    style: AppTypography.label,
                  ),
                  const SizedBox(height: 8),
                  for (final file in widget.manifest.files)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: AppColors.primaryText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${file.name} - '
                              '${OfflinePackageManifest.formatBytes(file.sizeBytes)}',
                              style: AppTypography.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _statusTitle,
                    style: AppTypography.label.copyWith(
                      color: isReady
                          ? AppColors.primaryText
                          : AppColors.ink,
                    ),
                  ),
                  if (_state.message != null &&
                      _state.status != OfflinePackageStatus.ready) ...[
                    const SizedBox(height: 6),
                    Text(
                      _state.message!,
                      style: AppTypography.caption,
                    ),
                  ],
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _state.progress == 0
                          ? null
                          : _state.progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.primary,
                      backgroundColor: AppColors.tonal,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_state.progress * 100).toStringAsFixed(0)}%',
                      style: AppTypography.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (canDownload)
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Unduh Paket'),
              ),
            if (_isDownloading)
              OutlinedButton.icon(
                onPressed: _cancelDownload,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Batalkan unduhan'),
              ),
            if (isReady) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Siap digunakan'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deletePackage,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                label: const Text('Hapus paket'),
              ),
            ],
            if (_state.status == OfflinePackageStatus.failed &&
                _state.message?.contains('Penyimpanan tidak cukup') == true)
              TextButton(
                onPressed: _openStorageSettings,
                child: const Text('Buka Pengaturan Penyimpanan'),
              ),
          ],
        ),
      ),
    );
  }
}
