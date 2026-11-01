import 'package:flutter/material.dart';

import '../models/preparedness_plan.dart';
import '../services/planning_service.dart';
import '../widgets/planning_widgets.dart';
import 'login_page.dart';

class PlanningSecurityPage extends StatefulWidget {
  const PlanningSecurityPage({
    super.key,
    required this.leader,
    this.onManageSharing,
  });
  final bool leader;
  final Future<void> Function()? onManageSharing;
  @override
  State<PlanningSecurityPage> createState() => _SecurityState();
}

class _SecurityState extends State<PlanningSecurityPage> {
  final service = PlanningService.instance;
  String? ownerId, error;
  HouseholdPlan? household;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final id = await service.currentOwner(widget.leader);
      final p = widget.leader ? null : await service.loadHousehold(id);
      if (mounted)
        setState(() {
          ownerId = id;
          household = p;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Sign in to view planning privacy controls.');
    }
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
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
          () => error = 'The action could not be completed. Please try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeLocalRecords() async {
    final id = ownerId;
    if (id == null) return;
    final accepted = await confirm(
      widget.leader
          ? 'Clear local roll-call records?'
          : 'Delete this local household plan?',
      widget.leader
          ? 'This removes manually entered residents, incident guests and recorded observations, including history, from this community workspace on this device. Shared household names may still appear while their owners keep sharing. Buildings and checklist answers remain. This does not delete backend records.'
          : 'This removes this household’s names, phone numbers, checklist answers and local shared summary. Your account and backend records are not deleted. Copies or observations previously recorded by others cannot be recalled.',
    );
    if (!accepted || !mounted) return;
    await run(() async {
      if (widget.leader) {
        await service.clearRollRecords(id);
      } else {
        await service.deleteHouseholdPlan(id);
      }
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local planning records removed.')),
        );
    });
  }

  Future<void> closeWorkspace() async {
    if (PlanningService.previewMode) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (!await confirm(
      'Close planning access on this device?',
      'You will need to sign in again to reopen household or community plans. Saved local records remain. This closes the app’s planning access; it does not revoke a backend session.',
    ))
      return;
    if (!mounted) return;
    await run(() async {
      await service.closePlanningAccess();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = household;
    return PlanningShell(
      title: 'Security & privacy',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Understand and control your planning information.',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          if (error != null) Text(error!),
          if (busy || (ownerId == null && error == null))
            const LinearProgressIndicator(),
          PlanningPanel('Why we ask for information', [
            Text(
              widget.leader
                  ? 'Building details support preparedness tasks. Resident names and observations help coordinate an event-specific roll call. They are not a public directory.'
                  : 'Community and household details organise your plan. Family names support preparedness and roll calls. Optional phone numbers help your household contact each other.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Only record information you are authorised to provide. Children and people sharing phones do not need an individual phone number. Avoid diagnoses, identity documents and other details this plan does not need.',
            ),
          ]),
          PlanningPanel('Who can see what?', [
            Text(
              widget.leader
                  ? 'Your community view shows only household summaries explicitly shared with this workspace. Resident names require a separate sharing choice or authorised manual entry. Guests are recorded for one incident and are not added to permanent community membership. Phone numbers and private checklist answers are not included.'
                  : 'Public warnings do not contain your plan. Your private family names, phone numbers and checklist answers are not included in community completion summaries.',
            ),
            const SizedBox(height: 8),
            const Text(
              'The residents’ roll is not public. Onsite, away and needs-help reports have an observation time and event reference. They are not continuous location tracking or a guarantee of safety.',
            ),
          ]),
          if (!widget.leader)
            PlanningPanel('My sharing choices', [
              Text(
                'Plan completion: ${p?.shareSummary == true ? 'Sharing on' : 'Off'}',
              ),
              Text(
                'Names for the residents’ roll: ${p?.shareResidents == true ? 'Sharing on' : 'Off'}',
              ),
              Text(
                'Shared label: ${(p?.sharedLabel.isNotEmpty ?? false) ? p!.sharedLabel : 'Not set'}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Each purpose has its own opt-in. Choose the recipient community explicitly. You can turn sharing off later; copies or recorded observations already held by others cannot automatically be recalled.',
              ),
              if (p?.consentUpdatedAt.isNotEmpty ?? false)
                Text(
                  'Choices last saved: ${p!.consentUpdatedAt} · Notice ${p.privacyNoticeVersion}',
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy || ownerId == null
                    ? null
                    : () async {
                        await widget.onManageSharing?.call();
                        if (mounted) await load();
                      },
                child: const Text('Review who I share with'),
              ),
            ]),
          const PlanningPanel('School and work links', [
            Text(
              'Not connected yet. No resident information is automatically sent to a school or workplace. Future links will need approved access permissions and a clear explanation of what is shared.',
            ),
          ]),
          PlanningPanel('This device and offline storage', [
            Text(
              PlanningService.previewMode
                  ? 'This design preview keeps fictional plans in memory only. Reloading resets the preview. It does not read or change your normal account or planning database.'
                  : 'This prototype saves planning records in local SQLite storage. This feature does not encrypt that storage. A shared or unlocked device may expose saved information. Use fictional personal details while testing.',
            ),
            SizedBox(height: 8),
            Text(
              'Private plans and resident lists are not placed in public warning caches. Planning data does not sync between devices yet. Local role checks do not replace backend authentication or permissions.',
            ),
          ]),
          PlanningPanel('Manage saved information', [
            Text(
              widget.leader
                  ? 'Clear locally recorded resident, guest and observation data when it is no longer needed. This does not erase another household’s source plan or backend data.'
                  : 'Edit or remove family members from your household plan. You can also delete this device’s household plan and its local shared summary.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || ownerId == null ? null : removeLocalRecords,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                widget.leader
                    ? 'Clear local roll-call records'
                    : 'Delete local household plan',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy || ownerId == null ? null : closeWorkspace,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Close planning workspace'),
            ),
          ]),
          const Text(
            'Privacy notice • version 1.0. Production access controls, encryption, retention rules and server-side deletion must be completed and tested with the backend team.',
          ),
        ],
      ),
    );
  }
}
