// Prueba de integración de punta a punta: base de datos -> repositorios ->
// función pura de cálculo de saldo. No reimplementa la matemática de
// `balance_calculator.dart` (ya probada aparte); solo confirma que los
// datos que devuelven los repositorios encajan con lo que esa función
// espera recibir.
import 'package:cuentas_claras/data/local/app_database.dart';
import 'package:cuentas_claras/data/local/debt_local_datasource.dart';
import 'package:cuentas_claras/data/local/payment_local_datasource.dart';
import 'package:cuentas_claras/data/local/person_local_datasource.dart';
import 'package:cuentas_claras/data/repositories/local_debt_repository.dart';
import 'package:cuentas_claras/data/repositories/local_payment_repository.dart';
import 'package:cuentas_claras/data/repositories/local_person_repository.dart';
import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/utils/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase appDatabase;
  late LocalPersonRepository personRepository;
  late LocalDebtRepository debtRepository;
  late LocalPaymentRepository paymentRepository;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    personRepository = LocalPersonRepository(PersonLocalDataSource(appDatabase));
    debtRepository = LocalDebtRepository(DebtLocalDataSource(appDatabase));
    paymentRepository = LocalPaymentRepository(PaymentLocalDataSource(appDatabase));
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test(
    'persona + dos deudas + un pago parcial dan el saldo neto esperado',
    () async {
      final person = await personRepository.createPerson(name: 'Ana');

      // Ana me debe 100.00, de los cuales ya pagó 30.00 -> quedan 70.00 a mi favor.
      final owedToMeDebt = await debtRepository.createDebt(
        personId: person.id,
        type: DebtType.owedToMe,
        description: 'Cena',
        amountCents: 10000,
      );
      await paymentRepository.createPayment(debtId: owedToMeDebt.id, amountCents: 3000);

      // Yo le debo 40.00 a Ana, sin pagos -> 40.00 en contra.
      await debtRepository.createDebt(
        personId: person.id,
        type: DebtType.iOwe,
        description: 'Nafta',
        amountCents: 4000,
      );

      final debtsForPerson = await debtRepository.getDebtsForPerson(person.id);
      final allPayments = await paymentRepository.getAllPayments();

      final netBalance = personNetBalanceCents(debtsForPerson, allPayments);

      // Neto esperado: (10000 - 3000) - 4000 = 3000 a favor.
      expect(netBalance, 3000);
    },
  );
}
