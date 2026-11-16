import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier, debugPrint;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Manages local persistence for cached incidents and device configuration.
///
/// Uses SQLite via FFI on native desktop/mobile platforms and an in-memory
/// store on Web (`kIsWeb`) so GitHub Pages and iOS Safari PWAs run without
/// requiring Cross-Origin Isolated WASM workers (`sqflite_sw.js`).
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Web-safe in-memory stores used when kIsWeb is true
  static final Map<String, Map<String, dynamic>> _webNotifications = {};
  static final Map<String, String> _webConfig = {};

  /// Reactive notifier incremented whenever cached records change.
  final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);

  // In-memory cache for coordinates
  double? cachedLat;
  double? cachedLng;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite Database instance is bypassed on Web.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('incidents_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE notifications ADD COLUMN validated_by TEXT;',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE notifications ADD COLUMN last_updated TEXT;',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE notifications ADD COLUMN test_incident TEXT;',
        );
      } catch (_) {}
    }
  }

  /// Updates the status value of an incident/report record inside the cache.
  Future<int> updateNotificationStatus(String id, String status) async {
    if (kIsWeb) {
      final existing = _webNotifications[id];
      if (existing != null) {
        existing['status'] = status;
        syncNotifier.value++;
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    final updated = await db.update(
      'notifications',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated > 0) syncNotifier.value++;
    return updated;
  }

  /// Sanitises and inserts or replaces an incident payload in local storage.
  Future<void> insertNotification(Map<String, dynamic> dataPayload) async {
    try {
      String? sanitizeString(dynamic value, {String? fallback}) {
        if (value == null) return fallback;
        final str = value.toString().trim();
        return str.isEmpty ? fallback : str;
      }

      double? parseCoordinate(dynamic val) {
        if (val == null) return null;
        if (val is num) return val.toDouble();
        return double.tryParse(val.toString().trim());
      }

      final String id = sanitizeString(
        dataPayload['id'],
        fallback: 'unknown_incident_${DateTime.now().millisecondsSinceEpoch}',
      )!;

      final Map<String, dynamic> row = {
        'id': id,
        'event_type': sanitizeString(
          dataPayload['title'] ?? dataPayload['event_type'],
          fallback: 'General Incident',
        ),
        'status': sanitizeString(dataPayload['status'], fallback: 'Active'),
        'warning_level': sanitizeString(
          dataPayload['warning_level'],
          fallback: 'Notice',
        ),
        'state': sanitizeString(
          dataPayload['state'],
          fallback: 'Active Status',
        ),
        'latitude': parseCoordinate(dataPayload['latitude']),
        'longitude': parseCoordinate(dataPayload['longitude']),
        'last_evaluated': sanitizeString(
          dataPayload['last_evaluated'],
          fallback: 'Not Evaluated',
        ),
        'reported_time': sanitizeString(
          dataPayload['reported_time'],
          fallback: 'Recently Reported',
        ),
        'expires': sanitizeString(
          dataPayload['expires'],
          fallback: 'Open Ended',
        ),
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

      if (kIsWeb) {
        _webNotifications[id] = row;
        syncNotifier.value++;
        return;
      }

      final db = await database;
      await db.insert(
        'notifications',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      syncNotifier.value++;
    } catch (methodError) {
      debugPrint('DatabaseHelper.insertNotification error: $methodError');
    }
  }

  /// Returns all cached notifications ordered by creation timestamp descending.
  Future<List<Map<String, dynamic>>> fetchAllNotifications() async {
    if (kIsWeb) {
      final list = _webNotifications.values
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      list.sort((a, b) => (b['created'] ?? '').compareTo(a['created'] ?? ''));
      return list;
    }

    final db = await instance.database;
    return await db.query('notifications', orderBy: 'created DESC');
  }

  /// Saves a key-value configuration pair to local storage.
  Future<void> saveConfig(String key, String value) async {
    if (kIsWeb) {
      _webConfig[key] = value;
      return;
    }

    final db = await instance.database;
    await db.insert('device_config', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Retrieves a stored configuration value by [key], or `null` if absent.
  Future<String?> getConfig(String key) async {
    if (kIsWeb) {
      return _webConfig[key];
    }

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
