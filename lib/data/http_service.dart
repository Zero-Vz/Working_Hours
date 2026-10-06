import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';

/// 极简 HTTP GET（不引入额外依赖，仅用于「更新节假日 / 检查软件更新」）
class HttpService {
  static const Duration _timeout = Duration(seconds: 20);

  /// 拉取文本；任何失败都抛出带中文说明的异常
  static Future<String> getText(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('地址无效：$url');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('仅支持 http / https 地址');
    }

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*')
        ..set(HttpHeaders.userAgentHeader, 'WorkingHours/$kAppVersion');
      final response = await request.close().timeout(_timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('服务器返回 ${response.statusCode}');
      }
      return body;
    } on SocketException {
      throw const SocketException('网络不可用，请检查网络连接');
    } on HandshakeException {
      throw const HttpException('安全连接失败，请检查地址是否为 https');
    } finally {
      client.close(force: true);
    }
  }

  /// 拉取并按 JSON 解析
  static Future<dynamic> getJson(String url) async {
    final text = await getText(url);
    return jsonDecode(text);
  }
}
