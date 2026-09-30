import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models.dart';
import '../../shared/widgets.dart';

class AccountDetailPage extends ConsumerWidget {
  final String id;
  const AccountDetailPage({super.key, required this.id});

  Future<void> _delete(BuildContext context, WidgetRef ref, String transactionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العملية'),
        content: const Text('هل تريد حذف هذه العملية نهائيًا؟ سيتم تحديث رصيد الحساب والإجماليات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repositoryProvider).deleteTransaction(transactionId);
      ref.invalidate(transactionsProvider(id));
      ref.invalidate(accountProvider(id));
      ref.invalidate(accountsProvider(''));
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العملية ✓')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف العملية: ' + e.toString())));
      }
    }
  }

  Future<void> _actions(BuildContext context, WidgetRef ref, TransactionItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: Icon(item.type == 'credit' ? Icons.arrow_downward : Icons.arrow_upward),
              title: const Text('عملية', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(item.amount.toStringAsFixed(2) + ' ' + item.currency + ' • ' + dateAr(item.date)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل العملية'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/edit-transaction/' + item.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('حذف العملية', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(context, ref, item.id);
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(accountProvider(id));
    final tx = ref.watch(transactionsProvider(id));
    final base = ref.watch(baseCurrencyProvider);
    return Scaffold(
      body: SafeArea(
        child: a.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text(e.toString())),
          data: (account) {
            if (account == null) return const Center(child: Text('الحساب غير موجود'));
            return base.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text(e.toString())),
              data: (baseCurrency) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  const AppHeader(title: 'تفاصيل الحساب'),
                  Center(child: AccountAvatar(name: account.name, radius: 38)),
                  const SizedBox(height: 8),
                  Center(child: Text(account.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
                  Center(child: Text(account.phone.isEmpty ? 'لا يوجد هاتف' : account.phone)),
                  if (account.companyName.isNotEmpty) Center(child: Text(account.companyName, style: const TextStyle(color: Colors.grey))),
                  if (account.address.isNotEmpty) Center(child: Text(account.address, style: const TextStyle(color: Colors.grey))),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    OutlinedButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يمكن ربط الاتصال من جهازك'))),
                      icon: const Icon(Icons.call),
                      label: const Text('اتصال'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/statements/' + account.id),
                      icon: const Icon(Icons.description),
                      label: const Text('كشف الحساب'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, double>>(
                    future: ref.read(repositoryProvider).accountBaseTotals(account.id, baseCurrency),
                    builder: (c, b) {
                      final totals = b.data ?? const {'credit': 0.0, 'debit': 0.0, 'net': 0.0};
                      final credit = totals['credit'] ?? 0;
                      final debit = totals['debit'] ?? 0;
                      final net = totals['net'] ?? 0;
                      final state = net > 0 ? 'الصافي له' : net < 0 ? 'الصافي عليه' : 'متوازن';
                      return Card(
                        color: Theme.of(context).colorScheme.primary,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(children: [
                            const Text('الرصيد الصافي', style: TextStyle(color: Colors.white70)),
                            Text(money(net.abs(), baseCurrency), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                            Text(state, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 14),
                            Row(children: [
                              _mini('إجمالي له', credit, baseCurrency),
                              const SizedBox(width: 8),
                              _mini('إجمالي عليه', debit, baseCurrency),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: () => context.push('/add-transaction?account=' + Uri.encodeComponent(account.id) + '&type=credit'), icon: const Icon(Icons.add), label: const Text('له'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/add-transaction?account=' + Uri.encodeComponent(account.id) + '&type=debit'), icon: const Icon(Icons.remove), label: const Text('عليه'))),
                  ]),
                  const SizedBox(height: 20),
                  const SectionTitle(title: 'العمليات'),
                  const SizedBox(height: 8),
                  tx.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text(e.toString()),
                    data: (items) => items.isEmpty
                        ? const EmptyState(title: 'لا توجد عمليات', subtitle: 'سجل أول عملية لهذا الحساب.')
                        : Column(
                            children: items.map((t) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onTap: () => _actions(context, ref, t),
                                leading: Icon(t.type == 'credit' ? Icons.arrow_downward : Icons.arrow_upward, color: t.type == 'credit' ? Colors.green : Colors.red),
                                title: const Text('عملية', style: TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(dateAr(t.date) + ' • ' + (t.note.isEmpty ? t.category : t.note)),
                                trailing: MoneyAmount(value: t.amount, currency: t.currency, positive: t.type == 'credit'),
                              ),
                            )).toList(),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _mini(String t, double v, String currency) => Expanded(child: Column(children: [
    Text(t, style: const TextStyle(color: Colors.white70)),
    Text(money(v, currency), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  ]));
}