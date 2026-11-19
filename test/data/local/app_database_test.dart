import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('abre la base de datos sin lanzar errores', () async {
    final db = await appDatabase.database;
    expect(db.isOpen, isTrue);
  });

  test('devuelve la misma instancia en accesos repetidos', () async {
    final first = await appDatabase.database;
    final second = await appDatabase.database;
    expect(identical(first, second), isTrue);
  });

  test('crea las tablas people, debts y payments', () async {
    final db = await appDatabase.database;
    final tables = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table'",
    );
    final tableNames = tables.map((row) => row['name'] as String).toSet();

    expect(tableNames, containsAll(<String>['people', 'debts', 'payments']));
  });

  test('una base de datos nueva no tiene filas en ninguna tabla', () async {
    final db = await appDatabase.database;

    final people = await db.query('people');
    final debts = await db.query('debts');
    final payments = await db.query('payments');

    expect(people, isEmpty);
    expect(debts, isEmpty);
    expect(payments, isEmpty);
  });
}
