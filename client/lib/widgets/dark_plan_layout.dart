import 'package:flutter/material.dart';

class PlanSection {
  final String title;
  final String description;
  final IconData icon;
  final Widget? content;
  const PlanSection(this.title, this.description, this.icon, {this.content});
}

/// Presentation only: no account, storage or backend changes.
class DarkPlanLayout extends StatelessWidget {
  final List<PlanSection> sections;
  final int? selectedIndex;
  final ValueChanged<int?> onSelected;
  final Widget incidents;
  final Widget? header;

  const DarkPlanLayout({
    super.key,
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
    required this.incidents,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header!,
              const SizedBox(height: 16),
            ],
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C292B),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < sections.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Semantics(
                                selected: selectedIndex == i,
                                child: IconButton(
                                  tooltip: sections[i].title,
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    maximumSize: const Size(56, 56),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: selectedIndex == i
                                        ? scheme.onSecondaryContainer
                                        : scheme.onSurfaceVariant,
                                    backgroundColor: selectedIndex == i
                                        ? scheme.secondaryContainer
                                        : Colors.transparent,
                                  ),
                                  onPressed: () => onSelected(selectedIndex == i ? null : i),
                                  icon: Icon(sections[i].icon, size: 22),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF14171A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: selectedIndex == null
                            ? incidents
                            : _section(context, sections[selectedIndex!]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, PlanSection section) => section.content ?? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(section.icon, color: const Color(0xFF4DB6AC), size: 28),
        const SizedBox(height: 12),
        Text(section.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Chip(label: Text('Coming soon')),
        const SizedBox(height: 12),
        Text(section.description, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        const Text('Planned for a future release. This feature is not enabled yet.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 20),
        TextButton.icon(onPressed: () => onSelected(null), icon: const Icon(Icons.arrow_back), label: const Text('Back to incidents')),
      ],
  );
}
