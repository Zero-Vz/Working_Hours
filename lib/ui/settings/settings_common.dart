/// 设置页通用组件与弹窗（各二级设置页共用，避免重复实现）
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 数字输入弹窗，返回 null 表示取消
Future<double?> promptNumber(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  bool decimal = true,
  double min = 0,
  double? max,
  String errorText = '请输入有效数字',
}) {
  final controller = TextEditingController(text: initialValue);
  String? error;

  return showDialog<double>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            final parsed = double.tryParse(controller.text.trim());
            if (parsed == null || parsed < min || (max != null && parsed > max)) {
              setDialogState(() => error = errorText);
              return;
            }
            Navigator.of(dialogContext).pop(parsed);
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: decimal,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                ),
              ],
              decoration: InputDecoration(
                labelText: label,
                errorText: error,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: submit,
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(controller.dispose);
}

/// 文本输入弹窗，返回 null 表示取消
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('保存'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// 分组标题
Widget settingsHeader(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
    child: Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// 分组卡片容器
Widget settingsCard(BuildContext context, {required List<Widget> children}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
    ),
    child: Column(children: children),
  );
}

/// 卡片内分隔线
const Widget settingsDivider = Divider(height: 1, indent: 16, endIndent: 16);

/// 倍率展示文本：1.50 → 1.5，2.00 → 2
String rateText(double rate) {
  final text = rate.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.00$'), '');
}
