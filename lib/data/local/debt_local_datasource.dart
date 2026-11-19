import 'package:sqflite/sqflite.dart';

import '../../models/debt.dart';
import 'app_database.dart';

/// Puerto (interfaz) con el subconjunto de operaciones sobre deudas que
/// necesita `SyncService` para sincronizar con Firestore. Se extrae como
/// interfaz solo para que los tests de sincronización puedan usar un fake
/// en memoria en lugar de una base sqflite real; no cambia el
/// comportamiento de [DebtLocalDataSource].
abstract class DebtLocalPort {
  Future<void> insert(Debt debt);
  Future<void> update(Debt debt);
  Future<Debt?> getById(String id);
  Future<List<Debt>> getPendingSync();
  Future<void> markSynced(String id);
}

/// Acceso CRUD directo a la tabla `debts`. No conoce reglas de negocio
/// (generación de id, `updatedAt`, etc.); eso vive en [LocalDebtRepository].
class DebtLocalDataSource implements DebtLocalPort {
  DebtLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _table = AppDatabaseTables.debts;

  /// Inserta una deuda nueva (upsert por [Debt.id]).
  @override
  Future<void> insert(Debt debt) => _upsert(debt);

  /// Actualiza una deuda existente. Mismo upsert que [insert], con nombre
  /// distinto para expresar intención en el código llamador.
  @override
  Future<void> update(Debt debt) => _upsert(debt);

  Future<void> _upsert(Debt debt) async {
    final db = await _appDatabase.database;
    await db.insert(_table, debt.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Busca una deuda por id, sin filtrar por [Debt.deleted].
  @override
  Future<Debt?> getById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Debt.fromMap(rows.first);
  }

  /// Devuelve todas las deudas. Por defecto excluye las marcadas como
  /// eliminadas (soft delete); [includeDeleted] permite traerlas también.
  Future<List<Debt>> getAll({bool includeDeleted = false}) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: includeDeleted ? null : 'deleted = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(Debt.fromMap).toList();
  }

  /// Devuelve las deudas de una persona puntual.
  Future<List<Debt>> getForPerson(String personId, {bool includeDeleted = false}) async {
    final db = await _appDatabase.database;
    final where = includeDeleted ? 'person_id = ?' : 'person_id = ? AND deleted = 0';
    final rows = await db.query(
      _table,
      where: where,
      whereArgs: [personId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Debt.fromMap).toList();
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
  Future<List<Debt>> getPendingSync() async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, where: 'pending_sync = 1');
    return rows.map(Debt.fromMap).toList();
  }

  /// Marca una fila como ya sincronizada (`pending_sync = 0`).
  @override
  Future<void> markSynced(String id) async {
    final db = await _appDatabase.database;
    await db.update(_table, {'pending_sync': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
