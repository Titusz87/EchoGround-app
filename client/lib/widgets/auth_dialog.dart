import 'dart:convert';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/session_store.dart';

/// Shows the login / sign-up dialog for either a household or a community leader.
/// [onAuthSuccess] is called after a successful login or registration.
void showLoginDialog(
  BuildContext context, {
  required bool isLeader,
  required VoidCallback onAuthSuccess,
}) {
  // Form field controllers
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final communityController = TextEditingController();
  final countController = TextEditingController();

  // Dialog state (kept here because the dialog is built with StatefulBuilder)
  bool isSubmitting = false;
  String signInStage = 'Please wait…';
  bool isLogin = true; // true = login mode, false = sign-up mode
  String? errorMessage;
  String? selectedCommunity; // Currently chosen dropdown option

  /// Fetches the list of community names from the backend environment.
  Future<List<String>> fetchCommunityNames() async {
    try {
      const String backendUrl = String.fromEnvironment(
        'BACKEND_URL',
        defaultValue: 'http://127.0.0.1:8000',
      );
      final url = Uri.parse('$backendUrl/household/get-community-names');

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        dynamic raw = decoded;
        if (decoded is Map) {
          raw =
              decoded['communities'] ??
              decoded['community_names'] ??
              decoded['names'] ??
              decoded['data'] ??
              decoded.values.firstWhere((v) => v is List, orElse: () => []);
        }

        if (raw is List) {
          return raw
              .map((item) {
                if (item is Map) {
                  return (item['community_name'] ?? item['name'] ?? '')
                      .toString()
                      .trim();
                }
                return item.toString().trim();
              })
              .where((name) => name.isNotEmpty)
              .toList();
        }
        print('Unexpected community response shape: ${response.body}');
      } else {
        print('Community names request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to pull live communities network array: $e');
    }
    return []; // Graceful fallback
  }

  // Created once so the list isn't re-fetched on every rebuild
  final Future<List<String>> communitiesFuture = fetchCommunityNames();

  showDialog(
    context: context,
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.4),
    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: const Color(0xFF14171A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isLogin ? 'Login' : 'Sign Up'} as ${isLeader ? 'Leader' : 'Household'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 82, 82, 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.redAccent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Input Forms Configuration Layout View Shell
                      if (!isLogin) ...[
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: isLeader ? 'First Name' : 'Last Name',
                            labelStyle: const TextStyle(color: Colors.white60),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
<<<<<<< HEAD
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(color: Colors.white60),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

=======

                      TextField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(color: Colors.white60),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

>>>>>>> origin/main
                      if (!isLogin) ...[
                        if (!isLeader) ...[
                          TextField(
                            controller: countController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Household Members Count',
                              labelStyle: TextStyle(color: Colors.white60),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          FutureBuilder<List<String>>(
                            future: communitiesFuture,
                            builder: (context, snapshot) {
                              final List<String> communities =
                                  snapshot.data ?? [];

                              return DropdownButtonFormField<String>(
                                initialValue:
                                    communities.contains(selectedCommunity)
                                    ? selectedCommunity
                                    : null,
                                dropdownColor: const Color(0xFF14171A),
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Select Community',
                                  labelStyle: TextStyle(color: Colors.white60),
                                  border: OutlineInputBorder(),
                                ),
                                hint: Text(
                                  snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Loading community names...'
                                      : 'Choose a community',
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 14,
                                  ),
                                ),
                                items: communities.map((String name) {
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(name),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    selectedCommunity = newValue;
                                    communityController.text = newValue ?? '';
                                  });
                                },
                              );
                            },
                          ),
                        ] else ...[
                          TextField(
                            controller: communityController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Create New Community Name',
                              labelStyle: TextStyle(color: Colors.white60),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.white60),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4DB6AC),
                            foregroundColor: const Color(0xFF14171A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isSubmitting ? null : () async {
                            setState(() { isSubmitting = true; signInStage = isLogin ? 'Signing in…' : 'Checking device…'; });
                            try {
                            setState(() => errorMessage = null);
<<<<<<< HEAD
                            int? parsedId;
                            if (isLogin) {
                              if (phoneController.text.trim().isEmpty) {
                                setState(() => errorMessage = 'Enter the phone number used when you created this account.');
                                return;
                              }
                            } else {
                              parsedId = await AuthService.ensureBackendPersonId(context);
                              if (!context.mounted) return;
                              if (parsedId == null) {
                                setState(() => errorMessage = AuthService.lastError ?? 'Device registration is not ready. Check permission prompts and retry.');
                                return;
                              }
=======
                            final String cleanPassword = passwordController.text
                                .trim();
                            final String cleanCommunity = communityController
                                .text
                                .trim();
                            final String cleanPhone = phoneController.text
                                .trim();
                            final String cleanSecondaryName = nameController
                                .text
                                .trim();
                            final int? parsedId =
                                await AuthService.ensureBackendPersonId(
                                  context,
                                );
                            if (parsedId == null) {
                              setState(
                                () => errorMessage = 'Could not resolve device connectivity. Please try again.',
                              );
                              return;
>>>>>>> origin/main
                            }
                            if (cleanPassword.isEmpty) {
                              setState(
                                () => errorMessage =
                                    'Password field cannot be empty.',
                              );
                              return;
                            }
                            setState(() => signInStage = isLogin ? 'Signing in…' : 'Creating account…');
                            bool success = false;
                            if (isLogin) {
                              success = await AuthService.login(
<<<<<<< HEAD
                                phone: phoneController.text.trim(),
                                password: passwordController.text.trim(),
=======
                                id: parsedId,
                                password: cleanPassword,
>>>>>>> origin/main
                                isLeader: isLeader,
                              );
                              if (success && isLeader) {
                                // 🎯 FIXED RECOVERY HANDSHAKE:
                                // Read the matching mapped name bound specifically to this Person ID inside your local key store!
                                final String savedMappingKey =
                                    'meta_community_mapping_${parsedId}';
                                final String recoveredDbName =
                                    await DatabaseHelper.instance.getConfig(
                                      savedMappingKey,
                                    ) ??
                                    '';
                                if (recoveredDbName.trim().isNotEmpty) {
                                  await DatabaseHelper.instance.saveConfig(
                                    'auth_community_name',
                                    recoveredDbName.trim(),
                                  );
                                  await DatabaseHelper.instance.saveConfig(
                                    'community_name',
                                    recoveredDbName.trim(),
                                  );
                                  print(
                                    "🎯 IDENTITIES RECOVERY SUCCESS: Restored Postgres target name from local mapping cache: $recoveredDbName",
                                  );
                                } else if (cleanCommunity.isNotEmpty) {
                                  await DatabaseHelper.instance.saveConfig(
                                    'auth_community_name',
                                    cleanCommunity,
                                  );
                                  await DatabaseHelper.instance.saveConfig(
                                    'community_name',
                                    cleanCommunity,
                                  );
                                }
                              }
                            } else {
                              if (cleanCommunity.isEmpty) {
                                setState(() {
                                  errorMessage = isLeader
                                      ? 'Please specify a name for your new community.'
                                      : 'Please select a valid community from the dropdown list.';
                                });
                                return;
                              }
                              success = await AuthService.register(
<<<<<<< HEAD
                                id: parsedId!,
                                password: passwordController.text.trim(),
                                phone: phoneController.text.trim(),
                                secondaryName: nameController.text.trim(),
                                communityName: communityController.text.trim(),
=======
                                id: parsedId,
                                password: cleanPassword,
                                phone: cleanPhone,
                                secondaryName: cleanSecondaryName,
                                communityName: cleanCommunity,
>>>>>>> origin/main
                                count:
                                    int.tryParse(countController.text.trim()) ??
                                    1,
                                isLeader: isLeader,
                              );
                              if (success) {
                                final String stylizedCommName = cleanCommunity
                                    .replaceAll('\r', '')
                                    .replaceAll('\n', '')
                                    .trim();
                                final String savedMappingKey =
                                    'meta_community_mapping_${parsedId}';
                                // 🎯 LOCK IN PERSISTENCE: Maps this custom hardware token ID directly to the registered group value
                                await DatabaseHelper.instance.saveConfig(
                                  'auth_leader_id',
                                  parsedId.toString(),
                                );
                                await DatabaseHelper.instance.saveConfig(
                                  'auth_community_name',
                                  stylizedCommName,
                                );
                                await DatabaseHelper.instance.saveConfig(
                                  'community_name',
                                  stylizedCommName,
                                );
                                await DatabaseHelper.instance.saveConfig(
                                  savedMappingKey,
                                  stylizedCommName,
                                );
                                print(
                                  "🎯 REGISTRATION LINK SEED: Established local identity map for token: $savedMappingKey -> $stylizedCommName",
                                );
                              }
                            }
                            if (!context.mounted) return;
                            if (success) {
<<<<<<< HEAD
                              // Login has already saved the ID returned by the backend.
                              if (!isLogin && parsedId != null) {
                                await SessionStore.activate(id: parsedId, isLeader: isLeader);
                              }
                              DatabaseHelper.instance.syncNotifier.value++;
                              if (!context.mounted) return;
=======
                              DatabaseHelper.instance.syncNotifier.value++;
>>>>>>> origin/main
                              Navigator.of(context).pop();
                              onAuthSuccess();
                            } else {
                              setState(
                                () => errorMessage =
                                    AuthService.lastError ?? 'Sign-in or account creation was rejected. Check your details and the backend response status.',
                              );
                            }
                            } on TimeoutException {
                              if (context.mounted) setState(() => errorMessage = AuthService.lastError ?? 'A sign-in operation timed out. Retry and check the device setup stage in the client console.');
                            } catch (_) {
                              if (context.mounted) setState(() => errorMessage = 'Could not finish sign-in. Check your connection and try again.');
                            } finally {
                              if (context.mounted) setState(() => isSubmitting = false);
                            }
                          },
                          child: Text(
                            isSubmitting ? signInStage : isLogin ? 'Login' : 'Register Now',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: isSubmitting ? null : () {
                          setState(() {
                            isLogin = !isLogin;
                            errorMessage = null;
                          });
                        },
                        child: Text(
                          isLogin
                              ? "Don't have an account? Sign Up"
                              : "Already have an account? Login",
                          style: const TextStyle(color: Color(0xFF4DB6AC)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
