import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/app_database.dart';
import '../domain/models.dart';
import 'statement_export_service.dart';

class BackupService {
  final AppDatabase database;
  const BackupService(this.database);
  Future<File> createLocalBackup() async { final dir=await getApplicationDocumentsDirectory(); final file=File('${dir.path}/ledger_backup_${DateTime.now().millisecondsSinceEpoch}.json'); await file.writeAsString(jsonEncode(await database.exportData()),flush:true); return file; }
  Future<void> restore() async { final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json']); final path=result?.files.single.path; if(path==null)return; await database.importData(jsonDecode(await File(path).readAsString()) as Map<String,dynamic>); }
  Future<void> shareBackup() async { final file=await createLocalBackup(); await SharePlus.instance.share(ShareParams(files:[XFile(file.path)],text:'نسخة احتياطية من دفتر Pro')); }
}

class StatementPdfService {
  final _export = StatementExportService();
  Future<Uint8List> build(Account account,List<TransactionItem> items,double balance,{Map<String,String>? profile}) =>
      _export.buildPdf(account,items,balance,profile:profile);
  Future<void> share(Account account,List<TransactionItem> items,double balance,{Map<String,String>? profile}) =>
      _export.share(account,items,balance,profile:profile);
  Future<void> printStatement(Account account,List<TransactionItem> items,double balance,{Map<String,String>? profile}) =>
      _export.printStatement(account,items,balance,profile:profile);
  Future<void> shareWord(Account account,List<TransactionItem> items,double balance,Map<String,String> profile) =>
      _export.shareWord(account,items,balance,profile);
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
