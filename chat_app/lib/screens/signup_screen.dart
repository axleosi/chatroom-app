import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String errorMessage = '';

  Future<void> handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    final url = Uri.parse('http://192.168.8.111:5000/api/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': usernameController.text,
          'email': emailController.text,
          'password': passwordController.text,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', data['token']);
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/chat');
        }
      } else {
        setState(() => errorMessage = data['message'] ?? 'Signup failed');
      }
    } catch (e) {
      setState(() => errorMessage = 'An error occurred');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text('Sign Up', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Username', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: usernameController,
                              decoration: _inputDecoration('Type your username'),
                              validator: (val) => val == null || val.length < 2 ? 'Min 2 characters' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Email', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: emailController,
                              decoration: _inputDecoration('you@example.com'),
                              validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Password', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: passwordController,
                              obscureText: !showPassword,
                              decoration: _inputDecoration('••••••••').copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => showPassword = !showPassword),
                                ),
                              ),
                              validator: (val) => val != null && val.length < 6 ? 'Min 6 characters' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Confirm Password', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: confirmPasswordController,
                              obscureText: !showConfirmPassword,
                              decoration: _inputDecoration('••••••••').copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                                ),
                              ),
                              validator: (val) => val != passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isLoading ? null : handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Sign Up', style: TextStyle(color: Colors.white)),
                  ),

                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14)),
                    ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text(
                      'Already have an account? Login here',
                      style: TextStyle(color: Colors.purple, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
