import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabanji/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JiabanjiApp());

    // 验证应用启动后显示底部导航栏
    expect(find.byType(NavigationBar), findsOneWidget);

    // 验证默认显示记录页
    expect(find.text('加班记'), findsOneWidget);
  });
}