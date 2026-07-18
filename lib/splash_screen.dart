import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'route_transition.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigating = false;

  Future<void> _navigate() async {
    if (_navigating) return;
    _navigating = true;
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    if (!onboardingDone) {
      pushReplacementPage(context, const OnboardingScreen());
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    pushReplacementPage(
      context,
      user != null ? const HomeScreen() : const LoginScreen(),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _navigate);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigate,
      child: Scaffold(
        body: SizedBox.expand(
          child: Image.asset(
            'assets/app_design.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
