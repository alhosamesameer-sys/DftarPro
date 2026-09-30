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

class _StatementsPageState extends ConsumerState<StatementsPage> {
  static const _pageSize = 200;
  final _scroll = ScrollController();
  List<TransactionItem> items=[];
  DateTime? from,to;
  bool loading=true, loadingMore=false, hasMore=true;
  int offset=0;

  @override void initState(){super.initState();_scroll.addListener(_onScroll);_load(reset:true);}
  @override void dispose(){_scroll.dispose();super.dispose();}

  Future<void> _load({required bool reset}) async {
    if(loadingMore && !reset)return;
    if(reset){setState((){loading=true;offset=0;hasMore=true;items=[];});}else{setState(()=>loadingMore=true);}
    try{
      final batch=await ref.read(repositoryProvider).transactions(accountId:widget.accountId,limit:_pageSize,offset:reset?0:offset,from:from,to:to);
      if(!mounted)return;
      setState((){
        if(reset)items=batch;else items.addAll(batch);
        offset=(reset?0:offset)+batch.length;
        hasMore=batch.length==_pageSize;
        loading=false;loadingMore=false;
      });
    }catch(e){if(mounted)setState((){loading=false;loadingMore=false;});}
  }

  void _onScroll(){if(_scroll.position.pixels>=_scroll.position.maxScrollExtent-500&&hasMore&&!loading&&!loadingMore)_load(reset:false);}

  Future<void> _pickRange() async {
    final range=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDateRange:from!=null&&to!=null?DateTimeRange(start:from!,end:to!):null);
    if(range==null)return;
    setState((){from=DateTime(range.start.year,range.start.month,range.start.day);to=DateTime(range.end.year,range.end.month,range.end.day);});
    await _load(reset:true);
  }

  Future<void> _clearRange() async {if(from==null&&to==null)return;setState((){from=null;to=null;});await _load(reset:true);}

  Future<List<TransactionItem>> _loadAllForExport() async {
    final all=<TransactionItem>[];var page=0;
    while(true){
      final batch=await ref.read(repositoryProvider).transactions(accountId:widget.accountId,limit:1000,offset:page,from:from,to:to);
      all.addAll(batch);if(batch.length<1000)break;page+=batch.length;
    }
    return all;
  }

  @override Widget build(BuildContext context){
    final accountAsync=ref.watch(accountProvider(widget.accountId));
    final baseAsync=ref.watch(baseCurrencyProvider);
    return Scaffold(body:SafeArea(child:accountAsync.when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(e,s)=>Center(child:Text('$e')),
      data:(account){
        if(account==null)return const Center(child:Text('الحساب غير موجود'));
        return baseAsync.when(
          loading:()=>const Center(child:CircularProgressIndicator()),
          error:(e,s)=>Center(child:Text('$e')),
          data:(base)=>_content(context,account,base),
        );
      },
    )));
  }

  Widget _content(BuildContext context,Account account,String base){
    return FutureBuilder<Map<String,double>>(
      future:ref.read(repositoryProvider).accountBaseTotals(widget.accountId,base),
      builder:(context,snap){
        final totals=snap.data??{'credit':0.0,'debit':0.0,'net':0.0};
        final credit=totals['credit']??0,debit=totals['debit']??0,net=totals['net']??0;
        return NotificationListener<ScrollNotification>(
          onNotification:(_)=>false,
          child:ListView(controller:_scroll,padding:const EdgeInsets.all(16),children:[
            AppHeader(title:'كشف حساب'),
            Card(child:ListTile(leading:AccountAvatar(name:account.name),title:Text(account.name),subtitle:Text(account.phone))),
            Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
              Text('إجمالي له: ${money(credit,base)}'),
              Text('إجمالي عليه: ${money(debit,base)}'),
              Text('الصافي: ${money(net.abs(),base)} ${net>=0?'له':'عليه'}',style:const TextStyle(fontWeight:FontWeight.bold)),
            ]))),
            Row(children:[
              Expanded(child:OutlinedButton.icon(onPressed:()=>_pickRange(),icon:const Icon(Icons.date_range),label:Text(from==null?'فلترة بالتاريخ':'${dateAr(from!)} - ${dateAr(to!)}'))),
              if(from!=null)const SizedBox(width:8),
              if(from!=null)IconButton(onPressed:_clearRange,tooltip:'مسح الفلترة',icon:const Icon(Icons.clear)),
            ]),
            const SizedBox(height:8),
            Row(children:[
              Expanded(child:OutlinedButton.icon(onPressed:()async{final all=await _loadAllForExport();final p=await ref.read(repositoryProvider).userProfile();await ref.read(pdfProvider).printStatement(account,all,net,profile:p);},icon:const Icon(Icons.print),label:const Text('طباعة'))),
              const SizedBox(width:8),
              Expanded(child:OutlinedButton.icon(onPressed:()async{final all=await _loadAllForExport();final p=await ref.read(repositoryProvider).userProfile();await ref.read(pdfProvider).share(account,all,net,profile:p);},icon:const Icon(Icons.picture_as_pdf),label:const Text('PDF'))),
            ]),
            const SizedBox(height:8),
            FilledButton.icon(onPressed:()async{final all=await _loadAllForExport();final p=await ref.read(repositoryProvider).userProfile();await ref.read(pdfProvider).shareWord(account,all,net,p);},icon:const Icon(Icons.description),label:const Text('Word')),
            const SizedBox(height:8),
            FilledButton.icon(onPressed:()async{final all=await _loadAllForExport();final b=StringBuffer('كشف حساب ${account.name}\n');b.writeln('الصافي: ${money(net,base)}');for(final x in all)b.writeln('${dateAr(x.date)} - ${x.type=='credit'?'له':'عليه'}: ${money(x.amount,x.currency)} = ${money(x.baseAmount,x.baseCurrency)}');await SharePlus.instance.share(ShareParams(text:b.toString()));},icon:const Icon(Icons.share),label:const Text('مشاركة كنص')),
            const SizedBox(height:16),
            SectionTitle(title:'سجل العمليات (${items.length}${hasMore?' +':''})'),
            if(loading)const Padding(padding:EdgeInsets.all(28),child:Center(child:CircularProgressIndicator())),
            if(!loading&&items.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('لا توجد عمليات في الفترة المحددة.'))),
            ...items.map((x)=>Card(child:ListTile(title:Text(x.note.isEmpty?x.category:x.note),subtitle:Text('${dateAr(x.date)} • ${formatAmount(x.amount,x.currency)} ${currencyName(x.currency)} = ${formatAmount(x.baseAmount,x.baseCurrency)} ${currencyName(x.baseCurrency)}'),trailing:Text(x.type=='credit'?'له':x.type=='debit'?'عليه':'دفع')))),
            if(loadingMore)const Padding(padding:EdgeInsets.all(16),child:Center(child:CircularProgressIndicator())),
          ]),
        );
      },
    );
  }
}
