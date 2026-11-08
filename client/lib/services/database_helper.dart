import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);

  // Global memory cache to bridge the thread isolation gaps on web browsers
  final List<Map<String, dynamic>> webGlobalMemoryBuffer = [];

  double? cachedLat;
  double? cachedLng;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('incidents_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(filePath, version: 1, onCreate: _createDB);
    } else {
      sqfliteFfiInit();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(path, version: 1, onCreate: _createDB);
    }
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

    await db.execute('''
      CREATE TABLE device_config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> insertNotification(Map<String, dynamic> dataPayload) async {
    final db = await instance.database;

    String? sanitizeString(dynamic value, {String? fallback}) {
      if (value == null) return fallback;
      final str = value.toString().trim();
      return str.isEmpty ? fallback : str;
    }

    final Map<String, dynamic> row = {
      'id': sanitizeString(
        dataPayload['id'] ?? dataPayload['incident_id'],
        fallback: 'unknown_incident_${DateTime.now().millisecondsSinceEpoch}',
      ),
      'event_type': sanitizeString(
        dataPayload['event_type'],
        fallback: 'bushfire',
      ),
      'status': sanitizeString(dataPayload['status'], fallback: 'Active'),
      'warning_level': sanitizeString(
        dataPayload['warning_level'],
        fallback: 'Notice',
      ),
      'state': sanitizeString(dataPayload['state'], fallback: 'Active Status'),
      'latitude': dataPayload['latitude'] != null
          ? double.tryParse(dataPayload['latitude'].toString())
          : null,
      'longitude': dataPayload['longitude'] != null
          ? double.tryParse(dataPayload['longitude'].toString())
          : null,
      'last_evaluated': sanitizeString(
        dataPayload['last_evaluated'],
        fallback: 'Not Evaluated',
      ),
      'reported_time': sanitizeString(
        dataPayload['reported_time'],
        fallback: 'Recently Reported',
      ),
      'expires': sanitizeString(dataPayload['expires'], fallback: 'Open Ended'),
      'description': sanitizeString(
        dataPayload['description'],
        fallback:
            'Emergency operations are active near local tracking boundaries.',
      ),
      'address': sanitizeString(
        dataPayload['address'],
        fallback: 'Adelaide Regional Location',
      ),
      'created': sanitizeString(
        dataPayload['created'],
        fallback: DateTime.now().toIso8601String(),
      ),
      'last_modified': sanitizeString(
        dataPayload['last_modified'] ?? dataPayload['last_updated'],
        fallback: 'Just Now',
      ),
    };

    // Ensures data is visible to the main layout thread instantly
    final int existingIdx = webGlobalMemoryBuffer.indexWhere(
      (element) => element['id'] == row['id'],
    );
    if (existingIdx != -1) {
      webGlobalMemoryBuffer[existingIdx] = row;
    } else {
      webGlobalMemoryBuffer.insert(0, row);
    }

    try {
      await db.insert(
        'notifications',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print("Database write failure bypassed: $e");
    }

    // Force layouts to repaint
    syncNotifier.value++;
  }

  Future<List<Map<String, dynamic>>> fetchAllNotifications() async {
    // If running on web and memory data is populated, return it directly to clear the card status
    if (kIsWeb && webGlobalMemoryBuffer.isNotEmpty) {
      return webGlobalMemoryBuffer;
    }

    final db = await instance.database;
    return await db.query('notifications', orderBy: 'created DESC');
  }

  Future<void> saveConfig(String key, String value) async {
    final db = await instance.database;
    await db.insert('device_config', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getConfig(String key) async {
    final db = await instance.database;
    final maps = await db.query(
      'device_config',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) return maps.first['value'] as String?;
    return null;
  }
}
