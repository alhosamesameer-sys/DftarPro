class LedgerValidators {
  static String? amount(String value) {
    final n = double.tryParse(value.trim().replaceAll(',', ''));
    if (n == null || !n.isFinite) return 'أدخل رقمًا صحيحًا';
    if (n <= 0) return 'يجب أن يكون المبلغ أكبر من صفر';
    return null;
  }
  static String? exchangeRate(String value) {
    final n = double.tryParse(value.trim().replaceAll(',', ''));
    if (n == null || !n.isFinite) return 'أدخل سعر صرف رقميًا صحيحًا';
    if (n <= 0) return 'سعر الصرف يجب أن يكون أكبر من صفر';
    return null;
  }
  static String? invoice(String totalText, String paidText) {
    final total = double.tryParse(totalText.trim().replaceAll(',', ''));
    final paid = double.tryParse(paidText.trim().replaceAll(',', ''));
    if (total == null || !total.isFinite || total <= 0) return 'إجمالي الفاتورة يجب أن يكون أكبر من صفر';
    if (paid == null || !paid.isFinite || paid < 0) return 'المدفوع يجب أن يكون رقمًا صحيحًا غير سالب';
    if (paid > total) return 'المبلغ المدفوع لا يمكن أن يكون أكبر من الإجمالي';
    return null;
  }
}