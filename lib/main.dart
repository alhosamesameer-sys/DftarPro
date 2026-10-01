import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_constants.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/accounts/accounts_page.dart';
import 'features/accounts/account_detail_page.dart';
import 'features/transactions/transactions_page.dart';
import 'features/transactions/add_transaction_page.dart';
import 'features/calculator/calculator_page.dart';
import 'features/currencies/currencies_page.dart';
import 'features/statements/statements_page.dart';
import 'features/reports/reports_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/backup_page.dart';
import 'features/settings/profile_page.dart';
import 'features/settings/printer_page.dart';
import 'features/settings/security_page.dart';
import 'features/settings/notifications_page.dart';
import 'features/settings/other_settings_page.dart';
import 'features/more/more_page.dart';
import 'features/more/support_page.dart';

void main() => runApp(const ProviderScope(child: LedgerApp()));

class LedgerApp extends ConsumerStatefulWidget {
  const LedgerApp({super.key});
  @override ConsumerState<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends ConsumerState<LedgerApp> with WidgetsBindingObserver {
  bool _ready = false, _locked = false, _useBiometric = false;
  DateTime? _backgroundedAt;
  static const _autoLockDelay = Duration(seconds: 30);
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _prepare(); }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  Future<void> _prepare() async {
    try {
      final db = ref.read(databaseProvider);
      final mode = await db.getSetting('theme_mode') ?? 'light';
      if (mounted) {
        ref.read(themeModeProvider.notifier).state =
            mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }

      final hasPin = await ref.read(securityProvider).hasPin();
      final biometricEnabled =
          (await db.getSetting('biometric_enabled')) == '1' && hasPin;
      _useBiometric = biometricEnabled;

      if (hasPin && biometricEnabled) {
        final ok = await ref.read(securityProvider).biometric();
        _locked = !ok;
      }
    } catch (e, st) {
      debugPrint('DftarPro startup initialization failed: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) {
        setState(() => _ready = true);
        unawaited(_startBackupCoordinator());
      }
    }
  }

  Future<void> _startBackupCoordinator() async {
    try {
      await ref.read(backupCoordinatorProvider).start();
    } catch (e, st) {
      debugPrint('Backup coordinator startup failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) { _backgroundedAt = DateTime.now(); return; }
    if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final elapsed = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (elapsed >= _autoLockDelay) _lockForReturn();
    }
  }
  Future<void> _lockForReturn() async {
    final hasPin = await ref.read(securityProvider).hasPin();
    if (!hasPin || !mounted) return;
    setState(() => _locked = true);
  }
  @override Widget build(BuildContext context) {
    if (!_ready) return MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ref.watch(themeModeProvider), home: const Scaffold(body: SizedBox.expand()));
    if (_locked) return MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ref.watch(themeModeProvider), home: _LockScreen(useBiometric: _useBiometric, onUnlocked: () => setState(() => _locked = false)));
    return const _RoutedApp();
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  final bool useBiometric;
  final VoidCallback onUnlocked;
  const _LockScreen({required this.useBiometric, required this.onUnlocked});
  @override ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  final pin = TextEditingController();
  bool busy = false;
  String error = '';
  int failures = 0;
  DateTime? blockedUntil;
  Timer? timer;
  @override void dispose() { timer?.cancel(); pin.dispose(); super.dispose(); }
  Future<void> _verifyPin() async {
    if (blockedUntil != null && DateTime.now().isBefore(blockedUntil!)) {
      setState(() => error = 'تم إيقاف المحاولات مؤقتًا. حاول بعد ' + (blockedUntil!.difference(DateTime.now()).inSeconds + 1).toString() + ' ثانية.');
      return;
    }
    if (pin.text.length != 6) { setState(() => error = 'أدخل رمز PIN المكون من 6 أرقام'); return; }
    setState(() => busy = true);
    final ok = await ref.read(securityProvider).verifyPin(pin.text);
    if (ok) { failures = 0; widget.onUnlocked(); }
    else {
      failures++; pin.clear();
      if (failures >= 5) {
        blockedUntil = DateTime.now().add(const Duration(seconds: 30)); failures = 0;
        timer?.cancel();
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (blockedUntil == null || !DateTime.now().isBefore(blockedUntil!)) { timer?.cancel(); setState(() => blockedUntil = null); }
          else setState(() => error = 'تم إيقاف المحاولات مؤقتًا. حاول بعد ' + (blockedUntil!.difference(DateTime.now()).inSeconds + 1).toString() + ' ثانية.');
        });
      } else {
        error = 'رمز PIN غير صحيح. المحاولات المتبقية: ' + (5 - failures).toString();
      }
    }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.lock_rounded, size: 72),
    const SizedBox(height: 18),
    const Text('دفتر Pro مقفل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    Text(widget.useBiometric ? 'استخدم البصمة أو أدخل رمز PIN' : 'أدخل رمز PIN المكون من 6 أرقام'),
    const SizedBox(height: 18),
    if (widget.useBiometric) FilledButton.icon(onPressed: busy ? null : () async { final ok = await ref.read(securityProvider).biometric(); if (ok) widget.onUnlocked(); }, icon: const Icon(Icons.fingerprint), label: const Text('فتح بالبصمة')),
    if (widget.useBiometric) const SizedBox(height: 12),
    TextField(controller: pin, enabled: blockedUntil == null, keyboardType: TextInputType.number, maxLength: 6, obscureText: true, textAlign: TextAlign.center, decoration: InputDecoration(labelText: 'رمز PIN', errorText: error.isEmpty ? null : error, counterText: ''), onSubmitted: (_) => _verifyPin()),
    const SizedBox(height: 14),
    FilledButton.icon(onPressed: busy || blockedUntil != null ? null : _verifyPin, icon: const Icon(Icons.lock_open), label: const Text('فتح التطبيق')),
  ]))));
}

