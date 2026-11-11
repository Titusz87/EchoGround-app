import 'database_helper.dart';

/// Local session routing only. Server authentication is a separate concern.
class SavedSession {
  const SavedSession(this.role, this.id);
  final String role;
  final int id;
}

class SessionStore {
  static Future<void> activate({required int id, required bool isLeader}) async {
    if (id < 0) throw StateError('Invalid account ID');
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final entry in {
        'auth_active_role': isLeader ? 'leader' : 'household',
        'auth_household_id': isLeader ? '' : '$id',
        'auth_leader_id': isLeader ? '$id' : '',
      }.entries) {
        await txn.rawInsert('INSERT OR REPLACE INTO device_config (key, value) VALUES (?, ?)', [entry.key, entry.value]);
      }
    });
  }

  static Future<SavedSession?> restore() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('device_config', where: 'key IN (?, ?, ?)',
      whereArgs: ['auth_active_role', 'auth_household_id', 'auth_leader_id']);
    final values = {for (final row in rows) row['key'] as String: row['value']?.toString() ?? ''};
    int? valid(String key) {
      final id = int.tryParse((values[key] ?? '').trim());
      return id != null && id >= 0 ? id : null;
    }
    final household = valid('auth_household_id');
    final leader = valid('auth_leader_id');
    final role = values['auth_active_role'];
    if (role == 'household' && household != null) return SavedSession('household', household);
    if (role == 'leader' && leader != null) return SavedSession('leader', leader);
    // Migrate unambiguous existing sessions without guessing between two roles.
    if (household != null && leader == null) return SavedSession('household', household);
    if (leader != null && household == null) return SavedSession('leader', leader);
    if (household != null && leader != null) throw StateError('Choose your account role again from Profile.');
    return null;
  }

  static Future<void> clear() async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final key in ['auth_active_role', 'auth_household_id', 'auth_leader_id']) {
        await txn.rawInsert('INSERT OR REPLACE INTO device_config (key, value) VALUES (?, ?)', [key, '']);
      }
    });
    // Keep the device identity and each household's private saved plan.
  }
}
