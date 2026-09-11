import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/overtime_record.dart';
import '../providers/records_provider.dart';
import '../widgets/record_card.dart';
import '../widgets/month_picker.dart';
import 'record_form_screen.dart';

/// 记录列表页
class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key});

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final recordsAsync = ref.watch(monthlyRecordsProvider);
    final searchKeyword = ref.watch(searchKeywordProvider);
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索项目...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(searchKeywordProvider.notifier).state = value;
                },
              )
            : const Text('加班记'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(searchKeywordProvider.notifier).state = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份选择器
          MonthPicker(
            selectedMonth: selectedMonth,
            onChanged: (date) {
              ref.read(selectedMonthProvider.notifier).state = date;
            },
          ),
          const Divider(height: 1),
          // 记录列表
          Expanded(
            child: _isSearching && searchKeyword.isNotEmpty
                ? _buildSearchResults(searchResults)
                : _buildRecordList(recordsAsync, selectedMonth),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRecordList(AsyncValue<List<OvertimeRecord>> recordsAsync, DateTime selectedMonth) {
    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败: $error')),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  '暂无加班记录',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右下角 + 添加记录',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlyRecordsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return RecordCard(
                record: record,
                onTap: () => _navigateToForm(context, record: record),
                onDelete: () => _confirmDelete(context, record),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(AsyncValue<List<OvertimeRecord>> searchResults) {
    return searchResults.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('搜索失败: $error')),
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: Text('未找到匹配的记录', style: TextStyle(color: Colors.grey[600])),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return RecordCard(
              record: record,
              onTap: () => _navigateToForm(context, record: record),
              onDelete: () => _confirmDelete(context, record),
            );
          },
        );
      },
    );
  }

  Future<void> _navigateToForm(BuildContext context, {OvertimeRecord? record}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecordFormScreen(record: record),
      ),
    );
    if (result == true) {
      ref.invalidate(monthlyRecordsProvider);
      ref.invalidate(allRecordsProvider);
    }
  }

  void _confirmDelete(BuildContext context, OvertimeRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')} 的加班记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(recordsProvider.notifier).deleteRecord(record.id);
              Navigator.pop(ctx);
              ref.invalidate(monthlyRecordsProvider);
              ref.invalidate(allRecordsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}