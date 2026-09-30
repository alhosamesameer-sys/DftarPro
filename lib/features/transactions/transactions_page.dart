import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets.dart';

class TransactionsPage extends ConsumerStatefulWidget{
 const TransactionsPage({super.key});
 @override ConsumerState<TransactionsPage> createState()=>_TransactionsPageState();
}
class _TransactionsPageState extends ConsumerState<TransactionsPage>{
 final search=TextEditingController();
 @override void dispose(){search.dispose();super.dispose();}
 Future<void> _delete(String id,String accountId)async{
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف العملية'),content:const Text('هل تريد حذف العملية؟'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف'))]))??false;
  if(!ok)return;await ref.read(repositoryProvider).deleteTransaction(id);ref.invalidate(transactionsProvider(null));ref.invalidate(transactionsProvider(accountId));ref.invalidate(accountProvider(accountId));ref.invalidate(accountsProvider(''));ref.invalidate(dashboardProvider);
 }
 @override Widget build(BuildContext context){
  final data=ref.watch(transactionsProvider(null));
  return Column(children:[
   const AppHeader(title:'العمليات',back:false),
   Padding(padding:const EdgeInsets.all(16),child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'بحث'))),
   Expanded(child:data.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,s)=>Center(child:Text(e.toString())),data:(all){
    final q=search.text.trim().toLowerCase();
    final items=q.isEmpty?all:all.where((x)=>(x.amount.toString()+' '+x.currency+' '+x.category+' '+x.note).toLowerCase().contains(q)).toList();
    if(items.isEmpty)return const EmptyState(title:'لا توجد عمليات',subtitle:'أضف أول عملية مالية.');
    return ListView.separated(padding:const EdgeInsets.fromLTRB(16,0,16,90),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){
     final x=items[i];final positive=x.type=='credit';
     return Card(child:ListTile(
      onTap:()=>showModalBottomSheet(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
       ListTile(title:Text('عملية '+x.amount.toStringAsFixed(2)+' '+x.currency),subtitle:Text(dateAr(x.date))),
       ListTile(leading:const Icon(Icons.edit),title:const Text('تعديل'),onTap:(){Navigator.pop(c);context.push('/edit-transaction/'+x.id);}),
       ListTile(leading:const Icon(Icons.delete,color:Colors.red),title:const Text('حذف'),onTap:(){Navigator.pop(c);_delete(x.id,x.accountId);}),
      ]))),
      leading:Icon(positive?Icons.arrow_downward:Icons.arrow_upward,color:positive?Colors.green:Colors.red),
      title:Text(x.note.isEmpty?x.category:x.note),subtitle:Text(dateAr(x.date)),trailing:MoneyAmount(value:x.amount,currency:x.currency,positive:positive)));
    });
   })),
  ]);
 }
}