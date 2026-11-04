import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/database_helper.dart';

/// Private, account-scoped checklist. Does not transmit household information.
class HouseholdChecklist extends StatefulWidget {
  const HouseholdChecklist({super.key});
  @override
  State<HouseholdChecklist> createState() => _HouseholdChecklistState();
}

class _HouseholdChecklistState extends State<HouseholdChecklist> {
  int step = 0;
  int? owner;
  bool loading = true;
  bool saving = false;
  String? error;
  String? savedAt;
  Map<String, String> fields = {};
  List<Map<String, String>> members = [];
  Map<String, String> answers = {};
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
  Iterable<String> get itemIds => [...supplies.keys, ...arrangements.keys, ...dwelling.keys, ...review.keys];
  int get applicable => itemIds.where((id) => answers[id] != 'na').length;
  int get completed => itemIds.where((id) => answers[id] == 'done').length;
  int get assistance => itemIds.where((id) => answers[id] == 'help').length;
  int get count => int.tryParse(fields['count'] ?? '') ?? 0;
  bool get setupComplete => (fields['family'] ?? '').trim().isNotEmpty &&
    (fields['community'] ?? '').trim().isNotEmpty && count > 0 &&
    count == members.length && members.every((m) => (m['name'] ?? '').trim().isNotEmpty);
  bool get detailsComplete => ['destination', 'alternative', 'transport', 'meeting', 'contacts', 'dwelling_tasks', 'review_date'].every((key) => (fields[key] ?? '').trim().isNotEmpty);
  bool get complete => setupComplete && detailsComplete && applicable > 0 && completed == applicable;

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
      await db.saveConfig('household_checklist.v1.$owner', jsonEncode({
        'version': 1, 'fields': fields, 'members': members,
        'answers': answers, 'saved_at': now,
      }));
      if (mounted) setState(() => savedAt = now);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist saved privately on this device.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Your entries remain open; check your account and try again.')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Widget field(String id, String label, {TextInputType? keyboard, int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('field.$id'), initialValue: fields[id] ?? '',
      enabled: !saving, keyboardType: keyboard, minLines: lines, maxLines: lines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: lines > 1),
      onChanged: (value) => setState(() => fields[id] = value),
    ),
  );

  Widget tasks(Map<String, String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: items.entries.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.value, style: const TextStyle(fontWeight: FontWeight.bold)),
        for (final status in statuses.entries)
          Row(children: [
            Radio<String>(value: status.key, groupValue: answers[item.key] ?? 'todo', onChanged: saving ? null : (value) => setState(() => answers[item.key] = value!)),
            Expanded(child: Text(status.value)),
          ]),
        const Divider(color: Colors.white10),
      ]),
    )).toList(),
  );

  List<Widget> household() => [
    field('family', 'Family name'), field('community', 'Community name'),
    field('count', 'Total household members', keyboard: TextInputType.number),
    for (var i = 0; i < members.length; i++) ...[
      Text('Member ${i + 1}'), const SizedBox(height: 8),
      TextFormField(key: ObjectKey(members[i]), initialValue: members[i]['name'], enabled: !saving,
        decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        onChanged: (v) => setState(() => members[i]['name'] = v)),
      const SizedBox(height: 8),
      TextFormField(key: ValueKey('phone.${identityHashCode(members[i])}'), initialValue: members[i]['phone'], enabled: !saving, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone number (optional)', border: OutlineInputBorder()),
        onChanged: (v) => members[i]['phone'] = v),
      TextButton.icon(onPressed: saving ? null : () => setState(() => members.removeAt(i)), icon: const Icon(Icons.remove_circle_outline), label: const Text('Remove member')),
      const SizedBox(height: 12),
    ],
    OutlinedButton.icon(onPressed: saving ? null : () => setState(() => members.add({'name': '', 'phone': ''})), icon: const Icon(Icons.person_add_outlined), label: const Text('Add household member')),
    const SizedBox(height: 12),
    Text('${members.length} named entries / $count total household members'),
    const SizedBox(height: 12),
    field('assistance', 'Assistance needs (optional)', lines: 3),
  ];

  List<Widget> content() {
    switch (step) {
      case 0: return household();
      case 1: return [tasks(supplies)];
      case 2: return [
        field('destination', 'Evacuation destination'), field('alternative', 'Alternative destination'),
        field('transport', 'Transport, drivers and available seats', lines: 3),
        field('meeting', 'Family meeting point'), field('contacts', 'Emergency contacts', lines: 3),
        tasks(arrangements),
      ];
      case 3: return [field('dwelling_tasks', 'Local dwelling tasks and responsibilities', lines: 4), tasks(dwelling)];
      default: return [
        Text('Checklist: ${complete ? 'Complete' : 'Incomplete'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('$completed of $applicable applicable items complete'),
        Text('$assistance assistance requests'),
        if (!setupComplete) const Text('Confirm family name, community and named members matching the total count.'),
        if (!detailsComplete) const Text('Complete the evacuation details, dwelling responsibilities and review date.'),
        if (applicable == 0) const Text('No applicable items: readiness cannot be assessed.'),
        const SizedBox(height: 12),
        const Text('Preparedness completion does not indicate that anyone has evacuated or is safe.'),
        const SizedBox(height: 16),
        field('review_date', 'Review date (DD/MM/YYYY)'), tasks(review),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Column(children: [Text(error!), TextButton(onPressed: () { setState(() => loading = true); load(); }, child: const Text('Retry'))]);
    final percent = applicable == 0 ? 0 : (completed * 100 / applicable).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF14171A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('HOUSEHOLD CHECKLIST', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Text('Step ${step + 1} of 5 · ${steps[step]}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: applicable == 0 ? 0 : completed / applicable),
        const SizedBox(height: 8), Text('$percent% of applicable checklist items complete'),
        const SizedBox(height: 20),
        ...content(),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          if (step > 0) OutlinedButton(onPressed: saving ? null : () => setState(() => step--), child: const Text('Back')),
          if (step < 4) FilledButton(onPressed: saving ? null : () => setState(() => step++), child: const Text('Next')),
          OutlinedButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving…' : 'Save progress')),
        ]),
        const SizedBox(height: 16),
        const Text('Private to this household account on this device. Not sent to community leaders or the backend. Save progress before leaving this panel.', style: TextStyle(color: Colors.white54, fontSize: 13)),
        if (savedAt != null) Text('Last saved: ${DateTime.tryParse(savedAt!)?.toLocal().toString().split('.').first ?? savedAt}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}
