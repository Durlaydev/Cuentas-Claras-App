import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/payment_local_datasource.dart';
import 'package:cuentas_claras/data/repositories/local_payment_repository.dart';
import 'package:cuentas_claras/models/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late PaymentLocalDataSource dataSource;
  late LocalPaymentRepository repository;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    dataSource = PaymentLocalDataSource(appDatabase);
    repository = LocalPaymentRepository(dataSource);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<Payment> createSamplePayment({String debtId = 'd1', int amountCents = 3000}) {
    return repository.createPayment(debtId: debtId, amountCents: amountCents);
  }

  test('createPayment genera un id uuid y marca pendingSync=true', () async {
    final payment = await createSamplePayment();

    expect(payment.debtId, 'd1');
    expect(payment.amountCents, 3000);
    expect(payment.pendingSync, isTrue);
    expect(() => Uuid.parse(payment.id), returnsNormally);
  });

  test('createPayment persiste el pago en la base de datos', () async {
    final payment = await createSamplePayment();

    final fetched = await repository.getPaymentById(payment.id);

    // sqflite guarda las fechas en milisegundos (ver Payment.toMap), así
    // que se compara contra el mismo pago truncado a esa precisión en
    // lugar de contra el DateTime.now() original (que trae microsegundos).
    expect(
      fetched,
      payment.copyWith(
        date: DateTime.fromMillisecondsSinceEpoch(payment.date.millisecondsSinceEpoch),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          payment.updatedAt.millisecondsSinceEpoch,
        ),
      ),
    );
  });

  test('updatePayment bump-ea updatedAt y vuelve a marcar pendingSync=true', () async {
    final payment = await createSamplePayment();
    await dataSource.markSynced(payment.id);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    final updated = await repository.updatePayment(payment.copyWith(note: 'Ajustado'));

    expect(updated.note, 'Ajustado');
    expect(updated.pendingSync, isTrue);
    expect(updated.updatedAt.isAfter(payment.updatedAt), isTrue);
  });

  test('deletePayment hace soft delete: desaparece de getAllPayments pero sigue por id', () async {
    final payment = await createSamplePayment();

    await repository.deletePayment(payment.id);

    final all = await repository.getAllPayments();
    expect(all, isEmpty);

    final fetched = await repository.getPaymentById(payment.id);
    expect(fetched!.deleted, isTrue);
    expect(fetched.pendingSync, isTrue);
  });

  test('getPaymentsForDebt filtra por deuda', () async {
    await createSamplePayment(debtId: 'd1');
    await createSamplePayment(debtId: 'd2');

    final result = await repository.getPaymentsForDebt('d1');

    expect(result.map((p) => p.debtId), ['d1']);
  });

  test('getAllPayments devuelve todos los pagos no eliminados', () async {
    await createSamplePayment(debtId: 'd1');
    await createSamplePayment(debtId: 'd2');

    final all = await repository.getAllPayments();

    expect(all.length, 2);
  });
}
