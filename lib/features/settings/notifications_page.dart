import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});
  @override ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}
class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  final top = TextEditingController(), bottom = TextEditingController();
  bool header=true, footer=true, autoWhatsapp=false, date=true, whatsappBusiness=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final r=ref.read(repositoryProvider); top.text=await r.getSetting('statement_message_top')??''; bottom.text=await r.getSetting('statement_message_bottom')??''; header=(await r.getSetting('statement_message_header')??'1')=='1'; footer=(await r.getSetting('statement_message_footer')??'1')=='1'; autoWhatsapp=(await r.getSetting('whatsapp_auto')??'0')=='1'; date=(await r.getSetting('whatsapp_date')??'1')=='1'; whatsappBusiness=(await r.getSetting('whatsapp_business')??'0')=='1'; if(mounted)setState((){});}
  Future<void> _save() async {final r=ref.read(repositoryProvider);await r.setSetting('statement_message_top',top.text.trim());await r.setSetting('statement_message_bottom',bottom.text.trim());await r.setSetting('statement_message_header',header?'1':'0');await r.setSetting('statement_message_footer',footer?'1':'0');await r.setSetting('whatsapp_auto',autoWhatsapp?'1':'0');await r.setSetting('whatsapp_date',date?'1':'0');await r.setSetting('whatsapp_business',whatsappBusiness?'1':'0');if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم حفظ إعدادات الرسائل ✓')));}
  @override void dispose(){top.dispose();bottom.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:const AppHeader(title:'الإشعارات والرسائل'),body:ListView(padding:const EdgeInsets.all(16),children:[
    const SectionTitle(title:'رسالة كشف الحساب'),
    TextField(controller:top,maxLines:3,decoration:const InputDecoration(labelText:'النص أعلى الرسالة')),
    const SizedBox(height:10),TextField(controller:bottom,maxLines:3,decoration:const InputDecoration(labelText:'النص أسفل الرسالة')),
    Card(child:Column(children:[SwitchListTile(value:header,onChanged:(v)=>setState(()=>header=v),title:const Text('إظهار مقدمة الكشف')),const Divider(height:1),SwitchListTile(value:footer,onChanged:(v)=>setState(()=>footer=v),title:const Text('إظهار نهاية الكشف'))])),
    const SizedBox(height:14),const SectionTitle(title:'واتساب عند إضافة عملية'),
    Card(child:Column(children:[SwitchListTile(value:autoWhatsapp,onChanged:(v)=>setState(()=>autoWhatsapp=v),title:const Text('فتح رسالة واتساب تلقائيًا')),const Divider(height:1),SwitchListTile(value:whatsappBusiness,onChanged:autoWhatsapp?(v)=>setState(()=>whatsappBusiness=v):null,title:const Text('استخدام واتساب للأعمال')),const Divider(height:1),SwitchListTile(value:date,onChanged:(v)=>setState(()=>date=v),title:const Text('إظهار تاريخ العملية'))])),
    const SizedBox(height:18),PrimaryButton(label:'حفظ الإعدادات',icon:Icons.save,onPressed:_save),
  ]));
}