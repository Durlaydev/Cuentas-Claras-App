import 'package:uuid/uuid.dart';

import '../../models/payment.dart';
import '../local/payment_local_datasource.dart';
import 'payment_repository.dart';

/// Implementación de [PaymentRepository] respaldada por sqflite local
/// ([PaymentLocalDataSource]). Es la única capa que sabe generar ids y
/// manejar los metadatos de sincronización offline-first.
class LocalPaymentRepository implements PaymentRepository {
  LocalPaymentRepository(this._dataSource, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final PaymentLocalDataSource _dataSource;
  final Uuid _uuid;

  @override
  Future<Payment> createPayment({
    required String debtId,
    required int amountCents,
    DateTime? date,
    String? note,
  }) async {
    final payment = Payment(
      id: _uuid.v4(),
      debtId: debtId,
      amountCents: amountCents,
      date: date ?? DateTime.now(),
      note: note,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );
    await _dataSource.insert(payment);
    return payment;
  }

  @override
  Future<Payment?> getPaymentById(String id) => _dataSource.getById(id);

  @override
  Future<List<Payment>> getAllPayments({bool includeDeleted = false}) =>
      _dataSource.getAll(includeDeleted: includeDeleted);

  @override
  Future<List<Payment>> getPaymentsForDebt(String debtId, {bool includeDeleted = false}) =>
      _dataSource.getForDebt(debtId, includeDeleted: includeDeleted);

  @override
  Future<Payment> updatePayment(Payment payment) async {
    final updated = payment.copyWith(updatedAt: DateTime.now(), pendingSync: true);
    await _dataSource.update(updated);
    return updated;
  }

  @override
  Future<void> deletePayment(String id) => _dataSource.delete(id);

  @override
  Future<Payment> restorePayment(Payment original) async {
    final restored = original.copyWith(deleted: false, updatedAt: DateTime.now(), pendingSync: true);
    await _dataSource.update(restored);
    return restored;
  }
}
