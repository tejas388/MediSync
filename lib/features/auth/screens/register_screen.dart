// lib/features/auth/screens/register_screen.dart
// MediSync - Registration screen (caregiver-only — no role selector)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/extensions/extensions.dart';
import '../../dashboard/screens/caregiver_dashboard_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure    = true;
  bool _submitting = false;

  // All new registrations are caregivers — no patient role in the app
  static const String _role = 'caregiver';

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().registerWithEmail(
        name: _nameCtrl.text, email: _emailCtrl.text,
        password: _passCtrl.text, role: _role,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CaregiverDashboardScreen()),
          (r) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // ── Logo ────────────────────────────────────────────────────
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.medication_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  ShaderMask(
                    shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                    child: const Text('MediSync', style: TextStyle(fontFamily: 'Inter',
                        fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 40),

                Text('Create account 🚀',
                  style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Join MediSync to manage your patients',
                  style: context.textTheme.bodyMedium),
                const SizedBox(height: 8),

                // ── Caregiver Badge ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_services_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Registering as Caregiver',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                            fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Name ─────────────────────────────────────────────────────
                TextFormField(
                  controller: _nameCtrl, textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name', hintText: 'John Doe',
                      prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: Validators.name,
                ),
                const SizedBox(height: 14),

                // ── Email ─────────────────────────────────────────────────────
                TextFormField(
                  controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),

                // ── Password ──────────────────────────────────────────────────
                TextFormField(
                  controller: _passCtrl, obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password', hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),

                // ── Confirm Password ──────────────────────────────────────────
                TextFormField(
                  controller: _confirmCtrl, obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  decoration: const InputDecoration(labelText: 'Confirm Password', hintText: '••••••••',
                      prefixIcon: Icon(Icons.lock_outline_rounded)),
                  validator: (v) => Validators.confirmPassword(v, _passCtrl.text),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _register,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Already have an account? ', style: context.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('Sign In'),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
