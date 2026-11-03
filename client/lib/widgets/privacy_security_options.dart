import 'package:flutter/material.dart';

/// Presentation-only controls. Never changes account consent or backend data.
class PrivacySecurityOptions extends StatefulWidget {
  const PrivacySecurityOptions({super.key});
  @override
  State<PrivacySecurityOptions> createState() => _PrivacySecurityOptionsState();
}

class _PrivacySecurityOptionsState extends State<PrivacySecurityOptions> {
  bool readiness = false;
  bool names = false;
  bool notices = false;

  Widget option(String title, String description, bool value, ValueChanged<bool> change) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6),
      Text(description),
      Row(children: [
        Expanded(child: Text(value ? 'Opted in' : 'Opted out')),
        Semantics(label: title, child: Switch(value: value, onChanged: change)),
      ]),
      const Divider(),
    ]),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.privacy_tip_outlined, color: Color(0xFF4DB6AC), size: 28),
      const SizedBox(height: 12),
      Text('Privacy & security', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const Text('Design preview only. These choices are not saved or applied to your account. They reset when you leave this panel.'),
      const SizedBox(height: 20),
      option('Share household readiness', 'Allow your linked community leader to see whether your household plan is complete or incomplete.', readiness, (v) => setState(() => readiness = v)),
      option('Share resident names', 'Allow your linked community leader to see household member names for the future incident roll call. This is separate from readiness sharing.', names, (v) => setState(() => names = v)),
      option('Community notifications', 'Receive notifications about posts from your linked community noticeboard. This preference is separate from official emergency warnings.', notices, (v) => setState(() => notices = v)),
      const Text('Planned privacy protections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      const Text('Private checklist answers, phone numbers and precise locations are excluded from these sharing choices. Community access and withdrawal of consent must be enforced by the backend before release.'),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        icon: const Icon(Icons.lock_outline),
        label: const Text('Opt out of all'),
        onPressed: () => setState(() { readiness = false; names = false; notices = false; }),
      ),
    ],
  );
}
