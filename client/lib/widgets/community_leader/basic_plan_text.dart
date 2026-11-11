import 'package:flutter/material.dart';

/// Small, text-only Markdown subset. Never evaluates HTML, links or images.
class BasicPlanText extends StatelessWidget {
  final String text;
  const BasicPlanText({super.key, required this.text});

  static List<InlineSpan> inline(String value) {
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|<u>(.+?)</u>');
    final spans = <InlineSpan>[];
    var end = 0;
    for (final match in pattern.allMatches(value)) {
      if (match.start > end) spans.add(TextSpan(text: value.substring(end, match.start)));
      spans.add(TextSpan(
        text: match.group(1) ?? match.group(2) ?? match.group(3),
        style: TextStyle(
          fontWeight: match.group(1) != null ? FontWeight.bold : null,
          fontStyle: match.group(2) != null ? FontStyle.italic : null,
          decoration: match.group(3) != null ? TextDecoration.underline : null,
        ),
      ));
      end = match.end;
    }
    if (end < value.length) spans.add(TextSpan(text: value.substring(end)));
    return spans;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: text.split('\n').map((line) {
      if (line.trim().isEmpty) return const SizedBox(height: 12);
      final heading = RegExp(r'^(#{1,3}) (.*)$').firstMatch(line);
      if (heading != null) {
        final size = {1: 28.0, 2: 24.0, 3: 20.0}[heading.group(1)!.length]!;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: SelectableText.rich(TextSpan(children: inline(heading.group(2)!)), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: size, fontWeight: FontWeight.bold, height: 1.4)));
      }
      final list = RegExp(r'^\s*(- |\d+\. )(.*)$').firstMatch(line);
      final spans = inline(list?.group(2) ?? line);
      final content = SelectableText.rich(TextSpan(children: spans), style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5));
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: list == null ? content : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 36, child: Text(list!.group(1)!.trim() == '-' ? '•' : list.group(1)!.trim(), style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5))),
            Expanded(child: content),
          ],
        ),
      );
    }).toList(),
  );
}
