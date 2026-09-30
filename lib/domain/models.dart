class Account {
  final String id, name, phone, companyName, address, notes, type, currency, image;
  final DateTime createdAt, updatedAt;
  final bool archived;
  const Account({required this.id,required this.name,this.phone='',this.companyName='',this.address='',this.notes='',this.type='customer',this.currency='YER',this.image='',required this.createdAt,required this.updatedAt,this.archived=false});
  factory Account.fromMap(Map<String,Object?> m)=>Account(id:m['id'] as String,name:m['name'] as String,phone:(m['phone'] as String?)??'',companyName:(m['company_name'] as String?)??'',address:(m['address'] as String?)??'',notes:(m['notes'] as String?)??'',type:(m['account_type'] as String?)??'customer',currency:(m['currency'] as String?)??'YER',image:(m['image'] as String?)??'',createdAt:DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num?)?.toInt()??0),updatedAt:DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as num?)?.toInt()??0),archived:(m['archived'] as int? ?? 0)==1);
}
class TransactionItem {
  final String id,accountId,type,currency,baseCurrency,category,note,status,source;
  final double amount,baseAmount,exchangeRate;
  final DateTime date;
  final String? parentId;
  const TransactionItem({required this.id,required this.accountId,required this.type,required this.amount,required this.currency,required this.baseAmount,required this.baseCurrency,required this.exchangeRate,required this.category,required this.date,required this.note,this.status='accepted',this.source='local',this.parentId});
  factory TransactionItem.fromMap(Map<String,Object?> m)=>TransactionItem(id:m['id'] as String,accountId:m['account_id'] as String,type:m['type'] as String,amount:(m['amount'] as num).toDouble(),currency:m['currency'] as String,baseAmount:(m['base_amount'] as num).toDouble(),baseCurrency:m['base_currency'] as String,exchangeRate:(m['exchange_rate'] as num).toDouble(),category:(m['category'] as String?)??'عملية',date:DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),note:(m['note'] as String?)??'',status:(m['status'] as String?)??'accepted',source:(m['source'] as String?)??'local',parentId:m['parent_id'] as String?);
}
class CurrencyModel {
  final String code,name,symbol;
  final int decimals;
  final bool base;
  const CurrencyModel({required this.code,required this.name,required this.symbol,this.decimals=2,this.base=false});
  factory CurrencyModel.fromMap(Map<String,Object?> m)=>CurrencyModel(code:m['code'] as String,name:(m['name'] as String?)??m['code'] as String,symbol:(m['symbol'] as String?)??m['code'] as String,decimals:(m['decimals'] as num?)?.toInt()??2,base:(m['is_base'] as int? ?? 0)==1);
}
class Invoice {
  final String id,number,accountId,currency,notes;
  final DateTime date;
  final double total,paid;
  const Invoice({required this.id,required this.number,required this.accountId,required this.date,required this.total,required this.paid,required this.currency,this.notes=''});
  double get remaining=>total-paid;
  factory Invoice.fromMap(Map<String,Object?> m)=>Invoice(id:m['id'] as String,number:(m['number'] as String?)??'',accountId:m['account_id'] as String,date:DateTime.fromMillisecondsSinceEpoch((m['date'] as num).toInt()),total:(m['total'] as num).toDouble(),paid:(m['paid'] as num).toDouble(),currency:(m['currency'] as String?)??'YER',notes:(m['notes'] as String?)??'');
}