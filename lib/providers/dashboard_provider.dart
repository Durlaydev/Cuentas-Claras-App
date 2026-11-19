import 'package:flutter/foundation.dart';

import '../data/repositories/debt_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../models/debt.dart';
import '../utils/balance_calculator.dart';
import '../utils/debt_type_label.dart';

/// Una porción del gráfico de torta del dashboard, como datos puros.
///
/// A propósito no conoce nada de `fl_chart` (ni de ninguna otra librería de
/// gráficos): esta capa debe seguir siendo agnóstica de la librería de
/// charting que use la UI, para poder testearse sin arrastrar un widget de
/// gráficos a los tests unitarios y para poder cambiar de librería en el
/// futuro sin tocar `DashboardProvider`. Las pantallas son responsables de
/// mapear cada [ChartSlice] al `PieChartSectionData` (u otro tipo) que
/// necesite su librería de gráficos.
class ChartSlice {
  const ChartSlice(this.label, this.valueCents);

  final String label;
  final int valueCents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartSlice && other.label == label && other.valueCents == valueCents);

  @override
  int get hashCode => Object.hash(label, valueCents);

  @override
  String toString() => 'ChartSlice(label: $label, valueCents: $valueCents)';
}

/// Responsable del resumen global de saldos que se muestra en el dashboard:
/// cuánto le deben al usuario, cuánto debe el usuario, y el neto entre
/// ambos.
///
/// Vive separado de [DebtsProvider] porque su responsabilidad es de
/// agregación/reporte, no de CRUD: la pantalla de dashboard no necesita
/// reaccionar a cada alta/baja individual de una deuda, sino recalcular el
/// resumen completo cuando se le pide un [refresh] (por ejemplo, al entrar
/// a la pantalla).
class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._debtRepository, this._paymentRepository);

  final DebtRepository _debtRepository;
  final PaymentRepository _paymentRepository;

  bool isLoading = false;
  String? errorMessage;

  GlobalBalanceSummary _summary = const GlobalBalanceSummary(
    totalOwedToMeCents: 0,
    totalIOweCents: 0,
    netCents: 0,
  );

  /// Último resumen global calculado por [refresh].
  GlobalBalanceSummary get summary => _summary;

  /// Representación del resumen lista para graficarse: una porción "Me
  /// deben" y una "Debo", en ese orden.
  List<ChartSlice> get chartSlices => [
        ChartSlice(DebtType.owedToMe.label, _summary.totalOwedToMeCents),
        ChartSlice(DebtType.iOwe.label, _summary.totalIOweCents),
      ];

  /// Recalcula el resumen global a partir de todas las deudas y pagos
  /// actuales.
  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final debts = await _debtRepository.getAllDebts();
      final payments = await _paymentRepository.getAllPayments();
      _summary = computeGlobalSummary(debts, payments);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
