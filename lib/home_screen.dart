import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'language_service.dart';
import 'notification_service.dart';
import 'error_handler.dart';
import 'checkup_screen.dart';
import 'photo_screen.dart';
import 'tips_screen.dart';
import 'temperature_screen.dart';
import 'touch_test_screen.dart';
import 'risk_screen.dart';
import 'risk_assessment_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'researches_screen.dart';
import 'ai_chat_screen.dart';
import 'route_transition.dart';
import 'login_screen.dart';
import 'theme_service.dart';
import 'widgets/dark_mode_toggle.dart';
import 'providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkupAsync = ref.watch(lastCheckupProvider);
    final touchAsync = ref.watch(lastTouchTestProvider);
    final tempAsync = ref.watch(lastTemperatureProvider);
    final profileAsync = ref.watch(profileDoneProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('app_name')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: LanguageService.t('edit_profile'),
            onPressed: _editProfile,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: LanguageService.t('daily_reminder'),
            onPressed: _toggleReminder,
          ),
          TextButton.icon(
            onPressed: _showLanguageSheet,
            icon: const Icon(Icons.language, color: Colors.white),
            label: const Text('', style: TextStyle(color: Colors.white)),
          ),
          const DarkModeToggle(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: LanguageService.t('logout'),
            onPressed: _logout,
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => ErrorHandler.loadingWidget(),
        error: (_, _) => _buildBody(checkupAsync, touchAsync, tempAsync, false),
        data: (profileDone) => _buildBody(checkupAsync, touchAsync, tempAsync, profileDone),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushPage(context, const AiChatScreen()),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildBody(AsyncValue<String?> checkupAsync, AsyncValue<String?> touchAsync, AsyncValue<String?> tempAsync, bool profileDone) {
    final lastCheckup = checkupAsync.asData?.value;
    final lastTouch = touchAsync.asData?.value;
    final lastTemp = tempAsync.asData?.value;

    return Directionality(
      textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lastCheckupProvider);
          ref.invalidate(lastTouchTestProvider);
          ref.invalidate(lastTemperatureProvider);
          ref.invalidate(profileDoneProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!profileDone) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00897B), Color(0xFF004D40)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt, color: Colors.white, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(LanguageService.t('setup_profile_title'),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(LanguageService.t('setup_profile_desc'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _editProfile,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.teal.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(LanguageService.t('setup_profile_btn'), style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 10),
            Text(
              LanguageService.t('choose_checkup'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCard(context,
              icon: Icons.checklist,
              title: LanguageService.t('daily_checkup'),
              subtitle: lastCheckup == null
                  ? LanguageService.t('no_previous_checkup')
                  : LanguageService.t(lastCheckup),
              color: Colors.teal,
              onTap: () async {
                await pushPage(context, const CheckupScreen());
                ref.invalidate(lastCheckupProvider);
              }),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.touch_app,
              title: LanguageService.t('touch_test'),
              subtitle: lastTouch == null
                  ? LanguageService.t('no_previous_test')
                  : LanguageService.t(lastTouch),
              color: Colors.blue,
              onTap: () async {
                await pushPage(context, const TouchTestScreen());
                ref.invalidate(lastTouchTestProvider);
              }),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.thermostat,
              title: LanguageService.t('temperature'),
              subtitle: lastTemp == null
                  ? LanguageService.t('no_previous_measure')
                  : LanguageService.t(lastTemp),
              color: Colors.orange,
              onTap: () async {
                await pushPage(context, const TemperatureScreen());
                ref.invalidate(lastTemperatureProvider);
              }),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.health_and_safety,
              title: LanguageService.t('prevention_tips'),
              subtitle: LanguageService.t('prevention_tips_sub'),
              color: Colors.green,
              onTap: () => pushPage(context, const TipsScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.camera_alt,
              title: LanguageService.t('foot_photo'),
              subtitle: LanguageService.t('foot_photo_sub'),
              color: Colors.purple,
              onTap: () => pushPage(context, const PhotoScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.assessment,
              title: LanguageService.t('risk_assessment'),
              subtitle: LanguageService.t('risk_assessment_sub'),
              color: Colors.red,
              onTap: () => pushPage(context, const RiskScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.shield,
              title: LanguageService.t('risk_assessment_full'),
              subtitle: LanguageService.t('risk_assessment_full_sub'),
              color: Colors.deepOrange,
              onTap: () => pushPage(context, const RiskAssessmentScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.history,
              title: LanguageService.t('history'),
              subtitle: LanguageService.t('history_sub'),
              color: Colors.indigo,
              onTap: () => pushPage(context, const HistoryScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.menu_book,
              title: LanguageService.t('researches'),
              subtitle: LanguageService.t('researches_sub'),
              color: Colors.teal.shade700,
              onTap: () => pushPage(context, const ResearchesScreen()),
            ),
            const SizedBox(height: 12),
            _buildCard(context,
              icon: Icons.document_scanner,
              title: LanguageService.t('doctor_report'),
              subtitle: LanguageService.t('doctor_report_sub'),
              color: Colors.red,
              onTap: () => pushPage(context, const ReportScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('email');
    if (!mounted) return;
    pushReplacementPage(context, const LoginScreen());
  }

  Future<void> _editProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await pushPage(context, ProfileScreen(existingData: {
        'name': prefs.getString('name') ?? '',
        'age': prefs.getString('age') ?? '',
        'diabetes_years': prefs.getString('diabetes_years') ?? '',
        'diabetes_type': prefs.getString('diabetes_type') ?? 'type_2',
        'phone': prefs.getString('phone') ?? '',
      }));
    ref.invalidate(profileDoneProvider);
  }

  Future<void> _toggleReminder() async {
    try {
      final enabled = await NotificationService.isEnabled();
      await NotificationService.setEnabled(!enabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.t(enabled ? 'reminder_off' : 'reminder_on'))),
      );
    } catch (e) {
      ErrorHandler.showSnackBar(context, e);
    }
  }

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                LanguageService.t('choose_language'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _langTile(LanguageService.t('arabic'), 'ar'),
            _langTile(LanguageService.t('english'), 'en'),
            _langTile(LanguageService.t('french'), 'fr'),
            const Divider(),
            SwitchListTile(
              title: Text(LanguageService.t(ThemeService.isDark ? 'dark_mode' : 'light_mode')),
              value: ThemeService.isDark,
              onChanged: (_) async {
                await ThemeService.toggle();
                if (mounted) Navigator.pop(context);
              },
              secondary: Icon(ThemeService.isDark ? Icons.dark_mode : Icons.light_mode),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _langTile(String label, String code) {
    final selected = LanguageService.currentLang.value == code;
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: selected ? const Icon(Icons.check, color: Colors.teal) : null,
      onTap: () async {
        await LanguageService.setLang(code);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Widget _buildCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
                  Text(subtitle, style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  )),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
