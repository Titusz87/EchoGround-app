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
      // 🛠️ PURE SQLITE WEB CONFIG: Force a globally named virtual file storage signature
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
    // 1. Core local notification caching layout table schematic
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

    // 2. Created persistent configuration metadata table slot tracking
    await db.execute('''
      CREATE TABLE device_config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // Updated type-safe insert method to normalize empty strings and casing parameters cleanly
  Future<void> insertNotification(Map<String, dynamic> dataPayload) async {
    final db = await instance.database;

    String? sanitizeString(dynamic value, {String? fallback}) {
      if (value == null) return fallback;
      final str = value.toString().trim();
      return str.isEmpty ? fallback : str;
    }

    // 🛠️ CASE STABILIZER: Force incoming string values to fit uniform layout casing patterns
    String rawStatus = sanitizeString(
      dataPayload['status'],
      fallback: 'active',
    )!.toLowerCase();
    String normalizedStatus = 'Active';
    if (rawStatus == 'completed' || rawStatus == 'safe')
      normalizedStatus = 'Completed';
    if (rawStatus == 'controlled') normalizedStatus = 'Controlled';

    final Map<String, dynamic> row = {
      'id': sanitizeString(
        dataPayload['id'] ?? dataPayload['incident_id'],
        fallback: 'unknown_incident_${DateTime.now().millisecondsSinceEpoch}',
      ),
      'event_type': sanitizeString(
        dataPayload['event_type'],
        fallback: 'General Incident',
      ),
      'status': normalizedStatus, // Capitalized target keys matching UI checks
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
        dataPayload['reported_time'] ?? dataPayload['created'],
        fallback: 'Recently Reported',
      ),
      'expires': sanitizeString(dataPayload['expires'], fallback: 'Open Ended'),

      // 🛠️ FIXED COGNIZANCE: Force default text strings if description arrives empty to prevent row drop issues
      'description': sanitizeString(
        dataPayload['description'],
        fallback: 'Emergency operations are active near tracking coordinates.',
      ),
      'address': sanitizeString(
        dataPayload['address'] ?? dataPayload['location'],
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

    try {
      print("Syncing cleaned dataset entry to local database: ${row['id']}");

      await db.insert(
        'notifications',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ⚡ ALERT LISTENER STREAM: Forces UI cards to reload instantly on completion
      syncNotifier.value++;
    } catch (e) {
      print("Database Write Failure Intercepted Safely: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllNotifications() async {
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
