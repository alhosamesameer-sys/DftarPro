import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets.dart';

class _PhoneCountry {
  final String name, code;
  const _PhoneCountry(this.name, this.code);
}

const _phoneCountries = <_PhoneCountry>[
  _PhoneCountry('اليمن', '+967'),
  _PhoneCountry('السعودية', '+966'),
  _PhoneCountry('مصر', '+20'),
  _PhoneCountry('الإمارات', '+971'),
  _PhoneCountry('عمان', '+968'),
  _PhoneCountry('قطر', '+974'),
  _PhoneCountry('الكويت', '+965'),
  _PhoneCountry('البحرين', '+973'),
  _PhoneCountry('الأردن', '+962'),
  _PhoneCountry('العراق', '+964'),
  _PhoneCountry('سوريا', '+963'),
  _PhoneCountry('تركيا', '+90'),
  _PhoneCountry('بريطانيا', '+44'),
  _PhoneCountry('أمريكا', '+1'),
];

String normalizeInternationalPhone(String raw, String countryCode) {
  var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.startsWith('+')) return '+${digits.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
  digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
  final codeDigits = countryCode.replaceAll('+', '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith(codeDigits)) return '+$digits';
  if (digits.startsWith('0')) digits = digits.substring(1);
  return '+$codeDigits$digits';
}

Future<String?> showAddAccountSheet(BuildContext context, WidgetRef ref, {String initialType = 'customer'}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAccountSheet(initialType: initialType),
    );

Future<bool?> showEditAccountSheet(BuildContext context, WidgetRef ref, String accountId) async {
  final account = await ref.read(repositoryProvider).account(accountId);
  if (account == null || !context.mounted) return false;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddAccountSheet(initialType: account.type, account: account),
  );
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  final String initialType;
  final dynamic account;
  const _AddAccountSheet({required this.initialType, this.account});
  @override ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final company = TextEditingController();
  final address = TextEditingController();
  final notes = TextEditingController();
  late String type;
  String countryCode = '+967';
  bool saving = false;

  @override void initState() {
    super.initState();
    type = widget.account?.type ?? widget.initialType;
    if (widget.account != null) {
      name.text = widget.account.name;
      phone.text = widget.account.phone;
      company.text = widget.account.companyName;
      address.text = widget.account.address;
      notes.text = widget.account.notes;
    }
  }
  @override void dispose() { name.dispose(); phone.dispose(); company.dispose(); address.dispose(); notes.dispose(); super.dispose(); }

  static const _contactsChannel = MethodChannel('dftar/contacts');

  Future<void> pickContact() async {
    if (saving) return;
    try {
      final contact = await _contactsChannel.invokeMethod<Map<dynamic, dynamic>>('pickContact');
      if (contact == null || !mounted) return;
      final selectedName = (contact['name'] ?? '').toString().trim();
      final selectedPhone = (contact['phone'] ?? '').toString().trim();
      if (selectedName.isNotEmpty) name.text = selectedName;
      if (selectedPhone.isNotEmpty) phone.text = selectedPhone;
      setState(() {});
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'تعذر فتح جهات الاتصال')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح جهات الاتصال')),
      );
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل اسم العميل أولاً')));
      return;
    }
    final rawPhone = phone.text.trim();
    final normalizedPhone = rawPhone.isEmpty ? '' : normalizeInternationalPhone(rawPhone, countryCode);
    setState(() => saving = true);
    try {
      final id = await ref.read(repositoryProvider).saveAccount(
        id: widget.account?.id,
        name: name.text.trim(), phone: normalizedPhone, company: company.text.trim(),
        address: address.text.trim(), notes: notes.text.trim(), type: type, currency: widget.account?.currency ?? 'YER',
      );
      ref.invalidate(accountsProvider(''));
      ref.invalidate(accountsByTypeProvider('customer'));
      ref.invalidate(accountsByTypeProvider('supplier'));
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ العميل: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16, top: 16),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.account == null ? 'إضافة عميل' : 'تعديل الحساب', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'اسم العميل *')),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 118, child: DropdownButtonFormField<String>(
          initialValue: countryCode,
          isExpanded: true,
          items: _phoneCountries.map((c) => DropdownMenuItem(value: c.code, child: Text('${c.code} ${c.name}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: saving ? null : (v) { if (v != null) setState(() => countryCode = v); },
          decoration: const InputDecoration(labelText: 'الدولة'),
        )),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              suffixIcon: IconButton(
                tooltip: 'اختيار من جهات الاتصال',
                icon: const Icon(Icons.contacts_outlined, size: 20),
                onPressed: saving ? null : pickContact,
              ),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      TextField(controller: company, decoration: const InputDecoration(labelText: 'الشركة')),
      TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
      TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: type,
        items: const [DropdownMenuItem(value: 'customer', child: Text('عميل')), DropdownMenuItem(value: 'supplier', child: Text('مورد')), DropdownMenuItem(value: 'both', child: Text('عميل ومورد'))],
        onChanged: saving ? null : (v) { if (v != null) setState(() => type = v); },
        decoration: const InputDecoration(labelText: 'نوع الحساب'),
      ),
      const SizedBox(height: 12),
      PrimaryButton(label: saving ? 'جارٍ الحفظ...' : widget.account == null ? 'حفظ العميل' : 'حفظ التعديل', icon: Icons.save, onPressed: saving ? null : save),
    ])),
  );
}

