import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_service.dart';
import 'error_handler.dart';
import 'widgets/dark_mode_toggle.dart';
import 'providers/app_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Map<String, String>> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _typeFilter = 'all';

  static const _types = ['all', 'daily_checkup', 'touch_test', 'temperature', 'risk_assessment'];

  @override
  void initState() {
    super.initState();
    LanguageService.currentLang.addListener(_onLangChanged);
    _searchCtrl.addListener(_applyFilter);
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageService.currentLang.removeListener(_onLangChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final history = ref.read(fullHistoryProvider).asData?.value ?? [];
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = history.where((item) {
        if (_typeFilter != 'all' && item['type'] != _typeFilter) return false;
        if (query.isEmpty) return true;
        final type = LanguageService.t(item['type'] ?? '').toLowerCase();
        final result = LanguageService.t(item['result'] ?? '').toLowerCase();
        final date = (item['date'] ?? '').toLowerCase();
        return type.contains(query) || result.contains(query) || date.contains(query);
      }).toList();
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

    final history = ref.read(fullHistoryProvider).asData?.value ?? [];
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList('full_history') ?? [];
    final reversedIndex = history.length - 1 - index;
    raw.removeAt(reversedIndex);
    await prefs.setStringList('full_history', raw);
    ref.invalidate(fullHistoryProvider);
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
    final historyAsync = ref.watch(fullHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.t('history')),
        centerTitle: true,
        actions: [const DarkModeToggle()],
      ),
      body: Directionality(
        textDirection: LanguageService.isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: LanguageService.t('search'),
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _types.map((type) {
                  final selected = type == _typeFilter;
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text(type == 'all' ? LanguageService.t('all') : LanguageService.t(type), style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.teal.shade700)),
                      selected: selected,
                      selectedColor: Colors.teal,
                      backgroundColor: Colors.teal.shade50,
                      onSelected: (_) {
                        setState(() => _typeFilter = type);
                        _applyFilter();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: historyAsync.when(
                loading: () => ErrorHandler.loadingWidget(),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
                data: (history) {
                  if (_filtered.isEmpty && _searchCtrl.text.isEmpty && _typeFilter == 'all') {
                    _filtered = history;
                  }
                  if (_filtered.isEmpty) {
                    return Center(
                      child: Text(
                        LanguageService.t('no_history'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(fullHistoryProvider);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        final isGood = _isGood(item['result'] ?? '');
                        final d = item['date'] ?? '';
                        return Dismissible(
                          key: ValueKey('${item['date']}_$index'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsetsDirectional.only(end: 20),
                            decoration: BoxDecoration(
                              color: Colors.red, borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            final realIndex = history.indexOf(item);
                            if (realIndex >= 0) await _deleteItem(realIndex);
                            return false;
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isGood ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isGood ? Colors.green.shade200 : Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(isGood ? Icons.check_circle : Icons.warning, color: isGood ? Colors.green : Colors.red),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_typeLabel(item['type'] ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(_resultLabel(item['result'] ?? ''), style: TextStyle(fontSize: 13, color: isGood ? Colors.green.shade800 : Colors.red.shade800)),
                                    ],
                                  ),
                                ),
                                Text(d.length >= 10 ? d.substring(0, 10) : d, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
