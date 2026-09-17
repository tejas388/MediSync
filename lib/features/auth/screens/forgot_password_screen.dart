// lib/features/auth/screens/forgot_password_screen.dart
// MediSync - Forgot password screen

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/extensions.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  bool _sent       = false;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().sendPasswordResetEmail(_emailCtrl.text);
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset Password')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: _sent ? _successView() : _formView(),
    ),
  );

  Widget _formView() => Form(
    key: _formKey,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Forgot your password?', style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text("Enter your email address and we'll send you a reset link.", style: context.textTheme.bodyMedium),
      const SizedBox(height: 32),
      TextFormField(
        controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _send(),
        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
        validator: Validators.email,
      ),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _send,
          child: _submitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send Reset Link'),
        ),
      ),
    ]),
  );

  Widget _successView() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.mark_email_read_outlined, size: 80, color: Color(0xFF4CAF50)),
    const SizedBox(height: 24),
    Text('Email Sent! 📧', style: context.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    Text("We sent a password reset link to ${_emailCtrl.text}. Check your inbox.",
        style: context.textTheme.bodyMedium, textAlign: TextAlign.center),
    const SizedBox(height: 32),
    SizedBox(width: double.infinity,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Back to Login'),
      ),
    ),
  ]);
}
