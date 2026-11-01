import 'package:flutter/material.dart';

import '../planning_security_page.dart';

import '../../models/preparedness_plan.dart';
import '../../services/planning_service.dart';
import '../../widgets/planning_widgets.dart';

class HouseholdPlanPage extends StatefulWidget {
  const HouseholdPlanPage({super.key});
  @override
  State<HouseholdPlanPage> createState() => _HouseholdPlanPageState();
}

class _HouseholdPlanPageState extends State<HouseholdPlanPage> {
  final service = PlanningService.instance;
  HouseholdPlan? plan;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final id = await service.currentOwner(false);
      final value = await service.loadHousehold(id);
      if (mounted)
        setState(() {
          plan = value;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Sign in to Household first. If already signed in, local plans could not be loaded.',
        );
    }
  }

  HouseholdPlan copy() => HouseholdPlan.fromJson(plan!.toJson());
  Future<void> save(HouseholdPlan next) async {
    await service.saveHousehold(next);
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
          () => error = 'The change could not be saved. Check your details and try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> setup() async {
    final p = plan!;
    final v = await openPlanningForm(
      context,
      'Household setup',
      [
        PlanningField(
          'community',
          'Name of the community',
          value: p.community,
          communityDirectory: true,
        ),
        PlanningField('family', 'Family name for household', value: p.family),
        PlanningField(
          'count',
          'Total family members',
          value: '${p.totalMembers}',
          number: true,
        ),
      ],
      note: 'Include everyone in the household, including children and people without phones. This plan is saved locally on this device.',
    );
    if (v == null || !mounted) return;
    final next = copy();
    next.community = v['community']!;
    next.family = v['family']!;
    next.totalMembers = int.parse(v['count']!);
    if (next.totalMembers < next.members.length) {
      setState(
        () => error =
            'Total family members must be at least ${next.members.length}, the number of names already listed.',
      );
      return;
    }
    await run(() => save(next));
  }

  Future<void> member([Map<String, dynamic>? m]) async {
    final v = await openPlanningForm(
      context,
      m == null ? 'Add family member' : 'Edit family member',
      [
        PlanningField('name', 'Family member name', value: m?['name'] ?? ''),
        PlanningField(
          'phone',
          'Phone number (optional)',
          value: m?['phone'] ?? '',
          required: false,
          phone: true,
        ),
      ],
      note: 'Only add names and phone numbers you are authorised to provide. Leave the phone blank for children or people using a shared phone. Phone numbers are not included in community summaries.',
    );
    if (v == null || !mounted) return;
    final next = copy();
    if (m == null) {
      next.members.add({'id': planningId(), ...v});
    } else {
      final i = next.members.indexWhere((x) => x['id'] == m['id']);
      next.members[i] = {...m, ...v};
    }
    if (next.members.length > next.totalMembers)
      next.totalMembers = next.members.length;
    await run(() => save(next));
  }

  Future<void> removeMember(Map<String, dynamic> member) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove family member?'),
        content: const Text(
          'The total family count is kept unchanged so you can review it separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final next = copy();
    next.members.removeWhere((m) => m['id'] == member['id']);
    await run(() => save(next));
  }

  Future<void> checklist(bool outside) async {
    final p = plan!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanningChecklistPage(
          title: outside ? 'Prepare the dwelling' : 'Prepare to evacuate',
          checks: outside ? dwellingChecks : evacuationChecks,
          initial: outside ? p.dwelling : p.evacuation,
          property: outside,
          onSave: (values) async {
            final next = copy();
            if (outside) {
              next.dwelling = Map.from(values);
            } else {
              next.evacuation = Map.from(values);
            }
            await save(next);
          },
        ),
      ),
    );
  }

  Future<void> sharing() async {
    try {
      final choices = await service.communityChoices();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _HouseholdSharingPage(
            initial: copy(),
            choices: choices,
            onSave: save,
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Community workspaces could not be loaded. Try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return PlanningShell(
      title: 'My household plan',
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
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(error!),
            ),
          if (p == null) ...[
            if (error == null) const LinearProgressIndicator(),
            TextButton(onPressed: load, child: const Text('Reload plan')),
          ] else ...[
            if (busy) const LinearProgressIndicator(),
            PlanningPanel(
              p.family.isEmpty
                  ? 'Start with your household'
                  : '${p.family} household',
              [
                Text(
                  p.community.isEmpty
                      ? 'Community not yet recorded'
                      : p.community,
                ),
                const SizedBox(height: 8),
                Text(
                  '${p.totalMembers} total family members · ${p.members.length} named',
                ),
                if (!p.setupComplete)
                  const Text(
                    'Complete household setup and list everyone to finish your plan.',
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : setup,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Household setup'),
                ),
              ],
            ),
            PlanningPanel('Readiness progress', [
              PlanningProgress(p.progress),
              const SizedBox(height: 12),
              Text('Plan status: ${p.status}'),
              const Text(
                'Percentage covers checklist answers. Plan completion also requires household details and everyone listed. Readiness is separate from a person’s current safety or location.',
              ),
            ]),
            PlanningPanel('Get ready to leave', [
              Text(
                '${p.evacuationProgress.percent}% · Supplies, contacts and transport',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : () => checklist(false),
                icon: const Icon(Icons.backpack_outlined),
                label: const Text('Evacuation checklist'),
              ),
            ]),
            PlanningPanel('Prepare the dwelling', [
              Text(
                '${p.dwellingProgress.percent}% · Outside areas and property preparation',
              ),
              const SizedBox(height: 8),
              const Text(planningSafetyNote),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : () => checklist(true),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Dwelling checklist'),
              ),
            ]),
            PlanningPanel('Family members', [
              const Text(
                'Private names and phone numbers. Adding a name does not confirm that person is onsite.',
              ),
              if (p.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No family members added yet.'),
                ),
              for (final m in p.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m['name']),
                  subtitle: Text(
                    (m['phone'] as String).isEmpty
                        ? 'No individual phone'
                        : m['phone'],
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Edit family member',
                        onPressed: busy ? null : () => member(m),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove family member',
                        onPressed: busy ? null : () => removeMember(m),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              if (p.totalMembers > p.members.length)
                Text(
                  '${p.totalMembers - p.members.length} family members still need to be listed.',
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => member(),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add family member'),
              ),
            ]),
            PlanningPanel('Security & privacy', [
              Text(
                p.shareSummary || p.shareResidents
                    ? 'Selected information is available in the chosen local community workspace.'
                    : 'Private by default. Nothing is shared with a community workspace.',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlanningSecurityPage(
                              leader: false,
                              onManageSharing: sharing,
                            ),
                          ),
                        );
                        if (mounted) await load();
                      },
                child: const Text('Manage security & privacy'),
              ),
            ]),
            Text(
              'Last saved: ${p.updatedAt.isEmpty ? 'Not saved yet' : p.updatedAt}',
            ),
            const SizedBox(height: 8),
            Text(
              PlanningService.previewMode
                  ? 'Design preview: fictional plans stay in memory only and reset on reload. No planning information is sent to the backend.'
                  : 'Local prototype: saved in this device’s existing SQLite storage, not encrypted by this feature. Use fictional contacts for testing on shared devices. No planning information is sent to the backend.',
            ),
          ],
        ],
      ),
    );
  }
}

