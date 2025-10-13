import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'civic_security.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE blocklist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            number TEXT NOT NULL UNIQUE,
            reason TEXT,
            created_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            message TEXT NOT NULL,
            severity TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');
      },
    );
  }

  // Blocklist
  Future<void> addBlocked(String number, {String? reason}) async {
    final db = await database;
    await db.insert(
      'blocklist',
      {
        'number': number,
        'reason': reason,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeBlocked(String number) async {
    final db = await database;
    await db.delete('blocklist', where: 'number = ?', whereArgs: [number]);
  }

  Future<List<Map<String, dynamic>>> getBlocked() async {
    final db = await database;
    return db.query('blocklist', orderBy: 'created_at DESC');
  }

  // Alerts
  Future<int> addAlert(FraudAlert alert) async {
    final db = await database;
    return db.insert('alerts', {
      'type': alert.type,
      'message': alert.message,
      'severity': alert.severity,
      'created_at': alert.timestamp.millisecondsSinceEpoch,
    });
  }

  Future<List<FraudAlert>> getAlerts() async {
    final db = await database;
    final rows = await db.query('alerts', orderBy: 'created_at DESC');
    return rows
        .map((r) => FraudAlert(
              id: r['id'] as int?,
              type: r['type'] as String,
              message: r['message'] as String,
              severity: r['severity'] as String,
              timestamp: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            ))
        .toList();
  }
}
