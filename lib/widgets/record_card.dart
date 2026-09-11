import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/overtime_record.dart';
import '../utils/calculations.dart';

/// 加班记录卡片
class RecordCard extends StatelessWidget {
  final OvertimeRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const RecordCard({
    super.key,
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 第一行：日期和类型标签
                Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(record.date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTypeChip(context),
                    const Spacer(),
                    if (record.isCompensatory)
                      _buildTag(context, '调休', colorScheme.tertiary),
                    if (record.isSettled)
                      _buildTag(context, '已结算', colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 8),
                // 第二行：时间、时长
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${Calculations.formatTimeOfDay(record.startTime)} - ${Calculations.formatTimeOfDay(record.endTime)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.timelapse, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      Calculations.formatDuration(record.durationMinutes),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 第三行：倍率、折算工时、金额
                Row(
                  children: [
                    Text(
                      '倍率: ${record.rate}x',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '折算: ${Calculations.formatHours(Calculations.calculateConvertedHours(record.durationMinutes, record.rate))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Calculations.formatAmount(record.amount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // 第四行：项目和备注
                if (record.project.isNotEmpty || record.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (record.project.isNotEmpty) ...[
                        Icon(Icons.folder, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            record.project,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (record.note.isNotEmpty) ...[
                        Icon(Icons.note, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            record.note,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color chipColor;
    switch (record.type) {
      case OvertimeType.workday:
        chipColor = colorScheme.primary;
        break;
      case OvertimeType.restday:
        chipColor = colorScheme.secondary;
        break;
      case OvertimeType.holiday:
        chipColor = colorScheme.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        record.type.label,
        style: TextStyle(fontSize: 12, color: chipColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }
}