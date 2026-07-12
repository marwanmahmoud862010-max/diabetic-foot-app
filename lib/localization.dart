class AppLocalizations {
  static const Map<String, Map<String, String>> translations = {
    'ar': {
      'app_title': 'حماية قدمك',
      'daily_checkup': 'الفحص اليومي',
      'touch_test': 'اختبار اللمس',
      'temperature': 'درجات الحرارة',
      'tips': 'نصائح الوقاية',
      'photo': 'تصوير القدم',
      'history': 'السجل التاريخي',
      'report': 'تقرير للدكتور',
      'select_test': 'اختار نوع الفحص',
      'welcome': 'أهلاً بك في حماية قدمك',
      'name': 'الاسم',
      'age': 'العمر',
      'diabetes_years': 'كام سنة عندك السكري؟',
      'diabetes_type': 'نوع السكري',
      'start': 'ابدأ',
    },
    'en': {
      'app_title': 'Foot Care',
      'daily_checkup': 'Daily Checkup',
      'touch_test': 'Touch Test',
      'temperature': 'Temperature',
      'tips': 'Prevention Tips',
      'photo': 'Photo Tracking',
      'history': 'History',
      'report': 'Doctor Report',
      'select_test': 'Select Test Type',
      'welcome': 'Welcome to Foot Care',
      'name': 'Name',
      'age': 'Age',
      'diabetes_years': 'How long have you had diabetes?',
      'diabetes_type': 'Diabetes Type',
      'start': 'Start',
    },
    'fr': {
      'app_title': 'Soin des Pieds',
      'daily_checkup': 'Contrôle Quotidien',
      'touch_test': 'Test de Sensation',
      'temperature': 'Température',
      'tips': 'Conseils de Prévention',
      'photo': 'Suivi Photo',
      'history': 'Historique',
      'report': 'Rapport Médecin',
      'select_test': 'Sélectionner le Type de Test',
      'welcome': 'Bienvenue dans Soin des Pieds',
      'name': 'Nom',
      'age': 'Âge',
      'diabetes_years': 'Depuis combien d\'années avez-vous le diabète?',
      'diabetes_type': 'Type de Diabète',
      'start': 'Commencer',
    },
  };

  static String translate(String key, String language) {
    return translations[language]?[key] ?? key;
  }
}