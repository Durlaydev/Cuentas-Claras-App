import 'package:cuentas_claras/models/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime.fromMillisecondsSinceEpoch(1690000000000);
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Payment buildPayment({
    String id = 'pay1',
    String debtId = 'd1',
    int amountCents = 25000,
    DateTime? dateOverride,
    String? note = 'Pago parcial',
    DateTime? updatedAtOverride,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    return Payment(
      id: id,
      debtId: debtId,
      amountCents: amountCents,
      date: dateOverride ?? date,
      note: note,
      updatedAt: updatedAtOverride ?? updatedAt,
      pendingSync: pendingSync,
      deleted: deleted,
    );
  }

  test('amountCents <= 0 lanza ArgumentError', () {
    expect(() => buildPayment(amountCents: 0), throwsArgumentError);
    expect(() => buildPayment(amountCents: -500), throwsArgumentError);
  });

  test('toMap produce las columnas snake_case esperadas', () {
    final payment = buildPayment();
    final map = payment.toMap();

    expect(map['id'], 'pay1');
    expect(map['debt_id'], 'd1');
    expect(map['amount_cents'], 25000);
    expect(map['date'], date.millisecondsSinceEpoch);
    expect(map['note'], 'Pago parcial');
    expect(map['updated_at'], updatedAt.millisecondsSinceEpoch);
    expect(map['pending_sync'], 1);
    expect(map['deleted'], 0);
  });

  test('note nulo se guarda y se recupera como null', () {
    final payment = Payment(
      id: 'pay1',
      debtId: 'd1',
      amountCents: 25000,
      date: date,
      updatedAt: updatedAt,
    );
    final map = payment.toMap();

    expect(map['note'], isNull);
    expect(Payment.fromMap(map).note, isNull);
  });

  test('fromMap(toMap(x)) es igual a x (round-trip)', () {
    final payment = buildPayment();
    final roundTripped = Payment.fromMap(payment.toMap());

    expect(roundTripped, payment);
  });

  test('copyWith actualiza únicamente los campos indicados', () {
    final payment = buildPayment();
    final updated = payment.copyWith(amountCents: 30000);

    expect(updated.amountCents, 30000);
    expect(updated.id, payment.id);
    expect(updated.debtId, payment.debtId);
  });

  test('copyWith con amountCents <= 0 lanza ArgumentError', () {
    final payment = buildPayment();
    expect(() => payment.copyWith(amountCents: -1), throwsArgumentError);
  });

  test('dos instancias con el mismo contenido son iguales', () {
    final a = buildPayment();
    final b = buildPayment();

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('instancias con distinto monto no son iguales', () {
    final a = buildPayment(amountCents: 1000);
    final b = buildPayment(amountCents: 2000);

    expect(a == b, isFalse);
  });
}
