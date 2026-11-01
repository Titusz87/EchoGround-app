import 'package:flutter/material.dart';

import '../services/community_directory_service.dart';
import '../services/database_helper.dart';
import '../services/planning_service.dart';

class _DirectoryCache implements CommunityDirectoryStore {
  static const key = 'echoground.community-directory.v1';
  @override
  Future<String?> read() => DatabaseHelper.instance.getConfig(key);
  @override
  Future<void> write(String value) =>
      DatabaseHelper.instance.saveConfig(key, value);
}

/// Shared by both setup forms. Manually entered names never alter the directory
/// or register/join a backend community, and selection never grants access.
class CommunityDropdown extends StatefulWidget {
  const CommunityDropdown({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.required = true,
  });
  final String label, initialValue;
  final ValueChanged<String> onChanged;
  final bool required;
  @override
  State<CommunityDropdown> createState() => _CommunityDropdownState();
}

class _CommunityDropdownState extends State<CommunityDropdown> {
  late final service = CommunityDirectoryService(_DirectoryCache());
  late final manual = TextEditingController(text: widget.initialValue);
  late String? selected = widget.initialValue.isEmpty
      ? null
      : 'name:${widget.initialValue}';
  CommunityDirectorySnapshot? snapshot;
  bool loading = true, refreshing = false;
  int revision = 0;
  String query = '';
  String? notice;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final saved = PlanningService.previewMode
          ? const CommunityDirectorySnapshot(
              names: ['Example community', 'Example valley'],
              savedAt: '',
            )
          : await service.load();
      if (mounted) setState(() => snapshot = saved);
    } catch (_) {
      if (mounted)
        setState(
          () => notice = 'The saved list could not be read. Enter a name manually or refresh while connected.',
        );
    } finally {
      if (mounted)
        setState(() {
          loading = false;
          revision++;
        });
    }
  }

  Future<void> refresh() async {
    if (refreshing || PlanningService.previewMode) return;
    setState(() {
      refreshing = true;
      notice = null;
    });
    try {
      final updated = await service.refresh();
      if (mounted)
        setState(() {
          snapshot = updated;
          revision++;
          notice = 'Community list updated and saved for offline use.';
        });
    } catch (_) {
      if (mounted)
        setState(
          () => notice = 'Could not update the list. The device may be offline or the server unavailable. The last saved list has been kept.',
        );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = [...?snapshot?.names];
    final retained = selected != null && selected!.startsWith('name:')
        ? selected!.substring(5)
        : null;
    if (retained != null && !names.contains(retained))
      names.insert(0, retained);
    final matches = names
        .where(
          (name) => name.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    final visible = matches.take(200).toList();
    if (retained != null && !visible.contains(retained))
      visible.insert(0, retained);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading || refreshing) const LinearProgressIndicator(),
        TextField(
          enabled: !loading && !refreshing,
          decoration: const InputDecoration(
            labelText: 'Search communities',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() {
            query = value;
            revision++;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('$revision:$selected'),
          isExpanded: true,
          initialValue: selected,
          decoration: InputDecoration(labelText: widget.label),
          items: [
            for (final name in visible)
              DropdownMenuItem(
                value: 'name:$name',
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem(
              value: 'manual',
              child: Text('Not listed — enter manually'),
            ),
          ],
          onChanged: loading || refreshing
              ? null
              : (value) {
                  setState(() => selected = value);
                  widget.onChanged(
                    value == 'manual'
                        ? manual.text.trim()
                        : value?.substring(5) ?? '',
                  );
                },
          validator: (v) => widget.required && v == null
              ? 'Choose a community or enter it manually.'
              : null,
        ),
        if (matches.length > 200)
          Text(
            '${matches.length} matches. Showing the first 200; search to narrow the list.',
          ),
        if (selected == 'manual') ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: manual,
            enabled: !refreshing,
            decoration: const InputDecoration(
              labelText: 'Community name used locally',
            ),
            onChanged: (v) => widget.onChanged(v.trim()),
            validator: (v) => widget.required && (v ?? '').trim().isEmpty
                ? 'Enter a community name.'
                : null,
          ),
        ],
        const SizedBox(height: 8),
        if (PlanningService.previewMode)
          const Text(
            'Fictional community list for design preview. Online refresh is available in the normal app.',
          )
        else
          Text(
            snapshot == null
                ? 'No offline directory saved yet. Enter a name manually or refresh while online.'
                : '${snapshot!.names.length} registered communities · Saved on this device: ${snapshot!.savedAt}',
          ),
        if (retained != null &&
            snapshot != null &&
            !snapshot!.names.contains(retained))
          const Text(
            'Your existing plan selection is retained even though it is not in the latest directory.',
          ),
        if (notice != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(notice!)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: loading || refreshing || PlanningService.previewMode
                ? null
                : refresh,
            icon: const Icon(Icons.sync),
            label: Text(
              refreshing ? 'Updating list…' : 'Refresh list (internet needed)',
            ),
          ),
        ),
        const Text(
          'Selecting a name does not join a community or grant access to household information.',
        ),
      ],
    );
  }
}
