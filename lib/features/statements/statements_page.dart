import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

class StatementsPage extends ConsumerStatefulWidget {
  final String accountId;
  const StatementsPage({super.key, required this.accountId});
  @override ConsumerState<StatementsPage> createState() => _StatementsPageState();
}

class _StatementsPageState extends ConsumerState<StatementsPage> {
  List<TransactionItem> items = [];
  bool loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final rows = await ref.read(repositoryProvider).transactions(accountId: widget.accountId, limit: 1000);
    if (mounted) setState(() { items = rows; loading = false; });
  }
  @override Widget build(BuildContext context) {
    final account = ref.watch(accountProvider(widget.accountId));
    final base = ref.watch(baseCurrencyProvider).asData?.value ?? 'YER';
    return Scaffold(body: SafeArea(child: account.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(e.toString())),
      data: (a) {
        if (a == null) return const Center(child: Text('الحساب غير موجود'));
        final net = items.fold<double>(0, (sum, x) => sum + (x.type == 'credit' ? x.baseAmount : -x.baseAmount));
        return ListView(padding: const EdgeInsets.all(16), children: [
          const AppHeader(title: 'كشف حساب'),
          Card(child: ListTile(leading: AccountAvatar(name: a.name), title: Text(a.name), subtitle: Text(a.phone))),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('الصافي: ' + money(net.abs(), base) + ' ' + (net >= 0 ? 'له' : 'عليه'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('تحديث'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: () async {
                final b = StringBuffer();
                b.writeln('كشف حساب ' + a.name);
                b.writeln('الصافي: ' + money(net, base));
                for (final x in items) b.writeln(dateAr(x.date) + ' - ' + x.amount.toStringAsFixed(2) + ' ' + x.currency);
                await SharePlus.instance.share(ShareParams(text: b.toString()));
              },
              icon: const Icon(Icons.share), label: const Text('مشاركة'),
            )),
          ]),
          const SizedBox(height: 12),
          if (loading) const Center(child: CircularProgressIndicator()),
          for (final x in items) Card(child: ListTile(title: Text(x.note.isEmpty ? x.category : x.note), subtitle: Text(dateAr(x.date)), trailing: MoneyAmount(value: x.amount, currency: x.currency, positive: x.type == 'credit'))),
        ]);
      },
    )));
  }
}