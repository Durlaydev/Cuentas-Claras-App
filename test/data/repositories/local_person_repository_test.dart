import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/person_local_datasource.dart';
import 'package:cuentas_claras/data/repositories/local_person_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late PersonLocalDataSource dataSource;
  late LocalPersonRepository repository;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dataSource = PersonLocalDataSource(appDatabase);
    repository = LocalPersonRepository(dataSource);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('createPerson genera un id uuid y marca pendingSync=true', () async {
    final person = await repository.createPerson(name: 'Ana', phone: '111');

    expect(person.name, 'Ana');
    expect(person.phone, '111');
    expect(person.pendingSync, isTrue);
    expect(() => Uuid.parse(person.id), returnsNormally);
  });

  test('createPerson persiste la persona en la base de datos', () async {
    final person = await repository.createPerson(name: 'Ana');

    final fetched = await repository.getPersonById(person.id);

    // sqflite guarda las fechas en milisegundos (ver Person.toMap), así
    // que se compara contra la misma persona truncada a esa precisión en
    // lugar de contra el DateTime.now() original (que trae microsegundos).
    expect(
      fetched,
      person.copyWith(
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          person.updatedAt.millisecondsSinceEpoch,
        ),
      ),
    );
  });

  test('updatePerson bump-ea updatedAt y vuelve a marcar pendingSync=true', () async {
    final person = await repository.createPerson(name: 'Ana');
    await dataSource.markSynced(person.id);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    final updated = await repository.updatePerson(person.copyWith(name: 'Ana María'));

    expect(updated.name, 'Ana María');
    expect(updated.pendingSync, isTrue);
    expect(updated.updatedAt.isAfter(person.updatedAt), isTrue);

    final fetched = await repository.getPersonById(person.id);
    expect(fetched!.name, 'Ana María');
    expect(fetched.pendingSync, isTrue);
  });

  test('deletePerson hace soft delete: desaparece de getAllPeople pero sigue por id', () async {
    final person = await repository.createPerson(name: 'Ana');

    await repository.deletePerson(person.id);

    final all = await repository.getAllPeople();
    expect(all, isEmpty);

    final allIncludingDeleted = await repository.getAllPeople(includeDeleted: true);
    expect(allIncludingDeleted.map((p) => p.id), [person.id]);

    final fetched = await repository.getPersonById(person.id);
    expect(fetched!.deleted, isTrue);
    expect(fetched.pendingSync, isTrue);
  });

  test('getAllPeople devuelve todas las personas no eliminadas', () async {
    await repository.createPerson(name: 'Ana');
    await repository.createPerson(name: 'Beto');

    final all = await repository.getAllPeople();

    expect(all.map((p) => p.name).toSet(), {'Ana', 'Beto'});
  });
}
