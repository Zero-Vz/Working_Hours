import 'dart:convert';

import '../core/constants.dart';
import 'http_service.dart';

/// 远端版本信息
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.url,
    this.notes = '',
  });

  /// 远端版本号（已去掉 v 前缀）
  final String version;

  /// 下载 / 发布页地址
  final String url;

  /// 更新说明
  final String notes;
}

/// 检查软件更新：
///
/// 请求 [kReleaseApiUrl] 风格的 GitHub Releases JSON，
/// 本地版本高于远端时视为「已是最新」。
class UpdateCheckService {
  const UpdateCheckService._();

  /// 解析远端 JSON；无法识别时抛出中文异常
  static UpdateInfo parse(String text) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('返回内容不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('返回内容缺少版本信息');
    }

    final version = _normalizeVersion(
      _text(decoded['tag_name']) == ''
          ? _text(decoded['name'])
          : _text(decoded['tag_name']),
    );
    if (version.isEmpty) {
      throw const FormatException('返回内容缺少版本号');
    }

    return UpdateInfo(
      version: version,
      url: _text(decoded['html_url']).isEmpty
          ? kReleasesPageUrl
          : _text(decoded['html_url']),
      notes: _text(decoded['body']),
    );
  }

  /// 拉取远端版本信息
  static Future<UpdateInfo> check(String url) async {
    final text = await HttpService.getText(url);
    return parse(text);
  }

  /// 远端版本是否比本地新
  static bool isNewer(String remote, [String local = kAppVersion]) {
    final a = _normalizeVersion(remote);
    final b = _normalizeVersion(local);
    if (a.isEmpty || b.isEmpty) return false;

    List<int> parts(String value) =>
        value.split('.').map(int.tryParse).whereType<int>().toList();
    final ra = parts(a);
    final rb = parts(b);
    for (var i = 0; i < ra.length || i < rb.length; i++) {
      final x = i < ra.length ? ra[i] : 0;
      final y = i < rb.length ? rb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// 版本号规整：去掉 v / V 前缀与构建号
  static String _normalizeVersion(String raw) {
    var value = raw.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    final plus = value.indexOf('+');
    if (plus > 0) value = value.substring(0, plus);
    final dash = value.indexOf('-');
    if (dash > 0) value = value.substring(0, dash);
    return value.trim();
  }

  static String _text(dynamic value) =>
      value == null ? '' : value.toString().trim();
}
