import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

class StatementsPage extends ConsumerStatefulWidget {
  final String accountId;
  const StatementsPage({super.key, required this.accountId});
  @override ConsumerState<StatementsPage> createState()=>_StatementsPageState();
}
class _StatementsPageState extends ConsumerState<StatementsPage>{
  List<TransactionItem> items=[]; DateTime? from,to; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{setState(()=>loading=true);final rows=await ref.read(repositoryProvider).transactions(accountId:widget.accountId,limit:1000,from:from,to:to);if(mounted)setState((){items=rows;loading=false;});}
  Future<void> _range()async{final r=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDateRange:from!=null&&to!=null?DateTimeRange(start:from!,end:to!):null);if(r!=null){from=DateTime(r.start.year,r.start.month,r.start.day);to=DateTime(r.end.year,r.end.month,r.end.day);await _load();}}
  @override Widget build(BuildContext context){final account=ref.watch(accountProvider(widget.accountId));final base=ref.watch(baseCurrencyProvider).asData?.value??'YER';return Scaffold(body:SafeArea(child:account.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,s)=>Center(child:Text('$e')),data:(a){if(a==null)return const Center(child:Text('الحساب غير موجود'));final net=items.fold<double>(0,(v,x)=>v+(x.type=='credit'?x.baseAmount:-x.baseAmount));return ListView(padding:const EdgeInsets.all(16),children:[const AppHeader(title:'كشف حساب'),Card(child:ListTile(leading:AccountAvatar(name:a.name),title:Text(a.name),subtitle:Text(a.phone))),Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('الصافي: ${money(net.abs(),base)} ${net>=0?'له':'عليه'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)))),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_range,icon:const Icon(Icons.date_range),label:const Text('فلترة بالتاريخ'))),const SizedBox(width:8),IconButton(onPressed:(){from=null;to=null;_load();},icon:const Icon(Icons.clear))]),const SizedBox(height:8),FilledButton.icon(onPressed:()async{final b=StringBuffer('كشف حساب ${a.name}\nالصافي: ${money(net,base)}\n');for(final x in items){b.writeln('${dateAr(x.date)} - ${x.type=='credit'?'له':'عليه'}: ${money(x.amount,x.currency)}');}await SharePlus.instance.share(ShareParams(text:b.toString()));},icon:const Icon(Icons.share),label:const Text('مشاركة')),const SizedBox(height:12),SectionTitle(title:'العمليات (${items.length})'),if(loading)const Center(child:CircularProgressIndicator()),...items.map((x)=>Card(child:ListTile(title:Text(x.note.isEmpty?x.category:x.note),subtitle:Text('${dateAr(x.date)} • ${formatAmount(x.amount,x.currency)} ${currencyName(x.currency)}'),trailing:Text(x.type=='credit'?'له':'عليه'))))];}))));}
}
