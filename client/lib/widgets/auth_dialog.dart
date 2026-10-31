import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';

void showLoginDialog(BuildContext context, {required bool isLeader, required VoidCallback onAuthSuccess}) {
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController(); 
  final communityController = TextEditingController();
  
  bool isLogin = true; 
  String? errorMessage; // Dynamic inline error message state placeholder

  showDialog(
    context: context,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.4), 
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            
            return Dialog(
              backgroundColor: Colors.grey[850], // Darkened background slightly for premium contrast
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    Text(
                      '${isLogin ? 'Login' : 'Sign Up'} as ${isLeader ? 'Leader' : 'Household'}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- DYNAMIC ERROR STATE ALERT PANELS ---
                    if (errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(255, 82, 82, 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // ----------------------------------------

                    if (!isLogin) ...[
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isLeader ? 'First Name' : 'Last Name', 
                          labelStyle: const TextStyle(color: Colors.white60), 
                          border: const OutlineInputBorder()
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number', 
                          labelStyle: TextStyle(color: Colors.white60), 
                          border: OutlineInputBorder()
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isLeader) ...[
                        TextField(
                          controller: communityController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Community Name', 
                            labelStyle: TextStyle(color: Colors.white60), 
                            border: OutlineInputBorder()
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Password', 
                        labelStyle: TextStyle(color: Colors.white60), 
                        border: OutlineInputBorder()
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary, 
                          padding: const EdgeInsets.symmetric(vertical: 14)
                        ),
                        onPressed: () async {
                          // Clear out past warning strings upon every new button invocation click
                          setState(() { errorMessage = null; });

                          final String? savedPersonId = await DatabaseHelper.instance.getConfig('backend_person_id');
                          if (savedPersonId == null) {
                            setState(() {
                              errorMessage = 'Device Registration missing. Please restart app setup.';
                            });
                            return;
                          }

                          final int? parsedId = int.tryParse(savedPersonId);
                          if (parsedId == null) return;

                          if (passwordController.text.trim().isEmpty) {
                            setState(() { errorMessage = 'Password field cannot be empty.'; });
                            return;
                          }

                          bool success = false;
                          if (isLogin) {
                            success = await AuthService.login(
                              id: parsedId, 
                              password: passwordController.text, 
                              isLeader: isLeader
                            );
                            if (!success) {
                              setState(() {
                                errorMessage = 'Incorrect password provided. Please try again.';
                              });
                            }
                          } else {
                            if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                              setState(() { errorMessage = 'All dynamic information fields are required.'; });
                              return;
                            }
                            if (isLeader && communityController.text.trim().isEmpty) {
                              setState(() { errorMessage = 'Community Name is explicitly required.'; });
                              return;
                            }

                            success = await AuthService.register(
                              id: parsedId,
                              password: passwordController.text,
                              phone: phoneController.text,
                              secondaryName: nameController.text,
                              communityName: communityController.text,
                              isLeader: isLeader,
                            );
                            
                            if (success) {
                              setState(() { 
                                isLogin = true; 
                                errorMessage = 'Account created! Please log in now.';
                              }); 
                              return;
                            } else {
                              setState(() {
                                errorMessage = 'Registration failed. The profile configuration may already exist.';
                              });
                            }
                          }

                          if (success && context.mounted) {
                            Navigator.of(context).pop(); 
                            onAuthSuccess(); 
                          }
                        },
                        child: Text(
                          isLogin ? 'Log In' : 'Sign Up', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() { 
                          isLogin = !isLogin; 
                          errorMessage = null; // Clear warnings when flipping panels
                        });
                      },
                      child: Text(
                        isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Login', 
                        style: TextStyle(color: theme.colorScheme.primary)
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
