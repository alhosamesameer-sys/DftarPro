import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_pro/core/utils/calculator_engine.dart';
void main() {
  test('respects multiplication before addition', () { expect(CalculatorEngine.evaluate('2+3*4'), 14); expect(CalculatorEngine.evaluate('(2+3)*4'), 20); });
  test('supports negative numbers and unary minus', () { expect(CalculatorEngine.evaluate('-5+2'), -3); expect(CalculatorEngine.evaluate('5*-2'), -10); expect(CalculatorEngine.evaluate('-5*-2'), 10); });
  test('returns null for division by zero and malformed expressions', () { expect(CalculatorEngine.evaluate('10/0'), isNull); expect(CalculatorEngine.evaluate('2+'), isNull); expect(CalculatorEngine.evaluate('1.2.3'), isNull); expect(CalculatorEngine.evaluate('(2+3'), isNull); });
}