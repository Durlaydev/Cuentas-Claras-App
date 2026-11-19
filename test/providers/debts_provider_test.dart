import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/providers/debts_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeDebtRepository debtRepository;
  late FakePaymentRepository paymentRepository;
  late DebtsProvider provider;

  setUp(() {
    debtRepository = FakeDebtRepository();
    paymentRepository = FakePaymentRepository();
    provider = DebtsProvider(debtRepository, paymentRepository);
  });

  test('loadAll fetches all debts and payments', () async {
    await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 1000,
    );

    await provider.loadAll();

    expect(provider.debts.length, 1);
    expect(provider.errorMessage, isNull);
  });

  test('addDebt persiste vía el repositorio y actualiza el estado en memoria', () async {
    await provider.addDebt(
      personId: 'p1',
      type: DebtType.iOwe,
      description: 'Compras',
      amountCents: 2000,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(provider.debts.length, 1);
    expect(debtRepository.debts.length, 1);
    expect(provider.debts.single.description, 'Compras');
  });

  test('updateDebt persiste los cambios', () async {
    final debt = await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.iOwe,
      description: 'Compras',
      amountCents: 2000,
    );
    await provider.loadAll();

    await provider.updateDebt(debt.copyWith(description: 'Compras varias'));

    expect(provider.debts.single.description, 'Compras varias');
    expect(debtRepository.debts.single.description, 'Compras varias');
  });

  test('markPaid cambia el estado a pagada y el saldo pasa a 0', () async {
    final debt = await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 3000,
    );
    await provider.loadAll();

    await provider.markPaid(debt.id);

    final updated = provider.debts.single;
    expect(updated.status, DebtStatus.paid);
    expect(provider.debtBalance(updated), 0);
  });

  test('registerPayment reduce el saldo de la deuda', () async {
    final debt = await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 3000,
    );
    await provider.loadAll();

    await provider.registerPayment(debtId: debt.id, amountCents: 1000, date: DateTime(2026, 1, 5));

    expect(provider.paymentsForDebt(debt.id).length, 1);
    expect(provider.debtBalance(debt), 2000);
  });

  test('deleteDebt saca la deuda de la lista visible y restoreLastDeletedDebt la recupera', () async {
    final debt = await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 3000,
    );
    await provider.loadAll();

    await provider.deleteDebt(debt.id);
    expect(provider.debts, isEmpty);
    expect(debtRepository.debts.single.deleted, isTrue);

    await provider.restoreLastDeletedDebt();
    expect(provider.debts.map((d) => d.id), [debt.id]);
    expect(provider.debts.single.deleted, isFalse);
  });

  test('deletePayment saca el pago de la lista visible y restoreLastDeletedPayment lo recupera', () async {
    final debt = await debtRepository.createDebt(
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Cena',
      amountCents: 3000,
    );
    await provider.loadAll();
    await provider.registerPayment(debtId: debt.id, amountCents: 1000, date: DateTime(2026, 1, 5));
    final payment = provider.paymentsForDebt(debt.id).single;

    await provider.deletePayment(payment.id);
    expect(provider.paymentsForDebt(debt.id), isEmpty);

    await provider.restoreLastDeletedPayment();
    expect(provider.paymentsForDebt(debt.id).map((p) => p.id), [payment.id]);
  });

  group('filtered', () {
    test('DebtFilter.all devuelve todas las deudas', () async {
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Cena',
        amountCents: 1000,
      );
      await debtRepository.createDebt(
        personId: 'p2',
        type: DebtType.iOwe,
        description: 'Compras',
        amountCents: 2000,
      );
      await provider.loadAll();

      expect(provider.filtered().length, 2);
    });

    test('DebtFilter.owedToMe devuelve solo deudas de ese tipo', () async {
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Cena',
        amountCents: 1000,
      );
      await debtRepository.createDebt(
        personId: 'p2',
        type: DebtType.iOwe,
        description: 'Compras',
        amountCents: 2000,
      );
      await provider.loadAll();

      final result = provider.filtered(filter: DebtFilter.owedToMe);
      expect(result.length, 1);
      expect(result.every((d) => d.type == DebtType.owedToMe), isTrue);
    });

    test('DebtFilter.iOwe devuelve solo deudas de ese tipo', () async {
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Cena',
        amountCents: 1000,
      );
      await debtRepository.createDebt(
        personId: 'p2',
        type: DebtType.iOwe,
        description: 'Compras',
        amountCents: 2000,
      );
      await provider.loadAll();

      final result = provider.filtered(filter: DebtFilter.iOwe);
      expect(result.length, 1);
      expect(result.every((d) => d.type == DebtType.iOwe), isTrue);
    });

    test('DebtFilter.overdue devuelve solo deudas abiertas vencidas', () async {
      final past = DateTime.now().subtract(const Duration(days: 3));
      final future = DateTime.now().add(const Duration(days: 3));
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Vencida',
        amountCents: 1000,
        dueDate: past,
      );
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Vigente',
        amountCents: 1000,
        dueDate: future,
      );
      await provider.loadAll();

      final result = provider.filtered(filter: DebtFilter.overdue);
      expect(result.length, 1);
      expect(result.single.description, 'Vencida');
    });

    test('DebtFilter.overdue excluye deudas ya pagadas aunque tengan fecha vencida', () async {
      final past = DateTime.now().subtract(const Duration(days: 3));
      final debt = await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Vencida pagada',
        amountCents: 1000,
        dueDate: past,
      );
      await debtRepository.updateDebt(debt.copyWith(status: DebtStatus.paid));
      await provider.loadAll();

      expect(provider.filtered(filter: DebtFilter.overdue), isEmpty);
    });

    test('el query filtra por descripción sin importar mayúsculas/minúsculas', () async {
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Cena en lo de Beto',
        amountCents: 1000,
      );
      await provider.loadAll();

      expect(provider.filtered(query: 'CENA').length, 1);
      expect(provider.filtered(query: 'inexistente'), isEmpty);
    });

    test('el query también matchea contra el nombre de persona resuelto', () async {
      await debtRepository.createDebt(
        personId: 'p1',
        type: DebtType.owedToMe,
        description: 'Cena',
        amountCents: 1000,
      );
      await provider.loadAll();

      final result = provider.filtered(
        query: 'ana',
        personNameResolver: (personId) => personId == 'p1' ? 'Ana' : 'Desconocido',
      );

      expect(result.length, 1);
    });
  });
}
