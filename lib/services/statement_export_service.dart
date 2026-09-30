import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/models.dart';

class StatementExportService {
  Future<File> _file(Account account,List<TransactionItem> items,double balance,Map<String,String> profile) async {
    final dir=await getTemporaryDirectory();
    final file=File('${dir.path}/statement_${account.id}.txt');
    final b=StringBuffer();
    b.writeln(profile['user_name']??'دفتر Pro'); b.writeln('كشف حساب: ${account.name}'); b.writeln('الرصيد: ${balance.toStringAsFixed(2)}'); b.writeln('');
    for(final x in items){b.writeln('${x.date.toIso8601String()} | ${x.type} | ${x.amount} ${x.currency} | ${x.note.isEmpty?x.category:x.note}');}
    await file.writeAsString(b.toString(),encoding:utf8,flush:true); return file;
  }
  Future<void> share(Account account,List<TransactionItem> items,double balance,{required Map<String,String> profile}) async {
    final f=await _file(account,items,balance,profile);
    await SharePlus.instance.share(ShareParams(files:[XFile(f.path,mimeType:'text/plain')],text:'كشف حساب ${account.name}'));
  }
  Future<void> printStatement(Account account,List<TransactionItem> items,double balance,{required Map<String,String> profile}) async {
    await share(account,items,balance,profile:profile);
  }
  Future<void> shareWord(Account account,List<TransactionItem> items,double balance,Map<String,String> profile) async {
    await share(account,items,balance,profile:profile);
  }
}
