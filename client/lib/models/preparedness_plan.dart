import 'dart:math';

String planningId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
String planningTime() => DateTime.now().toUtc().toIso8601String();

const evacuationChecks = <String, String>{
  'water': 'Drinking water and food packed',
  'medicine': 'Medicines, first aid and essential equipment ready',
  'documents': 'Important documents, keys and payment arrangements ready',
  'clothes': 'Clothing, sturdy shoes and personal hygiene items packed',
  'power': 'Phone, charger, backup power, torch and radio ready',
  'pets': 'Pets, carriers and supplies arranged',
  'transport': 'Transport and pickup arrangements confirmed',
  'meeting': 'Meeting point and emergency contacts agreed',
  'warnings': 'Ways to receive warnings and local evacuation advice checked',
};
const dwellingChecks = <String, String>{
  'loose': 'Loose outdoor furniture, bins and equipment secured',
  'drainage': 'Gutters, downpipes and drains checked and cleared safely',
  'roof': 'Roof, doors, windows and fences inspected; repairs arranged',
  'trees': 'Hazardous branches assessed; qualified help arranged where needed',
  'access': 'Exits, paths and vehicle access kept clear',
  'supplies': 'Essential supplies and communication arrangements ready',
  'local': 'Local hazard advice and household evacuation triggers reviewed',
};
const buildingChecks = <String, String>{
  'sites': 'Community buildings and responsible contacts identified',
  'loose': 'Loose outdoor items and equipment secured',
  'drainage': 'Gutters and drains checked; safe maintenance arranged',
  'repairs': 'Roofs, windows, doors and fences checked; repairs arranged',
  'trees': 'Tree and branch hazards assessed by appropriate people',
  'access': 'Accessible exits, paths and pickup areas kept clear',
  'supplies': 'Emergency supplies and communication arrangements reviewed',
  'local':
      'Local authority advice and building evacuation arrangements reviewed',
};
const checkOptions = <String, String>{
  'todo': 'Not yet complete',
  'done': 'Complete',
  'help': 'Need help',
  'na': 'Not applicable',
};
const presenceOptions = <String, String>{
  'unknown': 'Not confirmed',
  'onsite': 'Onsite — observed',
  'away': 'Away — confirmed',
  'help': 'Onsite — needs help',
};

class ChecklistProgress {
  ChecklistProgress(Map<String, String> tasks, Iterable<String> keys) {
    for (final key in keys) {
      final value = tasks[key] ?? 'todo';
      if (value == 'na') {
        excluded++;
        continue;
      }
      total++;
      if (value == 'done') done++;
      if (value == 'help') help++;
    }
  }
  int total = 0, done = 0, help = 0, excluded = 0;
  double get fraction => total == 0 ? 0 : done / total;
  int get percent => (fraction * 100).round();
  bool get complete => total > 0 && done == total;
}

