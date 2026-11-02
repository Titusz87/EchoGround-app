import 'package:flutter/material.dart';

import '../../widgets/community_leader/community_coming_soon.dart';

import '../planning_security_page.dart';

import '../../models/preparedness_plan.dart';
import '../../services/planning_service.dart';
import '../../widgets/planning_widgets.dart';

class CommunityPlanPage extends StatefulWidget {
  const CommunityPlanPage({super.key});
  @override
  State<CommunityPlanPage> createState() => _CommunityPlanPageState();
}

class _CommunityPlanPageState extends State<CommunityPlanPage> {
  final service = PlanningService.instance;
  CommunityPlan? plan;
  List<Map<String, dynamic>> summaries = [];
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (communityPlanningAvailable) load();
  }

  Future<void> load() async {
    try {
      final id = await service.currentOwner(true);
      final p = await service.loadCommunity(id);
      final rows = await service.summaries(id);
      if (mounted)
        setState(() {
          plan = p;
          summaries = rows;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Sign in as a community leader first. If already signed in, local plans could not be loaded.',
        );
    }
  }

  CommunityPlan copy() => CommunityPlan.fromJson(plan!.toJson());
  Future<void> save(CommunityPlan next) async {
    await service.saveCommunity(next);
    if (mounted) setState(() => plan = next);
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'The change could not be saved. Please try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setup() async {
    final v = await openPlanningForm(
      context,
      'Community setup',
      [
        PlanningField(
          'name',
          'Name of the community',
          value: plan!.name,
          communityDirectory: true,
        ),
      ],
      note: 'Use the name of the community you coordinate. This local workspace is separate from backend community membership.',
    );
    if (v == null || !mounted) return;
    final next = copy();
    next.name = v['name']!;
    await run(() => save(next));
  }

  Future<void> addBuilding() async {
    final v = await openPlanningForm(context, 'Add community building', [
      const PlanningField('name', 'Building name'),
      const PlanningField('location', 'Location / address'),
    ]);
    if (v == null || !mounted) return;
    final next = copy();
    next.buildings.add({'id': planningId(), ...v});
    await run(() => save(next));
  }

  Future<void> buildingChecklist(Map<String, dynamic> building) async {
    final prefix = '${building['id']}:';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanningChecklistPage(
          title: '${building['name']} checklist',
          checks: buildingChecks,
          property: true,
          initial: {
            for (final k in buildingChecks.keys)
              k: plan!.building['$prefix$k'] ?? 'todo',
          },
          onSave: (values) async {
            final next = copy();
            for (final e in values.entries) {
              next.building['$prefix${e.key}'] = e.value;
            }
            await save(next);
          },
        ),
      ),
    );
  }

  Future<void> roll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ResidentsRollPage(ownerId: plan!.ownerId),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    if (!communityPlanningAvailable) {
      return PlanningShell(
        title: 'Community tools',
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: const [CommunityComingSoon()],
        ),
      );
    }
    final p = plan;
    final rows = summaries.where((r) => r.containsKey('status')).toList();
    return PlanningShell(
      title: 'Community plan',
      actions: [
        IconButton(
          tooltip: 'Refresh local plans',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'ECHOGROUND • PREPARED TOGETHER',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          if (error != null) Text(error!),
          if (p == null) ...[
            if (error == null) const LinearProgressIndicator(),
            TextButton(onPressed: load, child: const Text('Reload plan')),
          ] else ...[
            if (busy) const LinearProgressIndicator(),
            PlanningPanel(p.name.isEmpty ? 'Set up your community' : p.name, [
              const Text(
                'Local planning prototype. Only explicitly shared households stored on this device appear here. This is not a complete live community directory.',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : setup,
                child: const Text('Community setup'),
              ),
            ]),
            PlanningPanel('Household plan status', [
              const Text(
                'Only households sharing plan completion are counted. Missing or private plans are not counted as incomplete.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final state in ['Complete', 'Incomplete', 'Not started'])
                    Chip(
                      label: Text(
                        '$state: ${rows.where((r) => r['status'] == state).length}',
                      ),
                    ),
                ],
              ),
              if (rows.isEmpty)
                const Text('No household plan summaries shared yet.'),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row['label']} · ${row['status']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        '${row['percent']}% overall · evacuation ${row['evacuationPercent']}% · dwelling ${row['dwellingPercent']}%',
                      ),
                      Text('Last saved: ${row['updatedAt']}'),
                    ],
                  ),
                ),
            ]),
            PlanningPanel('Community buildings', [
              PlanningProgress(p.progress),
              const SizedBox(height: 12),
              const Text(planningSafetyNote),
              for (final b in p.buildings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b['name']),
                  subtitle: Text(
                    '${b['location']}\n${ChecklistProgress(p.building, buildingChecks.keys.map((k) => "${b['id']}:$k")).percent}% checklist complete',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => buildingChecklist(b),
                ),
              if (p.buildings.isEmpty)
                const Text(
                  'Add a building to start its outside preparedness checklist.',
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : addBuilding,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Add community building'),
              ),
            ]),
            PlanningPanel('Residents onsite', [
              const Text(
                'Record each person’s observed status for a specific event. A household plan or building checklist never automatically marks people as present.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : roll,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Open residents’ roll'),
              ),
            ]),
            PlanningPanel('Security & privacy', [
              const Text(
                'Review resident visibility, local storage and shared-device controls.',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PlanningSecurityPage(leader: true),
                          ),
                        );
                        if (mounted) await load();
                      },
                child: const Text('Manage security & privacy'),
              ),
            ]),
            Text(
              PlanningService.previewMode
                  ? 'Design preview: data stays in memory and resets on reload. No real accounts, private plans or backend records are used.'
                  : 'Local SQLite storage. Names and phone numbers are not added to warning caches or offline public packs. Cross-device updates and school/work roster integration need future backend support.',
            ),
          ],
        ],
      ),
    );
  }
}

