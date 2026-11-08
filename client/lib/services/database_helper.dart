import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Added reactive synchronisation notifier layer for real-time UI triggering
  final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);

  // 🎯 THE WEB STATE BRIDGE: Global memory repo to sync threads if web workers split storage files
  static final List<Map<String, dynamic>> crossThreadMemoryBuffer = [];

  // In-memory cache for coordinates
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
      return await openDatabase(
        filePath,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } else {
      sqfliteFfiInit();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
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
        last_modified TEXT,
        validated_by TEXT,
        last_updated TEXT,
        test_incident TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE device_config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        await db.execute(
          "ALTER TABLE notifications ADD COLUMN validated_by TEXT;",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE notifications ADD COLUMN last_updated TEXT;",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE notifications ADD COLUMN test_incident TEXT;",
        );
      } catch (_) {}
    }
  }

  Future<void> insertNotification(Map<String, dynamic> dataPayload) async {
    final db = await instance.database;

    String? sanitizeString(dynamic value, {String? fallback}) {
      if (value == null) return fallback;
      final str = value.toString().trim();
      return str.isEmpty ? fallback : str;
    }

    // Standardize incoming parameters to uniform keys
    final Map<String, dynamic> row = {
      'id': sanitizeString(
        dataPayload['id'],
        fallback: 'unknown_incident_${DateTime.now().millisecondsSinceEpoch}',
      ),
      'event_type': sanitizeString(
        dataPayload['event_type'],
        fallback: 'General Incident',
      ),
      'status': sanitizeString(dataPayload['status'], fallback: 'Active'),
      'warning_level': sanitizeString(
        dataPayload['warning_level'],
        fallback: 'Notice',
      ),
      'state': sanitizeString(dataPayload['state'], fallback: 'Active Status'),

      'latitude':
          dataPayload['latitude'] != null &&
              dataPayload['latitude'].toString().isNotEmpty
          ? double.tryParse(dataPayload['latitude'].toString())
          : null,
      'longitude':
          dataPayload['longitude'] != null &&
              dataPayload['longitude'].toString().isNotEmpty
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
        fallback: 'No further details available at this time.',
      ),
      'address': sanitizeString(
        dataPayload['address'],
        fallback: 'Regional Location',
      ),
      'created': sanitizeString(
        dataPayload['created'],
        fallback: DateTime.now().toIso8601String(),
      ),
      'last_modified': sanitizeString(
        dataPayload['last_modified'] ?? dataPayload['last_updated'],
        fallback: 'Just Now',
      ),
      'validated_by': sanitizeString(
        dataPayload['validated_by'],
        fallback: 'Not Validated',
      ),
      'last_updated': sanitizeString(
        dataPayload['last_updated'],
        fallback: 'Not Provided',
      ),
      'test_incident': sanitizeString(
        dataPayload['test_incident'],
        fallback: 'False',
      ),
    };

    // 🎯 INJECT STRAIGHT TO SHARED RUNTIME STATIC RAM MEMORY
    final int existingIdx = crossThreadMemoryBuffer.indexWhere(
      (element) => element['id'] == row['id'],
    );
    if (existingIdx != -1) {
      crossThreadMemoryBuffer[existingIdx] = row;
    } else {
      crossThreadMemoryBuffer.insert(0, row);
    }

    try {
      await db.insert(
        'notifications',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print("Database Write Failure Intercepted Safely: $e");
    }

    // ⚡ ALERT USER INTERFACE: Force dashboard layouts to repaint instantly!
    syncNotifier.value++;
  }

  Future<List<Map<String, dynamic>>> fetchAllNotifications() async {
    // 🛠️ WEB THREAD RE-SYNCHRONIZATION:
    // If running on web and the memory buffer holds data, serve it directly to populate the cards instantly
    if (kIsWeb && crossThreadMemoryBuffer.isNotEmpty) {
      return crossThreadMemoryBuffer;
    }

    try {
      final db = await instance.database;
      final List<Map<String, dynamic>> diskResults = await db.query(
        'notifications',
        orderBy: 'created DESC',
      );

      if (kIsWeb && diskResults.isEmpty && crossThreadMemoryBuffer.isNotEmpty) {
        return crossThreadMemoryBuffer;
      }
      return diskResults;
    } catch (e) {
      return crossThreadMemoryBuffer;
    }
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
