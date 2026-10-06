import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:working_hours/core/constants.dart';

void main() {
  test('kAppVersion 与 pubspec.yaml 的 version 保持一致', () {
    final yaml = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(yaml);
    expect(match, isNotNull, reason: 'pubspec.yaml 中未找到 version 字段');
    // pubspec 形如 1.5.2+7，去掉 build 号后应与常量一致
    final pubspecVersion = match!.group(1)!.split('+').first;
    expect(
      kAppVersion,
      pubspecVersion,
      reason: 'kAppVersion 需要与 pubspec.yaml 的 version 同步修改',
    );
  });
}
