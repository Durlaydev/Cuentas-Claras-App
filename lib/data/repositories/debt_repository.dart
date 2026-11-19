import '../../models/debt.dart';

/// Puerto que expone la capa de datos de deudas a providers/pantallas. La
/// UI depende únicamente de esta interfaz, nunca de `DebtLocalDataSource`
/// directamente, para que la implementación se pueda reemplazar o decorar
/// (por ejemplo con sincronización a Firestore) sin cambiar a quien la usa.
abstract class DebtRepository {
  /// Crea una deuda nueva. El repositorio decide `id` (uuid v4),
  /// `updatedAt` y `pendingSync = true`; quien llama solo aporta los
  /// campos de negocio.
  Future<Debt> createDebt({
    required String personId,
    required DebtType type,
    required String description,
    required int amountCents,
    DateTime? createdAt,
    DateTime? dueDate,
    DebtStatus status = DebtStatus.open,
  });

  /// Busca una deuda por id.
  Future<Debt?> getDebtById(String id);

  /// Devuelve todas las deudas (excluye eliminadas por defecto).
  Future<List<Debt>> getAllDebts({bool includeDeleted = false});

  /// Devuelve las deudas de una persona puntual (excluye eliminadas por
  /// defecto).
  Future<List<Debt>> getDebtsForPerson(String personId, {bool includeDeleted = false});

  /// Actualiza una deuda existente. El repositorio bump-ea `updatedAt` y
  /// vuelve a marcar `pendingSync = true`.
  Future<Debt> updateDebt(Debt debt);

  /// Elimina (soft delete) una deuda: la marca `deleted = true` y
  /// `pendingSync = true`, sin borrar la fila físicamente.
  Future<void> deleteDebt(String id);

  /// Restaura una deuda previamente eliminada, re-persistiendo [original]
  /// con `deleted = false`. Pensado para el flujo de "Deshacer" tras un
  /// borrado accidental (ver `DebtsProvider.restoreLastDeletedDebt`).
  Future<Debt> restoreDebt(Debt original);
}
