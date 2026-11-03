import 'dart:convert';
import 'basic_plan_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final editorFocus = FocusNode();
  bool editing = false;
  bool preview = false;
  int textLevel = 0;
  bool loading = true;
  bool saving = false;
  int? ownerId;
  String? loadError;

  Future<void> loadDraft() async {
    try {
      final db = DatabaseHelper.instance;
      final id = int.tryParse(await db.getConfig('auth_leader_id') ?? '');
      if (id == null || id <= 0) throw StateError('Sign in as a community leader to load a draft.');
      final raw = await db.getConfig('community_plan.draft.v1.$id');
      if (raw != null && raw.isNotEmpty) {
        final value = jsonDecode(raw);
        if (value is! Map || value['body'] is! String) throw StateError('Saved draft could not be read.');
        widget.draft.body = value['body'] as String;
      }
      if (mounted) setState(() { ownerId = id; body.text = widget.draft.body; loading = false; loadError = null; });
    } catch (_) {
      if (mounted) setState(() { loading = false; loadError = 'The saved draft could not be loaded. Check your sign-in and try again.'; });
    }
  }

  Future<void> persistDraft(String text) async {
    final db = DatabaseHelper.instance;
    final current = int.tryParse(await db.getConfig('auth_leader_id') ?? '');
    if (ownerId == null || current != ownerId) throw StateError('Account changed.');
    await db.saveConfig('community_plan.draft.v1.$ownerId', jsonEncode({'body': text, 'saved_at': DateTime.now().toUtc().toIso8601String()}));
  }
  @override
  void initState() { super.initState(); body = TextEditingController(text: widget.draft.body); loadDraft(); }
  @override
  void dispose() { body.dispose(); editorFocus.dispose(); super.dispose(); }

  void cancel() => setState(() { body.text = widget.draft.body; editing = false; });
  Future<int> registeredLeader() async {
    final db = DatabaseHelper.instance;
    final personId = int.tryParse(await db.getConfig('backend_person_id') ?? '');
    final leaderId = int.tryParse(await db.getConfig('auth_leader_id') ?? '');
    if (personId == null || personId != leaderId || leaderId != ownerId) {
      throw const CommunityPlanApiError('Sign in as the community leader on this registered device before saving.');
    }
    return personId;
  }

  Future<void> save() async {
    if (saving || loading || widget.draft.sending) return;
    final text = body.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the community plan text.')));
      return;
    }
    setState(() { saving = true; widget.draft.feedback = null; });
    try {
      final id = await registeredLeader();
      await CommunityPlanApi().submit(id: id, body: text);
      widget.draft.body = text;
      widget.draft.feedback = 'Plan saved to the backend database. Household retrieval is pending its API.';
      try { await persistDraft(text); } catch (_) {
        widget.draft.feedback = 'Plan saved to the backend, but the local copy could not be updated.';
      }
      if (mounted) setState(() => editing = false);
    } on CommunityPlanApiError catch (error) {
      widget.draft.feedback = error.message;
    } catch (_) {
      widget.draft.feedback = 'Saving could not be confirmed. Your text remains in the editor.';
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void formatInline(String before, String after) {
    final value = body.text;
    final selected = body.selection;
    final start = selected.isValid ? selected.start : value.length;
    final end = selected.isValid ? selected.end : value.length;
    final inner = start == end ? 'text' : value.substring(start, end);
    body.value = TextEditingValue(
      text: value.replaceRange(start, end, '$before$inner$after'),
      selection: TextSelection(baseOffset: start + before.length, extentOffset: start + before.length + inner.length),
    );
    editorFocus.requestFocus();
  }

  void formatList(bool numbered) {
    final value = body.text;
    final selected = body.selection;
    final start = selected.isValid ? selected.start : value.length;
    var end = selected.isValid ? selected.end : value.length;
    if (end > start && value[end - 1] == '\n') end--;
    final lineStart = start == 0 ? 0 : value.lastIndexOf('\n', start - 1) + 1;
    final next = value.indexOf('\n', end);
    final lineEnd = next < 0 ? value.length : next;
    final previousEnd = lineStart > 0 ? lineStart - 1 : 0;
    final previousStart = previousEnd > 0 ? value.lastIndexOf('\n', previousEnd - 1) + 1 : 0;
    final previousNumber = RegExp(r'^\s*(\d+)\. ').firstMatch(value.substring(previousStart, previousEnd));
    final firstNumber = previousNumber == null ? 1 : (int.tryParse(previousNumber.group(1)!) ?? 0) + 1;
    final lines = value.substring(lineStart, lineEnd).split('\n');
    final result = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final content = lines[i].replaceFirst(RegExp(r'^\s*(?:- |\d+\. )'), '');
      result.add('${numbered ? '${firstNumber + i}. ' : '- '}$content');
    }
    final replacement = result.join('\n');
    body.value = TextEditingValue(text: value.replaceRange(lineStart, lineEnd, replacement), selection: TextSelection.collapsed(offset: lineStart + replacement.length));
    editorFocus.requestFocus();
  }

  void changeTextSize(int level) {
    final text = body.text;
    final selection = body.selection;
    final start = selection.isValid ? selection.start : text.length;
    var end = selection.isValid ? selection.end : text.length;
    if (end > start && text[end - 1] == '\n') end--;
    final first = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final newline = text.indexOf('\n', end);
    final last = newline < 0 ? text.length : newline;
    final prefix = level == 0 ? '' : '${'#' * level} ';
    final replacement = text.substring(first, last).split('\n').map((line) => '$prefix${line.replaceFirst(RegExp(r'^#{1,3} '), '')}').join('\n');
    body.value = TextEditingValue(text: text.replaceRange(first, last, replacement), selection: TextSelection.collapsed(offset: first + replacement.length));
    setState(() => textLevel = level);
    editorFocus.requestFocus();
  }

  Widget toolbar() => Wrap(spacing: 4, runSpacing: 4, children: [
    IconButton(tooltip: 'Bold', onPressed: saving || preview ? null : () => formatInline('**', '**'), icon: const Icon(Icons.format_bold)),
    IconButton(tooltip: 'Italic', onPressed: saving || preview ? null : () => formatInline('*', '*'), icon: const Icon(Icons.format_italic)),
    IconButton(tooltip: 'Underline', onPressed: saving || preview ? null : () => formatInline('<u>', '</u>'), icon: const Icon(Icons.format_underlined)),
    IconButton(tooltip: 'Bullet list', onPressed: saving || preview ? null : () => formatList(false), icon: const Icon(Icons.format_list_bulleted)),
    IconButton(tooltip: 'Numbered list', onPressed: saving || preview ? null : () => formatList(true), icon: const Icon(Icons.format_list_numbered)),
    DropdownButton<int>(
      value: textLevel,
      hint: const Text('Text size'),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Normal')),
        DropdownMenuItem(value: 3, child: Text('Large')),
        DropdownMenuItem(value: 2, child: Text('Heading')),
        DropdownMenuItem(value: 1, child: Text('Title')),
      ],
      onChanged: saving || preview ? null : (value) { if (value != null) changeTextSize(value); },
    ),
    TextButton.icon(onPressed: saving ? null : () => setState(() => preview = !preview), icon: Icon(preview ? Icons.edit_outlined : Icons.visibility_outlined), label: Text(preview ? 'Edit text' : 'Preview')),
  ]);

  Future<void> send() async {
    if (loading || saving || loadError != null || widget.draft.sending || editing || widget.draft.body.trim().isEmpty) return;
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
      await persistDraft(draft.body);
      await CommunityPlanApi().submit(id: personId, body: draft.body);
      draft.feedback = 'Plan saved by the server. Household retrieval awaits its read API; push delivery has not been confirmed.';
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
      if (loading) const LinearProgressIndicator(),
      if (loadError != null) ...[
        Text(loadError!),
        TextButton(onPressed: () { setState(() { loading = true; }); loadDraft(); }, child: const Text('Retry loading draft')),
      ],
      Text('Community evacuation plan', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      if (editing) ...[
        toolbar(),
        const SizedBox(height: 8),
        if (preview) BasicPlanText(text: body.text) else TextField(inputFormatters: [ContinuePlanList()], focusNode: editorFocus,enabled: !saving, controller: body, minLines: 8, maxLines: 16, keyboardType: TextInputType.multiline, decoration: const InputDecoration(labelText: 'Plan text', alignLabelWithHint: true, border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(onPressed: saving ? null : save, icon: const Icon(Icons.check), label: Text(saving ? 'Saving…' : 'Save plan')),
          TextButton(onPressed: saving ? null : cancel, child: const Text('Cancel')),
        ]),
      ] else ...[
        BasicPlanText(text: widget.draft.body.isEmpty ? 'No community plan has been added yet.' : widget.draft.body),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: loading || loadError != null || widget.draft.sending ? null : () => setState(() { editing = true; preview = false; }), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: loading || loadError != null || saving || editing || widget.draft.sending || widget.draft.body.isEmpty ? null : send,
        icon: const Icon(Icons.send_outlined),
        label: Text(widget.draft.sending ? 'Submitting…' : 'Send to households'),
      ),
      if (widget.draft.feedback != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(widget.draft.feedback!)),
      ],
      const SizedBox(height: 16),
      const Text('Save plan submits formatted text to the backend and keeps a local copy for reopening. Formatting uses simple Markdown; underline uses <u> tags. Server retrieval and household display remain pending the read API.', style: TextStyle(color: Colors.white54, fontSize: 13)),
    ],
  );
}

