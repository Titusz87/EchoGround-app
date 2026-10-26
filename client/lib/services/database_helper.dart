import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('incidents_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      sqfliteFfiInit();
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        event_type TEXT,
        status TEXT,
        warning_level TEXT,
        state TEXT,
        latitude REAL,
        longitude REAL,
        last_evaluated TEXT,
        reported_time TEXT,
        expires TEXT,
        description TEXT,
        address TEXT,
        created TEXT,
        last_modified TEXT
      )
    ''');
  }

  Future<void> insertNotification(Map<String, dynamic> dataPayload) async {
    final db = await instance.database;
    
    final Map<String, dynamic> row = {
      'id': dataPayload['id'] ?? 'unknown_id',
      'event_type': dataPayload['event_type'],
      'status': dataPayload['status'],
      'warning_level': dataPayload['warning_level'],
      'state': dataPayload['state'] == 'NULL' ? null : dataPayload['state'],
      'latitude': dataPayload['latitude'] != null ? double.tryParse(dataPayload['latitude'].toString()) : null,
      'longitude': dataPayload['longitude'] != null ? double.tryParse(dataPayload['longitude'].toString()) : null,
      'last_evaluated': dataPayload['last_evaluated'],
      'reported_time': dataPayload['reported_time'],
      'expires': dataPayload['expires'],
      'description': dataPayload['description'],
      'address': dataPayload['address'],
      'created': dataPayload['created'],
      'last_modified': dataPayload['last_modified'],
    };

    await db.insert(
      'notifications', 
      row, 
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllNotifications() async {
    final db = await instance.database;
    return await db.query('notifications', orderBy: 'created DESC');
  }
}
