import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/overtime_record.dart';

class DatabaseHelper {
  static const String _dbName = 'jiabanji.db';
  static const int _dbVersion = 1;
  static const String tableRecords = 'overtime_records';
  static const String tableSettings = 'settings';

  static Database? _database;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableRecords (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        type_index INTEGER NOT NULL,
        rate REAL NOT NULL,
        project TEXT DEFAULT '',
        note TEXT DEFAULT '',
        is_compensatory INTEGER DEFAULT 0,
        is_settled INTEGER DEFAULT 0,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 插入默认设置
    await db.insert(tableSettings, {'key': 'hourly_wage', 'value': '50.0'});
    await db.insert(tableSettings, {'key': 'workday_rate', 'value': '1.5'});
    await db.insert(tableSettings, {'key': 'restday_rate', 'value': '2.0'});
    await db.insert(tableSettings, {'key': 'holiday_rate', 'value': '3.0'});
    await db.insert(tableSettings, {'key': 'deduct_break', 'value': '0'});
    await db.insert(tableSettings, {'key': 'round_to_minute', 'value': '1'});
    await db.insert(tableSettings, {'key': 'break_minutes', 'value': '0'});
  }

  // ==================== 记录 CRUD ====================

  Future<List<OvertimeRecord>> getAllRecords() async {
    final db = await database;
    final maps = await db.query(tableRecords, orderBy: 'date DESC, start_time DESC');
    return maps.map((m) => OvertimeRecord.fromMap(m)).toList();
  }

  Future<List<OvertimeRecord>> getRecordsByMonth(int year, int month) async {
    final db = await database;
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final endDate = month == 12
        ? '${year + 1}-01-01'
        : '$year-${(month + 1).toString().padLeft(2, '0')}-01';
    final maps = await db.query(
      tableRecords,
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC, start_time DESC',
    );
    return maps.map((m) => OvertimeRecord.fromMap(m)).toList();
  }

  Future<List<OvertimeRecord>> getRecordsByYear(int year) async {
    final db = await database;
    final startDate = '$year-01-01';
    final endDate = '${year + 1}-01-01';
    final maps = await db.query(
      tableRecords,
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
    return maps.map((m) => OvertimeRecord.fromMap(m)).toList();
  }

  Future<List<OvertimeRecord>> searchByProject(String keyword) async {
    final db = await database;
    final maps = await db.query(
      tableRecords,
      where: 'project LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'date DESC',
    );
    return maps.map((m) => OvertimeRecord.fromMap(m)).toList();
  }

  Future<OvertimeRecord> insertRecord(OvertimeRecord record) async {
    final db = await database;
    await db.insert(tableRecords, record.toMap());
    return record;
  }

  Future<int> updateRecord(OvertimeRecord record) async {
    final db = await database;
    return db.update(
      tableRecords,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteRecord(String id) async {
    final db = await database;
    return db.delete(tableRecords, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllRecords() async {
    final db = await database;
    return db.delete(tableRecords);
  }

  // ==================== 设置 CRUD ====================

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await database;
    final results = await db.query(
      tableSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return defaultValue;
    return results.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double> getHourlyWage() async {
    final val = await getSetting('hourly_wage', defaultValue: '50.0');
    return double.tryParse(val) ?? 50.0;
  }

  Future<void> setHourlyWage(double wage) async {
    await setSetting('hourly_wage', wage.toStringAsFixed(2));
  }
}