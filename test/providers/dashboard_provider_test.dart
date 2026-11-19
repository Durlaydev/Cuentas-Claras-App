import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/providers/dashboard_provider.dart';
import 'package:cuentas_claras/utils/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeDebtRepository debtRepository;
  late FakePaymentRepository paymentRepository;
  late DashboardProvider provider;

  setUp(() {
    debtRepository = FakeDebtRepository();
    paymentRepository = FakePaymentRepository();
    provider = DashboardProvider(debtRepository, paymentRepository);
  });

  test('el resumen inicial (sin refresh) es todo en cero', () {
    expect(provider.summary.totalOwedToMeCents, 0);
    expect(provider.summary.totalIOweCents, 0);
    expect(provider.summary.netCents, 0);
  });

  test('refresh calcula el GlobalBalanceSummary correcto a partir de datos conocidos', () async {
    final owed = await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 5000,
    );
    await debtRepository.createDebt(
      personId: 'p2',
      type: DebtType.iOwe,
      description: 'Compras',
      amountCents: 2000,
    );
    await paymentRepository.createPayment(debtId: owed.id, amountCents: 1000, date: DateTime(2026, 1, 2));

    await provider.refresh();

    final expected = computeGlobalSummary(
      debtRepository.debts,
      paymentRepository.payments,
    );
    expect(provider.summary, expected);
    expect(provider.summary.totalOwedToMeCents, 4000);
    expect(provider.summary.totalIOweCents, 2000);
    expect(provider.summary.netCents, 2000);
    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
  });

  test('chartSlices expone "Me deben" y "Debo" como datos planos', () async {
    await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 5000,
    );
    await debtRepository.createDebt(
      personId: 'p2',
      type: DebtType.iOwe,
      description: 'Compras',
      amountCents: 2000,
    );

    await provider.refresh();

    expect(provider.chartSlices, [
      const ChartSlice('Me deben', 5000),
      const ChartSlice('Debo', 2000),
    ]);
  });
}