class _RoutedApp extends ConsumerWidget {
  const _RoutedApp();
  @override Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', redirect: (_, __) => '/home'),
      GoRoute(path: '/home', builder: (_, __) => const AppShell(index: 0, child: DashboardPage())),
      GoRoute(path: '/accounts', builder: (_, __) => const AppShell(index: 1, child: AccountsPage())),
      GoRoute(path: '/transactions', builder: (_, __) => const AppShell(index: 2, child: TransactionsPage())),
      GoRoute(path: '/more', builder: (_, __) => const AppShell(index: 4, child: MorePage())),
      GoRoute(path: '/accounts/:id', builder: (_, s) => AccountDetailPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/add-transaction', builder: (_, s) => AddTransactionPage(accountId: s.uri.queryParameters['account'], initialType: s.uri.queryParameters['type'] ?? 'credit')),
      GoRoute(path: '/edit-transaction/:id', builder: (_, s) => AddTransactionPage(transactionId: s.pathParameters['id']!)),
      GoRoute(path: '/calculator', builder: (_, __) => const CalculatorPage()),
      GoRoute(path: '/currencies', builder: (_, __) => const CurrenciesPage()),
      GoRoute(path: '/statements/:id', builder: (_, s) => StatementsPage(accountId: s.pathParameters['id']!)),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsPage()),
      GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(path: '/backup', builder: (_, __) => const BackupPage()),
      GoRoute(path: '/settings/profile', builder: (_, __) => const ProfileSettingsPage()),
      GoRoute(path: '/settings/printer', builder: (_, __) => const PrinterSettingsPage()),
      GoRoute(path: '/settings/security', builder: (_, __) => const SecuritySettingsPage()),
      GoRoute(path: '/settings/notifications', builder: (_, __) => const NotificationSettingsPage()),
      GoRoute(path: '/settings/other', builder: (_, __) => const OtherSettingsPage()),
      GoRoute(path: '/support', builder: (_, __) => const SupportPage()),
    ]);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(title: AppConstants.appName, debugShowCheckedModeBanner: false, theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: mode, locale: const Locale('ar'), supportedLocales: const [Locale('ar'), Locale('en')], localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], routerConfig: router, builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!));
  }
}

class AppShell extends ConsumerWidget {
  final int index;
  final Widget child;
  const AppShell({super.key, required this.index, required this.child});
  void _go(BuildContext c, int i) {
    const paths = ['/home', '/accounts', '/transactions', '/reports', '/more'];
    GoRouter.of(c).go(paths[i]);
  }
  @override Widget build(BuildContext c, WidgetRef ref) => Scaffold(
    body: SafeArea(child: child),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) => _go(c, i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'الحسابات'),
        NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), selectedIcon: Icon(Icons.swap_horiz), label: 'العمليات'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
        NavigationDestination(icon: Icon(Icons.grid_view_rounded), selectedIcon: Icon(Icons.grid_view), label: 'المزيد'),
      ],
    ),
    floatingActionButton: index == 0
        ? FloatingActionButton.extended(onPressed: () => showChooseAccountAndRecord(c, ref), icon: const Icon(Icons.add_rounded), label: const Text('إضافة'))
        : index == 2
            ? FloatingActionButton(onPressed: () => c.push('/add-transaction'), child: const Icon(Icons.add_rounded))
            : null,
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  );
}