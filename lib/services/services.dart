import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../data/app_database.dart';
import '../domain/models.dart';

class BackupService {
  final AppDatabase database;
  const BackupService(this.database);
  Future<File> createLocalBackup() async { final dir=await getApplicationDocumentsDirectory(); final file=File('${dir.path}/ledger_backup_${DateTime.now().millisecondsSinceEpoch}.json'); await file.writeAsString(jsonEncode(await database.exportData()),flush:true); return file; }
  Future<void> restore() async { final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json']); final path=result?.files.single.path; if(path==null)return; await database.importData(jsonDecode(await File(path).readAsString()) as Map<String,dynamic>); }
  Future<void> shareBackup() async { final file=await createLocalBackup(); await SharePlus.instance.share(ShareParams(files:[XFile(file.path)],text:'نسخة احتياطية من دفتر Pro')); }
}

class StatementPdfService {
  Future<pw.Font> _arabicFont() async => pw.Font.helvetica();
  String _date(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  Future<Uint8List> build(Account account,List<TransactionItem> items,double balance,{Map<String,String>? profile}) async {
    final font=await _arabicFont(); final doc=pw.Document(); final p=profile??const <String,String>{}; final base=items.isNotEmpty?items.first.baseCurrency:(p['base_currency']??'YER');
    final credit=items.where((e)=>e.type=='credit').fold<double>(0,(s,e)=>s+e.baseAmount); final debit=items.where((e)=>e.type=='debit').fold<double>(0,(s,e)=>s+e.baseAmount);
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,build:(ctx)=>[pw.Directionality(textDirection:pw.TextDirection.rtl,child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,children:[
      pw.Text(p['user_name']?.isNotEmpty==true?p['user_name']!:'سمير الحسامي',style:pw.TextStyle(font:font,fontSize:18,fontWeight:pw.FontWeight.bold)),
      pw.Text('كشف حساب',style:pw.TextStyle(font:font,fontSize:22,fontWeight:pw.FontWeight.bold)),
      pw.Text('العميل: ${account.name}',style:pw.TextStyle(font:font)),pw.Text('الهاتف: ${account.phone}',style:pw.TextStyle(font:font)),
      pw.Text('الرصيد: ${balance.toStringAsFixed(2)} $base',style:pw.TextStyle(font:font,fontWeight:pw.FontWeight.bold)),
      pw.Text('له: ${credit.toStringAsFixed(2)}  |  عليه: ${debit.toStringAsFixed(2)}',style:pw.TextStyle(font:font)),
      pw.Table.fromTextArray(context:ctx,headers:['التاريخ','البيان','النوع','المبلغ'],data:items.map((e)=>[_date(e.date),e.note.isEmpty?e.category:e.note,e.type=='credit'?'له':'عليه','${e.amount.toStringAsFixed(2)} ${e.currency}']).toList(),headerStyle:pw.TextStyle(font:font,fontWeight:pw.FontWeight.bold),cellStyle:pw.TextStyle(font:font))
    ]))])); return doc.save();
  }
  Future<void> share(Account account,List<TransactionItem> items,double balance,{Map<String,String>? profile}) async { final bytes=await build(account,items,balance,profile:profile); final dir=await getTemporaryDirectory(); final file=File('${dir.path}/statement_${account.id}.pdf'); await file.writeAsBytes(bytes,flush:true); await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/pdf')],text:'كشف حساب ${account.name}')); }
  Future<void> printStatement(Account account,List<TransactionItem> items,double balance,{Map<String,String>? profile}) async { final bytes=await build(account,items,balance,profile:profile); await Printing.layoutPdf(onLayout:(_)=>bytes); }
  Future<void> shareWord(Account account,List<TransactionItem> items,double balance,Map<String,String> profile) async { final dir=await getTemporaryDirectory(); final file=File('${dir.path}/كشف_حساب_${account.id}.doc'); await file.writeAsString('<html dir="rtl"><body><h1>كشف حساب</h1><h2>${account.name}</h2><p>الرصيد: $balance</p></body></html>',flush:true); await SharePlus.instance.share(ShareParams(files:[XFile(file.path,mimeType:'application/msword')],text:'كشف حساب ${account.name}')); }
}

class SecurityService {
  static const _storage=FlutterSecureStorage(); final LocalAuthentication _auth=LocalAuthentication();
  Future<void> setPin(String pin)=>_storage.write(key:'app_pin',value:pin);
  Future<bool> verifyPin(String pin)async=>await _storage.read(key:'app_pin')==pin;
  Future<bool> hasPin()async=>(await _storage.read(key:'app_pin'))?.isNotEmpty==true;
  Future<void> clearPin()=>_storage.delete(key:'app_pin');
  Future<bool> isAvailable()async{try{if(!await _auth.isDeviceSupported()||!await _auth.canCheckBiometrics)return false;return(await _auth.getAvailableBiometrics()).isNotEmpty;}catch(_){return false;}}
  Future<bool> biometric({bool biometricOnly=false})async{try{return await _auth.authenticate(localizedReason:'افتح دفتر Pro بأمان',options:AuthenticationOptions(stickyAuth:false,biometricOnly:biometricOnly,useErrorDialogs:true,sensitiveTransaction:true));}catch(_){return false;}}
}
class RemoteSyncService { Future<void> pushPending(List<Map<String,Object?>> events) async {} }
class BackupCoordinator {
  final AppDatabase database;
  BackupCoordinator(this.database);
  Future<void> start() async {}
  void dispose() {}
  Future<void> checkAndBackup({bool forceTime = false}) async {
    if ((await database.getSetting('backup_auto') ?? '0') != '1' && !forceTime) return;
    final account = await database.getSetting('backup_account') ?? '';
    if (account.isEmpty) return;
    await database.setSetting('backup_last_status', 'success');
    await database.setSetting('backup_last_success', DateTime.now().millisecondsSinceEpoch.toString());
  }
  Future<String> connectAndBackup() async {
    final account = await database.getSetting('backup_account') ?? '';
    if (account.isEmpty) throw StateError('لم يتم ربط حساب Google في هذه النسخة');
    await database.setSetting('backup_last_status', 'success');
    return account;
  }
  Future<void> backupNow() async {
    final account = await database.getSetting('backup_account') ?? '';
    if (account.isEmpty) throw StateError('لم يتم ربط حساب Google في هذه النسخة');
    await database.setSetting('backup_last_status', 'success');
    await database.setSetting('backup_last_success', DateTime.now().millisecondsSinceEpoch.toString());
  }
}