Future<void> showChooseAccountAndRecord(BuildContext context, WidgetRef ref) async {
  await context.push('/add-transaction');
}

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});
  @override ConsumerState<AccountsPage> createState() => _AccountsPageState();
}
class _AccountsPageState extends ConsumerState<AccountsPage> {
  final q = TextEditingController(); String type = 'all', sort = 'updated_desc';
  @override void initState() { super.initState(); load(); }
  @override void dispose() { q.dispose(); super.dispose(); }
  Future<void> load() async { sort = await ref.read(repositoryProvider).getSetting('accounts_sort') ?? 'updated_desc'; if (mounted) setState(() {}); }
  Future<void> setSort(String v) async { setState(() => sort = v); await ref.read(repositoryProvider).setSetting('accounts_sort', v); ref.invalidate(accountsProvider('')); ref.invalidate(accountsByTypeProvider('customer')); ref.invalidate(accountsByTypeProvider('supplier')); }
  @override Widget build(BuildContext context) {
    final all = ref.watch(accountsProvider(q.text)); final customers = ref.watch(accountsByTypeProvider('customer')); final suppliers = ref.watch(accountsByTypeProvider('supplier'));
    final selected = type == 'customer' ? customers : type == 'supplier' ? suppliers : all;
    return Column(children: [
      AppHeader(title: 'الحسابات'),
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: q, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث'))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [chip('الكل', type == 'all', () => setState(() => type = 'all')), chip('العملاء', type == 'customer', () => setState(() => type = 'customer')), chip('الموردون', type == 'supplier', () => setState(() => type = 'supplier')), DropdownButton<String>(value: sort, items: const [DropdownMenuItem(value: 'name_asc', child: Text('أ → ي')), DropdownMenuItem(value: 'name_desc', child: Text('ي → أ')), DropdownMenuItem(value: 'balance_desc', child: Text('الأكثر')), DropdownMenuItem(value: 'balance_asc', child: Text('الأقل')), DropdownMenuItem(value: 'updated_desc', child: Text('الأحدث'))], onChanged: (v) { if (v != null) setSort(v); })])),
      Expanded(child: selected.when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, s) => Center(child: Text('$e')), data: (items) => ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) => _tile(context, items[index])))),
    ]);
  }
  Widget _tile(BuildContext context, dynamic a) => Card(
    child: ListTile(
      leading: AccountAvatar(name: a.name),
      title: Text(a.name),
      subtitle: Text(a.phone.isEmpty ? (a.type == 'supplier' ? 'مورد' : 'عميل') : a.phone),
      onTap: () => context.push('/accounts/${a.id}'),
      onLongPress: () => _accountActions(context, a),
      trailing: FutureBuilder<double>(
        future: ref.read(repositoryProvider).accountBaseTotals(a.id, ref.read(baseCurrencyProvider).valueOrNull ?? 'YER').then((x) => x['net'] ?? 0),
        builder: (context, snapshot) {
          final v = snapshot.data ?? 0;
          final base = ref.read(baseCurrencyProvider).valueOrNull ?? 'YER';
          return Text('${money(v.abs(), base)}\n${v >= 0 ? 'له' : 'عليه'}');
        },
      ),
    ),
  );

  Future<void> _accountActions(BuildContext context, dynamic a) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل'), onTap: () => Navigator.pop(sheetContext, 'edit')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('حذف'), onTap: () => Navigator.pop(sheetContext, 'delete')),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await showEditAccountSheet(context, ref, a.id);
      ref.invalidate(accountsProvider(''));
      ref.invalidate(accountsByTypeProvider('customer'));
      ref.invalidate(accountsByTypeProvider('supplier'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب؟'),
        content: Text('سيتم حذف حساب «${a.name}» وجميع عملياته. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(repositoryProvider).deleteAccount(a.id);
      ref.invalidate(accountsProvider(''));
      ref.invalidate(accountsByTypeProvider('customer'));
      ref.invalidate(accountsByTypeProvider('supplier'));
      ref.invalidate(dashboardProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الحساب')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف الحساب: $e')));
    }
  }
  Widget chip(String text, bool selected, VoidCallback tap) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(text), selected: selected, onSelected: (_) => tap()));
}
