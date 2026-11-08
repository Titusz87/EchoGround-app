import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_helper.dart';

/// Private, account-scoped checklist. Does not transmit household information.
class HouseholdChecklist extends StatefulWidget {
  const HouseholdChecklist({super.key});
  @override
  State<HouseholdChecklist> createState() => _HouseholdChecklistState();
}

class _HouseholdChecklistState extends State<HouseholdChecklist> {
  int step = -1;
  final checklistTop = GlobalKey();
  Timer? autosaveTimer;
  bool closing = false;
  int editVersion = 0;
  bool dirty = false;
  String? saveError;

  void changed(VoidCallback update) {
    setState(() { update(); editVersion++; dirty = true; saveError = null; });
    autosaveTimer?.cancel();
    autosaveTimer = Timer(const Duration(milliseconds: 700), () => save(quiet: true));
  }

  bool sectionDone(int index) {
    bool done(Map<String, String> items) => items.keys.every((id) => answers[id] == 'done' || answers[id] == 'na');
    switch (index) {
      case 0: return setupComplete;
      case 1: return done(supplies) && activeMedicines.every((m) => ['done', 'na'].contains(answers['medication.${m['id']}'])) && (fields['pets'] != 'yes' || done(petTasks));
      case 2: return transportComplete && ['destination', 'alternative'].every((id) => (fields[id] ?? '').trim().isNotEmpty && fields['$id.confirmed'] == 'yes') && ['meeting', 'contacts'].every((id) => (fields[id] ?? '').trim().isNotEmpty) && done(arrangements);
      case 3: return done(dwelling) && dwelling.keys.where((id) => answers[id] != 'na').every((id) => members.any((m) => m['id'] == fields['assigned.$id']));
      default: return complete;
    }
  }
  void goToStep(int next) {
    // Release the old field so keyboard focus cannot scroll the new step down.
    FocusScope.of(context).unfocus();
    setState(() => step = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = checklistTop.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0, duration: Duration.zero);
    });
  }
  int? owner;
  bool loading = true;
  bool saving = false;
  String? error;
  String? savedAt;
  Map<String, String> fields = {};
  List<Map<String, String>> members = [];
  Map<String, String> answers = {};
  List<String> vehicles = [];
  List<Map<String, String>> medications = [];
  Iterable<Map<String, String>> medicinesFor(String memberId) => medications.where((m) => m['member_id'] == memberId);
  Iterable<Map<String, String>> get activeMedicines => medications.where((m) => members.any((person) => person['id'] == m['member_id'] && person['medication'] == 'yes'));
  bool get membersValid => members.every((m) =>
    (m['name'] ?? '').trim().isNotEmpty && ['yes', 'no'].contains(m['medication']) &&
    (m['medication'] != 'yes' || medicinesFor(m['id']!).isNotEmpty));

  @override
  void dispose() {
    closing = true;
    autosaveTimer?.cancel();
    if (dirty && !saving) unawaited(save(quiet: true, background: true));
    super.dispose();
  }

  Future<void> editMember([Map<String, String>? existing]) async {
    final id = existing?['id'] ?? 'member.${DateTime.now().microsecondsSinceEpoch}.${members.length}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (_) => _HouseholdMemberDialog(
        member: existing ?? {'id': id, 'name': '', 'phone': '', 'medication': 'unknown'},
        medicines: medicinesFor(id).map((m) => Map<String, String>.from(m)).toList(),
      ),
    );
    if (!mounted || result == null) return;
    changed(() {
      final person = Map<String, String>.from(result['member'] as Map);
      final newMedicines = (result['medicines'] as List).map((m) => Map<String, String>.from(m as Map)).toList();
      final removed = medicinesFor(id).where((m) => !newMedicines.any((n) => n['id'] == m['id'])).map((m) => 'medication.${m['id']}').toSet();
      answers.removeWhere((key, value) => removed.contains(key));
      medications.removeWhere((m) => m['member_id'] == id);
      medications.addAll(newMedicines);
      if (existing == null) { members.add(person); }
      else { members[members.indexWhere((m) => m['id'] == id)] = person; }
    });
    await save(quiet: true);
  }

  static const steps = ['Household', 'Supplies', 'Evacuation', 'Dwelling', 'Review'];
  static const sectionDescriptions = [
    'Family, members, medication and pets',
    'Water, food, family medication, documents and essential items',
    'Destinations, transport, drivers, seats and contacts',
    'Outside preparation and task responsibilities',
    'Outstanding tasks, review date and results',
  ];
  static const supplies = {
    'water': 'Drinking water', 'food': 'Suitable food',
    'medication': 'Medication and essential medical equipment',
    'first_aid': 'First-aid kit', 'torch': 'Torch, radio and batteries',
    'charging': 'Phone charging equipment', 'documents': 'Important documents',
    'clothing': 'Clothing and hygiene supplies',
    'individual': 'Supplies for children, pets and individual needs',
  };
  static const dwelling = {
    'hazards': 'Check the outside of the home for hazards',
    'loose_items': 'Identify loose items requiring securing',
    'exits': 'Check access paths and exits',
    'local_tasks': 'Identify preparation tasks for local hazards',
    'responsibility': 'Assign responsibility for dwelling preparation',
  };
  static const arrangements = {
    'destination_checked': 'Confirm a destination and an alternative',
    'transport_checked': 'Confirm transport, drivers and available seats',
    'support_checked': 'Identify people needing transport assistance',
    'meeting_checked': 'Confirm a family meeting point and emergency contacts',
    'warnings_checked': 'Confirm where to obtain official warnings and directions',
  };
  static const review = {
    'unfinished': 'Review unfinished items and assistance requests',
    'understood': 'Confirm household members understand the arrangements',
    'reviewed': 'Review the checklist following any household changes',
  };
  static const statuses = {
    'todo': 'Not started', 'done': 'Complete',
    'help': 'Assistance needed', 'na': 'Not applicable',
  };
  Iterable<String> get itemIds => [...supplies.keys, ...arrangements.keys, ...dwelling.keys, ...review.keys, for (final m in activeMedicines) 'medication.${m['id']}', if (fields['pets'] == 'yes') ...petTasks.keys];
  int get applicable => itemIds.where((id) => answers[id] != 'na').length;
  int get completed => itemIds.where((id) => answers[id] == 'done').length;
  int get assistance => itemIds.where((id) => answers[id] == 'help').length;
  int get count => members.length;
  int get registeredMemberCount => int.tryParse(fields['registration_count'] ?? '') ?? 0;
  int get addedMemberCount => members.where((m) => (m['name'] ?? '').trim().isNotEmpty).length;
  int get remainingMemberCount {
    final remaining = registeredMemberCount - addedMemberCount;
    return remaining > 0 ? remaining : 0;
  }
  bool get setupComplete => (fields['family'] ?? '').trim().isNotEmpty &&
    count > 0 &&
    remainingMemberCount == 0 && membersValid && ['yes', 'no'].contains(fields['pets']) && (fields['pets'] != 'yes' || ((int.tryParse(fields['pet_count'] ?? '') ?? 0) > 0 && (fields['pet_details'] ?? '').trim().isNotEmpty));
  int get seatCount => vehicles.fold(0, (total, id) => total + (int.tryParse(fields['seats.$id'] ?? '') ?? 0));
  bool get duplicateDrivers {
    final drivers = vehicles.map((id) => fields['driver.$id']).where((id) => id != null && id != '' && id != 'other').toList();
    return drivers.toSet().length != drivers.length;
  }
  bool get transportComplete {
    if (fields['transport_mode'] == 'community') return (fields['community_transport'] ?? '').trim().isNotEmpty && fields['community_transport_confirmed'] == 'yes';
    if (!['own', 'lift'].contains(fields['transport_mode']) || vehicles.isEmpty || duplicateDrivers || seatCount < count) return false;
    return vehicles.every((id) {
      final driver = fields['driver.$id'];
      final validDriver = driver == 'other' ? (fields['driver_other.$id'] ?? '').trim().isNotEmpty : members.any((m) => m['id'] == driver);
      return validDriver && (fields['vehicle.$id'] ?? '').trim().isNotEmpty && (int.tryParse(fields['seats.$id'] ?? '') ?? 0) > 0 && fields['vehicle_confirmed.$id'] == 'yes';
    });
  }
  bool get detailsComplete =>
    ['destination', 'alternative', 'meeting', 'contacts'].every((key) => (fields[key] ?? '').trim().isNotEmpty) &&
    fields['destination.confirmed'] == 'yes' && fields['alternative.confirmed'] == 'yes' && transportComplete && reviewDate() != null &&
    dwelling.keys.where((id) => answers[id] != 'na').every((id) => members.any((m) => m['id'] == fields['assigned.$id']));
  bool get complete => setupComplete && detailsComplete && applicable > 0 && completed == applicable;
  int get completionPercentage {
    if (complete) return 100;
    if (applicable == 0) return 0;
    final value = (completed * 100 / applicable).round();
    return value >= 100 ? 99 : value;
  }

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    var stage = 'session';
    try {
      final db = DatabaseHelper.instance;
      final id = int.tryParse(await db.getConfig('auth_household_id') ?? '');
      if (id == null || id < 0) {
        if (mounted) setState(() {
          loading = false;
          error = 'No valid household session. Open Profile and sign in as Household.';
        });
        return;
      }
      stage = 'checklist storage';
      final raw = await db.getConfig('household_checklist.v1.$id');
      if (raw != null && raw.isNotEmpty) {
        stage = 'saved checklist format';
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final loadedFields = Map<String, String>.from(json['fields'] as Map);
        final loadedMembers = (json['members'] as List).map((m) => Map<String, String>.from(m as Map)).toList();
        final loadedAnswers = Map<String, String>.from(json['answers'] as Map);
        if (loadedAnswers.values.any((s) => !statuses.containsKey(s))) throw FormatException('Invalid status');
        fields = loadedFields; members = loadedMembers; answers = loadedAnswers;
        savedAt = json['saved_at'] as String?;
        vehicles = List<String>.from(json['vehicles'] ?? []);
        medications = (json['medications'] as List? ?? []).map((m) => Map<String, String>.from(m as Map)).toList();
        for (var i = 0; i < members.length; i++) {
          members[i].putIfAbsent('id', () => 'legacy.$i');
          members[i].putIfAbsent('medication', () => 'unknown');
        }
      }
      stage = 'household profile';
      // Fill gaps only. Never replace a household's existing checklist entries.
      Map<String, dynamic> profile = {};
      final profileRaw = await db.getConfig('household_profile.v1.$id');
      if (profileRaw != null && profileRaw.isNotEmpty) {
        try { profile = Map<String, dynamic>.from(jsonDecode(profileRaw) as Map); } catch (_) {}
      }
      // Legacy registration cached name/count on the registered device only.
      if (await db.getConfig('backend_person_id') == id.toString()) {
        profile.putIfAbsent('family', () => '');
        if ((profile['family']?.toString() ?? '').trim().isEmpty) {
          profile['family'] = await db.getConfig('household_last_name') ?? '';
        }
        profile.putIfAbsent('count', () => '');
        if (int.tryParse(profile['count'].toString()) == null) {
          profile['count'] = await db.getConfig('household_count') ?? '';
        }
      }
      bool imported = false;
      for (final key in ['family', 'community']) {
        final value = profile[key]?.toString().trim() ?? '';
        if ((fields[key] ?? '').trim().isEmpty && value.isNotEmpty && value != 'Unknown') {
          fields[key] = value; imported = true;
        }
      }
      final registeredCount = int.tryParse(profile['count']?.toString() ?? '') ?? 0;
      if (registeredCount > 0 && fields['registration_count_imported'] != 'yes') {
        fields['registration_count'] = registeredCount.toString();
        // Keep the signup total as a target; add actual members through the form.
        fields['registration_count_imported'] = 'yes';
        imported = true;
      }
      stage = 'session check';
      if (await db.getConfig('auth_household_id') != id.toString()) throw StateError('Account changed');
      if (mounted) setState(() { owner = id; loading = false; error = null; });
      if (imported && mounted) { dirty = true; editVersion++; await save(quiet: true); }
    } catch (failure) {
      debugPrint('Household checklist load failed at $stage (${failure.runtimeType}).');
      if (mounted) setState(() {
        loading = false;
        error = stage == 'saved checklist format'
            ? 'The saved checklist format could not be read. Your saved data has been kept.'
            : stage == 'session check'
                ? 'The household session could not be verified. Sign in again from Profile.'
                : 'Could not read local $stage. Select Retry to try again.';
      });
    }
  }

  Future<void> save({bool quiet = false, bool background = false}) async {
    if (saving || owner == null) return;
    autosaveTimer?.cancel();
    if (mounted && !background && !closing) { setState(() => saving = true); } else { saving = true; }
    var savedVersion = editVersion;
    try {
      final db = DatabaseHelper.instance;
      if (await db.getConfig('auth_household_id') != owner.toString()) throw StateError('Account changed');
      savedVersion = editVersion;
      final now = DateTime.now().toUtc().toIso8601String();
      final privatePlan = jsonEncode({
        'version': 1, 'fields': fields, 'members': members,
        'answers': answers, 'saved_at': now, 'vehicles': vehicles, 'medications': medications,
      });
      // This restricted summary is local only, awaiting the documented API.
      // No names, medicines, phone numbers, destinations or answers are included.
      final summary = jsonEncode({
        'household_id': owner,
        'status': complete ? 'complete' : 'incomplete',
        'percentage': completionPercentage,
        'updated_at': now,
      });
      final database = await db.database;
      await database.transaction((txn) async {
        await txn.rawInsert('INSERT OR REPLACE INTO device_config (key, value) VALUES (?, ?)', ['household_checklist.v1.$owner', privatePlan]);
        await txn.rawInsert('INSERT OR REPLACE INTO device_config (key, value) VALUES (?, ?)', ['household_checklist.summary.v1.$owner', summary]);
      });
      void saved() { savedAt = now; dirty = editVersion != savedVersion; saveError = null; }
      if (mounted && !background && !closing) { setState(saved); } else { saved(); }
      if (mounted && !closing && !quiet) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist saved privately on this device.')));
    } catch (_) {
      void failed() { saveError = 'Could not save on this device. Your entries remain open. Select Retry save.'; }
      if (mounted && !background && !closing) { setState(failed); } else { failed(); }
      if (mounted && !closing && !quiet) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saveError!)));
    } finally {
      if (mounted && !background && !closing) { setState(() => saving = false); } else { saving = false; }
      if (dirty && saveError == null) unawaited(save(quiet: true, background: closing || !mounted));
    }
  }

  Widget field(String id, String label, {TextInputType? keyboard, int lines = 1, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('field.$id'), initialValue: fields[id] ?? '',
      enabled: !saving, keyboardType: keyboard, minLines: lines, maxLines: lines,
      inputFormatters: keyboard == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label, helperText: hint, helperMaxLines: 5, border: const OutlineInputBorder(), alignLabelWithHint: lines > 1),
      onChanged: (value) => changed(() => fields[id] = value),
    ),
  );

  Widget choice(String id, String label, Map<String, String> options) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: options.length == 2 && options.containsKey('yes') && options.containsKey('no')
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _CompactYesNo(
              value: fields[id],
              onChanged: saving ? null : (value) => changed(() => fields[id] = value),
            ),
          ])
        : DropdownButtonFormField<String>(
            key: ValueKey('choice.$id.${fields[id]}'),
            value: options.containsKey(fields[id]) ? fields[id] : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            hint: const Text('Select an option'),
            items: options.entries.map((entry) => DropdownMenuItem<String>(
              value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: saving ? null : (value) { if (value != null) changed(() => fields[id] = value); },
          ),
  );

  Widget memberChoice(String id, String label, {bool allowOther = false}) {
    final options = <String, String>{
      '': 'Not assigned yet',
      for (final member in members)
        member['id']!: (member['name'] ?? '').trim().isEmpty ? 'Unnamed member' : member['name']!,
      if (allowOther) 'other': 'Someone outside the household',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey('assignment.$id.${fields[id]}'),
        value: options.containsKey(fields[id]) ? fields[id] : '',
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: options.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: saving ? null : (value) => changed(() => fields[id] = value!),
      ),
    );
  }

  Widget note(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
  );

  static const explanations = {
    'water': 'Store sealed drinking water. The three-day baseline is 10 litres per person in total; allow extra for pets, heat, medical needs and longer isolation.',
    'food': 'Pack non-perishable food for three days that your household normally eats, including dietary and baby needs. Include a manual can opener and utensils. No fixed food weight suits everyone.',
    'medication': 'Include essential medication, prescriptions and required medical equipment. Check storage and supply needs with a pharmacist; do not change prescribed doses.',
    'first_aid': 'Pack a first-aid kit suitable for your household and check its contents and expiry dates.',
    'torch': 'Have a torch or headlamp for each person where possible, a battery-powered radio and matching spare batteries.',
    'charging': 'Pack phone cables, chargers and charged power banks compatible with the phones you use.',
    'documents': 'Examples: driver licence or other ID, Medicare card, passports, birth certificates, insurance details, emergency contacts and your plan. Keep copies protected from water; no document upload is needed here.',
    'clothing': 'Pack practical protective clothing, sturdy shoes, hygiene products and bedding appropriate to local conditions.',
    'individual': 'Include items for babies, disability or communication needs and personal comfort; use the pet checks below when you have pets.',
    'destination_checked': 'Confirm that both places can receive your household. A planned place is not confirmation that an evacuation centre is open.',
    'transport_checked': 'Confirm each vehicle, driver and usable seat. Include child restraints and mobility needs; do not count the same seat or driver twice.',
    'support_checked': 'Confirm how anyone without transport or needing assistance will travel.',
    'meeting_checked': 'Choose a place to reunite if separated and record a contact who can help.',
    'warnings_checked': 'Use official local warnings, road information and instructions. These planning choices do not provide safe-route guidance.',
    'hazards': 'Identify outside hazards while conditions are safe. Avoid powerlines, floodwater and other dangerous areas.',
    'loose_items': 'Identify items that need securing before severe weather, only when it is safe to do so.',
    'exits': 'Keep access paths and exits clear and consider mobility needs.',
    'local_tasks': 'Identify extra tasks appropriate to the hazards affecting your dwelling.',
    'responsibility': 'Confirm that everyone knows their preparation tasks. Do not delay evacuation to finish them.',
    'unfinished': 'Check unfinished tasks and requests for help before recording the review.',
    'understood': 'Discuss the plan in a way every household member can understand.',
    'reviewed': 'Recheck arrangements when people, transport, destinations or emergency conditions change.',
  };

  Widget tasks(Map<String, String> items, {bool assign = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final item in items.entries)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(item.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (explanations[item.key] != null) note(explanations[item.key]!),
            if (assign) memberChoice('assigned.${item.key}', 'Who will complete this task'),
            DropdownButtonFormField<String>(
              key: ValueKey('status.${item.key}.${answers[item.key]}'),
              value: answers[item.key] ?? 'todo',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: statuses.entries.map((status) => DropdownMenuItem<String>(
                value: status.key, child: Text(status.value, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: saving ? null : (value) { if (value != null) changed(() => answers[item.key] = value); },
            ),
          ]),
        ),
    ],
  );

  void removeMember(int index) {
    final id = members[index]['id'];
    changed(() {
      members.removeAt(index);
      final removed = medications.where((m) => m['member_id'] == id).map((m) => 'medication.${m['id']}').toSet();
      medications.removeWhere((m) => m['member_id'] == id);
      answers.removeWhere((key, value) => removed.contains(key));
      fields.removeWhere((key, value) => value == id && (key.startsWith('assigned.') || key.startsWith('driver.')));
    });
  }

  List<Widget> household() => [
    const Text('Who is in your household?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    note('Add the people you are planning for.'),
    field('family', 'Family name'),
    const Text('Household members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    for (var i = 0; i < members.length; i++)
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text((members[i]['name'] ?? '').isEmpty ? 'Member ${i + 1} — add details' : members[i]['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(members[i]['medication'] == 'yes' ? '${medicinesFor(members[i]['id']!).length} medication(s) recorded' : members[i]['medication'] == 'no' ? 'No medication' : 'Medication answer needed', style: const TextStyle(color: Colors.white70)),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: saving ? null : () => editMember(members[i]), child: const Text('Edit member')),
          TextButton(onPressed: saving ? null : () async {
            final remove = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
              title: const Text('Remove household member?'), content: const Text('Their medication entries and task assignments will also be removed.'),
              actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove'))],
            ));
            if (mounted && remove == true) removeMember(i);
          }, child: const Text('Remove')),
        ]),
      ]))),
    OutlinedButton.icon(onPressed: saving ? null : () => editMember(), icon: const Icon(Icons.person_add_outlined), label: const Text('Add household member')),
    const SizedBox(height: 12),
    if (registeredMemberCount > 0) ...[
      Text('Household size: $registeredMemberCount'),
      const SizedBox(height: 6),
      Text('$addedMemberCount added · $remainingMemberCount remaining', style: const TextStyle(fontWeight: FontWeight.bold)),
      if (remainingMemberCount == 0) note('Everyone in the signup household count has been added.'),
    ] else Text('$addedMemberCount household member(s) added'),
    if (members.any((m) => (m['name'] ?? '').trim().isEmpty)) note('Select Edit member to complete any existing unnamed entries.'),
    const SizedBox(height: 16),
    choice('pets', 'Do you have pets?', const {'yes': 'Yes', 'no': 'No'}),
    if (fields['pets'] == 'yes') ...[
      field('pet_count', 'Number of pets', keyboard: TextInputType.number),
      field('pet_details', 'Pet types and needs', lines: 2, hint: 'For example: two dogs, carriers, food and transport needs.'),
    ],
    note('Medication details stay in your private household checklist on this device.'),
  ];

  Widget guideBullet(String title, List<String> details) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('• $title', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      for (final detail in details)
        Padding(padding: const EdgeInsets.only(left: 18, bottom: 6), child: Text('• $detail', style: const TextStyle(color: Colors.white70, fontSize: 13))),
    ]),
  );

  Widget supplyGuide() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Three-day guide for $count people', style: const TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    if (count > 0) ...[
      guideBullet('Drinking water', [
        'At least ${count * 10} litres total: 10 litres per person for three days.',
        if (fields['pets'] == 'yes') 'Allow extra drinking water for your animals, based on their size, species and usual needs.',
      ]),
      guideBullet('Food', [
        'Three days of suitable non-perishable food for $count people.',
        'Planning example: ${count * 9} meal portions if allowing three meals per person per day. Adjust for actual appetites, dietary and baby needs.',
        'Include a manual can opener and utensils.',
        if (fields['pets'] == 'yes') 'Pack additional suitable pet food.',
      ]),
      guideBullet('Torches', ['Aim for $count torches or headlamps: one per person where possible.', 'Include matching spare batteries and a battery-powered radio.']),
      guideBullet('Phones and charging', ['Pack compatible cables, chargers and charged power banks for the phones you rely on.']),
    ] else note('Add household members in Step 1 to calculate quantities.'),
    note('This is a baseline for a household emergency kit, not a limit. Allow extra for heat, medical needs and longer isolation, and follow local emergency advice.'),
    const SelectableText('Guidance: Queensland SES — ses.qld.gov.au/pack-your-emergency-kit (checked 4 Nov 2026)', style: TextStyle(color: Colors.white54, fontSize: 12)),
    const SizedBox(height: 18),
  ]);

  static const petTasks = {
    'pet_food': 'Pet food and water ready',
    'pet_transport': 'Pet carriers, leads and transport ready',
    'pet_health': 'Pet medication, identification and records ready (if needed)',
  };

  Widget medicationChecks() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Family medication', style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    for (final member in members.where((m) => m['medication'] == 'yes')) ...[
      Text((member['name'] ?? '').trim().isEmpty ? 'Unnamed member' : member['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
      if (medicinesFor(member['id']!).isEmpty) note('Add this member’s medication names in Step 1.'),
      tasks({for (final medicine in medicinesFor(member['id']!)) 'medication.${medicine['id']}': medicine['name']!}),
    ],
  ]);

  Widget destination(String prefix, String label) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12),
    choice('$prefix.type', 'What kind of place?', const {
      'family': 'Family or friends', 'community': 'Community-arranged location',
      'centre': 'Official evacuation centre', 'other': 'Another agreed place', 'unknown': 'I need help choosing',
    }),
    field(prefix, 'Place name and address', lines: 2),
    choice('$prefix.confirmed', 'Has this place been confirmed?', const {'unknown': 'Not confirmed yet', 'yes': 'Yes', 'no': 'No / need help'}),
  ]);

  Widget transport() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    choice('transport_mode', 'How will your household travel?', const {
      'own': 'Our household vehicle(s)', 'lift': 'A confirmed lift',
      'community': 'Community-arranged transport', 'help': 'We need transport help',
    }),
    if (fields['transport_mode'] == 'own' || fields['transport_mode'] == 'lift') ...[
      for (var i = 0; i < vehicles.length; i++) ...[
        Text('Vehicle ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
        field('vehicle.${vehicles[i]}', 'Vehicle name / description'),
        memberChoice('driver.${vehicles[i]}', 'Driver', allowOther: true),
        if (fields['driver.${vehicles[i]}'] == 'other') field('driver_other.${vehicles[i]}', 'Driver name and contact'),
        field('seats.${vehicles[i]}', 'Usable seats for our household', keyboard: TextInputType.number, hint: 'Include the driver if they are a household member. Exclude seats occupied by people outside this household.'),
        choice('vehicle_confirmed.${vehicles[i]}', 'Driver and vehicle confirmed?', const {'unknown': 'Not confirmed yet', 'yes': 'Yes', 'no': 'No / need help'}),
        TextButton(onPressed: saving ? null : () => changed(() => vehicles.removeAt(i)), child: const Text('Remove vehicle')),
      ],
      OutlinedButton.icon(onPressed: saving ? null : () => changed(() => vehicles.add('vehicle.${DateTime.now().microsecondsSinceEpoch}.${vehicles.length}')), icon: const Icon(Icons.add), label: const Text('Add vehicle')),
      const SizedBox(height: 12),
      Text('$seatCount usable seats for $count household members.'),
      if (seatCount < count) note('${count - seatCount} more seat(s) or another transport arrangement needed.'),
      if (duplicateDrivers) note('The same household driver is assigned to more than one vehicle. Confirm separate drivers.'),
    ],
    if (fields['transport_mode'] == 'community') ...[
      field('community_transport', 'Transport contact / pickup details', lines: 3),
      choice('community_transport_confirmed', 'Places for everyone confirmed?', const {'unknown': 'Not confirmed yet', 'yes': 'Yes', 'no': 'No / need help'}),
    ],
    if (fields['transport_mode'] == 'help') field('transport_help', 'What help is needed?', lines: 3),
    if ((fields['transport'] ?? '').isNotEmpty) note('Previously saved transport notes: ${fields['transport']}'),
    field('travel_needs', 'Child restraints, mobility or pet needs (optional)', lines: 3, hint: 'Leave blank if no additional arrangements are needed.'),
  ]);

  DateTime? reviewDate() {
    final value = fields['review_date'] ?? '';
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]), month = int.tryParse(parts[1]), year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month && date.year == year ? date : null;
  }

  Future<void> pickReviewDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(2000);
    final last = DateTime(2100, 12, 31);
    final saved = reviewDate();
    final initial = saved == null || saved.isBefore(first) || saved.isAfter(last) ? now : saved;
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (!mounted || date == null) return;
    changed(() => fields['review_date'] = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
  }

  Widget dateField() {
    final date = reviewDate();
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: OutlinedButton.icon(
      onPressed: saving ? null : pickReviewDate,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(date == null ? 'Choose review date' : 'Review date: ${date.day}/${date.month}/${date.year}'),
    ));
  }

  List<Widget> content() {
    switch (step) {
      case 0: return household();
      case 1: return [
        supplyGuide(), tasks(supplies),
        if (members.any((m) => m['medication'] == 'yes')) medicationChecks(),
        if (members.any((m) => m['medication'] == 'unknown')) note('Confirm medication needs for each member in Step 1.'),
        if (fields['pets'] == 'yes') ...[
          note('Pack food and drinking water suited to each pet, bowls, carriers or leads, identification and any required medication. Quantities depend on species and size; check with your vet. Confirm pet acceptance at the destination.'),
          tasks(petTasks),
        ],
      ];
      case 2: return [
        note('Plan possible destinations in advance. Follow current official warnings, road conditions and directions when an incident occurs.'),
        destination('destination', 'Where would you go first?'),
        destination('alternative', 'Where could you go instead?'),
        transport(), field('meeting', 'Where will you meet if separated?'),
        field('contacts', 'Who can your household contact?', lines: 3), tasks(arrangements),
      ];
      case 3: return [
        note('Choose a household member for each applicable task. Only prepare the dwelling while it is safe; never delay an evacuation instruction.'),
        if ((fields['dwelling_tasks'] ?? '').isNotEmpty) note('Previously saved dwelling notes: ${fields['dwelling_tasks']}'),
        tasks(dwelling, assign: true),
      ];
      default: return [
        Text('Checklist: ${complete ? 'Complete' : 'Incomplete'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: saving ? null : showResults, icon: const Icon(Icons.summarize_outlined), label: Text(complete ? 'View completed results' : 'View checklist results')),
        if (!complete) ...[
          const SizedBox(height: 8),
          for (final issue in completionIssues) Text('• $issue'),
        ],
        const SizedBox(height: 12),
        note('Community completion status: not connected. Saving prepares only a completion summary locally; no information has been sent.'),
        const SizedBox(height: 12), Text('$completed of $applicable applicable items complete'),
        Text('$assistance assistance requests'),
        if (!setupComplete) const Text('Confirm household details, medication and pet answers, and each added member’s details.'),
        if (!detailsComplete) const Text('Confirm destinations, transport for everyone, task assignments and the review date.'),
        if (applicable == 0) const Text('No applicable items: readiness cannot be assessed.'),
        const SizedBox(height: 12), const Text('Preparedness completion does not indicate that anyone has evacuated or is safe.'),
        const SizedBox(height: 16), dateField(), tasks(review),
      ];
    }
  }

  List<String> get completionIssues => [
    if ((fields['family'] ?? '').trim().isEmpty) 'Enter the family name in Step 1.',
    if (members.isEmpty) 'Add at least one household member in Step 1.',
    if (remainingMemberCount > 0) 'Add $remainingMemberCount remaining household member(s) in Step 1.',
    if (!membersValid) 'Complete each member’s name, medication Yes/No answer and medication list where needed.',
    if (!['yes', 'no'].contains(fields['pets'])) 'Confirm whether the household has pets.',
    if (fields['pets'] == 'yes' && ((int.tryParse(fields['pet_count'] ?? '') ?? 0) <= 0 || (fields['pet_details'] ?? '').trim().isEmpty)) 'Complete the pet count and details.',
    if (['destination', 'alternative'].any((id) => (fields[id] ?? '').trim().isEmpty || fields['$id.confirmed'] != 'yes')) 'Enter and confirm both evacuation destinations in Step 3.',
    if (!transportComplete) 'Confirm transport, drivers and enough seats for everyone in Step 3.',
    if ((fields['meeting'] ?? '').trim().isEmpty || (fields['contacts'] ?? '').trim().isEmpty) 'Enter a meeting point and emergency contact in Step 3.',
    if (dwelling.keys.where((id) => answers[id] != 'na').any((id) => !members.any((m) => m['id'] == fields['assigned.$id']))) 'Assign a household member to every applicable dwelling task in Step 4.',
    if (reviewDate() == null) 'Choose a review date in Step 5.',
    if (applicable == 0) 'No applicable checklist items are recorded.',
    if (completed < applicable) '${applicable - completed} applicable checklist item(s) still need completion, including $assistance assistance request(s).',
  ];

  String get resultsText {
    final lines = <String>[
      'HOUSEHOLD CHECKLIST RESULTS',
      'Status: ${complete ? 'Complete' : 'Incomplete'}',
      'Plan completion: $completionPercentage%',
      '$completed of $applicable applicable items complete',
      'Assistance requests: $assistance',
      'Review date: ${fields['review_date'] ?? 'Not set'}',
      'Last saved: ${savedAt ?? 'Not saved yet'}',
      'These results reflect the current entries. Check the saved message to confirm they are stored on this device.',
      if (!complete) ...['', 'REMAINING REQUIREMENTS', ...completionIssues],
      '', '1. HOUSEHOLD',
      'Family: ${fields['family'] ?? ''}',
      if ((fields['community'] ?? '').trim().isNotEmpty) 'Community: ${fields['community']}',
      'Household members: $count',
    ];
    for (final member in members) {
      lines.add('${member['name']} · Phone: ${(member['phone'] ?? '').isEmpty ? 'Not provided' : member['phone']}');
      lines.add('Taking medication: ${member['medication'] == 'yes' ? 'Yes' : member['medication'] == 'no' ? 'No' : 'Not confirmed'}');
    }
    lines.add('Pets: ${fields['pets'] == 'yes' ? '${fields['pet_count']} — ${fields['pet_details']}' : fields['pets'] == 'no' ? 'No' : 'Not confirmed'}');
    void appendTasks(String heading, Map<String, String> items, {bool assigned = false}) {
      lines.addAll(['', heading]);
      for (final item in items.entries) {
        lines.add('${item.value}: ${statuses[answers[item.key] ?? 'todo']}');
        if (assigned && answers[item.key] != 'na') {
          final people = members.where((m) => m['id'] == fields['assigned.${item.key}']);
          lines.add('Assigned to: ${people.isEmpty ? 'Not assigned' : people.first['name']}');
        }
      }
    }
    appendTasks('2. SUPPLIES', supplies);
    for (final member in members.where((m) => m['medication'] == 'yes')) {
      appendTasks('Medication for ${member['name']}', {for (final medicine in medicinesFor(member['id']!)) 'medication.${medicine['id']}': medicine['name']!});
    }
    if (fields['pets'] == 'yes') appendTasks('Pet supplies', petTasks);
    lines.addAll(['', '3. EVACUATION ARRANGEMENTS']);
    for (final entry in const {
      'destination': 'First destination', 'alternative': 'Alternative destination',
      'meeting': 'Meeting point', 'contacts': 'Emergency contacts',
      'community_transport': 'Community transport details', 'transport_help': 'Transport help',
      'travel_needs': 'Additional travel needs',
    }.entries) {
      if ((fields[entry.key] ?? '').isNotEmpty) lines.add('${entry.value}: ${fields[entry.key]}');
    }
    lines.add('Usable household seats: $seatCount');
    for (final vehicle in vehicles) {
      final drivers = members.where((m) => m['id'] == fields['driver.$vehicle']);
      final driver = fields['driver.$vehicle'] == 'other' ? fields['driver_other.$vehicle'] : drivers.isEmpty ? 'Not assigned' : drivers.first['name'];
      lines.add('Vehicle: ${fields['vehicle.$vehicle'] ?? ''} · Driver: $driver · Seats: ${fields['seats.$vehicle'] ?? '0'}');
    }
    appendTasks('Evacuation checks', arrangements);
    appendTasks('4. DWELLING PREPARATION', dwelling, assigned: true);
    appendTasks('5. FINAL REVIEW', review);
    lines.addAll(['', 'Preparedness completion does not confirm evacuation or safety.', 'Community status sharing is not connected. These detailed results remain private on this device.']);
    return lines.join('\n');
  }

  Widget resultsBody() {
    const accent = Color(0xFF80CBC4);
    const headings = {
      'REMAINING REQUIREMENTS', '1. HOUSEHOLD', '2. SUPPLIES',
      'Pet supplies', '3. EVACUATION ARRANGEMENTS', 'Evacuation checks',
      '4. DWELLING PREPARATION', '5. FINAL REVIEW',
    };
    final medicationHeadings = members.where((m) => m['medication'] == 'yes')
        .map((m) => 'Medication for ${m['name']}').toSet();
    final lines = resultsText.split('\n');
    final rows = <Widget>[];
    // The first five lines are represented by the summary below.
    for (final line in lines.skip(5)) {
      if (line.isEmpty) continue;
      if (headings.contains(line) || medicationHeadings.contains(line)) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SelectableText(line, style: const TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Colors.white24),
          ]),
        ));
        continue;
      }
      final statusEntries = statuses.entries.where((s) => line.endsWith(': ${s.value}'));
      if (statusEntries.isNotEmpty) {
        final status = statusEntries.first;
        final label = line.substring(0, line.length - status.value.length - 2);
        final color = status.key == 'done' ? accent
            : status.key == 'help' ? Colors.orangeAccent : Colors.white70;
        rows.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SelectableText(label, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(status.key == 'done' ? Icons.check_circle_outline
                  : status.key == 'help' ? Icons.help_outline
                  : status.key == 'na' ? Icons.remove_circle_outline : Icons.radio_button_unchecked,
                color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(status.value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ]),
        ));
      } else {
        final separator = line.indexOf(': ');
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: separator < 0
              ? SelectableText(line, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(line.substring(0, separator), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SelectableText(line.substring(separator + 2), style: const TextStyle(fontSize: 14, height: 1.5)),
                ]),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$completionPercentage% · ${complete ? 'Complete' : 'Incomplete'}', style: const TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: completionPercentage / 100, color: accent, backgroundColor: Colors.white12),
          const SizedBox(height: 12),
          Text('$completed of $applicable applicable items complete', style: const TextStyle(height: 1.5)),
          Text('Assistance requests: $assistance', style: const TextStyle(color: Colors.white70, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 16),
      ...rows,
    ]);
  }

  Future<void> showResults() async {
    await showDialog<void>(context: context, builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text(complete ? 'Completed checklist results' : 'Checklist results — incomplete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: resultsBody())),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ])),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Column(children: [Text(error!), TextButton(onPressed: () { setState(() => loading = true); load(); }, child: const Text('Retry'))]);
    final percent = completionPercentage;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
      key: checklistTop,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF14171A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('HOUSEHOLD CHECKLIST', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        if (complete) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving ? null : showResults,
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('View completed results'),
          ),
        ],
        const SizedBox(height: 12),
        LinearProgressIndicator(value: completionPercentage / 100),
        const SizedBox(height: 8), Text('$percent% plan completion'),
        const SizedBox(height: 20),
        if (step < 0) ...[
          const Text('Your household plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          note('Work through one section at a time. You can return to any section later.'),
          for (var index = 0; index < steps.length; index++)
            Card(child: ListTile(
              title: Text('${index + 1}. ${steps[index]}'),
              subtitle: Text('${sectionDescriptions[index]}\n${sectionDone(index) ? 'Complete' : 'Needs attention'}'),
              trailing: Text(sectionDone(index) ? 'Review' : savedAt == null ? 'Start' : 'Continue'),
              onTap: saving ? null : () => goToStep(index),
            )),
          const SizedBox(height: 12),
          FilledButton(onPressed: saving ? null : () => goToStep(0), child: Text(savedAt == null ? 'Start checklist' : 'Continue checklist')),
        ] else ...[
          Text('Step ${step + 1} of 5 · ${steps[step]}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...content(),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: [
            OutlinedButton(onPressed: saving ? null : () => goToStep(step == 0 ? -1 : step - 1), child: Text(step == 0 ? 'Back: Plan overview' : 'Back: ${steps[step - 1]}')),
            if (step < 4) FilledButton(onPressed: saving ? null : () => goToStep(step + 1), child: Text('Next: ${steps[step + 1]}')),
            if (step == 4) FilledButton(onPressed: saving ? null : () => goToStep(-1), child: const Text('Back to plan overview')),
          ]),
          TextButton(onPressed: saving ? null : () => goToStep(-1), child: const Text('View all sections')),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Icon(saveError != null ? Icons.error_outline : dirty || saving ? Icons.save_outlined : Icons.lock_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(saveError ?? (saving ? 'Saving on this device…' : dirty ? 'Changes waiting to save…' : savedAt != null ? 'Saved on this device' : 'Changes save automatically on this device.'))),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: saving ? null : () => save(), icon: const Icon(Icons.save_outlined), label: Text(saveError != null ? 'Retry save' : 'Save now')),
        const SizedBox(height: 16),
        const Text('Private to this household account on this device. Not sent to community leaders or the backend. Changes save automatically on this device. Check the saved message before leaving.', style: TextStyle(color: Colors.white54, fontSize: 13)),
        if (savedAt != null) Text('Last saved: ${DateTime.tryParse(savedAt!)?.toLocal().toString().split('.').first ?? savedAt}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    ),
      ),
    );
  }
}

