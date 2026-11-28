import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'offline_package.dart';

typedef PackageStateListener = void Function(OfflinePackageState state);

class OfflinePackageManager {
  static const MethodChannel _packageChannel =
      MethodChannel('com.hikenav/package_control');

  final http.Client _client = http.Client();
  bool _cancelRequested = false;

  void cancel() => _cancelRequested = true;

  Future<Map<String, int>?> getStorageStats() async {
    try {
      final result =
          await _packageChannel.invokeMethod<Map<Object?, Object?>>(
        'getStorageStats',
      );
      if (result == null) return null;
      final map = Map<String, dynamic>.from(result);
      return {
        'availableBytes': (map['availableBytes'] as num).toInt(),
        'totalBytes': (map['totalBytes'] as num).toInt(),
      };
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> openStorageSettings() async {
    try {
      return await _packageChannel.invokeMethod<bool>(
            'openStorageSettings',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Directory> get _packagesRoot async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/packages');
  }

  Future<bool> isReady(OfflinePackageManifest manifest) async {
    try {
      final root = await _packagesRoot;
      return isPackageReady(root.parent, manifest);
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> download({
    required OfflinePackageManifest manifest,
    required PackageStateListener onState,
  }) async {
    _cancelRequested = false;
    if (!manifest.validate()) {
      onState(const OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: 0,
        totalBytes: 0,
        message: 'Manifest paket tidak valid.',
      ));
      return;
    }

    onState(OfflinePackageState(
      status: OfflinePackageStatus.preparing,
      downloadedBytes: 0,
      totalBytes: manifest.estimatedBytes,
      message: 'Memeriksa penyimpanan...',
    ));

    final storage = await getStorageStats();
    if (storage != null) {
      final available = storage['availableBytes'] ?? 0;
      if (available < manifest.estimatedBytes + 32 * 1024 * 1024) {
        onState(OfflinePackageState(
          status: OfflinePackageStatus.failed,
          downloadedBytes: 0,
          totalBytes: manifest.estimatedBytes,
          message:
              'Penyimpanan tidak cukup. Paket ${manifest.estimatedSizeLabel}; '
              'tersedia ${OfflinePackageManifest.formatBytes(available)}.',
        ));
        return;
      }
    }

    late final Directory root;
    late final Directory tempDir;
    late final Directory packageDir;
    try {
      root = await _packagesRoot;
      tempDir = Directory('${root.path}/.tmp/${manifest.packageId}');
      packageDir =
          Directory('${root.path}/${manifest.packageId}/v${manifest.version}');
      await tempDir.create(recursive: true);
      await packageDir.parent.create(recursive: true);
    } on FileSystemException catch (error) {
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: 0,
        totalBytes: manifest.estimatedBytes,
        message: 'Tidak dapat membuka penyimpanan lokal: ${error.message}',
      ));
      return;
    }

    var downloadedBytes = 0;
    try {
      for (final file in manifest.files) {
        if (_cancelRequested) {
          onState(OfflinePackageState(
            status: OfflinePackageStatus.failed,
            downloadedBytes: downloadedBytes,
            totalBytes: manifest.estimatedBytes,
            message: 'Unduhan dibatalkan.',
          ));
          await tempDir.delete(recursive: true);
          return;
        }

        final uri = Uri.parse(file.url);
        if (uri.scheme != 'https') {
          throw const FormatException(
            'Unduhan paket harus menggunakan HTTPS.',
          );
        }

        onState(OfflinePackageState(
          status: OfflinePackageStatus.downloading,
          downloadedBytes: downloadedBytes,
          totalBytes: manifest.estimatedBytes,
          message: 'Mengunduh ${file.name}',
        ));

        final request = http.Request('GET', uri);
        request.headers['User-Agent'] = 'HikeNav/1.0';
        final response = await _client.send(request);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException(
            'Server paket menolak unduhan (${response.statusCode}).',
          );
        }

        final output = File('${tempDir.path}/${file.name}');
        await output.create(recursive: true);
        final sink = output.openWrite();
        var fileBytes = 0;
        await for (final chunk in response.stream) {
          if (_cancelRequested) {
            await sink.close();
            await tempDir.delete(recursive: true);
            onState(OfflinePackageState(
              status: OfflinePackageStatus.failed,
              downloadedBytes: downloadedBytes,
              totalBytes: manifest.estimatedBytes,
              message: 'Unduhan dibatalkan.',
            ));
            return;
          }
          sink.add(chunk);
          fileBytes += chunk.length;
          downloadedBytes += chunk.length;
          onState(OfflinePackageState(
            status: OfflinePackageStatus.downloading,
            downloadedBytes: downloadedBytes,
            totalBytes: manifest.estimatedBytes,
            message: 'Mengunduh ${file.name}',
          ));
        }
        await sink.close();

        if (fileBytes != file.sizeBytes && file.sizeBytes > 0) {
          throw HttpException(
            'Ukuran ${file.name} tidak sesuai manifest '
            '($fileBytes dari ${file.sizeBytes} byte).',
          );
        }

        if (file.sha256 != null && file.sha256!.isNotEmpty) {
          final digest =
              sha256.convert(await output.readAsBytes()).toString();
          if (digest.toLowerCase() != file.sha256!.toLowerCase()) {
            throw const FormatException(
              'Checksum paket tidak sesuai.',
            );
          }
        }
      }
    } on SocketException {
      await tempDir.delete(recursive: true);
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: downloadedBytes,
        totalBytes: manifest.estimatedBytes,
        message: 'Internet diperlukan untuk unduh pertama kali.',
      ));
      return;
    } on FormatException catch (error) {
      await tempDir.delete(recursive: true);
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: downloadedBytes,
        totalBytes: manifest.estimatedBytes,
        message: error.message,
      ));
      return;
    } on HttpException catch (error) {
      await tempDir.delete(recursive: true);
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: downloadedBytes,
        totalBytes: manifest.estimatedBytes,
        message: error.message,
      ));
      return;
    } on FileSystemException catch (error) {
      await tempDir.delete(recursive: true);
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: downloadedBytes,
        totalBytes: manifest.estimatedBytes,
        message: 'Gagal menyimpan paket: ${error.message}',
      ));
      return;
    } catch (error) {
      await tempDir.delete(recursive: true);
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: downloadedBytes,
        totalBytes: manifest.estimatedBytes,
        message: 'Unduhan gagal: $error',
      ));
      return;
    }

    onState(OfflinePackageState(
      status: OfflinePackageStatus.validating,
      downloadedBytes: downloadedBytes,
      totalBytes: manifest.estimatedBytes,
      message: 'Memvalidasi paket...',
    ));

    try {
      if (await packageDir.exists()) {
        await packageDir.delete(recursive: true);
      }
      await packageDir.create(recursive: true);

      for (final file in manifest.files) {
        await File('${tempDir.path}/${file.name}')
            .rename('${packageDir.path}/${file.name}');
      }

      await File('${packageDir.path}/package_manifest.json')
          .writeAsString(jsonEncode(manifest.toJson()));
      await tempDir.delete(recursive: true);

      onState(OfflinePackageState(
        status: OfflinePackageStatus.ready,
        downloadedBytes: manifest.estimatedBytes,
        totalBytes: manifest.estimatedBytes,
        message: 'Siap offline',
      ));
    } on FileSystemException catch (error) {
      onState(OfflinePackageState(
        status: OfflinePackageStatus.failed,
        downloadedBytes: downloadedBytes,
        totalBytes: manifest.estimatedBytes,
        message: 'Gagal mengaktifkan paket: ${error.message}',
      ));
    }
  }

  Future<bool> delete(OfflinePackageManifest manifest) async {
    try {
      final root = await _packagesRoot;
      final packageDir =
          Directory('${root.path}/${manifest.packageId}');
      if (await packageDir.exists()) {
        await packageDir.delete(recursive: true);
      }
      final tempDir =
          Directory('${root.path}/.tmp/${manifest.packageId}');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      return true;
    } on FileSystemException {
      return false;
    }
  }

  void dispose() => _client.close();
}

