import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants.dart';
import 'data/models/overtime_record.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(OvertimeRecordAdapter());
  }

  await Hive.openBox<OvertimeRecord>(BoxNames.records);
  await Hive.openBox(BoxNames.settings);

  runApp(const ProviderScope(child: WorkingHoursApp()));
}
