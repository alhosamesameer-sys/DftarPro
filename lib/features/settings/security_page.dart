import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

class SecuritySettingsPage extends ConsumerStatefulWidget{
  const SecuritySettingsPage({super.key});
  @override ConsumerState<SecuritySettingsPage> createState()=>_SecuritySettingsPageState();
}
class _SecuritySettingsPageState extends ConsumerState<SecuritySettingsPage>{
  bool pin=false,biometric=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{final s=ref.read(securityProvider);final p=await s.hasPin();final b=(await ref.read(repositoryProvider).getSetting('biometric_enabled')??'0')=='1';if(mounted)setState((){pin=p;biometric=b;});}
  Future<void> _pin()async{final ok=await showDialog<bool>(context:context,builder:(_)=>const _PinDialog());if(ok==true)await _load();}
  Future<void> _bio(bool value)async{if(!pin)return;setState(()=>biometric=value);await ref.read(repositoryProvider).setSetting('biometric_enabled',value?'1':'0');}
  @override Widget build(BuildContext context)=>Scaffold(appBar:const AppHeader(title:'خيارات الأمان'),body:ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:ListTile(onTap:_pin,leading:const Icon(Icons.password),title:Text(pin?'تغيير رمز PIN':'إضافة رمز PIN'),trailing:const Icon(Icons.chevron_left))),
    Card(child:SwitchListTile(value:biometric,onChanged:_bio,secondary:const Icon(Icons.fingerprint),title:const Text('تفعيل البصمة'),subtitle:const Text('يتطلب تفعيل PIN أولاً'))),
  ]));
}
class _PinDialog extends ConsumerStatefulWidget{const _PinDialog();@override ConsumerState<_PinDialog> createState()=>_PinDialogState();}
class _PinDialogState extends ConsumerState<_PinDialog>{
  final pin=TextEditingController(),confirm=TextEditingController();
  String error='';
  @override void dispose(){pin.dispose();confirm.dispose();super.dispose();}
  Future<void> _save()async{if(!RegExp(r'^\d{6}$').hasMatch(pin.text)||pin.text!=confirm.text){setState(()=>error='أدخل PIN من 6 أرقام متطابقة');return;}await ref.read(securityProvider).setPin(pin.text);if(mounted)Navigator.pop(context,true);}
  @override Widget build(BuildContext context)=>AlertDialog(title:const Text('إضافة رمز PIN'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:pin,maxLength:6,obscureText:true,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'PIN',errorText:error.isEmpty?null:error)),TextField(controller:confirm,maxLength:6,obscureText:true,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'تأكيد PIN'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:_save,child:const Text('حفظ'))]);
}