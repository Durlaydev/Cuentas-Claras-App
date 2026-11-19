import '../models/debt.dart';
import '../models/payment.dart';

/// Calcula cuánto falta saldar de una deuda: el monto original menos la
/// suma de los pagos no eliminados registrados para esa deuda.
///
/// Si la deuda está marcada como [DebtStatus.paid], el saldo es siempre
/// 0, independientemente de los pagos registrados (puede haberse saldado
/// sin dejar un pago explícito, por ejemplo al perdonar la deuda).
///
/// El resultado nunca es negativo: si los pagos superan el monto de la
/// deuda (sobrepago), el saldo queda en 0. Modelar qué hacer con ese
/// excedente (por ejemplo, ofrecer devolverlo o dejarlo como crédito a
/// favor) es una decisión de UI/producto, no de esta capa de cálculo puro.
int debtBalanceCents(Debt debt, List<Payment> paymentsForDebt) {
  if (debt.status == DebtStatus.paid) {
    return 0;
  }

  final paidCents = paymentsForDebt
      .where((payment) => payment.debtId == debt.id && !payment.deleted)
      .fold<int>(0, (sum, payment) => sum + payment.amountCents);

  final remaining = debt.amountCents - paidCents;
  return remaining < 0 ? 0 : remaining;
}

/// Calcula el saldo neto de una persona a partir de sus deudas.
///
/// Las deudas de tipo [DebtType.owedToMe] suman al neto (positivo =
/// te deben) y las de tipo [DebtType.iOwe] restan (negativo = debes).
/// Las deudas eliminadas ([Debt.deleted]) no se consideran.
int personNetBalanceCents(List<Debt> debtsForPerson, List<Payment> allPayments) {
  var net = 0;

  for (final debt in debtsForPerson) {
    if (debt.deleted) continue;

    final paymentsForDebt =
        allPayments.where((payment) => payment.debtId == debt.id).toList();
    final balance = debtBalanceCents(debt, paymentsForDebt);

    net += debt.type == DebtType.owedToMe ? balance : -balance;
  }

  return net;
}

/// Resumen global de saldos, agrupado por tipo de deuda entre todas las
/// personas.
class GlobalBalanceSummary {
  final int totalOwedToMeCents;
  final int totalIOweCents;
  final int netCents;

  const GlobalBalanceSummary({
    required this.totalOwedToMeCents,
    required this.totalIOweCents,
    required this.netCents,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GlobalBalanceSummary &&
        other.totalOwedToMeCents == totalOwedToMeCents &&
        other.totalIOweCents == totalIOweCents &&
        other.netCents == netCents;
  }

  @override
  int get hashCode =>
      Object.hash(totalOwedToMeCents, totalIOweCents, netCents);

  @override
  String toString() =>
      'GlobalBalanceSummary(totalOwedToMeCents: $totalOwedToMeCents, '
      'totalIOweCents: $totalIOweCents, netCents: $netCents)';
}

/// Calcula el resumen global de saldos a partir de todas las deudas y
/// todos los pagos de la aplicación, agrupando por tipo de deuda.
GlobalBalanceSummary computeGlobalSummary(
  List<Debt> allDebts,
  List<Payment> allPayments,
) {
  var totalOwedToMe = 0;
  var totalIOwe = 0;

  for (final debt in allDebts) {
    if (debt.deleted) continue;

    final paymentsForDebt =
        allPayments.where((payment) => payment.debtId == debt.id).toList();
    final balance = debtBalanceCents(debt, paymentsForDebt);

    if (debt.type == DebtType.owedToMe) {
      totalOwedToMe += balance;
    } else {
      totalIOwe += balance;
    }
  }

  return GlobalBalanceSummary(
    totalOwedToMeCents: totalOwedToMe,
    totalIOweCents: totalIOwe,
    netCents: totalOwedToMe - totalIOwe,
  );
}
