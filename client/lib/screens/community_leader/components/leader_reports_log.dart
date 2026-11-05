import 'package:flutter/material.dart';

/// Reports Feed Card allowing Leaders to inspect or toggle validation statuses.
class LeaderReportsLog extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final Function(int, bool?) onStatusChanged;

  const LeaderReportsLog({
    super.key,
    required this.reports,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Color(0xFF4DB6AC),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'REPORTS LOG',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length,
            separatorBuilder: (context, idx) =>
                const Divider(color: Colors.white10, height: 20),
            itemBuilder: (context, idx) {
              final report = reports[idx];
              return Row(
                children: [
                  _buildStatusIcon(report['status']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['type'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reported by: ${report['sender_name']}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF24292E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => _showReviewModal(context, report, idx),
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

  Widget _buildStatusIcon(bool? status) {
    if (status == true)
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color.fromRGBO(77, 182, 172, 0.15),
        child: Icon(Icons.check_rounded, size: 14, color: Color(0xFF4DB6AC)),
      );
    if (status == false)
      return const CircleAvatar(
        radius: 12,
        backgroundColor: Color.fromRGBO(239, 83, 80, 0.15),
        child: Icon(
          Icons.question_mark_rounded,
          size: 14,
          color: Colors.redAccent,
        ),
      );
    return const CircleAvatar(
      radius: 12,
      backgroundColor: Colors.white10,
      child: Icon(
        Icons.horizontal_rule_rounded,
        size: 12,
        color: Colors.white30,
      ),
    );
  }

  void _showReviewModal(
    BuildContext context,
    Map<String, dynamic> report,
    int index,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14171A),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF4DB6AC)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Report: ${report['type']}',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(color: Colors.white10),
              _buildRow('Reported By', report['sender_name']),
              _buildRow('Contact Phone', report['phone']),
              _buildRow('Incident Type', report['type']),
              _buildRow('Location', report['location']),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  report['description'],
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Invalidate'),
                onPressed: () {
                  onStatusChanged(index, false);
                  Navigator.pop(context);
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DB6AC),
                  foregroundColor: const Color(0xFF14171A),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Validate Report'),
                onPressed: () {
                  onStatusChanged(index, true);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
