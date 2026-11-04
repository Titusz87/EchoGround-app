import 'dart:convert';
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
  int step = 0;
  void goToStep(int next) {
    // Release the old field so keyboard focus cannot scroll the new step down.
    FocusScope.of(context).unfocus();
    setState(() => step = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The dashboard owns the SingleChildScrollView. Reset that actual
      // scroll position after the new step has been laid out.
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null && scrollable.position.hasContentDimensions) {
        scrollable.position.jumpTo(scrollable.position.minScrollExtent);
      }
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
  final Map<String, TextEditingController> medicationInputs = {};
  bool showMemberErrors = false;

  Iterable<Map<String, String>> medicinesFor(String memberId) => medications.where((m) => m['member_id'] == memberId);
  Iterable<Map<String, String>> get activeMedicines => medications.where((m) => members.any((person) => person['id'] == m['member_id'] && person['medication'] == 'yes'));
  bool get membersValid => members.every((m) =>
    (m['name'] ?? '').trim().isNotEmpty && ['yes', 'no'].contains(m['medication']) &&
    (m['medication'] != 'yes' || medicinesFor(m['id']!).isNotEmpty));

  @override
  void dispose() {
    for (final controller in medicationInputs.values) { controller.dispose(); }
    super.dispose();
  }

  void addMedication(Map<String, String> member) {
    final controller = medicationInputs.putIfAbsent(member['id']!, () => TextEditingController());
    final name = controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a medication name first.')));
      return;
    }
    if (medicinesFor(member['id']!).any((m) => m['name']!.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This medication is already listed for this member.')));
      return;
    }
    setState(() {
      medications.add({'id': 'medicine.${DateTime.now().microsecondsSinceEpoch}.${medications.length}', 'member_id': member['id']!, 'name': name});
      controller.clear();
    });
  }

  Widget memberMedications(Map<String, String> member) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const SizedBox(height: 12),
    TextField(
      controller: medicationInputs.putIfAbsent(member['id']!, () => TextEditingController()),
      enabled: !saving,
      decoration: InputDecoration(labelText: 'Medication name', border: const OutlineInputBorder(),
        errorText: showMemberErrors && medicinesFor(member['id']!).isEmpty ? 'Add at least one medication' : null),
      onSubmitted: saving ? null : (_) => addMedication(member),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: saving ? null : () => addMedication(member), icon: const Icon(Icons.add), label: const Text('Add medication')),
    for (final medicine in medicinesFor(member['id']!))
      Row(children: [
        Expanded(child: Text(medicine['name']!)),
        IconButton(tooltip: 'Remove medication', onPressed: saving ? null : () => setState(() { medications.remove(medicine); answers.remove('medication.${medicine['id']}'); }), icon: const Icon(Icons.remove_circle_outline)),
      ]),
  ]);

  static const steps = ['Household', 'Supplies', 'Evacuation', 'Dwelling', 'Review'];
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
  bool get setupComplete => (fields['family'] ?? '').trim().isNotEmpty &&
    (fields['community'] ?? '').trim().isNotEmpty && count > 0 &&
    membersValid && ['yes', 'no'].contains(fields['pets']) && (fields['pets'] != 'yes' || ((int.tryParse(fields['pet_count'] ?? '') ?? 0) > 0 && (fields['pet_details'] ?? '').trim().isNotEmpty));
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
    try {
      final db = DatabaseHelper.instance;
      final id = int.tryParse(await db.getConfig('auth_household_id') ?? '');
      if (id == null || id <= 0) throw StateError('Not signed in');
      final raw = await db.getConfig('household_checklist.v1.$id');
      if (raw != null && raw.isNotEmpty) {
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
      if (mounted) setState(() { owner = id; loading = false; error = null; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Sign in as a household to continue. If already signed in, the saved checklist could not be loaded.'; });
    }
  }

  Future<void> save() async {
    if (saving || owner == null) return;
    setState(() => saving = true);
    try {
      final db = DatabaseHelper.instance;
      if (await db.getConfig('auth_household_id') != owner.toString()) throw StateError('Account changed');
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
      if (mounted) setState(() => savedAt = now);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist saved privately on this device.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Your entries remain open; check your account and try again.')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Widget field(String id, String label, {TextInputType? keyboard, int lines = 1, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('field.$id'), initialValue: fields[id] ?? '',
      enabled: !saving, keyboardType: keyboard, minLines: lines, maxLines: lines,
      inputFormatters: keyboard == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label, helperText: hint, helperMaxLines: 5, border: const OutlineInputBorder(), alignLabelWithHint: lines > 1),
      onChanged: (value) => setState(() => fields[id] = value),
    ),
  );

  Widget choice(String id, String label, Map<String, String> options) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('choice.$id.${fields[id]}'),
      value: options.containsKey(fields[id]) ? fields[id] : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
      onChanged: saving ? null : (value) => setState(() => fields[id] = value!),
    ),
  );

  Widget memberChoice(String id, String label, {bool allowOther = false}) {
    final options = <String, String>{
      '': 'Not assigned yet',
      for (final member in members)
        member['id']!: (member['name'] ?? '').trim().isEmpty ? 'Unnamed member' : member['name']!,
      if (allowOther) 'other': 'Someone outside the household',
    };
    return choice(id, label, options);
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
    children: items.entries.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(item.value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (explanations[item.key] != null) note(explanations[item.key]!),
        if (assign) memberChoice('assigned.${item.key}', 'Who will complete this task'),
        for (final status in statuses.entries)
          Row(children: [
            Radio<String>(value: status.key, groupValue: answers[item.key] ?? 'todo', onChanged: saving ? null : (value) => setState(() => answers[item.key] = value!)),
            Expanded(child: Text(status.value)),
          ]),
        const Divider(color: Colors.white10),
      ]),
    )).toList(),
  );

  void removeMember(int index) {
    final id = members[index]['id'];
    setState(() {
      members.removeAt(index);
      final removed = medications.where((m) => m['member_id'] == id).map((m) => 'medication.${m['id']}').toSet();
      medications.removeWhere((m) => m['member_id'] == id);
      answers.removeWhere((key, value) => removed.contains(key));
      fields.removeWhere((key, value) => value == id && (key.startsWith('assigned.') || key.startsWith('driver.')));
    });
  }

  List<Widget> household() => [
    field('family', 'Family name'), field('community', 'Community name'),
    for (var i = 0; i < members.length; i++) ...[
      Text('Member ${i + 1}'), const SizedBox(height: 8),
      TextFormField(key: ValueKey('name.${members[i]['id']}'), initialValue: members[i]['name'], enabled: !saving,
        decoration: InputDecoration(labelText: 'Name (required)', border: const OutlineInputBorder(), errorText: showMemberErrors && (members[i]['name'] ?? '').trim().isEmpty ? 'Enter a name' : null),
        onChanged: (v) => setState(() => members[i]['name'] = v)),
      const SizedBox(height: 8),
      TextFormField(key: ValueKey('phone.${members[i]['id']}'), initialValue: members[i]['phone'], enabled: !saving, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone number (optional)', border: OutlineInputBorder()),
        onChanged: (v) => members[i]['phone'] = v),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('medication.${members[i]['id']}.${members[i]['medication']}'),
        value: ['yes', 'no'].contains(members[i]['medication']) ? members[i]['medication'] : null, isExpanded: true,
        decoration: InputDecoration(labelText: 'Currently taking medication? (required)', border: const OutlineInputBorder(), errorText: showMemberErrors && !['yes', 'no'].contains(members[i]['medication']) ? 'Choose Yes or No' : null),
        items: const [DropdownMenuItem(value: 'yes', child: Text('Yes')), DropdownMenuItem(value: 'no', child: Text('No'))],
        onChanged: saving ? null : (value) => setState(() => members[i]['medication'] = value!),
      ),
      if (members[i]['medication'] == 'yes') memberMedications(members[i]),
      SizedBox(
        height: 4,
      ),
      TextButton.icon(onPressed: saving ? null : () => removeMember(i), icon: const Icon(Icons.remove_circle_outline), label: const Text('Remove member')),
      const SizedBox(height: 12),
    ],
    OutlinedButton.icon(onPressed: saving ? null : () => setState(() => members.add({'id': 'member.${DateTime.now().microsecondsSinceEpoch}.${members.length}', 'name': '', 'phone': '', 'medication': 'unknown'})), icon: const Icon(Icons.person_add_outlined), label: const Text('Add household member')),
    const SizedBox(height: 12), Text('$count household member(s) added'),
    const SizedBox(height: 12),
    choice('pets', 'Do you have pets?', const {'unknown': 'Not confirmed yet', 'yes': 'Yes', 'no': 'No'}),
    if (fields['pets'] == 'yes') ...[
      field('pet_count', 'Number of pets', keyboard: TextInputType.number),
      field('pet_details', 'Pet types and needs', lines: 2, hint: 'For example: two dogs, carriers, food and transport needs.'),
    ],
    note('Medication and pet answers remain private in this local household checklist. Medication names are stored only in this private checklist; no doses are requested.'),
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
        TextButton(onPressed: saving ? null : () => setState(() => vehicles.removeAt(i)), child: const Text('Remove vehicle')),
      ],
      OutlinedButton.icon(onPressed: saving ? null : () => setState(() => vehicles.add('vehicle.${DateTime.now().microsecondsSinceEpoch}.${vehicles.length}')), icon: const Icon(Icons.add), label: const Text('Add vehicle')),
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
    setState(() => fields['review_date'] = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
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
        note('Community completion status: not connected. Save progress prepares only a completion summary locally; no information has been sent.'),
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
    if ((fields['community'] ?? '').trim().isEmpty) 'Enter the community name in Step 1.',
    if (members.isEmpty) 'Add at least one household member in Step 1.',
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
      'These results reflect the current entries. Save progress to store them.',
      if (!complete) ...['', 'REMAINING REQUIREMENTS', ...completionIssues],
      '', '1. HOUSEHOLD',
      'Family: ${fields['family'] ?? ''}',
      'Community: ${fields['community'] ?? ''}',
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

  Future<void> showResults() async {
    await showDialog<void>(context: context, builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text(complete ? 'Completed checklist results' : 'Checklist results — incomplete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: SelectableText(resultsText))),
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
    return Container(
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
        Text('Step ${step + 1} of 5 · ${steps[step]}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: completionPercentage / 100),
        const SizedBox(height: 8), Text('$percent% plan completion'),
        const SizedBox(height: 20),
        ...content(),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          if (step > 0) OutlinedButton(onPressed: saving ? null : () => goToStep(step - 1), child: const Text('Back')),
          if (step < 4) FilledButton(onPressed: saving ? null : () {
            if (step == 0 && !membersValid) {
              setState(() => showMemberErrors = true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete each member’s name, Yes/No medication answer, and medication list where needed.')));
              return;
            }
            goToStep(step + 1);
          }, child: const Text('Next')),
          OutlinedButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving…' : 'Save progress')),
        ]),
        const SizedBox(height: 16),
        const Text('Private to this household account on this device. Not sent to community leaders or the backend. Save progress before leaving this panel.', style: TextStyle(color: Colors.white54, fontSize: 13)),
        if (savedAt != null) Text('Last saved: ${DateTime.tryParse(savedAt!)?.toLocal().toString().split('.').first ?? savedAt}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}
