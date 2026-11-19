import 'package:cuentas_claras/models/debt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.fromMillisecondsSinceEpoch(1690000000000);
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  final dueDate = DateTime.fromMillisecondsSinceEpoch(1710000000000);

  Debt buildDebt({
    String id = 'd1',
    String personId = 'p1',
    DebtType type = DebtType.owedToMe,
    String description = 'Prestamo para el alquiler',
    int amountCents = 500000,
    DateTime? createdAtOverride,
    DateTime? dueDateOverride,
    DebtStatus status = DebtStatus.open,
    DateTime? updatedAtOverride,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    return Debt(
      id: id,
      personId: personId,
      type: type,
      description: description,
      amountCents: amountCents,
      createdAt: createdAtOverride ?? createdAt,
      dueDate: dueDateOverride ?? dueDate,
      status: status,
      updatedAt: updatedAtOverride ?? updatedAt,
      pendingSync: pendingSync,
      deleted: deleted,
    );
  }

  test('amountCents <= 0 lanza ArgumentError', () {
    expect(
      () => buildDebt(amountCents: 0),
      throwsArgumentError,
    );
    expect(
      () => buildDebt(amountCents: -100),
      throwsArgumentError,
    );
  });

  test('toMap almacena el tipo y el estado como strings snake_case', () {
    final debt = buildDebt(type: DebtType.iOwe, status: DebtStatus.paid);
    final map = debt.toMap();

    expect(map['type'], 'i_owe');
    expect(map['status'], 'paid');
    expect(map['amount_cents'], 500000);
    expect(map['created_at'], createdAt.millisecondsSinceEpoch);
    expect(map['due_date'], dueDate.millisecondsSinceEpoch);
    expect(map['updated_at'], updatedAt.millisecondsSinceEpoch);
    expect(map['pending_sync'], 1);
    expect(map['deleted'], 0);
  });

  test('toMap con owedToMe y open usa las claves esperadas', () {
    final debt = buildDebt(type: DebtType.owedToMe, status: DebtStatus.open);
    final map = debt.toMap();

    expect(map['type'], 'owed_to_me');
    expect(map['status'], 'open');
  });

  test('dueDate nulo se guarda y se recupera como null', () {
    final debt = Debt(
      id: 'd1',
      personId: 'p1',
      type: DebtType.owedToMe,
      description: 'Prestamo sin vencimiento',
      amountCents: 500000,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    final map = debt.toMap();

    expect(map['due_date'], isNull);
    expect(Debt.fromMap(map).dueDate, isNull);
  });

  test('fromMap(toMap(x)) es igual a x (round-trip)', () {
    final debt = buildDebt();
    final roundTripped = Debt.fromMap(debt.toMap());

    expect(roundTripped, debt);
  });

  test('copyWith actualiza únicamente los campos indicados', () {
    final debt = buildDebt();
    final updated = debt.copyWith(status: DebtStatus.paid);

    expect(updated.status, DebtStatus.paid);
    expect(updated.amountCents, debt.amountCents);
    expect(updated.id, debt.id);
  });

  test('copyWith con amountCents <= 0 lanza ArgumentError', () {
    final debt = buildDebt();
    expect(() => debt.copyWith(amountCents: 0), throwsArgumentError);
  });

  test('dos instancias con el mismo contenido son iguales', () {
    final a = buildDebt();
    final b = buildDebt();

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('instancias con distinto tipo no son iguales', () {
    final a = buildDebt(type: DebtType.owedToMe);
    final b = buildDebt(type: DebtType.iOwe);

    expect(a == b, isFalse);
  });
}
