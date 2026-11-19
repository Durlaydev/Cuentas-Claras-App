import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/payment_local_datasource.dart';
import 'package:cuentas_claras/models/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late PaymentLocalDataSource dataSource;

  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Payment buildPayment({
    String id = 'pay1',
    String debtId = 'd1',
    int amountCents = 5000,
    DateTime? updatedAt,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    return Payment(
      id: id,
      debtId: debtId,
      amountCents: amountCents,
      date: now,
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
    dataSource = PaymentLocalDataSource(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('insert + getById devuelve el mismo pago', () async {
    final payment = buildPayment();
    await dataSource.insert(payment);

    final fetched = await dataSource.getById(payment.id);

    expect(fetched, payment);
  });

  test('getById devuelve null si no existe', () async {
    final fetched = await dataSource.getById('no-existe');
    expect(fetched, isNull);
  });

  test('getAll excluye eliminados por defecto', () async {
    await dataSource.insert(buildPayment(id: 'pay1'));
    await dataSource.insert(buildPayment(id: 'pay2', deleted: true));

    final all = await dataSource.getAll();

    expect(all.map((p) => p.id), ['pay1']);
  });

  test('getAll con includeDeleted trae también los eliminados', () async {
    await dataSource.insert(buildPayment(id: 'pay1'));
    await dataSource.insert(buildPayment(id: 'pay2', deleted: true));

    final all = await dataSource.getAll(includeDeleted: true);

    expect(all.map((p) => p.id).toSet(), {'pay1', 'pay2'});
  });

  test('getForDebt filtra por debtId y excluye eliminados', () async {
    await dataSource.insert(buildPayment(id: 'pay1', debtId: 'd1'));
    await dataSource.insert(buildPayment(id: 'pay2', debtId: 'd2'));
    await dataSource.insert(buildPayment(id: 'pay3', debtId: 'd1', deleted: true));

    final result = await dataSource.getForDebt('d1');

    expect(result.map((p) => p.id), ['pay1']);
  });

  test('delete marca deleted=true, pendingSync=true y actualiza updatedAt', () async {
    final original = buildPayment(
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
    await dataSource.insert(buildPayment(id: 'pay1', pendingSync: true));
    await dataSource.insert(buildPayment(id: 'pay2', pendingSync: false));

    final pending = await dataSource.getPendingSync();

    expect(pending.map((p) => p.id), ['pay1']);
  });

  test('markSynced limpia el flag pendingSync', () async {
    await dataSource.insert(buildPayment(id: 'pay1', pendingSync: true));

    await dataSource.markSynced('pay1');

    final fetched = await dataSource.getById('pay1');
    expect(fetched!.pendingSync, isFalse);
  });
}
