// lib/features/auth/screens/onboarding_screen.dart
// MediSync - Animated 4-page onboarding (caregiver-focused)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final List<OnboardingPage> _pages = OnboardingPage.all;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── Pages ────────────────────────────────────────────────────────────
        PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => _OnboardPage(page: _pages[i]),
        ),

        // ── Bottom controls ───────────────────────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 48,
          child: Column(children: [
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i
                      ? _pages[_page].color
                      : _pages[_page].color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                // Skip
                if (_page < _pages.length - 1)
                  TextButton(
                    onPressed: _finish,
                    child: Text('Skip',
                        style: TextStyle(fontFamily: 'Inter',
                            color: _pages[_page].color.withOpacity(0.7),
                            fontWeight: FontWeight.w600)),
                  )
                else
                  const SizedBox(width: 64),
                const Spacer(),
                // Next / Get Started
                ElevatedButton(
                  onPressed: () {
                    if (_page < _pages.length - 1) {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    } else {
                      _finish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_page].color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _page == _pages.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(fontFamily: 'Inter',
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _OnboardPage extends StatefulWidget {
  final OnboardingPage page;
  const _OnboardPage({required this.page});
  @override
  State<_OnboardPage> createState() => _OnboardPageState();
}

class _OnboardPageState extends State<_OnboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<Offset>  _slide;
  late Animation<double>  _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final page  = widget.page;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [page.color.withOpacity(0.08), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 160),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [page.color, page.color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(color: page.color.withOpacity(0.35),
                          blurRadius: 32, offset: const Offset(0, 14)),
                    ],
                  ),
                  child: Icon(page.icon, color: Colors.white, size: 70),
                ),
              ),
              const SizedBox(height: 52),

              // Text
              SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(children: [
                    Text(page.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter',
                          fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Text(page.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter',
                          fontSize: 15, color: AppColors.textSecondaryLight,
                          height: 1.6),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Caregiver-focused onboarding pages ───────────────────────────────────────
class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  static final List<OnboardingPage> all = [
    const OnboardingPage(
      title: 'Monitor Your Patients',
      subtitle: 'Keep track of all your patients\' medication schedules in one place. Never miss a dose update again.',
      icon: Icons.people_rounded,
      color: Color(0xFF0A7EA4),
    ),
    const OnboardingPage(
      title: 'Manage Medication Schedules',
      subtitle: 'Add, edit, and organize medicines for each patient. Set reminders and monitor adherence with ease.',
      icon: Icons.medication_rounded,
      color: Color(0xFF2E7D32),
    ),
    const OnboardingPage(
      title: 'Smart Dispenser Control',
      subtitle: 'Connect to the MediSync smart dispenser and control medication dispensing remotely for your patients.',
      icon: Icons.settings_remote_rounded,
      color: Color(0xFF6A1B9A),
    ),
    const OnboardingPage(
      title: 'Real-Time Alerts',
      subtitle: 'Receive instant alerts for missed doses, low stock, and device status — so you\'re always in the loop.',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFE65100),
    ),
  ];
}
