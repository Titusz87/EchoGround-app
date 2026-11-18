import 'package:flutter/material.dart';

import '../../../services/database_helper.dart';
import 'leader_theme.dart';

/// Modal dialog allowing Community Leaders to compose and publish an FCM
/// broadcast message, optionally linked to an active incident or report.
class LeaderBroadcastDialog extends StatefulWidget {
  final Future<bool> Function(String messageBody) onSendBroadcast;

  const LeaderBroadcastDialog({super.key, required this.onSendBroadcast});

  @override
  State<LeaderBroadcastDialog> createState() => _LeaderBroadcastDialogState();
}

class _LeaderBroadcastDialogState extends State<LeaderBroadcastDialog> {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<Map<String, String>> _dropdownOptions = [];
  Map<String, String>? _selectedLinkedEntity;
  bool _isLoadingOptions = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadDropdownOptions();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Loads cached incidents and citizen reports to populate optional link targets.
  Future<void> _loadDropdownOptions() async {
    try {
      final allCachedRecords = await DatabaseHelper.instance
          .fetchAllNotifications();
      final List<Map<String, String>> populatedOptions = [];

      for (final item in allCachedRecords) {
        final String currentId = item['id']?.toString() ?? '';
        final String rawType = (item['event_type'] ?? item['type'] ?? '')
            .toString();
        final String rawTitle =
            (item['title'] ?? item['description'] ?? 'Alert').toString();

        if (currentId.startsWith('unknown_incident') ||
            currentId.contains('community_report')) {
          populatedOptions.add({
            'id': currentId,
            'display': 'REPORT - ${rawTitle.toUpperCase()}',
          });
        } else {
          populatedOptions.add({
            'id': currentId,
            'display': 'INCIDENT - ${rawType.toUpperCase()}',
          });
        }
      }

      if (mounted) {
        setState(() {
          _dropdownOptions = populatedOptions;
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load broadcast link options: $e');
      if (mounted) {
        setState(() => _isLoadingOptions = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSending || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSending = true);

    String finalBroadcastMessage = _textController.text.trim();
    if (_selectedLinkedEntity != null) {
      finalBroadcastMessage +=
          '\n\n[Linked Context: ${_selectedLinkedEntity!['display']}]';
    }

    final bool success = await widget.onSendBroadcast(finalBroadcastMessage);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Announcement broadcast sent via FCM successfully.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: LeaderTheme.brandTeal,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to dispatch broadcast. Please retry.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: LeaderTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: LeaderTheme.border),
      ),
      title: const Text(
        'Publish Community Broadcast',
        style: TextStyle(
          color: LeaderTheme.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingOptions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            LeaderTheme.brandTeal,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Loading list options...',
                        style: TextStyle(
                          color: LeaderTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<Map<String, String>>(
                  initialValue: _selectedLinkedEntity,
                  isExpanded: true,
                  dropdownColor: LeaderTheme.surfaceElevated,
                  style: const TextStyle(
                    color: LeaderTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Incident Link (Optional)',
                    labelStyle: TextStyle(color: LeaderTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: LeaderTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: LeaderTheme.brandTeal),
                    ),
                  ),
                  items: _dropdownOptions.map((option) {
                    return DropdownMenuItem<Map<String, String>>(
                      value: option,
                      child: Text(
                        option['display']!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedLinkedEntity = value),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,
                maxLines: 4,
                style: const TextStyle(
                  color: LeaderTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type announcement message...',
                  hintStyle: TextStyle(color: LeaderTheme.textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: LeaderTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: LeaderTheme.brandTeal),
                  ),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Announcement body text details required.'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: LeaderTheme.textMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LeaderTheme.brandTeal,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          onPressed: _isSending ? null : _handleSubmit,
          child: Text(
            _isSending ? 'Sending...' : 'Send Broadcast',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