class _ResidentsRollPage extends StatefulWidget {
  const _ResidentsRollPage({required this.ownerId});
  final String ownerId;
  @override
  State<_ResidentsRollPage> createState() => _ResidentsRollState();
}

class _ResidentsRollState extends State<_ResidentsRollPage> {
  final service = PlanningService.instance;
  CommunityPlan? plan;
  List<Map<String, dynamic>> shared = [];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await service.loadCommunity(widget.ownerId);
      final rows = await service.summaries(widget.ownerId);
      if (mounted)
        setState(() {
          plan = p;
          shared = rows;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'The local roll could not be loaded. Please sign in again or retry.',
        );
    }
  }

  Future<void> save(CommunityPlan next) async {
    await service.saveCommunity(next);
    if (mounted) setState(() => plan = next);
  }

  Future<void> run(Future<void> Function() f) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await f();
    } catch (_) {
      if (mounted)
        setState(() => error = 'The report could not be saved. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Map<String, dynamic>> get residents => [
    for (final h in shared)
      for (final m in h['residents'] as List? ?? [])
        {
          'key': 'household:${h['ownerId']}:${m['id']}',
          'name': m['name'],
          'group': h['label'],
          'source': 'household',
        },
    for (final m in plan?.residents ?? [])
      {
        'key': 'manual:${m['id']}',
        'name': m['name'],
        'group': m['group'],
        'source': 'manual',
      },
    for (final guest in plan?.currentGuests ?? [])
      {
        'key': 'guest:${guest['session']}:${guest['id']}',
        'name': guest['name'],
        'group': guest['group'],
        'source': 'guest',
      },
  ];
  Future<void> startEvent() async {
    final v = await openPlanningForm(
      context,
      'Start a new roll call',
      [const PlanningField('event', 'Incident / exercise reference')],
      note: 'Starting a new roll call resets everyone to Not confirmed. Older observations remain stored but never count as current presence. Guests from a previous event are not carried into the new roll.',
    );
    if (v == null || !mounted) return;
    final next = CommunityPlan.fromJson(plan!.toJson());
    next.eventLabel = v['event']!;
    next.rollSession = planningId();
    await run(() => save(next));
  }

  Future<void> addResident() async {
    final v = await openPlanningForm(
      context,
      'Add resident',
      [
        const PlanningField('name', 'Resident name'),
        const PlanningField(
          'group',
          'Household / group reference',
          required: false,
        ),
      ],
      note: 'Only record names you are authorised to hold for the residents’ roll. A phone number is not needed. This does not create an account.',
    );
    if (v == null || !mounted) return;
    final next = CommunityPlan.fromJson(plan!.toJson());
    next.residents.add({'id': planningId(), ...v});
    await run(() => save(next));
  }

  Future<void> addGuest() async {
    if (plan!.rollSession.isEmpty) {
      setState(
        () => error = 'Start an incident roll call before adding guests.',
      );
      return;
    }
    final session = plan!.rollSession;
    final v = await openPlanningForm(
      context,
      'Add guest to this incident',
      [
        const PlanningField('name', 'Guest name or agreed reference'),
        const PlanningField(
          'group',
          'Host household / group reference (optional)',
          required: false,
        ),
      ],
      note: 'Only record details you are authorised to hold. No phone number is needed. This guest is added to this incident only and starts as Not confirmed, not automatically onsite.',
    );
    if (v == null || !mounted) return;
    if (session != plan!.rollSession) {
      setState(
        () => error =
            'The incident changed. Please add the guest to the current roll.',
      );
      return;
    }
    final next = CommunityPlan.fromJson(plan!.toJson());
    next.guests.add({
      'id': planningId(),
      'session': session,
      'event': next.eventLabel,
      'addedAt': planningTime(),
      ...v,
    });
    await run(() => save(next));
  }

  Future<void> record(Map<String, dynamic> resident) async {
    if (plan!.rollSession.isEmpty) {
      setState(
        () => error = 'Start a roll call before recording observations.',
      );
      return;
    }
    final v = await openPlanningForm(
      context,
      'Confirm ${resident['name']}',
      [
        PlanningField(
          'status',
          'Observed status',
          options: resident['source'] == 'guest'
              ? {
                  ...presenceOptions,
                  'away': 'Left community / away — confirmed',
                }
              : presenceOptions,
          value: plan!.presenceFor(resident['key']),
        ),
        const PlanningField('reporter', 'Reported by (name or role)'),
        const PlanningField(
          'method',
          'Confirmation method',
          options: {
            'in_person': 'In person',
            'phone': 'Phone',
            'radio': 'Radio',
          },
        ),
        PlanningField(
          'observedAt',
          'Observation time (ISO 8601)',
          value: planningTime(),
        ),
      ],
      note: 'Record an observation, not an assumption. Onsite does not mean safe. Unconfirmed is not the same as away.',
    );
    if (v == null || !mounted) return;
    final time = DateTime.tryParse(v['observedAt']!);
    if (time == null ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(v['observedAt']!) ||
        time.isAfter(DateTime.now())) {
      setState(
        () => error = 'Use a valid observation time including timezone, not in the future.',
      );
      return;
    }
    final next = CommunityPlan.fromJson(plan!.toJson());
    final key = resident['key'] as String;
    final old = next.observations[key] as Map?;
    if (old != null &&
        old['session'] == next.rollSession &&
        DateTime.parse(old['observedAt']).isAfter(time)) {
      setState(
        () => error = 'An observation newer than this one is already recorded. The current status has not changed.',
      );
      return;
    }
    next.observations[key] = {
      ...v,
      'observedAt': time.toUtc().toIso8601String(),
      'recordedAt': planningTime(),
      'session': next.rollSession,
      'event': next.eventLabel,
      'source': resident['source'],
      'history': old == null
          ? []
          : [
              {
                for (final e in old.entries)
                  if (e.key != 'history') e.key: e.value,
              },
              ...(old['history'] as List? ?? []),
            ],
    };
    await run(() => save(next));
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    final people = residents;
    final onsite = people
        .where((r) => ['onsite', 'help'].contains(p?.presenceFor(r['key'])))
        .length;
    final unlisted = shared.fold<int>(
      0,
      (sum, h) =>
          sum +
          ((h['totalMembers'] as int? ?? 0) -
              (h['residents'] as List? ?? []).length),
    );
    return PlanningShell(
      title: 'Residents’ roll',
      actions: [
        IconButton(
          tooltip: 'Refresh local roll',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (error != null) Text(error!),
          if (p == null) ...[
            if (error == null) const LinearProgressIndicator(),
            TextButton(onPressed: load, child: const Text('Reload roll')),
          ] else ...[
            if (busy) const LinearProgressIndicator(),
            PlanningPanel('Confirm who is onsite', [
              Text(
                'Current event: ${p.eventLabel.isEmpty ? 'Not started' : p.eventLabel}',
              ),
              Text(
                '${people.where((r) => r['source'] != 'guest').length} residents · ${p.currentGuests.length} incident guests',
              ),
              Text(
                '$onsite observed onsite / ${people.length} listed people',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Not confirmed: ${people.where((r) => p.presenceFor(r['key']) == 'unknown').length} · Confirmed away: ${people.where((r) => p.presenceFor(r['key']) == 'away').length}',
              ),
              if (unlisted > 0)
                Text(
                  '$unlisted people in shared household counts have no listed name yet; they are not accounted for by this roll.',
                ),
              const Text(
                'This is a local list, not all community residents. Names appear only through opt-in household sharing or authorised manual entry.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : startEvent,
                child: const Text('Start a new roll call'),
              ),
            ]),
            for (final resident in people)
              PlanningPanel(
                '${resident['name']}${resident['source'] == 'guest' ? ' • Guest' : ''}',
                [
                  Text(
                    '${resident['group']} · ${resident['source'] == 'guest' && p.presenceFor(resident['key']) == 'away' ? 'Left community / away — confirmed' : presenceOptions[p.presenceFor(resident['key'])]}',
                  ),
                  if (p.observations[resident['key']] != null)
                    Text(
                      'Last observation: ${p.observations[resident['key']]['observedAt']} · ${p.observations[resident['key']]['reporter']}\nEvent: ${p.observations[resident['key']]['event']}',
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: busy ? null : () => record(resident),
                    child: const Text('Record observation'),
                  ),
                ],
              ),
            OutlinedButton.icon(
              onPressed: busy ? null : addResident,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add resident'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || p.rollSession.isEmpty ? null : addGuest,
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('Add incident guest'),
            ),
            const Text(
              'Guests belong to the current incident only. Start a roll call to add guests; record an observation to confirm their presence or departure.',
            ),

            const SizedBox(height: 12),
            const Text(
              'Future school/work records can link using stable person references and event-scoped observations. No automatic roster links are active yet.',
            ),
          ],
        ],
      ),
    );
  }
}
