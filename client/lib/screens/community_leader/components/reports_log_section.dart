import 'package:flutter/material.dart';

import '../../../../widgets/incident_tile.dart';

class ReportsLogSection extends StatelessWidget {
  final List<Map<String, dynamic>> reports;

  //  Explicit parameter to communicate click events back to the parent dashboard controller
  final Function(String reportId, String notice) onValidateReport;

  const ReportsLogSection({
    super.key,
    required this.reports,
    required this.onValidateReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2225),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFF4DB6AC),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'REPORTS LOG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No active community reports logged in your sector.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white10, height: 16),
              itemBuilder: (context, index) {
                final report = reports[index];

                // Wrap your standard tile with a clean row layout containing the validation execution button module
                return Row(
                  children: [
                    Expanded(child: IncidentTile(incident: report)),
                    const SizedBox(width: 12),

                    // 🎯 THE VALIDATION TRIGGER BUTTON
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14171A),
                        foregroundColor: const Color(0xFF4DB6AC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () =>
                          _showValidationConfirmationDialog(context, report),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// INTERACTIVE OVERLAY MODAL: Opens a confirmation sheet allowing the leader to type a broadcast notice comment
  void _showValidationConfirmationDialog(
    BuildContext context,
    Map<String, dynamic> report,
  ) {
    final textController = TextEditingController(
      text: 'Verified by sector community leader.',
    );
    final String reportId = report['id']?.toString() ?? '';
    final String eventTitle =
        report['event_type']?.toString().toUpperCase() ?? 'INCIDENT';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2225),
        title: Text(
          'VALIDATE $eventTitle',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report['description'] ??
                  'Review this citizen-submitted logging alert parameter.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Broadcast Notice Notice Comment',
                labelStyle: TextStyle(color: Colors.white60),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4DB6AC),
            ),
            onPressed: () {
              Navigator.pop(context);
              // HANDSHAKE DISPATCH: Sends your payload straight to the parent dashboard class function!
              onValidateReport(reportId, textController.text);
            },
            child: const Text(
              'Confirm Validation',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
