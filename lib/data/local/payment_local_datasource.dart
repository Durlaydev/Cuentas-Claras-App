import 'package:sqflite/sqflite.dart';

import '../../models/payment.dart';
import 'app_database.dart';

/// Puerto (interfaz) con el subconjunto de operaciones sobre pagos que
/// necesita `SyncService` para sincronizar con Firestore. Se extrae como
/// interfaz solo para que los tests de sincronización puedan usar un fake
/// en memoria en lugar de una base sqflite real; no cambia el
/// comportamiento de [PaymentLocalDataSource].
abstract class PaymentLocalPort {
  Future<void> insert(Payment payment);
  Future<void> update(Payment payment);
  Future<Payment?> getById(String id);
  Future<List<Payment>> getPendingSync();
  Future<void> markSynced(String id);
}

/// Acceso CRUD directo a la tabla `payments`. No conoce reglas de negocio
/// (generación de id, `updatedAt`, etc.); eso vive en [LocalPaymentRepository].
class PaymentLocalDataSource implements PaymentLocalPort {
  PaymentLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _table = AppDatabaseTables.payments;

  /// Inserta un pago nuevo (upsert por [Payment.id]).
  @override
  Future<void> insert(Payment payment) => _upsert(payment);

  /// Actualiza un pago existente. Mismo upsert que [insert], con nombre
  /// distinto para expresar intención en el código llamador.
  @override
  Future<void> update(Payment payment) => _upsert(payment);

  Future<void> _upsert(Payment payment) async {
    final db = await _appDatabase.database;
    await db.insert(_table, payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Busca un pago por id, sin filtrar por [Payment.deleted].
  @override
  Future<Payment?> getById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Payment.fromMap(rows.first);
  }

  /// Devuelve todos los pagos. Por defecto excluye los marcados como
  /// eliminados (soft delete); [includeDeleted] permite traerlos también.
  Future<List<Payment>> getAll({bool includeDeleted = false}) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: includeDeleted ? null : 'deleted = 0',
      orderBy: 'date DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// Devuelve los pagos de una deuda puntual.
  Future<List<Payment>> getForDebt(String debtId, {bool includeDeleted = false}) async {
    final db = await _appDatabase.database;
    final where = includeDeleted ? 'debt_id = ?' : 'debt_id = ? AND deleted = 0';
    final rows = await db.query(
      _table,
      where: where,
      whereArgs: [debtId],
      orderBy: 'date DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// Soft delete: marca `deleted = 1`, `pending_sync = 1` y actualiza
  /// `updated_at`. La fila NO se borra físicamente.
  Future<void> delete(String id) async {
    final db = await _appDatabase.database;
    await db.update(
      _table,
      {
        'deleted': 1,
        'pending_sync': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Filas pendientes de sincronizar, para el futuro `SyncService`.
  @override
  Future<List<Payment>> getPendingSync() async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, where: 'pending_sync = 1');
    return rows.map(Payment.fromMap).toList();
  }

  /// Marca una fila como ya sincronizada (`pending_sync = 0`).
  @override
  Future<void> markSynced(String id) async {
    final db = await _appDatabase.database;
    await db.update(_table, {'pending_sync': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
