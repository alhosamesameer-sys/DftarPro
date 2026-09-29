# دفتر Pro — Flutter Offline-First Ledger

مشروع Flutter عربي RTL لإدارة الحسابات والعمليات والفواتير والعملات، يعمل محليًا عبر SQLite مع بنية Offline First.

## التشغيل محليًا
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## البناء الآلي
GitHub Actions يقوم تلقائيًا عند الدفع أو Pull Request بـ:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. `flutter build apk --debug`
5. رفع APK كـ Artifact باسم `ledger-pro-debug-apk`

يمكن تشغيل Workflow يدويًا من تبويب **Actions**.

## المزايا
- حسابات العملاء والموردين.
- عمليات وأرصدة متعددة العملات.
- SQLite وSync Queue محلية.
- كشوف حساب وPDF ومشاركة.
- بحث وتقارير وحاسبة وفواتير.
- نسخ احتياطي واستعادة JSON.
- حماية PIN/بصمة وواجهة RTL.
