import 'app_database.dart';

extension TransactionCategoriesExtension on AppDatabase {
  Future<List<String>> transactionCategories() async {
    final d = await db;
    final rows = await d.query('settings', where: "key LIKE ?", whereArgs: ['transaction_category:%'], orderBy: 'key ASC');
    final values = rows.map((r) => (r['value'] as String?) ?? '').where((v) => v.trim().isNotEmpty).toSet().toList();
    if (!values.contains('عملية')) values.insert(0, 'عملية');
    return values.isEmpty ? ['عملية'] : values;
  }

  Future<void> addTransactionCategory(String value) async {
    final name = value.trim();
    if (name.isEmpty) return;
    final categories = await transactionCategories();
    if (categories.contains(name)) return;
    final key = 'transaction_category:${DateTime.now().microsecondsSinceEpoch}';
    await setSetting(key, name);
  }

  Future<void> removeTransactionCategory(String value) async {
    if (value.trim() == 'عملية') return;
    final d = await db;
    final rows = await d.query('settings', where: 'key LIKE ? AND value = ?', whereArgs: ['transaction_category:%', value]);
    for (final row in rows) {
      await d.delete('settings', where: 'key = ?', whereArgs: [row['key']]);
    }
  }
}
