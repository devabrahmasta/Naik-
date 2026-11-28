import 'dart:convert';
import 'dart:io';

class OfflinePackageFile {
  final String name;
  final String type;
  final int sizeBytes;
  final String? sha256;
  final String url;

  const OfflinePackageFile({
    required this.name,
    required this.type,
    required this.sizeBytes,
    required this.url,
    this.sha256,
  });

  factory OfflinePackageFile.fromJson(Map<String, dynamic> json) {
    return OfflinePackageFile(
      name: json['name'] as String,
      type: json['type'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      sha256: json['sha256'] as String?,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'url': url,
      };
}

class OfflinePackageManifest {
  final String packageId;
  final String routeId;
  final String areaName;
  final int version;
  final int estimatedBytes;
  final List<OfflinePackageFile> files;

  const OfflinePackageManifest({
    required this.packageId,
    required this.routeId,
    required this.areaName,
    required this.version,
    required this.estimatedBytes,
    required this.files,
  });

  factory OfflinePackageManifest.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>)
        .map((item) =>
            OfflinePackageFile.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
    return OfflinePackageManifest(
      packageId: json['packageId'] as String,
      routeId: json['routeId'] as String,
      areaName: json['areaName'] as String,
      version: (json['version'] as num).toInt(),
      estimatedBytes: (json['estimatedBytes'] as num).toInt(),
      files: files,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageId': packageId,
        'routeId': routeId,
        'areaName': areaName,
        'version': version,
        'estimatedBytes': estimatedBytes,
        'files': files.map((file) => file.toJson()).toList(),
      };

  String get estimatedSizeLabel => formatBytes(estimatedBytes);

  bool validate() {
    if (packageId.trim().isEmpty ||
        areaName.trim().isEmpty ||
        version <= 0 ||
        files.isEmpty) {
      return false;
    }
    for (final file in files) {
      if (!_isSafeFileName(file.name) ||
          file.sizeBytes < 0 ||
          Uri.tryParse(file.url)?.hasScheme != true) {
        return false;
      }
    }
    return true;
  }

  static bool _isSafeFileName(String name) {
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      return false;
    }
    return !name.startsWith('.') &&
        name != '.' &&
        name != '..';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum OfflinePackageStatus {
  notDownloaded,
  preparing,
  downloading,
  validating,
  ready,
  failed,
  corrupt,
}

class OfflinePackageState {
  final OfflinePackageStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final String? message;

  const OfflinePackageState({
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.message,
  });

  const OfflinePackageState.initial()
      : status = OfflinePackageStatus.notDownloaded,
        downloadedBytes = 0,
        totalBytes = 0,
        message = null;

  double get progress =>
      totalBytes <= 0 ? 0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  OfflinePackageState copyWith({
    OfflinePackageStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    String? message,
  }) {
    return OfflinePackageState(
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      message: message ?? this.message,
    );
  }
}

Future<bool> isPackageReady(
  Directory documents,
  OfflinePackageManifest manifest,
) async {
  final packageDir = Directory(
    '${documents.path}/packages/${manifest.packageId}/v${manifest.version}',
  );
  if (!await packageDir.exists()) return false;

  final manifestFile =
      File('${packageDir.path}/package_manifest.json');
  if (!await manifestFile.exists()) return false;

  try {
    final stored = jsonDecode(await manifestFile.readAsString());
    final storedManifest =
        OfflinePackageManifest.fromJson(Map<String, dynamic>.from(stored as Map));
    if (storedManifest.packageId != manifest.packageId ||
        storedManifest.version != manifest.version) {
      return false;
    }
  } on Object {
    return false;
  }

  for (final file in manifest.files) {
    final downloaded = File('${packageDir.path}/${file.name}');
    if (!await downloaded.exists()) return false;
  }
  return true;
}
