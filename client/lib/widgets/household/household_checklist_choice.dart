import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/database_helper.dart';
import 'household_checklist.dart';

class HouseholdChecklistChoice extends StatefulWidget {
  const HouseholdChecklistChoice({super.key});

  @override
  State<HouseholdChecklistChoice> createState() =>
      _HouseholdChecklistChoiceState();
}

enum _ChecklistMode { simple, detailed }

class _HouseholdChecklistChoiceState extends State<HouseholdChecklistChoice> {
  static const _sections = <String, Map<String, String>>{
    'Warnings and contacts': {
      'warnings': 'Know where to check official warnings.',
      'alerts': 'Check that emergency alerts can reach your household.',
      'contacts': 'Save emergency contacts and agree how to stay in touch.',
      'backupContact': 'Choose a backup contact.',
    },
    'Where to go and how to get there': {
      'destination': 'Agree where to go and where to meet if separated.',
      'backupPlace': 'Choose a backup place to stay.',
      'transport': 'Arrange transport and any help your household needs.',
      'backupRide': 'Agree on a backup ride if your first option falls through.',
    },
    'What to pack': {
      'supplies': 'Pack water, food, a torch and a phone charger.',
      'kitLocation': 'Show everyone where the emergency kit is kept.',
      'essentials': 'Pack essential medicines and copies of key documents.',
      'personalItems': 'Check for glasses, hearing aids or other personal essentials.',
    },
    'Pets and household review': {
      'pets': 'Make a plan for any pets or animals.',
      'petKit': 'Check animal carriers, leads, food and other supplies if needed.',
      'share': 'Share the plan with everyone in your household.',
      'review': 'Agree when to review the plan together.',
    },
  };

  static final _tasks = {
    for (final section in _sections.values) ...section,
  };

  final _db = DatabaseHelper.instance;
  int? _owner;
  _ChecklistMode? _mode;
  Set<String> _checked = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _modeKey(int id) => 'household_checklist_mode.v1.$id';
  String _simpleKey(int id) => 'household_simple_checklist.v1.$id';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int?> _session() async {
    final raw = await _db.getConfig('auth_household_id');
    final id = int.tryParse(raw?.trim() ?? '');
    return id != null && id >= 0 ? id : null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _owner = null;
      _mode = null;
      _checked = {};
    });
    try {
      final id = await _session();
      if (!mounted) return;
      if (id == null) {
        setState(() => _error =
            'No valid household session. Open Profile and sign in as Household.');
        return;
      }
      final mode = await _db.getConfig(_modeKey(id));
      final saved = await _db.getConfig(_simpleKey(id));
      final checked = saved == null
          ? <String>{}
          : (jsonDecode(saved) as List)
              .whereType<String>()
              .where(_tasks.containsKey)
              .toSet();
      if (await _session() != id) throw StateError('Household changed');
      if (!mounted) return;
      setState(() {
        _owner = id;
        _mode = switch (mode) {
          'simple' => _ChecklistMode.simple,
          'detailed' => _ChecklistMode.detailed,
          _ => null,
        };
        _checked = checked;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your checklist.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose(_ChecklistMode mode) => _save(
        (id) => _db.saveConfig(_modeKey(id), mode.name),
        () => _mode = mode,
      );

  Future<void> _toggle(String key, bool checked) {
    final next = {..._checked};
    if (checked) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return _save(
      (id) => _db.saveConfig(_simpleKey(id), jsonEncode(next.toList())),
      () => _checked = next,
    );
  }

  Future<void> _save(
    Future<void> Function(int) write,
    VoidCallback apply,
  ) async {
    final id = _owner;
    if (id == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (await _session() != id) throw StateError('Household changed');
      await write(id);
      if (mounted) setState(apply);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this change. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_owner == null) {
      return Column(children: [
        Text(_error ?? 'Could not load your checklist.'),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Choose your checklist',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Use Simple for the essentials, or Detailed for a step-by-step plan. '
          'Each version keeps its own progress.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final mode in _ChecklistMode.values)
              ChoiceChip(
                label: Text(mode == _ChecklistMode.simple ? 'Simple' : 'Detailed'),
                selected: _mode == mode,
                onSelected: _saving || _mode == mode
                    ? null
                    : (_) => _choose(mode),
              ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_mode != null) const SizedBox(height: 16),
        if (_mode == _ChecklistMode.detailed) const HouseholdChecklist(),
        if (_mode == _ChecklistMode.simple)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Household essentials',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('${_checked.length} of ${_tasks.length} done'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _checked.length / _tasks.length),
                  const SizedBox(height: 8),
                  const Text('If an item doesn’t apply to your household, you can tick it off.'),
                  for (final section in _sections.entries) ...[
                    const Divider(height: 24),
                    Text(section.key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    for (final task in section.value.entries)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(task.value),
                        value: _checked.contains(task.key),
                        onChanged: _saving
                            ? null
                            : (value) => _toggle(task.key, value == true),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
