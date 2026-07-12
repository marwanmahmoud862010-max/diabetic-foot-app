import 'package:flutter/material.dart';
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
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    if (!onboardingDone) {
      pushReplacementPage(context, const OnboardingScreen());
    } else {
      pushReplacementPage(
        context,
        loggedIn ? const HomeScreen() : const LoginScreen(),
      );
    }
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
        body: Center(
          child: Image.asset(
            'assets/app_design.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
