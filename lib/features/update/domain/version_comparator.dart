import 'package:package_info_plus/package_info_plus.dart';

class VersionComparator {
  /// Compares the installed app version code with the latest version code.
  /// Returns [true] if an update is available.
  static Future<bool> isUpdateAvailable(int latestVersionCode) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    return installedVersionCode < latestVersionCode;
  }

  /// Compares the installed app version code with the minimum supported version code.
  /// Returns [true] if the update is forced.
  static Future<bool> isForceUpdate(int minSupportedVersionCode) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    return installedVersionCode < minSupportedVersionCode;
  }

  static Future<int> getInstalledVersionCode() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return int.tryParse(packageInfo.buildNumber) ?? 0;
  }

  static Future<String> getInstalledVersionName() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
