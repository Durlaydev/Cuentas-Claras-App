import '../../models/payment.dart';

/// Puerto que expone la capa de datos de pagos a providers/pantallas. La
/// UI depende únicamente de esta interfaz, nunca de `PaymentLocalDataSource`
/// directamente, para que la implementación se pueda reemplazar o decorar
/// (por ejemplo con sincronización a Firestore) sin cambiar a quien la usa.
abstract class PaymentRepository {
  /// Crea un pago nuevo. El repositorio decide `id` (uuid v4), `updatedAt`
  /// y `pendingSync = true`; quien llama solo aporta los campos de
  /// negocio.
  Future<Payment> createPayment({
    required String debtId,
    required int amountCents,
    DateTime? date,
    String? note,
  });

  /// Busca un pago por id.
  Future<Payment?> getPaymentById(String id);

  /// Devuelve todos los pagos (excluye eliminados por defecto).
  Future<List<Payment>> getAllPayments({bool includeDeleted = false});

  /// Devuelve los pagos de una deuda puntual (excluye eliminados por
  /// defecto).
  Future<List<Payment>> getPaymentsForDebt(String debtId, {bool includeDeleted = false});

  /// Actualiza un pago existente. El repositorio bump-ea `updatedAt` y
  /// vuelve a marcar `pendingSync = true`.
  Future<Payment> updatePayment(Payment payment);

  /// Elimina (soft delete) un pago: lo marca `deleted = true` y
  /// `pendingSync = true`, sin borrar la fila físicamente.
  Future<void> deletePayment(String id);

  /// Restaura un pago previamente eliminado, re-persistiendo [original] con
  /// `deleted = false`. Pensado para el flujo de "Deshacer" tras un borrado
  /// accidental (ver `DebtsProvider.restoreLastDeletedPayment`).
  Future<Payment> restorePayment(Payment original);
}
