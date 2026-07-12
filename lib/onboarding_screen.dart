import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'route_transition.dart';
import 'language_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!mounted) return;
    pushReplacementPage(context, loggedIn ? const HomeScreen() : const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _Page(
        icon: Icons.health_and_safety,
        title: LanguageService.t('onboarding_title_1'),
        desc: LanguageService.t('onboarding_desc_1'),
        color: Colors.teal,
      ),
      _Page(
        icon: Icons.search,
        title: LanguageService.t('onboarding_title_2'),
        desc: LanguageService.t('onboarding_desc_2'),
        color: Colors.blue,
      ),
      _Page(
        icon: Icons.auto_awesome,
        title: LanguageService.t('onboarding_title_3'),
        desc: LanguageService.t('onboarding_desc_3'),
        color: Colors.purple,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? pages[i].color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _page < 2
                      ? () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                      : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pages[_page].color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _page < 2 ? LanguageService.t('next') : LanguageService.t('onboarding_start'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _Page({required this.icon, required this.title, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 32),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(desc, style: TextStyle(fontSize: 15, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
