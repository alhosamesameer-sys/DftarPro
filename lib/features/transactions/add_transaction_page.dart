import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models.dart';
import '../accounts/accounts_page.dart';
import '../../shared/widgets.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final String? accountId;
  final String initialType;
  final String? transactionId;
  const AddTransactionPage({super.key, this.accountId, this.initialType = 'credit', this.transactionId});
  @override ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  String? account;
  String type = 'credit';
  String currency = 'YER';
  String category = 'عملية';
  String baseCurrency = 'YER';
  List<String> categories = [];
  List<CurrencyModel> currencies = [];
  final amount = TextEditingController();
  final rate = TextEditingController(text: '1');
  final note = TextEditingController();
  final accountSearch = TextEditingController();
  DateTime date = DateTime.now();
  bool loading = true, saving = false, loadingRate = false, amountWords = false, showAccountSuggestions = false;
  bool get editing => widget.transactionId != null;
  bool get foreignCurrency => currency != baseCurrency;

  @override
  void initState() {
    super.initState();
    load();
    amount.addListener(_amountChanged);
    accountSearch.addListener(_accountSearchChanged);
  }

  Future<void> load() async {
    final r = ref.read(repositoryProvider);
    categories = await r.transactionCategories();
    currencies = await r.currencies();
    baseCurrency = await r.getSetting('base_currency') ?? 'YER';
    amountWords = (await r.getSetting('amount_words') ?? '0') == '1';
    account = widget.accountId;
    if (editing) {
      final x = await r.transaction(widget.transactionId!);
      if (x != null) {
        account = x.accountId;
        type = x.type;
        currency = x.currency;
        category = x.category;
        amount.text = x.amount.toString();
        rate.text = x.exchangeRate.toString();
        note.text = x.note;
        date = x.date;
        final a = await r.account(x.accountId);
        accountSearch.text = a?.name ?? '';
      }
    } else {
      type = widget.initialType == 'debit' ? 'debit' : 'credit';
      currency = baseCurrency;
      rate.text = '1';
      if (account != null) {
        final a = await r.account(account!);
        accountSearch.text = a?.name ?? '';
      }
    }
    if (!categories.contains(category)) {
      category = categories.contains('عملية') ? 'عملية' : (categories.isNotEmpty ? categories.first : 'عملية');
    }
    if (foreignCurrency) await _loadExchangeRate(currency, silent: true);
    if (mounted) setState(() => loading = false);
  }

  void _amountChanged() { if (mounted) setState(() {}); }

  void _accountSearchChanged() {
    if (!mounted || loading) return;
    final text = accountSearch.text.trim();
    if (account != null) {
      ref.read(repositoryProvider).account(account!).then((a) {
        final selectedName = a?.name ?? '';
        if (mounted && text != selectedName && account != null) {
          setState(() {
            account = null;
            showAccountSuggestions = text.isNotEmpty;
          });
        }
      });
    } else {
      setState(() => showAccountSuggestions = text.isNotEmpty);
    }
  }

  @override
  void dispose() {
    amount.removeListener(_amountChanged);
    accountSearch.removeListener(_accountSearchChanged);
    amount.dispose();
    rate.dispose();
    note.dispose();
    accountSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppHeader(title: editing ? 'تعديل العملية' : 'إضافة عملية'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _accountField(),
          const SizedBox(height: 12),
          _typeField(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ'))),
            const SizedBox(width: 8),
            SizedBox(width: 120, child: _currencyField()),
          ]),
          if (amountWords) ...[
            const SizedBox(height: 6),
            Text(_amountInWords(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
          if (foreignCurrency) ...[
            const SizedBox(height: 12),
            TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'سعر الصرف إلى ' + currencyName(baseCurrency), suffixIcon: loadingRate ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null)),
            const SizedBox(height: 5),
            Text('القيمة بالعملة الأساسية = المبلغ × سعر الصرف', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Builder(builder: (context) {
              final amountValue = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
              final rateValue = double.tryParse(rate.text.replaceAll(',', '')) ?? 0;
              final converted = amountValue * rateValue;
              return Text(
                'ما يعادل: ' + converted.toStringAsFixed(2) + ' ' + baseCurrency,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              );
            }),
          ],
          const SizedBox(height: 12),
          _categoryField(),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
          ListTile(title: const Text('التاريخ'), subtitle: Text(date.year.toString() + '/' + date.month.toString() + '/' + date.day.toString()), onTap: pickDate),
          const SizedBox(height: 12),
          PrimaryButton(label: saving ? 'جارٍ الحفظ...' : editing ? 'حفظ التعديل' : 'حفظ العملية', icon: Icons.save, onPressed: saving ? null : save),
        ],
      ),
    );
  }

  Widget _accountField() {
    final queryText = accountSearch.text.trim();
    final data = queryText.isEmpty ? null : ref.read(repositoryProvider).accounts(query: queryText);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: accountSearch,
        enabled: !editing,
        onTap: () {
          if (accountSearch.text.trim().isNotEmpty && account == null) setState(() => showAccountSuggestions = true);
        },
        decoration: InputDecoration(
          labelText: 'العميل / الحساب',
          hintText: 'اكتب اسم العميل للبحث',
          suffixIcon: account != null ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.search),
        ),
      ),
      if (!editing && showAccountSuggestions && queryText.isNotEmpty)
        FutureBuilder<List<Account>>(
          future: data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            }
            if (snapshot.hasError) {
              return Padding(padding: const EdgeInsets.all(8), child: Text('تعذر البحث: ' + snapshot.error.toString()));
            }
            final query = queryText.toLowerCase();
            final items = snapshot.data ?? const <Account>[];
            final filtered = items.where((a) => a.name.toLowerCase().contains(query)).take(6).toList();
            return Card(
              child: Column(children: [
                if (filtered.isNotEmpty)
                  ...filtered.map((a) => ListTile(
                    dense: true,
                    leading: AccountAvatar(name: a.name),
                    title: Text(a.name),
                    subtitle: Text(a.phone.isEmpty ? 'حساب' : a.phone),
                    onTap: () => _selectAccount(a),
                  )),
                if (filtered.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: const Text('إضافة عميل جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('لا يوجد عميل باسم «' + queryText + '»'),
                    onTap: _addCustomerFromTransaction,
                  ),
              ]),
            );
          },
        ),
    ]);
  }
  void _selectAccount(Account a) {
    setState(() {
      account = a.id;
      accountSearch.text = a.name;
      showAccountSuggestions = false;
    });
  }

  Future<void> _addCustomerFromTransaction() async {
    final id = await showAddAccountSheet(context, ref, initialType: 'customer');
    if (id == null || !mounted) return;
    final a = await ref.read(repositoryProvider).account(id);
    if (a != null) {
      setState(() {
        account = a.id;
        accountSearch.text = a.name;
        showAccountSuggestions = false;
      });
    }
  }

  Widget _typeField() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'credit', label: Text('له')),
      ButtonSegment(value: 'debit', label: Text('عليه')),
      ButtonSegment(value: 'payment', label: Text('دفع / تحصيل')),
    ],
    selected: {type},
    onSelectionChanged: (v) => setState(() => type = v.first),
  );

  Widget _currencyField() {
    final codes = currencies.map((x) => x.code).toSet().toList();
    if (!codes.contains(currency)) codes.insert(0, currency);
    return DropdownButtonFormField<String>(
      initialValue: currency,
      items: codes.map((code) {
        final found = currencies.where((x) => x.code == code).firstOrNull;
        final label = found == null ? code : found.name + ' (' + found.code + ')';
        return DropdownMenuItem(value: code, child: Text(label, overflow: TextOverflow.ellipsis));
      }).toList(),
      onChanged: (v) async {
        if (v != null) {
          setState(() {
            currency = v;
            rate.text = v == baseCurrency ? '1' : rate.text;
          });
          if (v == baseCurrency) return;
          await _loadExchangeRate(v);
        }
      },
      decoration: const InputDecoration(labelText: 'العملة'),
    );
  }
  Widget _categoryField() => DropdownButtonFormField<String>(
    initialValue: categories.contains(category) ? category : null,
    items: categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
    onChanged: (v) { if (v != null) setState(() => category = v); },
    decoration: const InputDecoration(labelText: 'التصنيف'),
  );

  Future<void> _loadExchangeRate(String from, {bool silent = false}) async {
    if (from == baseCurrency) {
      if (mounted) setState(() => rate.text = '1');
      return;
    }
    if (mounted) setState(() => loadingRate = true);
    try {
      final found = await ref.read(repositoryProvider).latestRate(from, baseCurrency);
      if (found != null && found > 0 && mounted) {
        rate.text = _trimNumber(found);
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا يوجد سعر صرف محفوظ لـ ' + currencyName(from) + ' → ' + currencyName(baseCurrency) + '. أضفه من العملات وأسعار الصرف.')));
      }
    } finally {
      if (mounted) setState(() => loadingRate = false);
    }
  }

  String _trimNumber(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: date);
    if (d != null) setState(() => date = d);
  }

  Future<void> save() async {
    final id = account;
    final value = double.tryParse(amount.text.replaceAll(',', ''));
    final r = foreignCurrency ? double.tryParse(rate.text.replaceAll(',', '')) : 1.0;
    if (id == null || value == null || !value.isFinite || value <= 0 || r == null || !r.isFinite || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العميل وأدخل مبلغًا أكبر من صفر وسعر صرف صحيحًا')));
      return;
    }
    setState(() => saving = true);
    try {
      final repo = ref.read(repositoryProvider);
      if (editing) {
        await repo.updateTransaction(id: widget.transactionId!, accountId: id, type: type, amount: value, currency: currency, rate: r, category: category, date: date, note: note.text);
      } else {
        await repo.saveTransaction(accountId: id, type: type, amount: value, currency: currency, rate: r, category: category, date: date, note: note.text);
      }
      ref.invalidate(transactionsProvider(id));
      ref.invalidate(accountsProvider(''));
      ref.invalidate(dashboardProvider);
      ref.invalidate(accountProvider(id));
      if (!editing) await whatsapp(id, value, r);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _amountInWords() {
    final value = double.tryParse(amount.text.replaceAll(',', ''));
    if (value == null) return '';
    final whole = value.floor();
    final fraction = ((value - whole) * 100).round();
    var result = _arabicInteger(whole) + ' ' + currencyName(currency);
    if (fraction > 0) result += ' و' + _arabicInteger(fraction) + ' جزء';
    return result;
  }

  String _arabicInteger(int n) {
    if (n == 0) return 'صفر';
    if (n < 0) return 'سالب ' + _arabicInteger(-n);
    const ones = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    const teens = ['عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'];
    const tens = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
    String under100(int x) {
      if (x < 10) return ones[x];
      if (x < 20) return teens[x - 10];
      final t = x ~/ 10, o = x % 10;
      return o == 0 ? tens[t] : ones[o] + ' و' + tens[t];
    }
    String under1000(int x) {
      if (x < 100) return under100(x);
      final h = x ~/ 100, rest = x % 100;
      const hundreds = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];
      return rest == 0 ? hundreds[h] : hundreds[h] + ' و' + under100(rest);
    }
    String group(int x, String singular, String dual, String plural) {
      if (x == 1) return singular;
      if (x == 2) return dual;
      if (x >= 3 && x <= 10) return plural;
      return singular;
    }
    final parts = <String>[];
    final millions = n ~/ 1000000;
    var rest = n % 1000000;
    final thousands = rest ~/ 1000;
    rest %= 1000;
    if (millions > 0) parts.add(_arabicInteger(millions) + ' ' + group(millions, 'مليون', 'مليونان', 'ملايين'));
    if (thousands > 0) {
      if (thousands == 1) parts.add('ألف');
      else if (thousands == 2) parts.add('ألفان');
      else if (thousands <= 10) parts.add(under1000(thousands) + ' آلاف');
      else parts.add(under1000(thousands) + ' ألف');
    }
    if (rest > 0) parts.add(under1000(rest));
    return parts.join(' و');
  }

  Future<void> whatsapp(String id, double value, double r) async {
    final repo = ref.read(repositoryProvider);
    if ((await repo.getSetting('whatsapp_auto') ?? '0') != '1') return;
    final a = await repo.account(id);
    if (a == null || a.phone.isEmpty) return;
    var phone = a.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!a.phone.trim().startsWith('+') && phone.startsWith('0')) phone = '967' + phone.substring(1);
    else if (!a.phone.trim().startsWith('+') && !phone.startsWith('967')) phone = '967' + phone;
    final base = await repo.getSetting('base_currency') ?? 'YER';
    final totals = await repo.accountBaseTotals(id, base);
    final profile = await repo.userProfile();
    final owner = (profile['user_name'] ?? '').trim().isEmpty ? 'صاحب التطبيق' : profile['user_name']!.trim();
    final top = await repo.getSetting('statement_message_top') ?? '';
    final bottom = await repo.getSetting('statement_message_bottom') ?? '';
    final showHeader = (await repo.getSetting('statement_message_header') ?? '1') == '1';
    final showFooter = (await repo.getSetting('statement_message_footer') ?? '1') == '1';
    final showDate = (await repo.getSetting('whatsapp_date') ?? '1') == '1';
    final business = (await repo.getSetting('whatsapp_business') ?? '0') == '1';
    final equivalent = value * r;
    final net = totals['net'] ?? 0;
    final lines = <String>[];
    if (showHeader && top.trim().isNotEmpty) lines.add(top.trim());
    lines.add('إشعار من ' + owner + ':');
    lines.add('العميل: ' + a.name);
    lines.add('تمت إضافة ' + value.toStringAsFixed(2) + ' ' + currencyName(currency));
    lines.add('ما يعادل ' + equivalent.toStringAsFixed(2) + ' ' + currencyName(base));
    if (amountWords) lines.add('كتابةً: ' + _amountInWords());
    lines.add('الإجمالي: ' + net.abs().toStringAsFixed(2) + ' ' + currencyName(base) + ' ' + (net >= 0 ? 'له' : 'عليه'));
    if (showDate) lines.add('التاريخ: ' + date.year.toString() + '/' + date.month.toString() + '/' + date.day.toString());
    if (showFooter && bottom.trim().isNotEmpty) lines.add(bottom.trim());
    final text = lines.join('\n');
    try {
      const channel = MethodChannel('dftar/whatsapp');
      final opened = await channel.invokeMethod<bool>('openWhatsApp', {'phone': phone, 'text': text, 'business': business}) ?? false;
      if (opened) return;
      final fallback = Uri.https('wa.me', '/' + phone, {'text': text});
      final fallbackOpened = await launchUrl(fallback, mode: LaunchMode.externalApplication);
      if (!fallbackOpened && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(business ? 'واتساب للأعمال غير مثبت أو غير متاح على الجهاز' : 'واتساب غير مثبت أو غير متاح على الجهاز')));
    } on PlatformException {
      final fallback = Uri.https('wa.me', '/' + phone, {'text': text});
      final fallbackOpened = await launchUrl(fallback, mode: LaunchMode.externalApplication);
      if (!fallbackOpened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }
}