import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/person_local_datasource.dart';
import 'package:cuentas_claras/models/person.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late PersonLocalDataSource dataSource;

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Person buildPerson({
    String id = 'p1',
    String name = 'Ana',
    String? phone,
    String? note,
    DateTime? updatedAt,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    return Person(
      id: id,
      name: name,
      phone: phone,
      note: note,
      updatedAt: updatedAt ?? now,
      pendingSync: pendingSync,
      deleted: deleted,
    );
  }

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dataSource = PersonLocalDataSource(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('insert + getById devuelve la misma persona', () async {
    final person = buildPerson();
    await dataSource.insert(person);

    final fetched = await dataSource.getById(person.id);

    expect(fetched, person);
  });

  test('getById devuelve null si no existe', () async {
    final fetched = await dataSource.getById('no-existe');
    expect(fetched, isNull);
  });

  test('getAll excluye eliminados por defecto', () async {
    await dataSource.insert(buildPerson(id: 'p1', name: 'Ana'));
    await dataSource.insert(buildPerson(id: 'p2', name: 'Beto', deleted: true));

    final all = await dataSource.getAll();

    expect(all.map((p) => p.id), ['p1']);
  });

  test('getAll con includeDeleted trae también los eliminados', () async {
    await dataSource.insert(buildPerson(id: 'p1', name: 'Ana'));
    await dataSource.insert(buildPerson(id: 'p2', name: 'Beto', deleted: true));

    final all = await dataSource.getAll(includeDeleted: true);

    expect(all.map((p) => p.id).toSet(), {'p1', 'p2'});
  });

  test('delete marca deleted=true, pendingSync=true y actualiza updatedAt', () async {
    final original = buildPerson(
      pendingSync: false,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await dataSource.insert(original);

    await dataSource.delete(original.id);

    final fetched = await dataSource.getById(original.id);
    expect(fetched!.deleted, isTrue);
    expect(fetched.pendingSync, isTrue);
    expect(fetched.updatedAt.isAfter(original.updatedAt), isTrue);
  });

  test('update sobrescribe los campos de una persona existente', () async {
    final original = buildPerson(name: 'Ana');
    await dataSource.insert(original);

    final updated = original.copyWith(name: 'Ana María');
    await dataSource.update(updated);

    final fetched = await dataSource.getById(original.id);
    expect(fetched!.name, 'Ana María');
  });

  test('getPendingSync devuelve solo las filas pendientes', () async {
    await dataSource.insert(buildPerson(id: 'p1', pendingSync: true));
    await dataSource.insert(buildPerson(id: 'p2', pendingSync: false));

    final pending = await dataSource.getPendingSync();

    expect(pending.map((p) => p.id), ['p1']);
  });

  test('markSynced limpia el flag pendingSync', () async {
    await dataSource.insert(buildPerson(id: 'p1', pendingSync: true));

    await dataSource.markSynced('p1');

    final fetched = await dataSource.getById('p1');
    expect(fetched!.pendingSync, isFalse);
  });
}
