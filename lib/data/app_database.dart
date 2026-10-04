import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/models.dart';

class AppDatabase {
  Database? _db;
  final _uuid=const Uuid();
  Future<Database> get db async {
    if(_db!=null)return _db!;
    final dir=await getApplicationDocumentsDirectory();
    _db=await openDatabase(p.join(dir.path,'ledger_pro.db'),version:1,onCreate:(db,v)async{
      await db.execute('CREATE TABLE accounts(id TEXT PRIMARY KEY,name TEXT,phone TEXT,company_name TEXT,address TEXT,notes TEXT,account_type TEXT,currency TEXT,image TEXT,created_at INTEGER,updated_at INTEGER,archived INTEGER DEFAULT 0)');
      await db.execute('CREATE TABLE transactions(id TEXT PRIMARY KEY,account_id TEXT,type TEXT,amount REAL,currency TEXT,base_amount REAL,base_currency TEXT,exchange_rate REAL,category TEXT,date INTEGER,created_at INTEGER,updated_at INTEGER,note TEXT,status TEXT,source TEXT,parent_id TEXT,deleted INTEGER DEFAULT 0)');
      await db.execute('CREATE TABLE currencies(code TEXT PRIMARY KEY,name TEXT,symbol TEXT,decimals INTEGER,is_base INTEGER DEFAULT 0)');
      await db.execute('CREATE TABLE exchange_rates(id TEXT PRIMARY KEY,from_code TEXT,to_code TEXT,rate REAL,effective_at INTEGER)');
      await db.execute('CREATE TABLE invoices(id TEXT PRIMARY KEY,number TEXT,account_id TEXT,date INTEGER,total REAL,paid REAL,currency TEXT,notes TEXT)');
      await db.execute('CREATE TABLE invoice_items(id TEXT PRIMARY KEY,invoice_id TEXT,name TEXT,quantity REAL,price REAL,discount REAL,tax REAL)');
      await db.execute('CREATE TABLE attachments(id TEXT PRIMARY KEY,transaction_id TEXT,path TEXT,name TEXT,mime TEXT,size INTEGER,created_at INTEGER)');
      await db.execute('CREATE TABLE sync_queue(id TEXT PRIMARY KEY, entity_type TEXT, entity_id TEXT, action TEXT, payload TEXT, created_at INTEGER, retry_count INTEGER DEFAULT 0, status TEXT, last_error TEXT)');
      await db.execute('CREATE TABLE activity_log(id TEXT PRIMARY KEY,action TEXT,entity_id TEXT,description TEXT,created_at INTEGER)');
      await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)');
      await db.insert('currencies',{'code':'YER','name':'ريال يمني','symbol':'﷼','decimals':0,'is_base':1});
      await db.insert('currencies',{'code':'SAR','name':'ريال سعودي','symbol':'ر.س','decimals':2,'is_base':0});
      await db.insert('currencies',{'code':'USD','name':'دولار أمريكي','symbol':'\$','decimals':2,'is_base':0});
      await db.insert('settings',{'key':'base_currency','value':'YER'});
      await db.insert('settings',{'key':'user_name','value':'سمير الحسامي'});
      await db.insert('settings',{'key':'user_name_en','value':'Sameer Alhosami'});
      await db.insert('settings',{'key':'address_ar','value':'اليمن - تعز'});
      await db.insert('settings',{'key':'address_en','value':'Yemen - Taiz'});
      await db.insert('settings',{'key':'theme_mode','value':'light'});
    });
    return _db!;
  }
  Future<List<Account>> accounts({String query='',String? type}) async {
    final d=await db;
    final where=<String>[];
    final args=<Object?>[];
    if(query.trim().isNotEmpty){
      where.add('(name LIKE ? OR phone LIKE ? OR company_name LIKE ?)');
      final q='%${query.trim()}%';
      args.addAll([q,q,q]);
    }
    if(type!=null&&type!='all'){where.add('account_type=?');args.add(type);}
    final rows=await d.query('accounts',where:where.isEmpty?null:where.join(' AND '),whereArgs:args,orderBy:'updated_at DESC');
    return rows.map(Account.fromMap).toList();
  }
  Future<Account?> account(String id)async{final d=await db;final r=await d.query('accounts',where:'id=?',whereArgs:[id],limit:1);return r.isEmpty?null:Account.fromMap(r.first);}
  Future<String> saveAccount({String? id,required String name,String phone='',String company='',String address='',String notes='',required String type,required String currency,String? image})async{
    final d=await db;final now=DateTime.now().millisecondsSinceEpoch;final key=id??_uuid.v4();final values=<String,Object?>{'name':name,'phone':phone,'company_name':company,'address':address,'notes':notes,'account_type':type,'currency':currency,'image':image??'','updated_at':now};
    if(id==null){values['id']=key;values['created_at']=now;values['archived']=0;await d.insert('accounts',values);}else await d.update('accounts',values,where:'id=?',whereArgs:[id]);return key;
  }
  Future<void> deleteAccount(String id) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.delete('attachments', where: 'transaction_id IN (SELECT id FROM transactions WHERE account_id=?)', whereArgs: [id]);
      await txn.delete('invoice_items', where: 'invoice_id IN (SELECT id FROM invoices WHERE account_id=?)', whereArgs: [id]);
      await txn.delete('invoices', where: 'account_id=?', whereArgs: [id]);
      await txn.delete('transactions', where: 'account_id=?', whereArgs: [id]);
      await txn.delete('accounts', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<List<TransactionItem>> transactions({String? accountId,String query='',int limit=200,int offset=0,DateTime? from,DateTime? to})async{
    final d=await db;
    final where=<String>['deleted=0'];
    final args=<Object?>[];
    if(accountId!=null){where.add('account_id=?');args.add(accountId);}
    if(query.trim().isNotEmpty){where.add('(note LIKE ? OR category LIKE ?)');final q='%${query.trim()}%';args.addAll([q,q]);}
    if(from!=null){where.add('date>=?');args.add(DateTime(from.year,from.month,from.day).millisecondsSinceEpoch);}
    if(to!=null){where.add('date<?');args.add(DateTime(to.year,to.month,to.day+1).millisecondsSinceEpoch);}
    final rows=await d.query('transactions',where:where.join(' AND '),whereArgs:args,orderBy:'date DESC',limit:limit,offset:offset);
    return rows.map(TransactionItem.fromMap).toList();
  }
  Future<Map<String,double>> accountTotals(String id,String currency)async{
    final d=await db;
    final rows=await d.rawQuery('SELECT type,SUM(amount) total FROM transactions WHERE account_id=? AND currency=? AND deleted=0 GROUP BY type',[id,currency]);
    double credit=0,debit=0;
    for(final r in rows){final n=(r['total'] as num?)?.toDouble()??0;if(r['type']=='credit')credit=n;if(r['type']=='debit')debit=n;}
    return {'credit':credit,'debit':debit,'net':credit-debit};
  }
  Future<Map<String,double>> accountBaseTotals(String id,String currency)async{
    final d=await db;
    final rows=await d.rawQuery('SELECT type,SUM(base_amount) total FROM transactions WHERE account_id=? AND base_currency=? AND deleted=0 GROUP BY type',[id,currency]);
    double credit=0,debit=0;
    for(final r in rows){final n=(r['total'] as num?)?.toDouble()??0;if(r['type']=='credit')credit=n;if(r['type']=='debit')debit=n;}
    return {'credit':credit,'debit':debit,'net':credit-debit};
  }
  Future<double> balanceFor(String id,String currency)async=>(await accountTotals(id,currency))['net']??0;
  Future<Map<String,double>> dashboardTotals(String currency)async{final d=await db;final rows=await d.rawQuery('SELECT type,SUM(base_amount) total FROM transactions WHERE base_currency=? AND deleted=0 GROUP BY type',[currency]);final out=<String,double>{'credit':0,'debit':0};for(final r in rows)out[r['type'] as String]=(r['total'] as num?)?.toDouble()??0;return out;}
  Future<String> saveTransaction({required String accountId,required String type,required double amount,required String currency,double rate=1,required String category,DateTime? date,String note='',String? parentId})async{
    final d=await db;
    final id=_uuid.v4();
    final now=DateTime.now().millisecondsSinceEpoch;
    final base=await getSetting('base_currency')??'YER';
    var effectiveRate=rate;
    if(currency!=base && (effectiveRate<=0 || effectiveRate==1)){
      effectiveRate=await _rateBetween(currency,base) ?? (throw StateError('لا يوجد سعر صرف محفوظ لـ $currency → $base'));
    }
    if(currency==base)effectiveRate=1;
    await d.insert('transactions',{'id':id,'account_id':accountId,'type':type,'amount':amount,'currency':currency,'base_amount':amount*effectiveRate,'base_currency':base,'exchange_rate':effectiveRate,'category':category,'date':(date??DateTime.now()).millisecondsSinceEpoch,'created_at':now,'updated_at':now,'note':note,'status':'accepted','source':'local','parent_id':parentId,'deleted':0});
    return id;
  }
  Future<void> addAttachment(String transactionId,String path,String name,String mime,int size)async{final d=await db;await d.insert('attachments',{'id':_uuid.v4(),'transaction_id':transactionId,'path':path,'name':name,'mime':mime,'size':size,'created_at':DateTime.now().millisecondsSinceEpoch});}
  Future<List<CurrencyModel>> currencies()async{final d=await db;return(await d.query('currencies',orderBy:'is_base DESC,code')).map(CurrencyModel.fromMap).toList();}
  Future<void> setBaseCurrency(String code)async{
    final d=await db;
    final target=code.toUpperCase();
    final exists=await d.query('currencies',where:'code=?',whereArgs:[target],limit:1);
    if(exists.isEmpty)throw StateError('العملة غير موجودة: $target');
    final oldBase=await getSetting('base_currency')??'YER';
    if(oldBase==target)return;
    final rows=await d.query('transactions',where:'deleted=0');
    final converted=<String,double>{};
    for(final row in rows){
      final id=row['id'] as String;
      final source=(row['currency'] as String?)??oldBase;
      final amount=(row['amount'] as num?)?.toDouble()??0;
      final rate=source==target?1:(await _rateBetween(source,target));
      if(rate==null)throw StateError('لا يوجد سعر صرف لتحويل $source إلى $target');
      converted[id]=amount*rate;
    }
    await d.transaction((txn)async{
      await txn.update('currencies',{'is_base':0});
      await txn.update('currencies',{'is_base':1},where:'code=?',whereArgs:[target]);
      for(final row in rows){
        final id=row['id'] as String;
        final amount=(row['amount'] as num?)?.toDouble()??0;
        final baseAmount=converted[id]??amount;
        final rate=amount==0?1:baseAmount/amount;
        await txn.update('transactions',{'base_amount':baseAmount,'base_currency':target,'exchange_rate':rate,'updated_at':DateTime.now().millisecondsSinceEpoch},where:'id=?',whereArgs:[id]);
      }
      await txn.insert('settings',{'key':'base_currency','value':target},conflictAlgorithm:ConflictAlgorithm.replace);
    });
  }

  Future<double?> _rateBetween(String from,String to)async{
    if(from==to)return 1;
    final direct=await latestRate(from,to);
    if(direct!=null&&direct>0)return direct;
    final reverse=await latestRate(to,from);
    if(reverse!=null&&reverse>0)return 1/reverse;
    return null;
  }
  Future<void> addCurrency(String code,String name,String symbol,int decimals)async{final d=await db;await d.insert('currencies',{'code':code.toUpperCase(),'name':name,'symbol':symbol,'decimals':decimals,'is_base':0});}
  Future<void> saveRate(String from,String to,double rate)async{final d=await db;await d.insert('exchange_rates',{'id':_uuid.v4(),'from_code':from,'to_code':to,'rate':rate,'effective_at':DateTime.now().millisecondsSinceEpoch});}
  Future<double?> latestRate(String from,String to)async{final d=await db;final r=await d.query('exchange_rates',where:'from_code=? AND to_code=?',whereArgs:[from,to],orderBy:'effective_at DESC',limit:1);return r.isEmpty?null:(r.first['rate'] as num).toDouble();}
  Future<void> saveInvoice({required String number,required String accountId,required double total,required double paid,required String currency,String notes=''})async{final d=await db;await d.insert('invoices',{'id':_uuid.v4(),'number':number,'account_id':accountId,'date':DateTime.now().millisecondsSinceEpoch,'total':total,'paid':paid,'currency':currency,'notes':notes});}
  Future<List<Invoice>> invoices()async{final d=await db;return(await d.query('invoices',orderBy:'date DESC')).map(Invoice.fromMap).toList();}
  Future<String?> getSetting(String key)async{final d=await db;final r=await d.query('settings',where:'key=?',whereArgs:[key],limit:1);return r.isEmpty?null:r.first['value'] as String?;}
  Future<void> setSetting(String key,String value)async{final d=await db;await d.insert('settings',{'key':key,'value':value},conflictAlgorithm:ConflictAlgorithm.replace);}
  Future<Map<String,String>> userProfile()async{final out=<String,String>{};for(final k in ['user_name','user_name_en','address_ar','address_en','phone','logo_path'])out[k]=await getSetting(k)??'';out['base_currency']=await getSetting('base_currency')??'YER';return out;}
  Future<List<String>> transactionCategories()async=>['مبيعات','مشتريات','دفعة','تحصيل','نقل','إيجار','صيانة','رواتب','أخرى'];
  Future<void> addTransactionCategory(String value)async{}
  Future<void> removeTransactionCategory(String value)async{}
  Future<void> deleteAllLedgerData()async{final d=await db;for(final t in ['attachments','transactions','invoices','invoice_items','exchange_rates','accounts'])await d.delete(t);}
  Future<Map<String,Object?>> exportData()async{final d=await db;final out=<String,Object?>{'schemaVersion':1};for(final t in ['accounts','transactions','currencies','exchange_rates','invoices','invoice_items','attachments','settings'])out[t]=await d.query(t);return out;}
  Future<void> importData(Map<String,dynamic> data,{bool merge=false})async{final d=await db;const tables=['accounts','transactions','currencies','exchange_rates','invoices','invoice_items','attachments','settings'];await d.transaction((txn)async{if(!merge)for(final t in tables)await txn.delete(t);for(final t in tables){final list=data[t];if(list is List)for(final row in list){if(row is Map)await txn.insert(t,Map<String,Object?>.from(row),conflictAlgorithm:ConflictAlgorithm.replace);}}});}
  Future<List<Map<String,Object?>>> pendingQueue()async{final d=await db;return d.query('sync_queue');}
}