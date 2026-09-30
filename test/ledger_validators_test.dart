import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_pro/core/utils/ledger_validators.dart';

void main() {
  test('accepts valid amounts and rejects zero, negative and non-numeric values', () {
    expect(LedgerValidators.amount('125.50'), isNull);
    expect(LedgerValidators.amount('0'), isNotNull);
    expect(LedgerValidators.amount('-1'), isNotNull);
    expect(LedgerValidators.amount('abc'), isNotNull);
  });
  test('rejects zero or negative exchange rates', () {
    expect(LedgerValidators.exchangeRate('140'), isNull);
    expect(LedgerValidators.exchangeRate('0'), isNotNull);
    expect(LedgerValidators.exchangeRate('-2'), isNotNull);
    expect(LedgerValidators.exchangeRate('x'), isNotNull);
  });
  test('invoice validation protects total and paid amount', () {
    expect(LedgerValidators.invoice('1000', '250'), isNull);
    expect(LedgerValidators.invoice('0', '0'), isNotNull);
    expect(LedgerValidators.invoice('-10', '0'), isNotNull);
    expect(LedgerValidators.invoice('1000', '1001'), isNotNull);
    expect(LedgerValidators.invoice('abc', '10'), isNotNull);
    expect(LedgerValidators.invoice('1000', 'abc'), isNotNull);
  });
}