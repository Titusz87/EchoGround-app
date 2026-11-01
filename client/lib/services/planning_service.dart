import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:sqflite/sqflite.dart';

import '../models/preparedness_plan.dart';
import 'database_helper.dart';

/// Local prototype adapter. No invented API routes or changes to auth services.
/// Replace this adapter with approved server-side membership/plan APIs later.
class PlanningService {
  PlanningService._();
  static final instance = PlanningService._();
  static const previewMode =
      kDebugMode && bool.fromEnvironment('ECHOGROUND_PLANNING_PREVIEW');
  // Isolated, fictional data only. No real login flags, SQLite rows or API calls.
  final Map<String, Map<String, dynamic>> _preview = {};
  Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
  Future<Database> get _db async {
    if (previewMode)
      throw StateError('Database access is disabled in design preview.');
    final db = await DatabaseHelper.instance.database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS echoground_planning (document_key TEXT PRIMARY KEY, kind TEXT NOT NULL, owner_id TEXT NOT NULL, value TEXT NOT NULL)',
    );
    return db;
  }

  Future<String> currentOwner(bool leader) async {
    if (previewMode) return leader ? 'preview-leader' : 'preview-household';
    final id = await DatabaseHelper.instance.getConfig(
      leader ? 'auth_leader_id' : 'auth_household_id',
    );
    if (id == null || id.isEmpty)
      throw StateError('Sign in to open your planning workspace.');
    return id;
  }

  Future<void> _checkOwner(String id, bool leader) async {
    if (await currentOwner(leader) != id)
      throw StateError('The account changed. Reopen your plan.');
  }

  Future<Map<String, dynamic>?> _read(String key) async {
    if (previewMode)
      return _preview[key] == null ? null : _clone(_preview[key]!);
    final rows = await (await _db).query(
      'echoground_planning',
      where: 'document_key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(rows.first['value'] as String));
  }

  Future<HouseholdPlan> loadHousehold(String id) async {
    await _checkOwner(id, false);
    final j = await _read('household:$id');
    return j == null ? HouseholdPlan(id) : HouseholdPlan.fromJson(j);
  }

  Future<CommunityPlan> loadCommunity(String id) async {
    await _checkOwner(id, true);
    final j = await _read('community:$id');
    return j == null ? CommunityPlan(id) : CommunityPlan.fromJson(j);
  }

  Future<void> saveHousehold(HouseholdPlan p) async {
    await _checkOwner(p.ownerId, false);
    if (p.members.length > p.totalMembers)
      throw StateError(
        'Total family members cannot be less than listed names.',
      );
    if ((p.shareResidents || p.shareSummary) &&
        (p.recipientId == null || p.sharedLabel.trim().isEmpty)) {
      throw StateError(
        'Choose a community workspace and shared label before sharing.',
      );
    }
    final previous = p.updatedAt;
    p.updatedAt = planningTime();
    try {
      if (previewMode) {
        _preview['household:${p.ownerId}'] = _clone(p.toJson());
        final summary = p.communityProjection();
        if (summary == null) {
          _preview.remove('summary:${p.ownerId}');
        } else {
          _preview['summary:${p.ownerId}'] = _clone(summary);
        }
        return;
      }
      final db = await _db;
      await db.transaction((txn) async {
        await txn.insert('echoground_planning', {
          'document_key': 'household:${p.ownerId}',
          'kind': 'household',
          'owner_id': p.ownerId,
          'value': jsonEncode(p.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        final projection = p.communityProjection();
        if (projection == null) {
          await txn.delete(
            'echoground_planning',
            where: 'document_key = ?',
            whereArgs: ['summary:${p.ownerId}'],
          );
        } else {
          await txn.insert('echoground_planning', {
            'document_key': 'summary:${p.ownerId}',
            'kind': 'summary',
            'owner_id': p.ownerId,
            'value': jsonEncode(projection),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (_) {
      p.updatedAt = previous;
      rethrow;
    }
  }

  Future<void> saveCommunity(CommunityPlan p) async {
    await _checkOwner(p.ownerId, true);
    final previous = p.updatedAt;
    p.updatedAt = planningTime();
    try {
      if (previewMode) {
        _preview['community:${p.ownerId}'] = _clone(p.toJson());
        return;
      }
      await (await _db).insert('echoground_planning', {
        'document_key': 'community:${p.ownerId}',
        'kind': 'community',
        'owner_id': p.ownerId,
        'value': jsonEncode(p.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      p.updatedAt = previous;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> communityChoices() async {
    await currentOwner(false);
    if (previewMode)
      return [
        for (final e in _preview.entries)
          if (e.key.startsWith('community:') &&
              (e.value['name'] as String).trim().isNotEmpty)
            {'id': e.value['ownerId'], 'name': e.value['name']},
      ];
    final rows = await (await _db).query(
      'echoground_planning',
      where: 'kind = ?',
      whereArgs: ['community'],
    );
    return [
      for (final r in rows)
        if ((jsonDecode(r['value'] as String)['name'] as String)
            .trim()
            .isNotEmpty)
          {
            'id': r['owner_id'],
            'name': jsonDecode(r['value'] as String)['name'],
          },
    ];
  }

  Future<List<Map<String, dynamic>>> summaries(String leaderId) async {
    await _checkOwner(leaderId, true);
    if (previewMode)
      return [
        for (final e in _preview.entries)
          if (e.key.startsWith('summary:') &&
              e.value['recipientId'] == leaderId)
            _clone(e.value),
      ];
    final rows = await (await _db).query(
      'echoground_planning',
      where: 'kind = ?',
      whereArgs: ['summary'],
    );
    return rows
        .map((r) => Map<String, dynamic>.from(jsonDecode(r['value'] as String)))
        .where((r) => r['recipientId'] == leaderId)
        .toList();
  }

  Future<void> deleteHouseholdPlan(String id) async {
    await _checkOwner(id, false);
    if (previewMode) {
      _preview.remove('household:$id');
      _preview.remove('summary:$id');
      return;
    }
    await (await _db).transaction((txn) async {
      for (final key in ['household:$id', 'summary:$id']) {
        await txn.delete(
          'echoground_planning',
          where: 'document_key = ?',
          whereArgs: [key],
        );
      }
    });
  }

  Future<void> clearRollRecords(String id) async {
    final p = await loadCommunity(id);
    p.residents = [];
    p.guests = [];
    p.observations = {};
    p.rollSession = '';
    p.eventLabel = '';
    await saveCommunity(p);
  }

  /// Close the app's cached planning access, without deleting device registration
  /// or pretending to revoke a server-side session.
  Future<void> closePlanningAccess() async {
    if (previewMode) return;
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final key in ['auth_household_id', 'auth_leader_id']) {
        await txn.insert('device_config', {
          'key': key,
          'value': '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
