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

void main()=>runApp(const ProviderScope(child:LedgerApp()));
class LedgerApp extends ConsumerWidget{const LedgerApp({super.key});
@override Widget build(BuildContext context,WidgetRef ref){
 final router=GoRouter(routes:[
  GoRoute(path:'/',redirect:(_,__)=>'/home'),
  GoRoute(path:'/home',builder:(_,__)=>const AppShell(index:0,child:DashboardPage())),
  GoRoute(path:'/accounts',builder:(_,__)=>const AppShell(index:1,child:AccountsPage())),
  GoRoute(path:'/transactions',builder:(_,__)=>const AppShell(index:2,child:TransactionsPage())),
  GoRoute(path:'/more',builder:(_,__)=>const AppShell(index:4,child:MorePage())),
  GoRoute(path:'/accounts/:id',builder:(_,s)=>AccountDetailPage(id:s.pathParameters['id']!)),
  GoRoute(path:'/add-transaction',builder:(_,s)=>AddTransactionPage(accountId:s.uri.queryParameters['account'],initialType:s.uri.queryParameters['type']??'credit')),
  GoRoute(path:'/edit-transaction/:id',builder:(_,s)=>AddTransactionPage(transactionId:s.pathParameters['id']!)),
  GoRoute(path:'/calculator',builder:(_,__)=>const CalculatorPage()),
  GoRoute(path:'/currencies',builder:(_,__)=>const CurrenciesPage()),
  GoRoute(path:'/statements/:id',builder:(_,s)=>StatementsPage(accountId:s.pathParameters['id']!)),
  GoRoute(path:'/reports',builder:(_,__)=>const ReportsPage()),
  GoRoute(path:'/search',builder:(_,__)=>const SearchPage()),
  GoRoute(path:'/settings',builder:(_,__)=>const SettingsPage()),
  GoRoute(path:'/backup',builder:(_,__)=>const BackupPage()),
  GoRoute(path:'/settings/profile',builder:(_,__)=>const ProfileSettingsPage()),
  GoRoute(path:'/settings/printer',builder:(_,__)=>const PrinterSettingsPage()),
  GoRoute(path:'/settings/security',builder:(_,__)=>const SecuritySettingsPage()),
  GoRoute(path:'/settings/notifications',builder:(_,__)=>const NotificationSettingsPage()),
  GoRoute(path:'/settings/other',builder:(_,__)=>const OtherSettingsPage()),
  GoRoute(path:'/support',builder:(_,__)=>const SupportPage()),
 ]);
 return MaterialApp.router(title:AppConstants.appName,debugShowCheckedModeBanner:false,theme:AppTheme.light(),darkTheme:AppTheme.dark(),themeMode:ref.watch(themeModeProvider),locale:const Locale('ar'),supportedLocales:const[Locale('ar'),Locale('en')],localizationsDelegates:const[GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],routerConfig:router,builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child!));
}}
class AppShell extends ConsumerWidget{
 final int index;final Widget child;
 const AppShell({super.key,required this.index,required this.child});
 void _go(BuildContext c,int i){const paths=['/home','/accounts','/transactions','/reports','/more'];GoRouter.of(c).go(paths[i]);}
 @override Widget build(BuildContext c,WidgetRef ref)=>Scaffold(body:SafeArea(child:child),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>_go(c,i),destinations:const[
 NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'الرئيسية'),
 NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'الحسابات'),
 NavigationDestination(icon:Icon(Icons.swap_horiz_rounded),selectedIcon:Icon(Icons.swap_horiz),label:'العمليات'),
 NavigationDestination(icon:Icon(Icons.bar_chart_outlined),selectedIcon:Icon(Icons.bar_chart),label:'التقارير'),
 NavigationDestination(icon:Icon(Icons.grid_view_rounded),selectedIcon:Icon(Icons.grid_view),label:'المزيد')]));
}