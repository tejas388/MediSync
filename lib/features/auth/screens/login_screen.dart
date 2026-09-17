// lib/features/auth/screens/login_screen.dart
// MediSync - Login screen (caregiver-only: email + Google + biometric)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/extensions/extensions.dart';
import '../../dashboard/screens/caregiver_dashboard_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _submitting = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().signInWithEmail(
        email: _emailCtrl.text, password: _passCtrl.text,
      );
      if (mounted) await _navigate();
    } on AuthException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  Future<void> _googleLogin() async {
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().signInWithGoogle();
      if (mounted) await _navigate();
    } on AuthException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  Future<void> _biometricLogin() async {
    final ok = await BiometricService.instance.authenticate(
      localizedReason: 'Authenticate to sign in to MediSync',
    );
    if (!ok || !mounted) return;
    await _navigate();
  }

  Future<void> _navigate() async {
    // Wait until profile is fully loaded
    final auth = context.read<AuthProvider>();
    while (auth.isLoadingProfile) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    if (!mounted) return;
    // All users go to Caregiver Dashboard
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CaregiverDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // ── Logo ─────────────────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.medication_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                      child: const Text('MediSync',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 24,
                            fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),

                  const SizedBox(height: 40),
                  Text('Welcome back 👋',
                    style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Sign in to manage your patients',
                    style: context.textTheme.bodyMedium),
                  const SizedBox(height: 36),

                  // ── Email ─────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email', hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),

                  // ── Password ──────────────────────────────────────────────
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
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

                  // ── Forgot Password ───────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Sign In Button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _login,
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Divider ───────────────────────────────────────────────
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: context.textTheme.bodySmall)),
                    const Expanded(child: Divider()),
                  ]),

                  const SizedBox(height: 16),

                  // ── Google Sign In ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _googleLogin,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                      label: const Text('Continue with Google'),
                    ),
                  ),

                  // ── Biometric ─────────────────────────────────────────────
                  if (auth.isBiometricEnabled) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _biometricLogin,
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: const Text('Sign in with Biometrics'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Register Link ──────────────────────────────────────────
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Don't have an account? ", style: context.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Sign Up'),
                    ),
                  ]),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