class HouseholdPlan {
  HouseholdPlan(this.ownerId);
  final String ownerId;
  String community = '', family = '', updatedAt = '';
  String consentUpdatedAt = '', privacyNoticeVersion = '';
  int totalMembers = 1;
  List<Map<String, dynamic>> members = [];
  Map<String, String> evacuation = {}, dwelling = {};
  String? recipientId;
  String sharedLabel = '';
  bool shareSummary = false, shareResidents = false;
  ChecklistProgress get evacuationProgress =>
      ChecklistProgress(evacuation, evacuationChecks.keys);
  ChecklistProgress get dwellingProgress =>
      ChecklistProgress(dwelling, dwellingChecks.keys);
  ChecklistProgress get progress => ChecklistProgress(
    {
      ...evacuation,
      ...{for (final e in dwelling.entries) 'home_${e.key}': e.value},
    },
    [...evacuationChecks.keys, ...dwellingChecks.keys.map((k) => 'home_$k')],
  );
  bool get setupComplete =>
      family.trim().isNotEmpty &&
      community.trim().isNotEmpty &&
      totalMembers > 0 &&
      members.length == totalMembers;
  String get status => updatedAt.isEmpty
      ? 'Not started'
      : setupComplete && progress.complete
      ? 'Complete'
      : 'Incomplete';
  Map<String, dynamic> toJson() => {
    'version': 1,
    'ownerId': ownerId,
    'community': community,
    'family': family,
    'totalMembers': totalMembers,
    'members': members,
    'evacuation': evacuation,
    'dwelling': dwelling,
    'updatedAt': updatedAt,
    'recipientId': recipientId,
    'sharedLabel': sharedLabel,
    'shareSummary': shareSummary,
    'shareResidents': shareResidents,
    'consentUpdatedAt': consentUpdatedAt,
    'privacyNoticeVersion': privacyNoticeVersion,
  };
  factory HouseholdPlan.fromJson(Map<String, dynamic> j) {
    final p = HouseholdPlan(j['ownerId'] as String);
    p.community = j['community'] ?? '';
    p.family = j['family'] ?? '';
    p.totalMembers = j['totalMembers'] ?? 1;
    p.members = (j['members'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    p.evacuation = Map<String, String>.from(j['evacuation'] ?? {});
    p.dwelling = Map<String, String>.from(j['dwelling'] ?? {});
    p.updatedAt = j['updatedAt'] ?? '';
    p.recipientId = j['recipientId'];
    p.sharedLabel = j['sharedLabel'] ?? '';
    p.shareSummary = j['shareSummary'] == true;
    p.shareResidents = j['shareResidents'] == true;
    p.consentUpdatedAt = j['consentUpdatedAt'] ?? '';
    p.privacyNoticeVersion = j['privacyNoticeVersion'] ?? '';
    return p;
  }

  /// Whitelist projection: private contacts and checklist answers never leave here.
  Map<String, dynamic>? communityProjection() {
    if ((!shareSummary && !shareResidents) ||
        recipientId == null ||
        sharedLabel.trim().isEmpty)
      return null;
    return {
      'ownerId': ownerId,
      'recipientId': recipientId,
      'label': sharedLabel.trim(),
      'updatedAt': updatedAt,
      if (shareSummary) ...{
        'status': status,
        'percent': progress.percent,
        'evacuationPercent': evacuationProgress.percent,
        'dwellingPercent': dwellingProgress.percent,
      },
      if (shareResidents) ...{
        'totalMembers': totalMembers,
        'residents': [
          for (final m in members) {'id': m['id'], 'name': m['name']},
        ],
      },
    };
  }
}

class CommunityPlan {
  CommunityPlan(this.ownerId);
  final String ownerId;
  String name = '', updatedAt = '', eventLabel = '', rollSession = '';
  Map<String, String> building = {};
  List<Map<String, dynamic>> buildings = [], residents = [], guests = [];
  Map<String, dynamic> observations = {};
  ChecklistProgress get progress => ChecklistProgress(building, [
    for (final b in buildings)
      for (final key in buildingChecks.keys) '${b['id']}:$key',
  ]);
  List<Map<String, dynamic>> get currentGuests => rollSession.isEmpty
      ? []
      : guests.where((guest) => guest['session'] == rollSession).toList();

  String presenceFor(String residentId) {
    final record = observations[residentId];
    return record is Map &&
            rollSession.isNotEmpty &&
            record['session'] == rollSession
        ? record['status'] as String
        : 'unknown';
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'ownerId': ownerId,
    'name': name,
    'updatedAt': updatedAt,
    'building': building,
    'buildings': buildings,
    'residents': residents,
    'guests': guests,
    'eventLabel': eventLabel,
    'rollSession': rollSession,
    'observations': observations,
  };
  factory CommunityPlan.fromJson(Map<String, dynamic> j) {
    final p = CommunityPlan(j['ownerId'] as String);
    p.name = j['name'] ?? '';
    p.updatedAt = j['updatedAt'] ?? '';
    p.building = Map<String, String>.from(j['building'] ?? {});
    p.buildings = (j['buildings'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    p.residents = (j['residents'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    p.guests = (j['guests'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    p.eventLabel = j['eventLabel'] ?? '';
    p.rollSession = j['rollSession'] ?? '';
    p.observations = Map<String, dynamic>.from(j['observations'] ?? {});
    return p;
  }
}
