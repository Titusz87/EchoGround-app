import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/database_helper.dart';

/// Emergency actions are stored separately from preparedness answers.
class HouseholdEvacuationPlan extends StatefulWidget {
  const HouseholdEvacuationPlan({super.key, required this.owner, required this.percentage});
  final int owner;
  final int percentage;
  @override
  State<HouseholdEvacuationPlan> createState() => _HouseholdEvacuationPlanState();
}

class _HouseholdEvacuationPlanState extends State<HouseholdEvacuationPlan> {
  Map<String, dynamic>? plan;
  Map<String, bool> ticks = {};
  String? error;
  bool busy = false;
  String get key => 'household_evacuation_ticks.v1.${widget.owner}';
  final db = DatabaseHelper.instance;
  @override
  void initState() { super.initState(); load(); }
  Future<void> checkOwner() async {
    if (await db.getConfig('auth_household_id') != '${widget.owner}') throw StateError('Account changed');
  }
  Future<void> load() async {
    try {
      await checkOwner();
      final raw = await db.getConfig('household_checklist.v1.${widget.owner}');
      if (raw == null) throw StateError('No saved plan');
      final loaded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final saved = await db.getConfig(key);
      final loadedTicks = saved == null ? <String, bool>{} : Map<String, bool>.from(jsonDecode(saved) as Map);
      await checkOwner();
      if (mounted) setState(() { plan = loaded; ticks = loadedTicks; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load your saved plan. Return to the checklist and check that it has saved.');
    }
  }
  Future<void> store(Map<String, bool> next) async {
    setState(() => busy = true);
    try {
      await checkOwner();
      await db.saveConfig(key, jsonEncode(next));
      if (mounted) setState(() { ticks = next; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save emergency ticks. Your previous ticks have been kept.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> reset() async {
    final yes = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Reset emergency ticks?'),
      content: const Text('This clears emergency ticks for this household. Your preparedness plan will be kept.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset'))],
    ));
    if (yes == true && mounted) await store({});
  }
  @override
  Widget build(BuildContext context) {
    final fields = Map<String, dynamic>.from(plan?['fields'] as Map? ?? {});
    final members = List<dynamic>.from(plan?['members'] as List? ?? []);
    final meds = List<dynamic>.from(plan?['medications'] as List? ?? []).where((m) => members.any((person) => person['id'] == m['member_id'] && person['medication'] == 'yes')).toList();
    final answers = Map<String, dynamic>.from(plan?['answers'] as Map? ?? {});
    final vehicles = List<dynamic>.from(plan?['vehicles'] as List? ?? []);
    String value(String name) => (fields[name]?.toString() ?? '').trim();
    String detail(String name) => value(name).isEmpty ? 'Not recorded — update your plan' : value(name);
    String memberName(dynamic id) {
      for (final m in members) { if (m['id'] == id) return m['name']?.toString() ?? 'Unnamed member'; }
      return 'Not assigned';
    }
    final actions = <String, String>{
      'people': 'Check everyone is accounted for',
      if (value('pets') == 'yes') 'pets': 'Secure pets for travel',
      for (final m in meds) 'medication.${m['id']}': 'Pack ${m['name']} for ${memberName(m['member_id'])}',
      if (meds.isEmpty && members.any((m) => m['medication'] != 'no')) 'medication_check': 'Check medication needs for each person',
      for (final entry in const {
        'water': 'Load drinking water', 'food': 'Load suitable food',
        'medication': 'Pack essential medical equipment and medication supplies',
        'first_aid': 'Pack the first-aid kit', 'torch': 'Take torches, radio and batteries',
        'charging': 'Take phones and charging equipment', 'documents': 'Take important documents',
        'clothing': 'Pack clothing and hygiene supplies',
        'individual': 'Pack supplies for children, pets and individual needs',
      }.entries)
        if (answers[entry.key] != 'na') 'supply.${entry.key}': entry.value,
      'transport': 'Confirm the destination and transport are still available',
      'leave': 'Check the household is ready to leave',
    };
    Widget heading(String text) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
    Widget action(String id, {String? subtitle}) => CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8), controlAffinity: ListTileControlAffinity.leading,
      value: ticks[id] == true, title: Text(actions[id]!), subtitle: subtitle == null ? null : Text(subtitle),
      onChanged: busy ? null : (v) => store({...ticks, id: v == true}),
    );
    return Scaffold(
      backgroundColor: const Color(0xFF14171A),
      appBar: AppBar(title: const Text('Use my plan'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Edit plan'))]),
      body: plan == null ? Center(child: error == null ? const CircularProgressIndicator() : Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: load, child: const Text('Retry'))]))
        : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Household ${detail('family')}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12), const Text('Tick off actions as you complete them.'),
          const SizedBox(height: 8), const Text('Emergency ticks are separate from preparedness progress.'),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: [Text('Preparedness: ${widget.percentage}%'), Text('Actions: ${actions.keys.where((id) => ticks[id] == true).length} of ${actions.length} ticked')]),
          if (widget.percentage < 100) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Your preparedness plan is incomplete. Check missing or unconfirmed arrangements before relying on this view.')),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          heading('People and pets'),
          action('people', subtitle: members.isEmpty ? 'No members recorded' : members.map((m) => m['name']).join(', ')),
          if (actions.containsKey('pets')) action('pets', subtitle: detail('pet_details')),
          heading('Take with you'),
          for (final id in actions.keys.where((id) => id.startsWith('medication'))) action(id),
          for (final id in actions.keys.where((id) => id.startsWith('supply.'))) action(id),
          heading('Destination and transport'),
          SelectableText('Destination: ${detail('destination')}\nAlternative: ${detail('alternative')}\nMeeting point: ${detail('meeting')}\nEmergency contacts: ${detail('contacts')}'),
          if (value('destination.confirmed') != 'yes') const Text('Destination has not been confirmed in your plan.'),
          if (value('transport_mode') == 'community') Text('Community transport: ${detail('community_transport')}')
          else if (value('transport_mode') == 'help') Text('Transport help needed: ${detail('transport_help')}')
          else if (vehicles.isEmpty) const Text('Transport: not recorded — update your plan'),
          for (final v in vehicles) Text('Vehicle: ${detail('vehicle.$v')}\nDriver: ${value('driver.$v') == 'other' ? detail('driver_other.$v') : memberName(fields['driver.$v'])} • Household seats: ${detail('seats.$v')}'),
          action('transport'),
          heading('Before leaving'), action('leave'),
          const SizedBox(height: 16), const Text('Follow official warnings. Do not delay evacuation to finish tasks.'),
          const SizedBox(height: 16), OutlinedButton(onPressed: busy ? null : reset, child: const Text('Reset emergency ticks')),
          Text(busy ? 'Saving emergency ticks…' : 'Ticks saved on this device • available offline'),
        ])))),
    );
  }
}
