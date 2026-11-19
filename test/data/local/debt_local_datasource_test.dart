import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/debt_local_datasource.dart';
import 'package:cuentas_claras/models/debt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late DebtLocalDataSource dataSource;

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Debt buildDebt({
    String id = 'd1',
    String personId = 'p1',
    DebtType type = DebtType.owedToMe,
    int amountCents = 10000,
    DateTime? updatedAt,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    return Debt(
      id: id,
      personId: personId,
      type: type,
      description: 'Deuda de prueba',
      amountCents: amountCents,
      createdAt: now,
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
    dataSource = DebtLocalDataSource(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('insert + getById devuelve la misma deuda', () async {
    final debt = buildDebt();
    await dataSource.insert(debt);

    final fetched = await dataSource.getById(debt.id);

    expect(fetched, debt);
  });

  test('getById devuelve null si no existe', () async {
    final fetched = await dataSource.getById('no-existe');
    expect(fetched, isNull);
  });

  test('getAll excluye eliminadas por defecto', () async {
    await dataSource.insert(buildDebt(id: 'd1'));
    await dataSource.insert(buildDebt(id: 'd2', deleted: true));

    final all = await dataSource.getAll();

    expect(all.map((d) => d.id), ['d1']);
  });

  test('getAll con includeDeleted trae también las eliminadas', () async {
    await dataSource.insert(buildDebt(id: 'd1'));
    await dataSource.insert(buildDebt(id: 'd2', deleted: true));

    final all = await dataSource.getAll(includeDeleted: true);

    expect(all.map((d) => d.id).toSet(), {'d1', 'd2'});
  });

  test('getForPerson filtra por personId y excluye eliminadas', () async {
    await dataSource.insert(buildDebt(id: 'd1', personId: 'p1'));
    await dataSource.insert(buildDebt(id: 'd2', personId: 'p2'));
    await dataSource.insert(buildDebt(id: 'd3', personId: 'p1', deleted: true));

    final result = await dataSource.getForPerson('p1');

    expect(result.map((d) => d.id), ['d1']);
  });

  test('delete marca deleted=true, pendingSync=true y actualiza updatedAt', () async {
    final original = buildDebt(
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

  test('getPendingSync devuelve solo las filas pendientes', () async {
    await dataSource.insert(buildDebt(id: 'd1', pendingSync: true));
    await dataSource.insert(buildDebt(id: 'd2', pendingSync: false));

    final pending = await dataSource.getPendingSync();

    expect(pending.map((d) => d.id), ['d1']);
  });

  test('markSynced limpia el flag pendingSync', () async {
    await dataSource.insert(buildDebt(id: 'd1', pendingSync: true));

    await dataSource.markSynced('d1');

    final fetched = await dataSource.getById('d1');
    expect(fetched!.pendingSync, isFalse);
  });
}
