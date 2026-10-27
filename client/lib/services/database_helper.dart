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

    // Updated type-safe insert method to neutralize empty strings and null value fields
  Future<void> insertNotification(Map<String, dynamic> dataPayload) async {
    final db = await instance.database;

    // Helper helper function to convert empty string parameters cleanly to null or fallback labels
    String? sanitizeString(dynamic value, {String? fallback}) {
      if (value == null) return fallback;
      final str = value.toString().trim();
      return str.isEmpty ? fallback : str;
    }

    // Safely structure and extract types matching your incoming live datasets
    final Map<String, dynamic> row = {
      'id': sanitizeString(dataPayload['id'], fallback: 'unknown_incident_${DateTime.now().millisecondsSinceEpoch}'),
      'event_type': sanitizeString(dataPayload['event_type'], fallback: 'General Incident'),
      'status': sanitizeString(dataPayload['status'], fallback: 'Active'),
      'warning_level': sanitizeString(dataPayload['warning_level'], fallback: 'Notice'),
      'state': sanitizeString(dataPayload['state'], fallback: 'Active Status'),
      
      // Safe parsing parameters for decimals/floats
      'latitude': dataPayload['latitude'] != null && dataPayload['latitude'].toString().isNotEmpty
          ? double.tryParse(dataPayload['latitude'].toString())
          : null,
      'longitude': dataPayload['longitude'] != null && dataPayload['longitude'].toString().isNotEmpty
          ? double.tryParse(dataPayload['longitude'].toString())
          : null,
          
      'last_evaluated': sanitizeString(dataPayload['last_evaluated'], fallback: 'Not Evaluated'),
      'reported_time': sanitizeString(dataPayload['reported_time'], fallback: 'Recently Reported'),
      'expires': sanitizeString(dataPayload['expires'], fallback: 'Open Ended'),
      'description': sanitizeString(dataPayload['description'], fallback: 'No further details available at this time.'),
      'address': sanitizeString(dataPayload['address'], fallback: 'Regional Location'),
      'created': sanitizeString(dataPayload['created'], fallback: DateTime.now().toIso8601String()),
      
      // FIXED: Uses 'last_updated' string keys sent by Python if 'last_modified' is omitted
      'last_modified': sanitizeString(dataPayload['last_modified'] ?? dataPayload['last_updated'], fallback: 'Just Now'),
    };

    try {
      print("Syncing cleaned dataset entry to local database: ${row['id']}");
      
      await db.insert(
        'notifications', 
        row, 
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    } catch (e) {
      print("Database Write Failure Intercepted Safely: $e");
    }
  }


  Future<List<Map<String, dynamic>>> fetchAllNotifications() async {
    final db = await instance.database;
    return await db.query('notifications', orderBy: 'created DESC');
  }
}
