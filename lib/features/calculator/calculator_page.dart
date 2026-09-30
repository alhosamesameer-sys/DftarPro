import 'package:flutter/material.dart';
import '../../core/utils/calculator_engine.dart';
import '../../shared/widgets.dart';

class CalculatorPage extends StatefulWidget { const CalculatorPage({super.key}); @override State<CalculatorPage> createState()=>_CalculatorPageState(); }
class _CalculatorPageState extends State<CalculatorPage>{
  String expr='';double? result;String? error;
  void press(String x){setState((){if(x=='='){result=CalculatorEngine.evaluate(expr);error=result==null?'تعبير غير صالح أو قسمة على صفر':null;}else if(x=='C'){expr='';result=null;error=null;}else{expr+=x;result=null;error=null;}});}
  @override Widget build(BuildContext context)=>Scaffold(appBar:const AppHeader(title:'حاسبة داخل التطبيق'),body:ListView(padding:const EdgeInsets.all(16),children:[Card(color:Theme.of(context).colorScheme.primary,child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(expr.isEmpty?'0':expr,style:const TextStyle(color:Colors.white70,fontSize:20)),const SizedBox(height:6),Text(error??(result==null?'':'= ${result!.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'),'').replaceFirst(RegExp(r'\.0+$'), '')}'),style:TextStyle(color:error==null?Colors.white:Colors.orange,fontSize:24,fontWeight:FontWeight.w900))]))),const SizedBox(height:16),GridView.count(shrinkWrap:true,crossAxisCount:4,mainAxisSpacing:8,crossAxisSpacing:8,childAspectRatio:1.2,children:['7','8','9','÷','4','5','6','×','1','2','3','-','0','.','+','=','C'].map((x)=>FilledButton.tonal(onPressed:()=>press(x),child:Text(x,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)))).toList())]));
}