class _HouseholdSharingPage extends StatefulWidget {
  const _HouseholdSharingPage({
    required this.initial,
    required this.choices,
    required this.onSave,
  });
  final HouseholdPlan initial;
  final List<Map<String, dynamic>> choices;
  final Future<void> Function(HouseholdPlan) onSave;
  @override
  State<_HouseholdSharingPage> createState() => _SharingState();
}

class _SharingState extends State<_HouseholdSharingPage> {
  late final p = widget.initial;
  late final label = TextEditingController(text: p.sharedLabel);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlanningShell(
    title: 'Household sharing',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Choose a recipient explicitly. A community name alone does not establish membership or permission to share.',
        ),
        const SizedBox(height: 18),
        if (widget.choices.isEmpty)
          const Text(
            'No community workspace is configured on this device yet. A leader must set one up before you can preview sharing.',
          ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: widget.choices.any((c) => c['id'] == p.recipientId)
              ? p.recipientId
              : null,
          decoration: const InputDecoration(
            labelText: 'Recipient community workspace',
          ),
          items: [
            for (final c in widget.choices)
              DropdownMenuItem(
                value: c['id'] as String,
                child: Text(c['name']),
              ),
          ],
          onChanged: busy ? null : (v) => setState(() => p.recipientId = v),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: label,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Shared household label (e.g. Household 07)',
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share plan completion'),
          subtitle: const Text(
            'Shared label, completion status, percentages and last-saved time only.',
          ),
          value: p.shareSummary,
          onChanged: busy ? null : (v) => setState(() => p.shareSummary = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share names for the residents’ roll'),
          subtitle: const Text(
            'Names and household count only, with the members’ agreement or appropriate guardian authorisation. Phone numbers and private checklist answers stay private.',
          ),
          value: p.shareResidents,
          onChanged: busy ? null : (v) => setState(() => p.shareResidents = v),
        ),
        const Text(
          'Sharing is a same-device prototype. It does not send data to other phones. Turn both options off and save to revoke local visibility. Copies already made cannot be recalled.',
        ),
        if (error != null) Text(error!),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  p.sharedLabel = label.text.trim();
                  p.consentUpdatedAt = planningTime();
                  p.privacyNoticeVersion = '1.0';
                  try {
                    await widget.onSave(p);
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted)
                      setState(
                        () => error = 'Choose a recipient and shared label before sharing. If already set, saving failed; try again.',
                      );
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Saving…' : 'Save sharing choices'),
        ),
      ],
    ),
  );
}
