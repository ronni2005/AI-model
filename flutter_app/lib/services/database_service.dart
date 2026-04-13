import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient_record.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;
  static const _table = 'patient_records';

  Future<void> init() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), 'rural_health_ai.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_name    TEXT NOT NULL,
          age             INTEGER NOT NULL,
          gender          TEXT NOT NULL,
          village         TEXT,
          worker_name     TEXT,
          assessment_json TEXT NOT NULL,
          risk_level      TEXT NOT NULL,
          primary_disease TEXT NOT NULL,
          created_at      TEXT NOT NULL
        )
      '''),
    );
  }

  Future<PatientRecord> insert(PatientRecord record) async {
    final map = record.toMap()..remove('id');
    final id = await _db!.insert(_table, map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return PatientRecord(
      id: id.toString(),
      patientName: record.patientName,
      age: record.age,
      gender: record.gender,
      village: record.village,
      workerName: record.workerName,
      assessment: record.assessment,
      createdAt: record.createdAt,
    );
  }

  Future<List<PatientRecord>> fetchAll({
    String? searchQuery,
    String? riskFilter,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(patient_name LIKE ? OR village LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }
    if (riskFilter != null && riskFilter != 'All') {
      conditions.add('risk_level = ?');
      args.add(riskFilter);
    }
    final rows = await _db!.query(
      _table,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(PatientRecord.fromMap).toList();
  }

  Future<void> delete(String id) async =>
      _db!.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<int> countByRisk(String level) async {
    final r = await _db!.rawQuery(
        'SELECT COUNT(*) as c FROM $_table WHERE risk_level = ?', [level]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<int> totalCount() async {
    final r = await _db!.rawQuery(
        'SELECT COUNT(*) as c FROM $_table');
    return (r.first['c'] as int?) ?? 0;
  }
}