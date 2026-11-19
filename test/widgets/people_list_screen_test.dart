import 'package:cuentas_claras/providers/people_provider.dart';
import 'package:cuentas_claras/providers/debts_provider.dart';
import 'package:cuentas_claras/screens/people/people_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../providers/fakes.dart';

/// Envuelve [PeopleListScreen] con los providers que necesita para
/// funcionar. No se incluye `NotificationService` porque
/// `PeopleListScreen` (a diferencia de las pantallas de deudas) no lo
/// consume: solo agrega/elimina personas.
Widget _buildHarness({
  required FakePersonRepository personRepository,
  required FakeDebtRepository debtRepository,
  required FakePaymentRepository paymentRepository,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => PeopleProvider(personRepository, debtRepository, paymentRepository),
      ),
      ChangeNotifierProvider(
        create: (_) => DebtsProvider(debtRepository, paymentRepository),
      ),
    ],
    child: const MaterialApp(home: PeopleListScreen()),
  );
}

void main() {
  testWidgets('muestra el estado vacío cuando no hay personas', (tester) async {
    final personRepository = FakePersonRepository();
    final debtRepository = FakeDebtRepository();
    final paymentRepository = FakePaymentRepository();

    await tester.pumpWidget(
      _buildHarness(
        personRepository: personRepository,
        debtRepository: debtRepository,
        paymentRepository: paymentRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todavía no agregaste a nadie.'), findsOneWidget);
  });

  testWidgets('muestra a la persona luego de agregarla y recargar', (tester) async {
    final personRepository = FakePersonRepository();
    final debtRepository = FakeDebtRepository();
    final paymentRepository = FakePaymentRepository();

    await personRepository.createPerson(name: 'Ana');

    await tester.pumpWidget(
      _buildHarness(
        personRepository: personRepository,
        debtRepository: debtRepository,
        paymentRepository: paymentRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Todavía no agregaste a nadie.'), findsNothing);
  });
}