/// Continues a list only for a single Enter keystroke, preserving paste and IME input.
class ContinuePlanList extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!oldValue.selection.isValid || !oldValue.selection.isCollapsed ||
        !newValue.selection.isCollapsed || !newValue.composing.isCollapsed) return newValue;
    final cursor = oldValue.selection.extentOffset;
    if (newValue.text != oldValue.text.replaceRange(cursor, cursor, '\n') ||
        newValue.selection.extentOffset != cursor + 1) return newValue;
    final start = cursor == 0 ? 0 : oldValue.text.lastIndexOf('\n', cursor - 1) + 1;
    final line = oldValue.text.substring(start, cursor);
    final match = RegExp(r'^([ \t]*)(?:(\d+)\. |(-) )(.*)$').firstMatch(line);
    if (match == null) return newValue;
    if (match.group(4)!.trim().isEmpty) {
      final text = newValue.text.replaceRange(start, cursor + 1, '\n');
      return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: start + 1));
    }
    final number = match.group(2) == null ? null : int.tryParse(match.group(2)!);
    if (match.group(2) != null && number == null) return newValue;
    final prefix = '${match.group(1)}${number == null ? '- ' : '${number + 1}. '}';
    final text = newValue.text.replaceRange(cursor + 1, cursor + 1, prefix);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor + 1 + prefix.length));
  }
}
