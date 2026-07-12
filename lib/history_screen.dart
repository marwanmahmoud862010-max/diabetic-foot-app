import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, String>> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
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

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList('full_history') ?? [];
    setState(() {
      history = raw.map((e) {
        final parts = e.split('||');
        return {
          'type': parts.isNotEmpty ? parts[0] : '',
          'result': parts.length > 1 ? parts[1] : '',
          'date': parts.length > 2 ? parts[2] : '',
        };
      }).toList().reversed.toList();
    });
  }

  Future<void> _deleteItem(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(LanguageService.t('delete_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(LanguageService.t('cancel'))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(LanguageService.t('delete'))),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList('full_history') ?? [];
    final reversedIndex = history.length - 1 - index;
    raw.removeAt(reversedIndex);
    await prefs.setStringList('full_history', raw);
    await _loadHistory();
  }

  String _typeLabel(String type) {
    const knownKeys = ['daily_checkup', 'touch_test', 'temperature', 'risk_assessment'];
    if (knownKeys.contains(type)) {
      return LanguageService.t(type);
    }
    return type;
  }

  String _resultLabel(String result) {
    return LanguageService.t(result);
  }

  bool _isGood(String result) {
    const goodCodes = ['checkup_ok', 'touch_cat0', 'temp_ok'];
    if (goodCodes.contains(result)) return true;
    const badCodes = [
      'checkup_danger',
      'touch_cat1',
      'touch_cat2',
      'temp_danger'
    ];
    if (badCodes.contains(result)) return false;
    if (result == 'risk_level_0') return true;
    return result.contains('✅');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('history')),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: history.isEmpty
            ? Center(
                child: Text(
                  LanguageService.t('no_history'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final isGood = _isGood(item['result'] ?? '');
                  final d = item['date'] ?? '';
                  return Dismissible(
                    key: ValueKey('${item['date']}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsetsDirectional.only(end: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteItem(index);
                      return false;
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isGood ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isGood
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isGood ? Icons.check_circle : Icons.warning,
                            color: isGood ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _typeLabel(item['type'] ?? ''),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _resultLabel(item['result'] ?? ''),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isGood
                                        ? Colors.green.shade800
                                        : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            d.length >= 10 ? d.substring(0, 10) : d,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
