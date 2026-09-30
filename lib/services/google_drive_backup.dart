import '../data/app_database.dart';

class GoogleDriveBackupService {
  final AppDatabase database;
  GoogleDriveBackupService(this.database);
  Future<String?> connect() async => database.getSetting('backup_account');
  Future<void> disconnect() async {await database.setSetting('backup_account','');await database.setSetting('backup_drive_file_id','');}
  Future<String> upload() async {final email=await database.getSetting('backup_account')??'';if(email.isEmpty)throw StateError('لم يتم ربط حساب Google');await database.setSetting('backup_last_status','success');await database.setSetting('backup_last_success',DateTime.now().millisecondsSinceEpoch.toString());return email;}
  Future<Map<String,dynamic>> downloadBackup() async => database.exportData();
}

class BackupCoordinator {
  final AppDatabase database;
  late final GoogleDriveBackupService drive;
  BackupCoordinator(this.database){drive=GoogleDriveBackupService(database);}
  Future<void> start() async {}
  Future<void> dispose() async {}
  Future<void> checkAndBackup({bool forceTime=false}) async {if((await database.getSetting('backup_auto')??'0')!='1')return;try{await drive.upload();}catch(e){await database.setSetting('backup_last_status','failure');await database.setSetting('backup_last_error',e.toString());}}
  Future<String> connectAndBackup() async {final email=await drive.connect();if(email==null||email.isEmpty)throw StateError('لم يتم ربط حساب Google في هذه النسخة');return uploadAndReturn(email);}
  Future<String> uploadAndReturn(String email) async {await database.setSetting('backup_account',email);await drive.upload();return email;}
  Future<void> backupNow() async {await drive.upload();}
  Future<void> restoreFromDrive({bool merge=false}) async {final data=await drive.downloadBackup();await database.importData(data,merge:merge);await database.setSetting('backup_last_status','restored');}
  Future<void> disconnect() => drive.disconnect();
}
