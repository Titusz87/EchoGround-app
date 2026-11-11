import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/database_helper.dart';

/// Reads the documented refresh-dashboard response; no guessed account IDs.
class CommunityPlanPanel extends StatefulWidget {
  const CommunityPlanPanel({super.key, this.isLeader = false});
  final bool isLeader;
  @override
  State<CommunityPlanPanel> createState() => _CommunityPlanPanelState();
}
class _CommunityPlanPanelState extends State<CommunityPlanPanel> with WidgetsBindingObserver {
  final db = DatabaseHelper.instance;
  final text = TextEditingController();
  Map<String, dynamic> data = {};
  Map<String, bool> checklist = {};
  int? owner;
  StreamSubscription<RemoteMessage>? foreground;
  StreamSubscription<RemoteMessage>? opened;
  bool loading = false, busy = false, editing = false;
  String? message, error;
  static const tasks = {
    'contacts': 'Confirm community emergency contacts',
    'destinations': 'Confirm evacuation locations and alternatives',
    'transport': 'Review available transport and support needs',
    'resources': 'Review water, food and essential community resources',
    'communication': 'Confirm how households will receive updates',
    'review': 'Review and publish the community plan',
  };
  String get roleKey => widget.isLeader ? 'auth_leader_id' : 'auth_household_id';
  String get cacheKey => 'community_plan_cache.v1.${widget.isLeader ? 'leader' : 'household'}.$owner';
  String get draftKey => 'community_plan_draft.v1.$owner';
  String get checklistKey => 'community_checklist.v1.$owner';
  String get body => data['community plans']?.toString() ?? '';
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this); load();
    foreground = FirebaseMessaging.onMessage.listen(planUpdated);
    opened = FirebaseMessaging.onMessageOpenedApp.listen(planUpdated);
  }
  void planUpdated(RemoteMessage event) {
    if (event.data['type'] != 'community_plan' || !mounted) return;
    if (editing || busy || loading) {
      setState(() => message = 'A community plan update was received. Refresh after finishing your current action.');
    } else { load(); }
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); foreground?.cancel(); opened?.cancel(); text.dispose(); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy && !editing) load();
  }
  Future<void> checkOwner() async {
    if (await db.getConfig(roleKey) != '$owner') throw StateError('Account changed');
  }
  Future<Map<String, dynamic>> post(String route, Map<String, dynamic> payload) async {
    const base = String.fromEnvironment('BACKEND_URL');
    if (base.isEmpty) throw StateError('BACKEND_URL is not configured');
    final response = await http.post(Uri.parse('${base.replaceFirst(RegExp(r'/+$'), '')}$route'),
      headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('API ${response.statusCode}');
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (result['status'] != 'ok') throw StateError('API did not confirm success');
    return result;
  }
  Future<void> load() async {
    if (busy || editing || loading) return;
    setState(() { loading = true; error = null; });
    try {
      owner = int.tryParse(await db.getConfig(roleKey) ?? '');
      if (owner == null || owner! < 0) throw StateError('Sign in required');
      final cached = await db.getConfig(cacheKey);
      if (cached != null) data = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      if (widget.isLeader) {
        final saved = await db.getConfig(checklistKey);
        if (saved != null) checklist = Map<String, bool>.from(jsonDecode(saved) as Map);
      }
      final response = await post(widget.isLeader ? '/community-leader/refresh-dashboard' : '/household/refresh-dashboard', {'id': owner});
      await checkOwner();
      data = Map<String, dynamic>.from(response['data'] as Map);
      await db.saveConfig(cacheKey, jsonEncode(data));
      message = 'Latest published plan loaded.';
    } catch (_) {
      error = data.isEmpty ? 'Could not load the community plan. Check your connection and sign-in, then refresh.' : 'Offline or unable to refresh. Showing the last plan saved on this device; it may be out of date.';
    } finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> edit() async {
    try {
      await checkOwner();
      final draft = await db.getConfig(draftKey);
      if (!mounted) return;
      setState(() { text.text = draft ?? body; editing = true; message = draft == null ? null : 'Recovered a local draft. It has not been published.'; });
    } catch (_) { if (mounted) setState(() => error = 'Sign in again before editing.'); }
  }
  Future<void> draft() async {
    setState(() => busy = true);
    try { await checkOwner(); await db.saveConfig(draftKey, text.text); if (mounted) setState(() => message = 'Draft saved on this device only.'); }
    catch (_) { if (mounted) setState(() => error = 'Could not save the draft. Keep this page open.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> publish() async {
    if (text.text.trim().isEmpty) { setState(() => error = 'Enter a community plan before publishing.'); return; }
    setState(() { busy = true; error = null; });
    try {
      await checkOwner();
      final published = text.text.trim();
      final result = await post('/community-leader/create-community-plans', {'id': owner, 'body': published});
      // Publishing succeeded even if a local cache write later fails.
      data = {...data, 'community plans': published};
      var cacheSaved = true;
      try { await db.saveConfig(cacheKey, jsonEncode(data)); await db.saveConfig(draftKey, published); } catch (_) { cacheSaved = false; }
      if (!mounted) return;
      setState(() {
        editing = false;
        message = 'Plan saved to the database. Households can refresh their Plan tab. '
          '${result['notifications_accepted'] ?? 0} of ${result['households_targeted'] ?? 0} household notifications accepted by Firebase (delivery is not guaranteed).'
          '${cacheSaved ? '' : ' Could not update the local offline copy.'}';
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Publishing could not be confirmed. Your text is still open. Refresh to check the server before retrying.');
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> tick(String id, bool value) async {
    setState(() => busy = true);
    try { await checkOwner(); final next = {...checklist, id: value}; await db.saveConfig(checklistKey, jsonEncode(next)); if (mounted) setState(() => checklist = next); }
    catch (_) { if (mounted) setState(() => error = 'Could not save the community checklist on this device.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Community plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    if (message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(message!)),
    if (!widget.isLeader) ...[
      Text('Community: ${data['community name'] ?? 'Not yet loaded'}'),
      Text('Community contact: ${data['community leader name'] ?? 'Not yet loaded'}'),
      Text('Phone: ${data['community leader phone'] ?? 'Not provided'}'),
    ],
    const SizedBox(height: 16),
    if (editing) TextField(controller: text, minLines: 8, maxLines: 18, enabled: !busy,
      decoration: const InputDecoration(labelText: 'Community evacuation plan', border: OutlineInputBorder()))
    else SelectableText(body.isEmpty ? 'No published community plan is available yet.' : body, style: const TextStyle(fontSize: 16, height: 1.5)),
    const SizedBox(height: 16),
    Wrap(spacing: 12, runSpacing: 8, children: [
      if (!editing) OutlinedButton.icon(onPressed: busy || loading ? null : load, icon: const Icon(Icons.refresh), label: const Text('Refresh plan')),
      if (widget.isLeader && !editing) FilledButton(onPressed: busy || loading || owner == null ? null : edit, child: const Text('Edit plan')),
      if (editing) ...[
        OutlinedButton(onPressed: busy ? null : draft, child: const Text('Save draft on device')),
        FilledButton(onPressed: busy ? null : publish, child: Text(busy ? 'Saving…' : 'Publish and notify households')),
        TextButton(onPressed: busy ? null : () => setState(() => editing = false), child: const Text('Cancel editing')),
      ],
    ]),
    if (widget.isLeader) ...[
      const SizedBox(height: 24),
      ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Community preparedness checklist'), subtitle: Text('${checklist.values.where((v) => v).length} of ${tasks.length} checked • saved on this device'), children: [
        const Text('Planning checks for the community leader. These checks are local only and are not sent to households.'),
        for (final task in tasks.entries) CheckboxListTile(controlAffinity: ListTileControlAffinity.leading, title: Text(task.value), value: checklist[task.key] == true, onChanged: busy || owner == null ? null : (v) => tick(task.key, v == true)),
      ]),
      const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Household preparedness status'), children: [ListTile(title: Text('Coming soon'), subtitle: Text('Household completion sharing is not connected to an API in this version.'))]),
      const ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('Privacy and security'), children: [ListTile(title: Text('Coming soon'))]),
    ],
  ])));
}
