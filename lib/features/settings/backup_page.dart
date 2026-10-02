import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool auto = false, busy = false;
  String account = '', driveName = '', driveProvider = '', lastStatus = '', lastError = '', backupTime = '02:00';
  int lastSuccess = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final repo = ref.read(repositoryProvider);
    final a = await repo.getSetting('backup_account') ?? '';
    final enabled = (await repo.getSetting('backup_auto') ?? '0') == '1';
    final driveFile = await repo.getSetting('backup_drive_name') ?? '';
    final driveSource = await repo.getSetting('backup_drive_provider') ?? '';
    final status = await repo.getSetting('backup_last_status') ?? '';
    final error = await repo.getSetting('backup_last_error') ?? '';
    final last = int.tryParse(await repo.getSetting('backup_last_success') ?? '0') ?? 0;
    final time = await repo.getSetting('backup_time') ?? '02:00';
    if (mounted) setState(() { account=a; driveName=driveFile; driveProvider=driveSource; auto=enabled; lastStatus=status; lastError=error; lastSuccess=last; backupTime=time; });
  }

  void _refreshLedger() {
    ref.invalidate(currenciesProvider);
    ref.invalidate(baseCurrencyProvider);
    ref.invalidate(accountsProvider(''));
    ref.invalidate(accountsByTypeProvider('customer'));
    ref.invalidate(accountsByTypeProvider('supplier'));
    ref.invalidate(dashboardProvider);
    ref.invalidate(userProfileProvider);
  }

  String _lastText() {
    if (lastSuccess <= 0) return 'لم يتم تنفيذ نسخة احتياطية ناجحة بعد.';
    final d = DateTime.fromMillisecondsSinceEpoch(lastSuccess);
    return 'آخر نسخة ناجحة: ${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  Future<void> _saveLocal() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final data = await ref.read(repositoryProvider).exportData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final path = await FilePicker.platform.saveFile(dialogTitle:'حفظ النسخة الاحتياطية المحلية',fileName:'dftar_backup_${DateTime.now().millisecondsSinceEpoch}.json',type:FileType.custom,allowedExtensions:const['json'],bytes:Uint8List.fromList(utf8.encode(json)));
      if (path != null && mounted) {
        await ref.read(repositoryProvider).setSetting('backup_local_last', path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم حفظ النسخة الاحتياطية محليًا ✓\n$path')));
      }
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر حفظ النسخة المحلية: $e')));
    } finally { if(mounted) setState(()=>busy=false); }
  }

  Future<String?> _modeDialog() async {
    if(!mounted) return null;
    return showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('طريقة الاستعادة'),
      content:const Text('استبدال يحذف البيانات الحالية ثم يستعيد النسخة. الدمج يحافظ على البيانات الحالية ويضيف السجلات غير المتعارضة.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c,'cancel'),child:const Text('إلغاء')),
        OutlinedButton(onPressed:()=>Navigator.pop(c,'merge'),child:const Text('دمج')),
        FilledButton(onPressed:()=>Navigator.pop(c,'replace'),child:const Text('استبدال')),
      ],
    ));
  }

  Future<void> _restoreLocal() async {
    if(busy)return;
    final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const['json'],withData:true);
    if(result==null)return;
    try{
      final file=result.files.single;
      final bytes=file.bytes??(file.path==null?null:await File(file.path!).readAsBytes());
      if(bytes==null)throw StateError('تعذر قراءة ملف النسخة الاحتياطية');
      final decoded=jsonDecode(utf8.decode(bytes));
      if(decoded is! Map<String,dynamic>)throw const FormatException('ملف النسخة الاحتياطية غير صالح');
      final mode=await _modeDialog();
      if(mode==null||mode=='cancel')return;
      setState(()=>busy=true);
      await ref.read(repositoryProvider).importData(decoded,merge:mode=='merge');
      _refreshLedger();
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(mode=='merge'?'تم دمج النسخة الاحتياطية بنجاح ✓':'تم استبدال البيانات واستعادة النسخة بنجاح ✓')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشلت الاستعادة: $e')));
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _restoreDrive() async {
    if(busy)return;
    final mode=await _modeDialog();
    if(mode==null||mode=='cancel')return;
    setState(()=>busy=true);
    try{
      await ref.read(backupCoordinatorProvider).restoreFromDrive(merge:mode=='merge');
      _refreshLedger();
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(mode=='merge'?'تم دمج نسخة Google Drive بنجاح ✓':'تم استبدال البيانات بنسخة Google Drive ✓')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشلت استعادة Google Drive: $e')));
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _connect() async {
    if(busy)return;
    setState(()=>busy=true);
    try{
      final email=await ref.read(backupCoordinatorProvider).connectAndBackup();
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم ربط $email ورفع أول نسخة احتياطية بنجاح ✓')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر الربط أو رفع النسخة: $e')));
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _backupNow() async {
    if(busy)return;
    setState(()=>busy=true);
    try{
      await ref.read(backupCoordinatorProvider).backupNow();
      await _load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تحديث النسخة الاحتياطية بنجاح ✓')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('فشل النسخ الاحتياطي: $e')));
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _disconnect() async {
    await ref.read(backupCoordinatorProvider).disconnect();
    await _load();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم فصل حساب Google Drive')));
  }

  Future<void> _chooseTime() async {
    final parts=backupTime.split(':');
    final initial=TimeOfDay(hour:int.tryParse(parts.first)??2,minute:int.tryParse(parts.length>1?parts[1]:'0')??0);
    final time=await showTimePicker(context:context,initialTime:initial);
    if(time==null)return;
    final value='${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}';
    await ref.read(repositoryProvider).setSetting('backup_time',value);
    if(mounted)setState(()=>backupTime=value); await ref.read(backupCoordinatorProvider).scheduleAutoBackup();
  }

  @override Widget build(BuildContext context) {
    final color=Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar:AppBar(title:const Text('النسخ الاحتياطي')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Icon(Icons.cloud_done_outlined,size:54,color:color),
          const SizedBox(height:10),
          const Text('Google Drive',textAlign:TextAlign.center,style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          Text(account.isEmpty?'لم يتم ربط نسخة Google Drive بعد':account,textAlign:TextAlign.center,style:const TextStyle(color:Colors.grey)),
          if (driveName.isNotEmpty) ...[
            const SizedBox(height:4),
            Text('${driveProvider.isEmpty ? 'Google Drive' : driveProvider}: $driveName',textAlign:TextAlign.center,style:const TextStyle(fontSize:12,color:Colors.grey)),
          ],
          const SizedBox(height:16),
          FilledButton.icon(onPressed:busy?null:_connect,icon:const Icon(Icons.login),label:Text(account.isEmpty?'ربط Google Drive وتحديث النسخة':'تغيير ملف/حساب Google Drive')),
          if(account.isNotEmpty)...[
            const SizedBox(height:8),
            OutlinedButton.icon(onPressed:busy?null:_disconnect,icon:const Icon(Icons.link_off),label:const Text('فصل الحساب'))
          ]
        ]))),
        const SizedBox(height:12),
        Card(child:Column(children:[
          ListTile(onTap:busy?null:_saveLocal,leading:const Icon(Icons.save_alt),title:const Text('حفظ نسخة احتياطية محلية الآن'),subtitle:const Text('حفظ ملف JSON في المكان الذي تختاره'),trailing:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.chevron_left)),
          const Divider(height:1),
          ListTile(onTap:busy?null:_restoreLocal,leading:const Icon(Icons.restore),title:const Text('استعادة نسخة احتياطية من الهاتف'),subtitle:const Text('اختر الاستبدال أو الدمج بأمان'),trailing:const Icon(Icons.chevron_left)),
          const Divider(height:1),
          ListTile(onTap:busy?null:_restoreDrive,leading:const Icon(Icons.cloud_download_outlined),title:const Text('استعادة من Google Drive'),subtitle:const Text('اختر النسخة من Drive ثم استبدال أو دمج البيانات'),trailing:const Icon(Icons.chevron_left)),
          const Divider(height:1),
          SwitchListTile(value:auto,onChanged:account.isEmpty?null:(v)async{await ref.read(repositoryProvider).setSetting('backup_auto',v?'1':'0');if(mounted)setState(()=>auto=v);await ref.read(backupCoordinatorProvider).scheduleAutoBackup(); if(v)await ref.read(backupCoordinatorProvider).checkAndBackup();},title:const Text('النسخ الاحتياطي التلقائي'),subtitle:Text('يعمل يوميًا في الوقت المحدد: $backupTime'),secondary:const Icon(Icons.autorenew)),
          const Divider(height:1),
          ListTile(onTap:account.isEmpty?null:_chooseTime,leading:const Icon(Icons.schedule),title:const Text('وقت النسخ الاحتياطي'),subtitle:Text(backupTime),trailing:const Icon(Icons.chevron_left)),
          const Divider(height:1),
          ListTile(onTap:busy?null:_backupNow,leading:const Icon(Icons.backup_outlined),title:const Text('نسخ Google Drive الآن'),subtitle:Text('تحديث النسخة المحلية ونسخة Google Drive المرتبطة\n$_lastText()'),trailing:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.chevron_left)),
        ])),
        const SizedBox(height:12),
        Card(child:ListTile(leading:Icon(lastStatus=='failure'?Icons.error_outline:Icons.verified_outlined,color:lastStatus=='failure'?Colors.red:color),title:Text(lastStatus=='failure'?'آخر محاولة فشلت':lastStatus=='success'?'آخر نسخة ناجحة':lastStatus=='restored'?'تمت الاستعادة':'حالة النسخ الاحتياطي'),subtitle:Text(lastStatus=='failure'?(lastError.isEmpty?'ستتم إعادة المحاولة عند توفر الاتصال.':lastError):_lastText()))),
      ]),
    );
  }
}
