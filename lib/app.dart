import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'ui/home/home_shell.dart';

/// 应用根组件（Material 3 / 中文 / 跟随系统深色模式）
class WorkingHoursApp extends ConsumerWidget {
  const WorkingHoursApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: '记工时',
      debugShowCheckedModeBanner: false,
      themeMode: settings.theme,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
