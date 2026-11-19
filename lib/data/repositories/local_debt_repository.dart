import 'package:uuid/uuid.dart';

import '../../models/debt.dart';
import '../local/debt_local_datasource.dart';
import 'debt_repository.dart';

/// Implementación de [DebtRepository] respaldada por sqflite local
/// ([DebtLocalDataSource]). Es la única capa que sabe generar ids y
/// manejar los metadatos de sincronización offline-first.
class LocalDebtRepository implements DebtRepository {
  LocalDebtRepository(this._dataSource, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final DebtLocalDataSource _dataSource;
  final Uuid _uuid;

  @override
  Future<Debt> createDebt({
    required String personId,
    required DebtType type,
    required String description,
    required int amountCents,
    DateTime? createdAt,
    DateTime? dueDate,
    DebtStatus status = DebtStatus.open,
  }) async {
    final now = DateTime.now();
    final debt = Debt(
      id: _uuid.v4(),
      personId: personId,
      type: type,
      description: description,
      amountCents: amountCents,
      createdAt: createdAt ?? now,
      dueDate: dueDate,
      status: status,
      updatedAt: now,
      pendingSync: true,
    );
    await _dataSource.insert(debt);
    return debt;
  }

  @override
  Future<Debt?> getDebtById(String id) => _dataSource.getById(id);

  @override
  Future<List<Debt>> getAllDebts({bool includeDeleted = false}) =>
      _dataSource.getAll(includeDeleted: includeDeleted);

  @override
  Future<List<Debt>> getDebtsForPerson(String personId, {bool includeDeleted = false}) =>
      _dataSource.getForPerson(personId, includeDeleted: includeDeleted);

  @override
  Future<Debt> updateDebt(Debt debt) async {
    final updated = debt.copyWith(updatedAt: DateTime.now(), pendingSync: true);
    await _dataSource.update(updated);
    return updated;
  }

  @override
  Future<void> deleteDebt(String id) => _dataSource.delete(id);

  @override
  Future<Debt> restoreDebt(Debt original) async {
    final restored = original.copyWith(deleted: false, updatedAt: DateTime.now(), pendingSync: true);
    await _dataSource.update(restored);
    return restored;
  }
}
