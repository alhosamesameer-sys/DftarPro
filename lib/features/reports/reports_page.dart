import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/widgets.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final base = ref.watch(baseCurrencyProvider).asData?.value ?? 'YER';

    return Scaffold(
      appBar: const AppHeader(title: 'التقارير'),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('تعذر تحميل التقرير: $error')),
        data: (values) {
          final credit = (values['credit'] ?? 0).toDouble();
          final debit = (values['debit'] ?? 0).toDouble();
          final net = credit - debit;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: 'إجمالي له', value: '${credit.toStringAsFixed(0)} $base', icon: Icons.trending_up)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'إجمالي عليه', value: '${debit.toStringAsFixed(0)} $base', icon: Icons.payments)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: StatCard(label: 'صافي الرصيد', value: '${net.toStringAsFixed(0)} $base', icon: Icons.account_balance_wallet)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(label: 'العملة', value: base, icon: Icons.currency_exchange)),
              ]),
              const SizedBox(height: 18),
              const SectionTitle(title: 'العمليات حسب النوع'),
              const SizedBox(height: 10),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 220, child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: credit, width: 32)]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: debit, width: 32)]),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(value.toInt() == 0 ? 'له' : 'عليه')))),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                ),
              )))),
              const SizedBox(height: 18),
              const SectionTitle(title: 'التقارير المتاحة'),
              Card(child: Column(children: [
                _reportTile(context, ref, 'تقرير المبيعات', Icons.point_of_sale, 'credit'),
                const Divider(height: 1),
                _reportTile(context, ref, 'تقرير المشتريات', Icons.shopping_cart, 'debit'),
                const Divider(height: 1),
                _reportTile(context, ref, 'حسب التصنيف', Icons.category, 'category'),
                const Divider(height: 1),
                _reportTile(context, ref, 'حسب العملة', Icons.currency_exchange, 'currency'),
              ])),
            ],
          );
        },
      ),
    );
  }

  static Widget _reportTile(BuildContext context, WidgetRef ref, String title, IconData icon, String kind) =>
      ListTile(onTap: () => _openReport(context, ref, title, kind), leading: Icon(icon), title: Text(title), trailing: const Icon(Icons.chevron_left));

  static Future<void> _openReport(BuildContext context, WidgetRef ref, String title, String kind) async {
    try {
      final items = await ref.read(repositoryProvider).transactions(limit: 1000);
      if (!context.mounted) return;
      final base = await ref.read(repositoryProvider).getSetting('base_currency') ?? 'YER';
      final filtered = kind == 'credit' || kind == 'debit' ? items.where((item) => item.type == kind).toList() : items;
      final groups = <String, double>{};
      for (final item in filtered) {
        final key = kind == 'category' ? (item.category.trim().isEmpty ? 'عملية' : item.category) : kind == 'currency' ? item.currency : (item.type == 'credit' ? 'له' : 'عليه');
        groups[key] = (groups[key] ?? 0) + item.baseAmount;
      }
      final sorted = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(width: 360, child: sorted.isEmpty ? const Text('لا توجد عمليات مطابقة.') : ListView.separated(
            shrinkWrap: true,
            itemCount: sorted.length,
            itemBuilder: (_, index) => ListTile(title: Text(sorted[index].key), trailing: Text('${sorted[index].value.toStringAsFixed(2)} $base', style: const TextStyle(fontWeight: FontWeight.bold))),
            separatorBuilder: (_, __) => const Divider(height: 1),
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
        ),
      );
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء التقرير: $error')));
    }
  }
}
