import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_pro/core/utils/formatters.dart';

void main() {
  test('uses Arabic currency names', () {
    expect(currencyName('SAR'), 'ريال سعودي');
    expect(currencyName('YER'), 'ريال يمني');
    expect(currencyName('EGP'), 'جنيه مصري');
  });
  test('respects configured decimal rules', () {
    expect(formatAmount(14000.75, 'YER'), '14001');
    expect(formatAmount(100.5, 'SAR'), '100.50');
    expect(formatAmount(12.3456, 'KWD'), '12.346');
  });
}