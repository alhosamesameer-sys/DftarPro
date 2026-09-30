class CalculatorEngine {
  static double? evaluate(String source) {
    final s=source.replaceAll('×','*').replaceAll('÷','/').replaceAll(' ','');
    if(s.isEmpty)return null;
    final tokens=<String>[];final buffer=StringBuffer();bool unary=true;
    for(int i=0;i<s.length;i++){
      final c=s[i];
      if(RegExp(r'[0-9.]').hasMatch(c)){buffer.write(c);unary=false;continue;}
      if(c=='-'&&unary){buffer.write('-');unary=false;continue;}
      if('+-*/()'.contains(c)){
        if(buffer.isNotEmpty){tokens.add(buffer.toString());buffer.clear();}
        if(c=='(')unary=true;else if(c==')')unary=false;else unary=true;
        tokens.add(c);
      }else{return null;}
    }
    if(buffer.isNotEmpty)tokens.add(buffer.toString());
    if(tokens.isEmpty)return null;
    final output=<String>[];final ops=<String>[];
    int prec(String op)=>op=='+'||op=='-'?1:2;
    bool isOp(String x)=>x=='+'||x=='-'||x=='*'||x=='/';
    for(final t in tokens){
      if(double.tryParse(t)!=null){output.add(t);continue;}
      if(t=='('){ops.add(t);continue;}
      if(t==')'){while(ops.isNotEmpty&&ops.last!='(')output.add(ops.removeLast());if(ops.isEmpty)return null;ops.removeLast();continue;}
      if(isOp(t)){while(ops.isNotEmpty&&isOp(ops.last)&&prec(ops.last)>=prec(t))output.add(ops.removeLast());ops.add(t);continue;}
      return null;
    }
    while(ops.isNotEmpty){if(ops.last=='(')return null;output.add(ops.removeLast());}
    final stack=<double>[];
    for(final t in output){final n=double.tryParse(t);if(n!=null){stack.add(n);continue;}if(stack.length<2)return null;final b=stack.removeLast(),a=stack.removeLast();switch(t){case '+':stack.add(a+b);break;case '-':stack.add(a-b);break;case '*':stack.add(a*b);break;case '/':if(b==0)return null;stack.add(a/b);break;default:return null;}}
    return stack.length==1&&stack.single.isFinite?stack.single:null;
  }
}