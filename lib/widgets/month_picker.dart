import 'package:flutter/material.dart';

/// 月份选择器
class MonthPicker extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  const MonthPicker({
    super.key,
    required this.selectedMonth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            onChanged(DateTime(selectedMonth.year, selectedMonth.month - 1));
          },
        ),
        GestureDetector(
          onTap: () => _showMonthPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            ),
            child: Text(
              '${selectedMonth.year}年${selectedMonth.month}月',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            onChanged(DateTime(selectedMonth.year, selectedMonth.month + 1));
          },
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month));
    }
  }
}