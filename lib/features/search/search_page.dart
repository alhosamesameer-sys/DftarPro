import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets.dart';
class SearchPage extends ConsumerStatefulWidget{const SearchPage({super.key});@override ConsumerState<SearchPage> createState()=>_SearchPageState();}
class _SearchPageState extends ConsumerState<SearchPage>{
  final q=TextEditingController();
  @override void dispose(){q.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:const AppHeader(title:'البحث المتقدم'),body:ListView(padding:const EdgeInsets.all(16),children:[
    TextField(controller:q,onChanged:(_)=>setState((){}),autofocus:true,decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'ابحث عن اسم، هاتف، مبلغ، وصف...')),const SizedBox(height:14),
    FutureBuilder(future:ref.read(repositoryProvider).accounts(query:q.text),builder:(c,s){if(!s.hasData)return const SizedBox.shrink();return Column(children:(s.data!).map((a)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(onTap:()=>context.push('/accounts/${a.id}'),leading:AccountAvatar(name:a.name),title:Text(a.name),subtitle:Text(a.phone),trailing:const Icon(Icons.chevron_left)))).toList());}),
    const SizedBox(height:12),
    FutureBuilder(future:ref.read(repositoryProvider).transactions(query:q.text),builder:(c,s){if(!s.hasData)return const SizedBox.shrink();return Column(children:(s.data!).map((t)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(title:Text(t.note.isEmpty?t.category:t.note),subtitle:Text('${dateAr(t.date)} • ${t.currency}'),trailing:MoneyAmount(value:t.amount,currency:t.currency,positive:t.type=='credit')))).toList());})
  ]));
}
