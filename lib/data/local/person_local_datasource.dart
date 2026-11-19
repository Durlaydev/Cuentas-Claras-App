import 'package:sqflite/sqflite.dart';

import '../../models/person.dart';
import 'app_database.dart';

/// Puerto (interfaz) con el subconjunto de operaciones sobre personas que
/// necesita `SyncService` para sincronizar con Firestore. Se extrae como
/// interfaz solo para que los tests de sincronización puedan usar un fake
/// en memoria en lugar de una base sqflite real; no cambia el
/// comportamiento de [PersonLocalDataSource].
abstract class PersonLocalPort {
  Future<void> insert(Person person);
  Future<void> update(Person person);
  Future<Person?> getById(String id);
  Future<List<Person>> getPendingSync();
  Future<void> markSynced(String id);
}

/// Acceso CRUD directo a la tabla `people`. No conoce reglas de negocio
/// (generación de id, `updatedAt`, etc.); eso vive en [LocalPersonRepository].
class PersonLocalDataSource implements PersonLocalPort {
  PersonLocalDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _table = AppDatabaseTables.people;

  /// Inserta una persona nueva. Si ya existe una fila con el mismo [Person.id]
  /// la reemplaza (comportamiento upsert), lo que también permite reutilizar
  /// este método para actualizaciones completas.
  @override
  Future<void> insert(Person person) => _upsert(person);

  /// Actualiza una persona existente. Internamente es el mismo upsert que
  /// [insert]; se expone con otro nombre para que el código llamador
  /// exprese su intención (crear vs. modificar).
  @override
  Future<void> update(Person person) => _upsert(person);

  Future<void> _upsert(Person person) async {
    final db = await _appDatabase.database;
    await db.insert(_table, person.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Busca una persona por id, sin filtrar por [Person.deleted]: una
  /// búsqueda puntual por id es explícita, a diferencia de un listado.
  @override
  Future<Person?> getById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Person.fromMap(rows.first);
  }

  /// Devuelve todas las personas. Por defecto excluye las marcadas como
  /// eliminadas (soft delete); [includeDeleted] permite traerlas también.
  Future<List<Person>> getAll({bool includeDeleted = false}) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      _table,
      where: includeDeleted ? null : 'deleted = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Person.fromMap).toList();
  }

  /// Soft delete: marca `deleted = 1`, `pending_sync = 1` (para que la
  /// eliminación se propague a Firestore más adelante) y actualiza
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

  /// Filas pendientes de sincronizar, para que el futuro `SyncService`
  /// sepa qué empujar a Firestore.
  @override
  Future<List<Person>> getPendingSync() async {
    final db = await _appDatabase.database;
    final rows = await db.query(_table, where: 'pending_sync = 1');
    return rows.map(Person.fromMap).toList();
  }

  /// Marca una fila como ya sincronizada (`pending_sync = 0`). La llamará
  /// el futuro `SyncService` después de subir el cambio con éxito.
  @override
  Future<void> markSynced(String id) async {
    final db = await _appDatabase.database;
    await db.update(_table, {'pending_sync': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
