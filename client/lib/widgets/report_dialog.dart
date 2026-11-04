import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/database_helper.dart';

/// Triggers the 3-Step Interactive Multi-Page Emergency Report Handshake Modal
void showReportDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevents accidental closing during input
    builder: (context) => const ReportDialog(),
  );
}

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  // Text Editing Input Field Controllers
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  int _currentPage = 0;
  bool _isSending = false;

  @override
  void dispose() {
    _pageController.dispose();
    _typeController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Sends the finalized emergency report straight to Evan's database path
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      // 1. Fetch backend base configurations and active profile context references
      final String backendUrl =
          await DatabaseHelper.instance.getConfig('BACKEND_URL') ??
          'http://127.0.0.1:8000';
      final String? personId = await DatabaseHelper.instance.getConfig(
        'backend_person_id',
      );

      // Fallback default to match swagger model index requirements
      final int parsedId = int.tryParse(personId ?? '') ?? 0;

      final url = Uri.parse('$backendUrl/household/emergency-report');

      // 2. Dispatch structured payload according to Swagger JSON schema
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': parsedId,
          'title': _typeController.text.trim(),
          'location': _locationController.text.trim(),
          'description': _descriptionController.text.trim(),
        }),
      );

      print(
        'Emergency Report Dispatch Status: ${response.statusCode} | Body: ${response.body}',
      );

      if (mounted) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Emergency report transmitted successfully to dispatch.',
              ),
              backgroundColor: Colors.teal,
            ),
          );
          Navigator.of(context).pop(); // Close modal on success
        } else {
          _showErrorSnackBar(
            'Server rejected report. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      print('Emergency report pipeline crash: $e');
      _showErrorSnackBar('Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showErrorSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      // Validate the active field before moving on
      if (_currentPage == 0 && _typeController.text.trim().isEmpty) return;
      if (_currentPage == 1 && _locationController.text.trim().isEmpty) return;

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF14171A), // Matte dark theme
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        height: 340,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // PAGE SLIDER
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    // PAGE 1: CATEGORY
                    _buildPageWrapper(
                      question:
                          'What kind of emergency do you want to report for?',
                      example: '(e.g., Bushfire, Flood, Medical Trauma, Power Outage)',
                      inputField: TextFormField(
                        controller: _typeController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter emergency type...',
                          hintStyle: TextStyle(color: Colors.white30),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal),
                          ),
                        ),
                      ),
                    ),

                    // PAGE 2: LOCATION
                    _buildPageWrapper(
                      question:
                          'What location do you want to make the report for?',
                      example: '(Provide street name, landmark, or region accuracy properties)',
                      inputField: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Enter incident address location...',
                                hintStyle: TextStyle(color: Colors.white30),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.teal),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Inactive map button
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white24,
                              backgroundColor: Colors.white10,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('Map'),
                            onPressed: null, // Disabled for now
                          ),
                        ],
                      ),
                    ),

                    // PAGE 3: DESCRIPTION
                    _buildPageWrapper(
                      question:
                          'Tell me briefly what is happening at the scene...',
                      example: '(Include casualties count or active environment risk parameters)',
                      inputField: TextFormField(
                        controller: _descriptionController,
                        autofocus: true,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText:
                              'Enter brief scene description details here...',
                          hintStyle: TextStyle(color: Colors.white30),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.teal),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ACTION BUTTON ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel / Back
                  if (_currentPage == 0)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    )
                  else
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),

                  // Progress dots
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.teal
                              : Colors.white12,
                        ),
                      ),
                    ),
                  ),

                  // Next / Send
                  if (_currentPage < 2)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      onPressed: _nextPage,
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSending ? null : _submitReport,
                      child: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send Report',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageWrapper({
    required String question,
    required String example,
    required Widget inputField,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          example,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white38,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 24),
        inputField,
      ],
    );
  }
}
