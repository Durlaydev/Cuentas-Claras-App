import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/models/payment.dart';
import 'package:cuentas_claras/utils/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Debt buildDebt({
    String id = 'd1',
    String personId = 'p1',
    DebtType type = DebtType.owedToMe,
    int amountCents = 100000,
    DebtStatus status = DebtStatus.open,
    bool deleted = false,
  }) {
    return Debt(
      id: id,
      personId: personId,
      type: type,
      description: 'Deuda de prueba',
      amountCents: amountCents,
      createdAt: now,
      status: status,
      updatedAt: now,
      deleted: deleted,
    );
  }

  Payment buildPayment({
    String id = 'pay1',
    required String debtId,
    required int amountCents,
    bool deleted = false,
  }) {
    return Payment(
      id: id,
      debtId: debtId,
      amountCents: amountCents,
      date: now,
      updatedAt: now,
      deleted: deleted,
    );
  }

  group('debtBalanceCents', () {
    test('sin pagos, el saldo es el monto total de la deuda', () {
      final debt = buildDebt(amountCents: 100000);
      expect(debtBalanceCents(debt, []), 100000);
    });

    test('con pago parcial, el saldo se reduce', () {
      final debt = buildDebt(amountCents: 100000);
      final payments = [
        buildPayment(debtId: debt.id, amountCents: 30000),
      ];
      expect(debtBalanceCents(debt, payments), 70000);
    });

    test('varios pagos parciales se suman', () {
      final debt = buildDebt(amountCents: 100000);
      final payments = [
        buildPayment(id: 'pay1', debtId: debt.id, amountCents: 30000),
        buildPayment(id: 'pay2', debtId: debt.id, amountCents: 20000),
      ];
      expect(debtBalanceCents(debt, payments), 50000);
    });

    test('pagos eliminados (deleted) no descuentan del saldo', () {
      final debt = buildDebt(amountCents: 100000);
      final payments = [
        buildPayment(debtId: debt.id, amountCents: 30000, deleted: true),
      ];
      expect(debtBalanceCents(debt, payments), 100000);
    });

    test('el sobrepago deja el saldo clamperado en 0, nunca negativo', () {
      final debt = buildDebt(amountCents: 100000);
      final payments = [
        buildPayment(debtId: debt.id, amountCents: 150000),
      ];
      expect(debtBalanceCents(debt, payments), 0);
    });

    test('una deuda marcada como pagada tiene saldo 0 aunque no haya pagos registrados', () {
      final debt = buildDebt(amountCents: 100000, status: DebtStatus.paid);
      expect(debtBalanceCents(debt, []), 0);
    });
  });

  group('personNetBalanceCents', () {
    test('una deuda owedToMe suma positivo al neto', () {
      final debt = buildDebt(type: DebtType.owedToMe, amountCents: 100000);
      expect(personNetBalanceCents([debt], []), 100000);
    });

    test('una deuda iOwe resta del neto', () {
      final debt = buildDebt(type: DebtType.iOwe, amountCents: 100000);
      expect(personNetBalanceCents([debt], []), -100000);
    });

    test('mezcla de owedToMe e iOwe calcula el neto correctamente', () {
      final owedToMe = buildDebt(
        id: 'd1',
        type: DebtType.owedToMe,
        amountCents: 100000,
      );
      final iOwe = buildDebt(id: 'd2', type: DebtType.iOwe, amountCents: 40000);
      expect(personNetBalanceCents([owedToMe, iOwe], []), 60000);
    });

    test('los pagos reducen el saldo de cada deuda antes de sumar al neto', () {
      final owedToMe = buildDebt(
        id: 'd1',
        type: DebtType.owedToMe,
        amountCents: 100000,
      );
      final payments = [
        buildPayment(debtId: 'd1', amountCents: 30000),
      ];
      expect(personNetBalanceCents([owedToMe], payments), 70000);
    });

    test('deudas eliminadas (deleted) no se cuentan en el neto', () {
      final debt = buildDebt(
        type: DebtType.owedToMe,
        amountCents: 100000,
        deleted: true,
      );
      expect(personNetBalanceCents([debt], []), 0);
    });

    test('una deuda pagada no aporta al neto', () {
      final debt = buildDebt(
        type: DebtType.iOwe,
        amountCents: 100000,
        status: DebtStatus.paid,
      );
      expect(personNetBalanceCents([debt], []), 0);
    });
  });

  group('computeGlobalSummary', () {
    test('agrupa por tipo de deuda entre todas las personas', () {
      final debts = [
        buildDebt(
          id: 'd1',
          personId: 'p1',
          type: DebtType.owedToMe,
          amountCents: 100000,
        ),
        buildDebt(
          id: 'd2',
          personId: 'p2',
          type: DebtType.owedToMe,
          amountCents: 50000,
        ),
        buildDebt(
          id: 'd3',
          personId: 'p1',
          type: DebtType.iOwe,
          amountCents: 30000,
        ),
      ];

      final summary = computeGlobalSummary(debts, []);

      expect(summary.totalOwedToMeCents, 150000);
      expect(summary.totalIOweCents, 30000);
      expect(summary.netCents, 120000);
    });

    test('descuenta pagos y respeta deudas pagadas/eliminadas', () {
      final debts = [
        buildDebt(
          id: 'd1',
          type: DebtType.owedToMe,
          amountCents: 100000,
        ),
        buildDebt(
          id: 'd2',
          type: DebtType.iOwe,
          amountCents: 50000,
          status: DebtStatus.paid,
        ),
        buildDebt(
          id: 'd3',
          type: DebtType.iOwe,
          amountCents: 20000,
          deleted: true,
        ),
      ];
      final payments = [
        buildPayment(debtId: 'd1', amountCents: 40000),
      ];

      final summary = computeGlobalSummary(debts, payments);

      expect(summary.totalOwedToMeCents, 60000);
      expect(summary.totalIOweCents, 0);
      expect(summary.netCents, 60000);
    });

    test('summary con los mismos valores es igual (value equality)', () {
      const a = GlobalBalanceSummary(
        totalOwedToMeCents: 100,
        totalIOweCents: 50,
        netCents: 50,
      );
      const b = GlobalBalanceSummary(
        totalOwedToMeCents: 100,
        totalIOweCents: 50,
        netCents: 50,
      );
      expect(a, b);
    });
  });
}
