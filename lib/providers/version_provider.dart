import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants.dart';

/// 应用版本号：读取 APK manifest 中的 versionName（与安装器显示的一致）
///
/// 读取失败（如单元测试环境没有平台通道）时回退到编译期常量 [kAppVersion]，
/// 保证关于页任何时候都能显示版本号。
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    return version.isEmpty ? kAppVersion : version;
  } catch (_) {
    return kAppVersion;
  }
});
