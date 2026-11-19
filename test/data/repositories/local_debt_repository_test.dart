import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/debt_local_datasource.dart';
import 'package:cuentas_claras/data/repositories/local_debt_repository.dart';
import 'package:cuentas_claras/models/debt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late DebtLocalDataSource dataSource;
  late LocalDebtRepository repository;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dataSource = DebtLocalDataSource(appDatabase);
    repository = LocalDebtRepository(dataSource);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<Debt> createSampleDebt({String personId = 'p1'}) {
    return repository.createDebt(
      personId: personId,
      type: DebtType.owedToMe,
      description: 'Almuerzo',
      amountCents: 10000,
    );
  }

  test('createDebt genera un id uuid y marca pendingSync=true', () async {
    final debt = await createSampleDebt();

    expect(debt.personId, 'p1');
    expect(debt.amountCents, 10000);
    expect(debt.pendingSync, isTrue);
    expect(() => Uuid.parse(debt.id), returnsNormally);
  });

  test('createDebt persiste la deuda en la base de datos', () async {
    final debt = await createSampleDebt();

    final fetched = await repository.getDebtById(debt.id);

    // sqflite guarda las fechas en milisegundos (ver Debt.toMap), así que
    // se compara contra la misma deuda truncada a esa precisión en lugar
    // de contra el DateTime.now() original (que trae microsegundos).
    expect(
      fetched,
      debt.copyWith(
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          debt.createdAt.millisecondsSinceEpoch,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          debt.updatedAt.millisecondsSinceEpoch,
        ),
      ),
    );
  });

  test('updateDebt bump-ea updatedAt y vuelve a marcar pendingSync=true', () async {
    final debt = await createSampleDebt();
    await dataSource.markSynced(debt.id);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    final updated = await repository.updateDebt(debt.copyWith(status: DebtStatus.paid));

    expect(updated.status, DebtStatus.paid);
    expect(updated.pendingSync, isTrue);
    expect(updated.updatedAt.isAfter(debt.updatedAt), isTrue);
  });

  test('deleteDebt hace soft delete: desaparece de getAllDebts pero sigue por id', () async {
    final debt = await createSampleDebt();

    await repository.deleteDebt(debt.id);

    final all = await repository.getAllDebts();
    expect(all, isEmpty);

    final fetched = await repository.getDebtById(debt.id);
    expect(fetched!.deleted, isTrue);
    expect(fetched.pendingSync, isTrue);
  });

  test('getDebtsForPerson filtra por persona', () async {
    await createSampleDebt(personId: 'p1');
    await createSampleDebt(personId: 'p2');

    final result = await repository.getDebtsForPerson('p1');

    expect(result.map((d) => d.personId), ['p1']);
  });

  test('getAllDebts devuelve todas las deudas no eliminadas', () async {
    await createSampleDebt(personId: 'p1');
    await createSampleDebt(personId: 'p2');

    final all = await repository.getAllDebts();

    expect(all.length, 2);
  });
}