/// Edits a private draft; Cancel never changes the household's saved entries.
class _HouseholdMemberDialog extends StatefulWidget {
  const _HouseholdMemberDialog({required this.member, required this.medicines});
  final Map<String, String> member;
  final List<Map<String, String>> medicines;
  @override
  State<_HouseholdMemberDialog> createState() => _HouseholdMemberDialogState();
}

class _HouseholdMemberDialogState extends State<_HouseholdMemberDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController phone;
  final medicine = TextEditingController();
  late List<Map<String, String>> medicines;
  String? takingMedication;
  String? medicationError;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.member['name']);
    phone = TextEditingController(text: widget.member['phone']);
    takingMedication = ['yes', 'no'].contains(widget.member['medication']) ? widget.member['medication'] : null;
    medicines = widget.medicines.map((m) => Map<String, String>.from(m)).toList();
  }
  @override
  void dispose() { name.dispose(); phone.dispose(); medicine.dispose(); super.dispose(); }

  bool addMedicine() {
    final text = medicine.text.trim();
    if (text.isEmpty) { setState(() => medicationError = 'Enter a medication name.'); return false; }
    if (medicines.any((m) => m['name']!.toLowerCase() == text.toLowerCase())) {
      setState(() => medicationError = 'This medication is already listed.'); return false;
    }
    setState(() {
      medicines.add({'id': 'medicine.${DateTime.now().microsecondsSinceEpoch}.${medicines.length}', 'member_id': widget.member['id']!, 'name': text});
      medicine.clear(); medicationError = null;
    });
    return true;
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    if (takingMedication == null) { setState(() => medicationError = 'Choose Yes or No.'); return; }
    if (takingMedication == 'yes' && medicine.text.trim().isNotEmpty && !addMedicine()) return;
    if (takingMedication == 'yes' && medicines.isEmpty) { setState(() => medicationError = 'Add at least one medication name.'); return; }
    Navigator.pop(context, <String, dynamic>{
      'member': {...widget.member, 'name': name.text.trim(), 'phone': phone.text.trim(), 'medication': takingMedication!},
      'medicines': medicines,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text((widget.member['name'] ?? '').isEmpty ? 'Add household member' : 'Edit household member'),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: formKey, child: Column(
      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Member details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Name (required)', border: OutlineInputBorder()),
          validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a name.' : null),
        const SizedBox(height: 16),
        TextFormField(controller: phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone number (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 20),
        const Text('Currently taking medication?', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _CompactYesNo(
          value: takingMedication,
          onChanged: (selected) => setState(() { takingMedication = selected; medicationError = null; }),
        ),
        if (takingMedication == 'yes') ...[
          const SizedBox(height: 16),
          TextField(controller: medicine, textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Medication name', border: OutlineInputBorder()),
            onSubmitted: (_) => addMedicine()),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: addMedicine, icon: const Icon(Icons.add), label: const Text('Add medication')),
          for (final entry in medicines)
            Row(children: [Expanded(child: Text(entry['name']!)), IconButton(tooltip: 'Remove medication', onPressed: () => setState(() => medicines.remove(entry)), icon: const Icon(Icons.close))]),
          const Text('Record names only. No doses needed.', style: TextStyle(color: Colors.white70)),
        ],
        if (medicationError != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(medicationError!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 20),
        FilledButton(onPressed: submit, child: const Text('Save member')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        const SizedBox(height: 12),
        const Text('Medication details stay in your private household checklist on this device.', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    )))),
  );
}

/// Compact single-choice input. An unanswered question stays unselected.
class _CompactYesNo extends StatelessWidget {
  const _CompactYesNo({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final option in const {'yes': 'Yes', 'no': 'No'}.entries)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
          child: ChoiceChip(
            label: Text(option.value),
            selected: value == option.key,
            showCheckmark: true,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            onSelected: onChanged == null ? null : (_) => onChanged!(option.key),
          ),
        ),
    ],
  );
}
