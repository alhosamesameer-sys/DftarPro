import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

class CurrenciesPage extends ConsumerWidget {
  const CurrenciesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppHeader(title: 'العملات وأسعار الصرف'),
      body: ref.watch(currenciesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('تعذر تحميل العملات: $e')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('لا توجد عملات'));
          final base = items.firstWhere((x) => x.base, orElse: () => items.first);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('العملة الأساسية', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${base.name} (${base.code})\nجميع الأرصدة المحولة تعتمد عليها.'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _chooseBase(context, ref, items),
              )),
              const SizedBox(height: 14),
              const SectionTitle(title: 'العملات المتاحة'),
              const SizedBox(height: 8),
              ...items.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text(c.code.characters.first)),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${c.code} • ${c.symbol} • ${c.decimals} منازل عشرية'),
                  trailing: c.base ? const Chip(label: Text('أساسية')) : const Icon(Icons.chevron_left),
                ),
              )),
              const SizedBox(height: 8),
              PrimaryButton(label: 'إضافة عملة', icon: Icons.add, onPressed: () => _add(context, ref)),
              const SizedBox(height: 10),
              PrimaryButton(label: 'إضافة سعر صرف', icon: Icons.swap_horiz, onPressed: () => _rate(context, ref, items)),
              const SizedBox(height: 16),
              const Card(child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('مثال: 100 ريال سعودي = 14,000 ريال يمني. عند تسجيل 100 SAR سيُضاف 14,000 YER إلى الرصيد، بينما يبقى كشف الحساب يعرض 100 SAR وما يعادله 14,000 YER.'),
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _chooseBase(BuildContext context, WidgetRef ref, List<CurrencyModel> items) async {
    String selected = items.firstWhere((x) => x.base, orElse: () => items.first).code;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('اختيار العملة الأساسية'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: items.map((x) => DropdownMenuItem(value: x.code, child: Text('${x.name} (${x.code})'))).toList(),
            onChanged: (value) { if (value != null) setDialogState(() => selected = value); },
            decoration: const InputDecoration(labelText: 'العملة الأساسية'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(repositoryProvider).setBaseCurrency(selected);
                  ref.invalidate(currenciesProvider);
                  ref.invalidate(baseCurrencyProvider);
                  ref.invalidate(dashboardProvider);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير العملة الأساسية وتحويل الأرصدة بأمان ✓')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لم يتم تغيير العملة: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(context: context, builder: (_) => const _AddCurrencyDialog());
    if (result == true) ref.invalidate(currenciesProvider);
  }

  Future<void> _rate(BuildContext context, WidgetRef ref, List<CurrencyModel> items) async {
    final result = await showDialog<bool>(context: context, builder: (_) => _ExchangeRateDialog(items: items, repository: ref.read(repositoryProvider)));
    if (result == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سعر الصرف بنجاح ✓')));
  }
}

class _AddCurrencyDialog extends ConsumerStatefulWidget {
  const _AddCurrencyDialog();
  @override ConsumerState<_AddCurrencyDialog> createState() => _AddCurrencyDialogState();
}

class _AddCurrencyDialogState extends ConsumerState<_AddCurrencyDialog> {
  final code = TextEditingController();
  final name = TextEditingController();
  final symbol = TextEditingController();
  final decimals = TextEditingController(text: '2');
  @override void dispose() { code.dispose(); name.dispose(); symbol.dispose(); decimals.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إضافة عملة'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'رمز العملة مثل SAR')),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم العملة')),
      TextField(controller: symbol, decoration: const InputDecoration(labelText: 'الرمز')),
      TextField(controller: decimals, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد المنازل العشرية (0 إلى 8)')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
      FilledButton(onPressed: () async {
        final d = int.tryParse(decimals.text.trim());
        if (code.text.trim().isEmpty || name.text.trim().isEmpty || d == null || d < 0 || d > 8) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بيانات العملة وعدد منازل عشرية بين 0 و8')));
          return;
        }
        try {
          await ref.read(repositoryProvider).addCurrency(code.text.trim().toUpperCase(), name.text.trim(), symbol.text.trim(), d);
          if (mounted) Navigator.pop(context, true);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة العملة: $e')));
        }
      }, child: const Text('حفظ')),
    ],
  );
}

class _ExchangeRateDialog extends StatefulWidget {
  final List<CurrencyModel> items;
  final dynamic repository;
  const _ExchangeRateDialog({required this.items, required this.repository});
  @override State<_ExchangeRateDialog> createState() => _ExchangeRateDialogState();
}

class _ExchangeRateDialogState extends State<_ExchangeRateDialog> {
  late String from;
  late String to;
  late final TextEditingController fromAmount;
  late final TextEditingController toAmount;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final base = widget.items.firstWhere((x) => x.base, orElse: () => widget.items.first);
    final other = widget.items.firstWhere((x) => !x.base, orElse: () => base);
    from = other.code; to = base.code;
    fromAmount = TextEditingController(text: '100');
    toAmount = TextEditingController();
  }
  @override void dispose() { fromAmount.dispose(); toAmount.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إضافة سعر صرف'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(initialValue: from, items: widget.items.map((x) => DropdownMenuItem(value: x.code, child: Text('${x.name} (${x.code})'))).toList(), onChanged: saving ? null : (v) { if (v != null) setState(() => from = v); }, decoration: const InputDecoration(labelText: 'من العملة')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: to, items: widget.items.map((x) => DropdownMenuItem(value: x.code, child: Text('${x.name} (${x.code})'))).toList(), onChanged: saving ? null : (v) { if (v != null) setState(() => to = v); }, decoration: const InputDecoration(labelText: 'إلى العملة')),
      const SizedBox(height: 8),
      TextField(controller: fromAmount, enabled: !saving, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'كم وحدة من العملة الأولى؟', hintText: 'مثلاً 100 أو 1000')),
      const SizedBox(height: 8),
      TextField(controller: toAmount, enabled: !saving, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'تساوي كم من العملة الثانية؟', hintText: 'مثلاً 14000')),
      const SizedBox(height: 8),
      const Text('يُحسب سعر الوحدة تلقائيًا: 100 SAR = 14000 YER → 1 SAR = 140 YER.', style: TextStyle(fontSize: 12)),
    ])),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')),
      FilledButton.icon(onPressed: saving ? null : _save, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: const Text('حفظ السعر')),
    ],
  );
  Future<void> _save() async {
    final a = double.tryParse(fromAmount.text.trim().replaceAll(',', ''));
    final b = double.tryParse(toAmount.text.trim().replaceAll(',', ''));
    if (a == null || b == null || !a.isFinite || !b.isFinite || a <= 0 || b <= 0 || from == to) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل قيمًا أكبر من صفر واختر عملتين مختلفتين')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.saveRate(from, to, b / a);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ سعر الصرف: $e')));
      }
    }
  }
}
