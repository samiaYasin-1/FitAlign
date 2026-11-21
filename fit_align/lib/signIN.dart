import 'dart:convert';
import 'package:fit_align/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class signin extends StatefulWidget {
  const signin({super.key});

  @override
  State<signin> createState() => _signupState();
}

class _signupState extends State<signin> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool isVisible = true;
  bool _isLoading = false;
  String _errorMessage = "";

  ColorScheme get cs => Theme.of(context).colorScheme;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(value);
  }

  void _setError(String message) => setState(() => _errorMessage = message);

  Future<void> insertData() async {
    _setError("");

    if (email.text.trim().isEmpty) return _setError("Please enter your email address");
    if (!_isValidEmail(email.text.trim())) return _setError("Please enter a valid email address");
    if (password.text.isEmpty) return _setError("Please enter your password");
    if (password.text.length < 6) return _setError("Password must be at least 6 characters");

    setState(() => _isLoading = true);

    try {
      var res = await http.post(
        Uri.parse("https://devtechnical.com/samia/login.php"),
        body: {"email": email.text.trim(), "password": password.text},
      );

      if (res.statusCode != 200) return _setError("Server error, please try again later");

      var result;
      try {
        result = jsonDecode(res.body.trim());
      } catch (e) {
        return _setError("Unexpected server response");
      }

      if (result is Map && result['success'] == 'true') {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => HomeDashboardScreen()));
      } else {
        _setError("Invalid email or password");
      }
    } catch (e) {
      _setError("Network error, please check your connection");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: cs.onSurfaceVariant),
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            prefixIcon: Icon(icon, color: cs.onSurfaceVariant, size: 20),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: border(cs.outlineVariant),
            focusedBorder: border(cs.primary),
          ),
        ),
      ],
    );
  }

  Widget _socialButton(String label, String imageUrl) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              imageUrl,
              height: 22,
              width: 22,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.circle, size: 22, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.primary.withAlpha(90)),
                ),
                child: Icon(Icons.fitness_center_rounded, color: cs.primary, size: 28),
              ),
              const SizedBox(height: 24),
              Text('Welcome back', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 6),
              Text('Sign in to continue your fitness journey', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),
              _inputField(
                label: 'Email',
                controller: email,
                hint: 'Enter your email',
                icon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 18),
              _inputField(
                label: 'Password',
                controller: password,
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: isVisible,
                suffix: IconButton(
                  onPressed: () => setState(() => isVisible = !isVisible),
                  icon: Icon(
                    isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errorMessage, style: TextStyle(color: cs.secondary, fontSize: 13)),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Forgot password?', style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : insertData,
                  child: _isLoading
                      ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: cs.onPrimary, strokeWidth: 2.5))
                      : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Divider(color: cs.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Or continue with', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: cs.outlineVariant)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _socialButton(
                      'Google',
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQaCj3HtO9Xpf30OJhy9ZnOlNrvkvBafTzQpw&s',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _socialButton(
                      'Apple',
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRCvh-j7HsTHJ8ZckknAoiZMx9VcFmsFkv72g&s',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(color: cs.onSurfaceVariant),
                    children: [
                      TextSpan(text: 'Sign Up', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}