import 'package:flutter/material.dart';

import '../models/preparedness_plan.dart';
import 'community_dropdown.dart';
import '../services/planning_service.dart';

const planningSafetyNote =
    'Prepare before an emergency, only when it is safe. A completed checklist does not mean a building is safe to occupy or permission to stay. Follow official warnings and evacuation instructions; do not delay leaving to finish tasks.';

class PlanningShell extends StatelessWidget {
  const PlanningShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8E321F),
      brightness: Brightness.light,
      primary: const Color(0xFF8E321F),
      surface: const Color(0xFFFFFDF8),
    );
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF7F4ED),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.all(14),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE6DFD3)),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Column(
          children: [
            if (PlanningService.previewMode)
              const ColoredBox(
                color: Color(0xFFFFE3AA),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'DESIGN PREVIEW • Fictional data only • No login or backend connection. Reload resets changes.',
                  ),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanningPanel extends StatelessWidget {
  const PlanningPanel(this.title, this.children, {super.key});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class PlanningProgress extends StatelessWidget {
  const PlanningProgress(this.progress, {super.key});
  final ChecklistProgress progress;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${progress.percent}% complete',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        value: progress.fraction,
        minHeight: 10,
        semanticsLabel: 'Checklist progress',
        semanticsValue: '${progress.percent} percent',
      ),
      const SizedBox(height: 10),
      Text(
        '${progress.done} of ${progress.total} applicable checks complete · ${progress.help} need help',
      ),
      if (progress.excluded > 0)
        Text(
          '${progress.excluded} not applicable (excluded from the percentage)',
        ),
      if (progress.total == 0)
        const Text(
          'No applicable checks recorded. This is not a completed plan.',
        ),
    ],
  );
}

class PlanningField {
  const PlanningField(
    this.key,
    this.label, {
    this.value = '',
    this.required = true,
    this.number = false,
    this.phone = false,
    this.communityDirectory = false,
    this.options,
  });
  final String key, label, value;
  final bool required, number, phone, communityDirectory;
  final Map<String, String>? options;
}

Future<Map<String, String>?> openPlanningForm(
  BuildContext context,
  String title,
  List<PlanningField> fields, {
  String? note,
}) => Navigator.push<Map<String, String>>(
  context,
  MaterialPageRoute(builder: (_) => _PlanningForm(title, fields, note)),
);

class _PlanningForm extends StatefulWidget {
  const _PlanningForm(this.title, this.fields, this.note);
  final String title;
  final List<PlanningField> fields;
  final String? note;
  @override
  State<_PlanningForm> createState() => _PlanningFormState();
}

class _PlanningFormState extends State<_PlanningForm> {
  final key = GlobalKey<FormState>();
  late final controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.value),
  };
  late final values = {
    for (final f in widget.fields)
      if (f.options != null)
        f.key: f.options!.containsKey(f.value)
            ? f.value
            : f.options!.keys.first,
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlanningShell(
    title: widget.title,
    child: Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(widget.note!),
            ),
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: f.communityDirectory
                  ? CommunityDropdown(
                      label: f.label,
                      initialValue: f.value,
                      required: f.required,
                      onChanged: (value) => controllers[f.key]!.text = value,
                    )
                  : f.options != null
                  ? DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: values[f.key],
                      decoration: InputDecoration(labelText: f.label),
                      items: [
                        for (final e in f.options!.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => values[f.key] = v!),
                    )
                  : TextFormField(
                      controller: controllers[f.key],
                      keyboardType: f.number
                          ? TextInputType.number
                          : f.phone
                          ? TextInputType.phone
                          : TextInputType.text,
                      decoration: InputDecoration(labelText: f.label),
                      validator: (v) {
                        if (f.required && (v ?? '').trim().isEmpty)
                          return 'Please complete this field.';
                        if (f.number &&
                            (int.tryParse(v ?? '') == null ||
                                int.parse(v!) < 1))
                          return 'Enter a whole number of at least 1.';
                        if (f.phone &&
                            (v ?? '').trim().isNotEmpty &&
                            !RegExp(r'^\+?[0-9\s()\-]{8,22}$')
                                .hasMatch(v!.trim()))
                          return 'Check the phone number.';
                        return null;
                      },
                    ),
            ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate())
                Navigator.pop(context, {
                  for (final f in widget.fields)
                    f.key: f.options != null
                        ? values[f.key]!
                        : controllers[f.key]!.text.trim(),
                });
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
}

class PlanningChecklistPage extends StatefulWidget {
  const PlanningChecklistPage({
    super.key,
    required this.title,
    required this.checks,
    required this.initial,
    required this.onSave,
    required this.property,
  });
  final String title;
  final Map<String, String> checks, initial;
  final Future<void> Function(Map<String, String>) onSave;
  final bool property;
  @override
  State<PlanningChecklistPage> createState() => _ChecklistState();
}

class _ChecklistState extends State<PlanningChecklistPage> {
  late final values = Map<String, String>.from(widget.initial);
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => PlanningShell(
    title: widget.title,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        PlanningPanel('Your progress', [
          PlanningProgress(ChecklistProgress(values, widget.checks.keys)),
          const SizedBox(height: 12),
          const Text('Changes apply when you tap Save checklist.'),
        ]),
        if (widget.property)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(planningSafetyNote),
          ),
        for (final task in widget.checks.entries)
          Card(
            child: ExpansionTile(
              title: Text(task.value),
              subtitle: Text(
                checkOptions[values[task.key] ?? 'todo'] ?? 'Not yet complete',
              ),
              children: [
                for (final option in checkOptions.entries)
                  RadioListTile<String>(
                    title: Text(option.value),
                    value: option.key,
                    groupValue: values[task.key] ?? 'todo',
                    onChanged: busy
                        ? null
                        : (v) => setState(() => values[task.key] = v!),
                  ),
              ],
            ),
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await widget.onSave(values);
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (_) {
                    if (mounted)
                      setState(
                        () => error = 'Checklist could not be saved. Your changes are still shown; try again.',
                      );
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Saving…' : 'Save checklist'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Reference guidance: DFES emergency preparation and VICSES storm preparation. Follow local advice for the actual hazard.',
        ),
        const SelectableText(
          'dfes.wa.gov.au/hazard-information/bushfire/prepare\nses.vic.gov.au/plan-and-stay-safe/emergencies/storm',
        ),
      ],
    ),
  );
}
