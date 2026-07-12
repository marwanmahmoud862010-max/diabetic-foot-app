# PROJECT MAP — Diabetic Foot App (حماية قدمك)

## SYSTEM FLOW
```
Splash → Profile (first time) → Home → [Checkup | Touch | Temp | Tips | Photo | Risk | RiskFull | History | Report]
```

## CURRENT STATE

| Feature | File | Status | Notes |
|---------|------|--------|-------|
| Splash Screen | `splash_screen.dart` | ✅ Done | Uses translations + RTL |
| Profile (user data) | `profile_screen.dart` | ✅ Done | Multi-lang aware |
| Home (dashboard) | `home_screen.dart` | ✅ Done | 9 cards, multi-lang |
| Daily Checkup | `checkup_screen.dart` | ✅ Done | Saves to StorageService |
| Touch Test | `touch_test_screen.dart` | ✅ Done | Saves to StorageService |
| Temperature | `temperature_screen.dart` | ✅ Done | Saves to StorageService |
| Prevention Tips | `tips_screen.dart` | ✅ Done | Static data |
| Foot Photo | `photo_screen.dart` | ✅ Done | Camera + gallery via image_picker |
| IWGDF Risk (old) | `risk_screen.dart` | ✅ Done | Reads from stored results |
| IWGDF Risk (full) | `risk_assessment_screen.dart` | ✅ Done | Uses translations, saves to StorageService |
| History Log | `history_screen.dart` | ✅ Done | Handles all types including risk_assessment |
| Doctor Report | `report_screen.dart` | ✅ Done | Generates real PDF via printing + pdf |
| Reminder Service | `notification_service.dart` | ✅ Done | Daily notification with toggle |
| Delete History | `history_screen.dart` | ✅ Done | Swipe to delete |
| Edit Profile | `profile_screen.dart` | ✅ Done | Editable via home screen appbar |
| Storage Service | `storage_service.dart` | ✅ Done | Photo + risk assessment storage added |
| Language Service | `language_service.dart` | ✅ Done | AR/EN/FR with all keys |
| RTL Support | All screens | ✅ Done | Via LanguageService.isRTL |
| Profile persistence | `profile_screen.dart` | ✅ Done | SharedPreferences |

## PACKAGES ADDED
- `image_picker: ^1.1.2` — camera + gallery
- `printing: ^5.13.4` — PDF print/share
- `pdf: ^3.11.1` — PDF generation
- `path_provider: ^2.1.5` — file system paths
- `path: ^1.9.1` — path utilities

## ORPHANS & PENDING

| Task | Priority | Status |
|------|----------|--------|
| تفعيل الكاميرا (image_picker) | HIGH | ✅ DONE |
| تصدير PDF (printing) | HIGH | ✅ DONE |
| حفظ نتائج RiskAssessment | MEDIUM | ✅ DONE |
| ترجمة نصوص RiskAssessment | MEDIUM | ✅ DONE |
| تحسين SplashScreen (ترجمة + RTL) | MEDIUM | ✅ DONE |
| إزالة localization.dart المهمل | LOW | ⏸️ SKIPPED (pre-existing) |
| Build verification | HIGH | ⚠️ Run `flutter pub get && flutter analyze` on device |

## NEXT STEPS (Optional)
- إضافة مواعيد/تذكيرات (appointments)
- مشاركة التقرير عبر Share
- دفع إشعارات للتذكير بالفحص اليومي
