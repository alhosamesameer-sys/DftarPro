import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/widgets.dart';

class MorePage extends StatelessWidget{
  const MorePage({super.key});
  @override
  Widget build(BuildContext context){
    return ListView(
      padding:const EdgeInsets.fromLTRB(16,10,16,90),
      children:[
        AppHeader(title:'المزيد'),
        Card(child:Column(children:[
          _item(context,'العملات وأسعار الصرف',Icons.currency_exchange,'/currencies'),
          _item(context,'الحاسبة',Icons.calculate_outlined,'/calculator'),
          _item(context,'البحث المتقدم',Icons.search,'/search'),
          _item(context,'النسخ الاحتياطي',Icons.cloud_outlined,'/backup'),
          _item(context,'الإعدادات',Icons.settings_outlined,'/settings'),
        ])),
        const SizedBox(height:16),
        SectionTitle(title:'التطبيق والدعم'),
        Card(child:Column(children:[
          ListTile(onTap:()=>GoRouter.of(context).push('/support'),leading:const Icon(Icons.support_agent_outlined),title:const Text('التواصل والدعم'),trailing:const Icon(Icons.chevron_left)),
          const Divider(height:1),
          ListTile(onTap:()=>showAboutDialog(context:context,applicationName:'دفتر Pro',applicationVersion:'1.0.0'),leading:const Icon(Icons.info_outline),title:const Text('حول البرنامج'),trailing:const Icon(Icons.chevron_left)),
          const Divider(height:1),
          ListTile(onTap:()=>SharePlus.instance.share(ShareParams(text:'دفتر Pro - تطبيق عربي لإدارة الحسابات والدفاتر والعمليات والعملات.')),leading:const Icon(Icons.share_outlined),title:const Text('مشاركة التطبيق'),trailing:const Icon(Icons.chevron_left)),
        ])),
      ],
    );
  }
  static Widget _item(BuildContext c,String title,IconData icon,String route)=>ListTile(onTap:()=>GoRouter.of(c).push(route),leading:Icon(icon,color:Theme.of(c).colorScheme.primary),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),trailing:const Icon(Icons.chevron_left));
}
