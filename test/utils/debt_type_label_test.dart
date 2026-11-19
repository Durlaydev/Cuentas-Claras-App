import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/utils/debt_type_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owedToMe se etiqueta como "Me deben"', () {
    expect(DebtType.owedToMe.label, 'Me deben');
  });

  test('iOwe se etiqueta como "Debo"', () {
    expect(DebtType.iOwe.label, 'Debo');
  });
}
