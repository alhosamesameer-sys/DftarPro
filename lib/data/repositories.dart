import 'dart:convert';
import '../domain/models.dart';
import 'app_database.dart';
import 'app_database_extensions.dart';

class LedgerRepository {
  final AppDatabase db;
  const LedgerRepository(this.db);
  Future<List<Account>> accounts({String query='',String? type}) async {
    final list=await db.accounts(query:query,type:type);
    final sort=await db.getSetting('accounts_sort')??'updated_desc';
    if(sort=='name_asc')list.sort((a,b)=>a.name.compareTo(b.name));
    if(sort=='name_desc')list.sort((a,b)=>b.name.compareTo(a.name));
    return list;
  }
  Future<Account?> account(String id)=>db.account(id);
  Future<String> saveAccount({String? id,required String name,String phone='',String company='',String address='',String notes='',required String type,required String currency})=>db.saveAccount(id:id,name:name,phone:phone,company:company,address:address,notes:notes,type:type,currency:currency);
  Future<void> deleteAccount(String id)=>db.deleteAccount(id);
  Future<List<TransactionItem>> transactions({String? accountId,String query='',int limit=200,int offset=0,DateTime? from,DateTime? to})=>db.transactions(accountId:accountId,query:query,limit:limit,offset:offset,from:from,to:to);
  Future<double> balanceFor(String id,String currency)=>db.balanceFor(id,currency);
  Future<Map<String,double>> accountTotals(String id,String currency)=>db.accountTotals(id,currency);
  Future<Map<String,double>> accountBaseTotals(String id,String baseCurrency)=>db.accountBaseTotals(id,baseCurrency);
  Future<Map<String,double>> dashboardTotals(String currency)=>db.dashboardTotals(currency);
  Future<String> saveTransaction({required String accountId,required String type,required double amount,required String currency,double rate=1,required String category,DateTime? date,String note='',String? parentId}) async {
    final base=await db.getSetting('base_currency')??'YER';
    var effective=rate;
    if(currency!=base && (effective<=0 || effective==1)){
      final direct=await db.latestRate(currency,base);
      if(direct!=null&&direct>0) effective=direct;
      else {
        final reverse=await db.latestRate(base,currency);
        if(reverse!=null&&reverse>0) effective=1/reverse;
      }
    }
    return db.saveTransaction(accountId:accountId,type:type,amount:amount,currency:currency,rate:effective,category:category,date:date,note:note,parentId:parentId);
  }
  Future<TransactionItem?> transaction(String id) async { final database=await db.db; final rows=await database.query('transactions',where:'id=? AND deleted=0',whereArgs:[id],limit:1); return rows.isEmpty?null:TransactionItem.fromMap(rows.first); }
  Future<void> updateTransaction({required String id,required String accountId,required String type,required double amount,required String currency,required double rate,required String category,required DateTime date,required String note}) async {
    final database=await db.db;
    final base=await db.getSetting('base_currency')??'YER';
    var effective=rate;
    if(currency!=base && (effective<=0 || effective==1)){
      final direct=await db.latestRate(currency,base);
      if(direct!=null&&direct>0)effective=direct;
      else {
        final reverse=await db.latestRate(base,currency);
        if(reverse!=null&&reverse>0)effective=1/reverse;
      }
    }
    if(currency==base)effective=1;
    await database.update('transactions',{'account_id':accountId,'type':type,'amount':amount,'currency':currency,'base_amount':amount*effective,'base_currency':base,'exchange_rate':effective,'category':category,'date':date.millisecondsSinceEpoch,'updated_at':DateTime.now().millisecondsSinceEpoch,'note':note},where:'id=?',whereArgs:[id]);
  }
  Future<void> deleteTransaction(String id) async { final database=await db.db; await database.update('transactions',{'deleted':1,'updated_at':DateTime.now().millisecondsSinceEpoch},where:'id=?',whereArgs:[id]); }
  Future<void> addAttachment(String transactionId,String path,String name,String mime,int size)=>db.addAttachment(transactionId,path,name,mime,size);
  Future<List<CurrencyModel>> currencies()=>db.currencies();
  Future<void> setBaseCurrency(String code)=>db.setBaseCurrency(code);
  Future<void> addCurrency(String code,String name,String symbol,int decimals)=>db.addCurrency(code,name,symbol,decimals);
  Future<void> saveRate(String from,String to,double rate)=>db.saveRate(from,to,rate);
  Future<double?> latestRate(String from,String to)async{if(from==to)return 1;final direct=await db.latestRate(from,to);if(direct!=null)return direct;final reverse=await db.latestRate(to,from);return reverse==null?null:1/reverse;}
  Future<void> saveInvoice({required String number,required String accountId,required double total,required double paid,required String currency,String notes=''})=>db.saveInvoice(number:number,accountId:accountId,total:total,paid:paid,currency:currency,notes:notes);
  Future<List<Invoice>> invoices()=>db.invoices();
  Future<String?> getSetting(String key)=>db.getSetting(key);
  Future<void> setSetting(String key,String value)=>db.setSetting(key,value);
  Future<Map<String,String>> userProfile()=>db.userProfile();
  Future<List<String>> transactionCategories()=>db.transactionCategories();
  Future<void> addTransactionCategory(String value)=>db.addTransactionCategory(value);
  Future<void> removeTransactionCategory(String value)=>db.removeTransactionCategory(value);
  Future<void> deleteAllLedgerData()=>db.deleteAllLedgerData();
  Future<Map<String,Object?>> exportData()=>db.exportData();
  Future<void> importData(Map<String,dynamic> data,{bool merge=false})=>db.importData(data,merge:merge);
}