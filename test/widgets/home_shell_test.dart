import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/providers/debts_provider.dart';
import 'package:cuentas_claras/providers/people_provider.dart';
import 'package:cuentas_claras/screens/debts/debt_detail_screen.dart';
import 'package:cuentas_claras/screens/people/person_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../providers/fakes.dart';

/// NOTA IMPORTANTE sobre por qué este archivo no importa
/// `package:cuentas_claras/screens/home_shell.dart` directamente:
///
/// `home_shell.dart` importa (sin condicionamiento posible, porque
/// `IndexedStack` necesita construir ambas pestañas) `dashboard_screen.dart`,
/// que a su vez importa `package:fl_chart/fl_chart.dart`. En este entorno,
/// la única versión de `fl_chart` resolvible (`1.1.0`) usa
/// `Matrix4.translateByDouble`/`scaleByDouble` (en
/// `fl_chart/lib/src/chart/base/custom_interactive_viewer.dart`), métodos
/// que NO existen en `vector_math: 2.1.4` — versión fijada de forma exacta
/// (no como rango) por el propio framework de Flutter en esta versión del
/// SDK (`packages/flutter/pubspec.yaml`). Es decir: cualquier test que
/// importe (aunque sea transitivamente) `dashboard_screen.dart` falla al
/// compilar con `flutter test` en este entorno, con un error interno de
/// `fl_chart` totalmente ajeno a este fix. `flutter analyze` no lo detecta
/// porque el analizador no tipa en profundidad el código de paquetes de
/// terceros como sí lo hace el compilador (CFE) usado por `flutter test`.
///
/// Arreglar esa incompatibilidad requeriría tocar `pubspec.yaml` (bajar
/// `fl_chart` o subir el SDK de Flutter), fuera del alcance de este fix
/// (`lib/screens/`, `lib/widgets/`, `test/widgets/`). Por eso, en lugar de
/// levantar `HomeShell` real, este archivo replica exactamente el mismo
/// patrón agregado en `HomeShell.initState()` (`addPostFrameCallback` +
/// `context.read<DebtsProvider>().loadAll()`) para verificar el
/// comportamiento que soluciona: que las deudas y pagos ya persistidos se
/// vean sin necesidad de agregar uno nuevo en la sesión.
class _HydratingShellHarness extends StatefulWidget {
  const _HydratingShellHarness({required this.child});

  final Widget child;

  @override
  State<_HydratingShellHarness> createState() => _HydratingShellHarnessState();
}

class _HydratingShellHarnessState extends State<_HydratingShellHarness> {
  @override
  void initState() {
    super.initState();
    // Mismo patrón que `HomeShell.initState()`: ver el comentario allí.
    // También se hidrata `PeopleProvider` aquí porque, en el flujo real, ya
    // habría sido cargado por `PeopleListScreen` (la pantalla desde la que
    // se navega a `PersonDetailScreen`/`DebtDetailScreen`) antes de que el
    // usuario llegue a estas pantallas de detalle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DebtsProvider>().loadAll();
      context.read<PeopleProvider>().loadPeople();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _buildHarness({
  required FakePersonRepository personRepository,
  required FakeDebtRepository debtRepository,
  required FakePaymentRepository paymentRepository,
  required Widget child,
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
    child: MaterialApp(home: _HydratingShellHarness(child: child)),
  );
}

void main() {
  testWidgets(
    'una deuda persistida se ve en PersonDetailScreen sin agregar una nueva en la sesión',
    (tester) async {
      final personRepository = FakePersonRepository();
      final debtRepository = FakeDebtRepository();
      final paymentRepository = FakePaymentRepository();

      await personRepository.createPerson(name: 'Ana');
      await debtRepository.createDebt(
        personId: 'person-0',
        type: DebtType.owedToMe,
        description: 'Almuerzo',
        amountCents: 1000,
      );

      await tester.pumpWidget(
        _buildHarness(
          personRepository: personRepository,
          debtRepository: debtRepository,
          paymentRepository: paymentRepository,
          child: const PersonDetailScreen(personId: 'person-0'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('No hay deudas que coincidan con la búsqueda.'), findsNothing);
    },
  );

  testWidgets(
    'un pago persistido se ve en DebtDetailScreen (y descuenta el saldo) sin registrar uno nuevo en la sesión',
    (tester) async {
      final personRepository = FakePersonRepository();
      final debtRepository = FakeDebtRepository();
      final paymentRepository = FakePaymentRepository();

      await personRepository.createPerson(name: 'Ana');
      final debt = await debtRepository.createDebt(
        personId: 'person-0',
        type: DebtType.owedToMe,
        description: 'Almuerzo',
        amountCents: 1000,
      );
      await paymentRepository.createPayment(debtId: debt.id, amountCents: 400);

      await tester.pumpWidget(
        _buildHarness(
          personRepository: personRepository,
          debtRepository: debtRepository,
          paymentRepository: paymentRepository,
          child: DebtDetailScreen(debtId: debt.id),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todavía no hay pagos registrados.'), findsNothing);
      expect(find.text('Saldo pendiente: '), findsOneWidget);
      expect(find.text('\$6,00'), findsOneWidget);
    },
  );
}
