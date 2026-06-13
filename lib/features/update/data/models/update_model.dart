class UpdateModel {
  final String id;
  final String versionName;
  final int versionCode;
  final String releaseNotes;
  final String apkUrl;
  final String apkSize;
  final bool forceUpdate;
  final DateTime releaseDate;
  final int minSupportedVersion;
  final List<String> changelog;
  final bool isActive;
  final String? sha256Hash;

  UpdateModel({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.apkUrl,
    required this.apkSize,
    required this.forceUpdate,
    required this.releaseDate,
    required this.minSupportedVersion,
    required this.changelog,
    required this.isActive,
    this.sha256Hash,
  });

  factory UpdateModel.fromMap(Map<String, dynamic> map) {
    return UpdateModel(
      id: map['\$id'] ?? '',
      versionName: map['version_name'] ?? '',
      versionCode: map['version_code']?.toInt() ?? 0,
      releaseNotes: map['release_notes'] ?? '',
      apkUrl: map['apk_url'] ?? '',
      apkSize: map['apk_size'] ?? '',
      forceUpdate: map['force_update'] ?? false,
      releaseDate: map['release_date'] != null 
          ? DateTime.parse(map['release_date']) 
          : DateTime.now(),
      minSupportedVersion: map['min_supported_version']?.toInt() ?? 0,
      changelog: List<String>.from(map['changelog'] ?? []),
      isActive: map['is_active'] ?? false,
      sha256Hash: map['sha256_hash'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version_name': versionName,
      'version_code': versionCode,
      'release_notes': releaseNotes,
      'apk_url': apkUrl,
      'apk_size': apkSize,
      'force_update': forceUpdate,
      'release_date': releaseDate.toIso8601String(),
      'min_supported_version': minSupportedVersion,
      'changelog': changelog,
      'is_active': isActive,
      if (sha256Hash != null) 'sha256_hash': sha256Hash,
    };
  }
}
