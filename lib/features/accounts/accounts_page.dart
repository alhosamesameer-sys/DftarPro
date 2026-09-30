import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

Future<String?> showAddAccountSheet(BuildContext context,WidgetRef ref,{String initialType='customer'}) async {
 final name=TextEditingController(),phone=TextEditingController(),address=TextEditingController(); var type=initialType; final currencies=await ref.read(currenciesProvider.future); var currency=currencies.isNotEmpty?currencies.first.code:'YER';
 final result=await showModalBottomSheet<String>(context:context,isScrollControlled:true,builder:(c)=>Padding(padding:EdgeInsets.only(left:16,right:16,bottom:MediaQuery.of(c).viewInsets.bottom+16,top:16),child:StatefulBuilder(builder:(c,set)=>Column(mainAxisSize:MainAxisSize.min,children:[
 Text('إضافة حساب',style:Theme.of(c).textTheme.titleLarge),const SizedBox(height:12),
 TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم *')),TextField(controller:phone,decoration:const InputDecoration(labelText:'الهاتف')),TextField(controller:address,decoration:const InputDecoration(labelText:'العنوان')),
 DropdownButtonFormField<String>(initialValue:type,items:const[DropdownMenuItem(value:'customer',child:Text('عميل')),DropdownMenuItem(value:'supplier',child:Text('مورد'))],onChanged:(v){if(v!=null)set(()=>type=v);},decoration:const InputDecoration(labelText:'النوع')),
 DropdownButtonFormField<String>(initialValue:currency,items:currencies.map((x)=>DropdownMenuItem(value:x.code,child:Text(x.name))).toList(),onChanged:(v){if(v!=null)set(()=>currency=v);},decoration:const InputDecoration(labelText:'العملة')),
 const SizedBox(height:12),FilledButton(onPressed:()async{if(name.text.trim().isEmpty)return;final id=await ref.read(repositoryProvider).saveAccount(name:name.text.trim(),phone:phone.text.trim(),address:address.text.trim(),type:type,currency:currency);if(c.mounted)Navigator.pop(c,id);},child:const Text('حفظ'))
])));name.dispose();phone.dispose();address.dispose();return result;
}
class AccountsPage extends ConsumerWidget{const AccountsPage({super.key});@override Widget build(BuildContext context,WidgetRef ref){final data=ref.watch(accountsProvider(''));return Scaffold(body:SafeArea(child:data.when(loading:()=>const Center(child:CircularProgressIndicator()),error:(e,s)=>Center(child:Text('$e')),data:(items)=>ListView(padding:const EdgeInsets.fromLTRB(16,10,16,90),children:[const AppHeader(title:'الحسابات',back:false),FilledButton.icon(onPressed:()async{await showAddAccountSheet(context,ref);ref.invalidate(accountsProvider(''));},icon:const Icon(Icons.add),label:const Text('إضافة حساب')),const SizedBox(height:12),if(items.isEmpty)const EmptyState(title:'لا توجد حسابات',subtitle:'أضف أول عميل أو مورد.') else ...items.map((a)=>Card(child:ListTile(onTap:()=>context.push('/accounts/${a.id}'),leading:AccountAvatar(name:a.name),title:Text(a.name),subtitle:Text(a.phone.isEmpty?(a.type=='supplier'?'مورد':'عميل'):a.phone),trailing:const Icon(Icons.chevron_left))))]))));}}
