import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jiabanji/app.dart';

void main() {
  setUpAll(() {
    // 初始化 sqflite FFI 用于测试环境
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: JiabanjiApp()),
    );

    // 使用 pump 替代 pumpAndSettle，避免 FutureProvider 加载动画导致超时
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证应用启动后显示底部导航栏
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}