import 'package:flutter/material.dart';
import '../../services/community_plan_api.dart';
import '../../services/database_helper.dart';

/// Dashboard-scoped draft. Only Send submits it to the documented backend route.
class CommunityPlanDraft {
  String body = '';
  bool sending = false;
  String? feedback;
}

class CommunityPlanEditor extends StatefulWidget {
  final CommunityPlanDraft draft;
  const CommunityPlanEditor({super.key, required this.draft});
  @override
  State<CommunityPlanEditor> createState() => _CommunityPlanEditorState();
}

class _CommunityPlanEditorState extends State<CommunityPlanEditor> {
  late final TextEditingController body;
  bool editing = false;
  @override
  void initState() { super.initState(); body = TextEditingController(text: widget.draft.body); }
  @override
  void dispose() { body.dispose(); super.dispose(); }

  void cancel() => setState(() { body.text = widget.draft.body; editing = false; });
  void save() {
    if (body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the community plan text.')));
      return;
    }
    setState(() { widget.draft.body = body.text.trim(); widget.draft.feedback = null; editing = false; });
  }

  Future<void> send() async {
    if (widget.draft.sending || editing || widget.draft.body.trim().isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send community plan?'),
        content: const Text('Submit this plan to the backend so linked households can retrieve it when opening their dashboard. This action does not confirm push-notification delivery.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit plan')),
        ],
      ),
    );
    if (!mounted || confirmed != true || widget.draft.sending) return;
    final draft = widget.draft;
    setState(() { draft.sending = true; draft.feedback = null; });
    try {
      final db = DatabaseHelper.instance;
      final personId = int.tryParse(await db.getConfig('backend_person_id') ?? '');
      final leaderId = int.tryParse(await db.getConfig('auth_leader_id') ?? '');
      if (personId == null || leaderId == null || personId != leaderId) {
        throw const CommunityPlanApiError('Sign in as the community leader on this registered device before submitting a plan.');
      }
      await CommunityPlanApi().submit(id: personId, body: draft.body);
      draft.feedback = 'Plan saved by the server. Linked households can retrieve it when opening their dashboard. Push delivery has not been confirmed.';
    } on CommunityPlanApiError catch (error) {
      draft.feedback = error.message;
    } catch (_) {
      draft.feedback = 'The plan could not be submitted. Your draft is retained; saving has not been confirmed.';
    } finally {
      draft.sending = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Community evacuation plan', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      if (editing) ...[
        TextField(controller: body, minLines: 8, maxLines: 16, keyboardType: TextInputType.multiline, decoration: const InputDecoration(labelText: 'Plan text', alignLabelWithHint: true, border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(onPressed: save, icon: const Icon(Icons.check), label: const Text('Save draft')),
          TextButton(onPressed: cancel, child: const Text('Cancel')),
        ]),
      ] else ...[
        SelectableText(widget.draft.body.isEmpty ? 'No community plan has been added yet.' : widget.draft.body),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: widget.draft.sending ? null : () => setState(() => editing = true), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: editing || widget.draft.sending || widget.draft.body.isEmpty ? null : send,
        icon: const Icon(Icons.send_outlined),
        label: Text(widget.draft.sending ? 'Submitting…' : 'Send to households'),
      ),
      if (widget.draft.feedback != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(widget.draft.feedback!)),
      ],
      const SizedBox(height: 16),
      const Text('Save draft keeps text only while this dashboard is open. Send submits the body and your registered device ID. Existing server plans are not loaded into this editor yet.', style: TextStyle(color: Colors.white54, fontSize: 13)),
    ],
  );
}
