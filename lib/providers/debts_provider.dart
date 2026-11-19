import 'package:flutter/foundation.dart';

import '../data/repositories/debt_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../utils/balance_calculator.dart';

/// Filtros disponibles para la búsqueda/listado de deudas.
///
/// `overdue` (vencida) se define como una deuda abierta (`DebtStatus.open`)
/// con [Debt.dueDate] anterior al momento actual; una deuda ya pagada nunca
/// se considera vencida, sin importar su fecha de vencimiento.
enum DebtFilter { all, owedToMe, iOwe, overdue }

/// Responsable de las deudas y de los pagos asociados a ellas: es la fuente
/// de verdad para las pantallas de listado, detalle y registro de pagos.
///
/// Mantiene todas las deudas y pagos en memoria, sin paginar, porque esta es
/// una app personal con un volumen de datos chico; si el volumen creciera,
/// este sería el lugar para introducir paginación sin tener que tocar las
/// pantallas que lo consumen.
///
/// A propósito NO depende de `PeopleProvider`: cada provider debe poder
/// testearse y evolucionar de forma aislada. Cuando una pantalla necesita
/// resolver el nombre de la persona asociada a una deuda (por ejemplo, para
/// buscar por texto en [filtered]), se lo pasa como función mediante
/// [personNameResolver] en lugar de que este provider dependa directamente
/// de `PeopleProvider`.
class DebtsProvider extends ChangeNotifier {
  DebtsProvider(this._debtRepository, this._paymentRepository);

  final DebtRepository _debtRepository;
  final PaymentRepository _paymentRepository;

  List<Debt> _debts = [];
  List<Payment> _payments = [];

  bool isLoading = false;
  String? errorMessage;

  /// Última deuda eliminada y su posición original, para poder deshacer el
  /// borrado (ver [restoreLastDeletedDebt]). Solo se conserva la última.
  Debt? _lastDeletedDebt;
  int? _lastDeletedDebtIndex;

  /// Último pago eliminado y su posición original, análogo a
  /// [_lastDeletedDebt] pero para [deletePayment]/[restoreLastDeletedPayment].
  Payment? _lastDeletedPayment;
  int? _lastDeletedPaymentIndex;

  /// Copia de solo lectura de todas las deudas cargadas (no incluye
  /// eliminadas).
  List<Debt> get debts => List.unmodifiable(_debts);

  /// Copia de solo lectura de todos los pagos cargados (no incluye
  /// eliminados).
  List<Payment> get payments => List.unmodifiable(_payments);

  /// Carga todas las deudas y todos los pagos de la app.
  Future<void> loadAll() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final debts = await _debtRepository.getAllDebts();
      final payments = await _paymentRepository.getAllPayments();
      _debts = debts;
      _payments = payments;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Deudas asociadas a la persona [personId].
  List<Debt> debtsForPerson(String personId) =>
      _debts.where((debt) => debt.personId == personId).toList();

  /// Pagos asociados a la deuda [debtId].
  List<Payment> paymentsForDebt(String debtId) =>
      _payments.where((payment) => payment.debtId == debtId).toList();

  /// Saldo pendiente de [debt], delegado en `debtBalanceCents`.
  int debtBalance(Debt debt) => debtBalanceCents(debt, _payments);

  Future<void> addDebt({
    required String personId,
    required DebtType type,
    required String description,
    required int amountCents,
    required DateTime createdAt,
    DateTime? dueDate,
  }) async {
    final debt = await _debtRepository.createDebt(
      personId: personId,
      type: type,
      description: description,
      amountCents: amountCents,
      createdAt: createdAt,
      dueDate: dueDate,
    );
    _debts = [..._debts, debt];
    notifyListeners();
  }

  Future<void> updateDebt(Debt debt) async {
    final updated = await _debtRepository.updateDebt(debt);
    _debts = [
      for (final existing in _debts) if (existing.id == updated.id) updated else existing,
    ];
    notifyListeners();
  }

  /// Marca la deuda [debtId] como pagada (`DebtStatus.paid`) y persiste el
  /// cambio. A partir de ese momento [debtBalance] devuelve 0 para esa
  /// deuda, sin importar los pagos registrados previamente.
  Future<void> markPaid(String debtId) async {
    final index = _debts.indexWhere((debt) => debt.id == debtId);
    if (index == -1) return;

    final updated = await _debtRepository.updateDebt(
      _debts[index].copyWith(status: DebtStatus.paid),
    );
    _debts = [..._debts]..[index] = updated;
    notifyListeners();
  }

  /// Elimina (soft delete) la deuda [id] y la saca de la lista visible.
  /// Guarda una copia en memoria para que [restoreLastDeletedDebt] pueda
  /// deshacer la acción.
  Future<void> deleteDebt(String id) async {
    final index = _debts.indexWhere((debt) => debt.id == id);
    if (index == -1) return;

    _lastDeletedDebt = _debts[index];
    _lastDeletedDebtIndex = index;

    await _debtRepository.deleteDebt(id);
    _debts = [..._debts]..removeAt(index);
    notifyListeners();
  }

  /// Restaura la última deuda eliminada mediante [deleteDebt] (pensado para
  /// el botón "Deshacer" de un SnackBar).
  Future<void> restoreLastDeletedDebt() async {
    final toRestore = _lastDeletedDebt;
    if (toRestore == null) return;

    final restored = await _debtRepository.restoreDebt(toRestore);
    final insertAt = (_lastDeletedDebtIndex ?? _debts.length).clamp(0, _debts.length);

    _debts = [..._debts]..insert(insertAt, restored);
    _lastDeletedDebt = null;
    _lastDeletedDebtIndex = null;
    notifyListeners();
  }

  Future<void> registerPayment({
    required String debtId,
    required int amountCents,
    required DateTime date,
    String? note,
  }) async {
    final payment = await _paymentRepository.createPayment(
      debtId: debtId,
      amountCents: amountCents,
      date: date,
      note: note,
    );
    _payments = [..._payments, payment];
    notifyListeners();
  }

  /// Elimina (soft delete) el pago [id] y lo saca de la lista visible.
  /// Guarda una copia en memoria para que [restoreLastDeletedPayment] pueda
  /// deshacer la acción.
  Future<void> deletePayment(String id) async {
    final index = _payments.indexWhere((payment) => payment.id == id);
    if (index == -1) return;

    _lastDeletedPayment = _payments[index];
    _lastDeletedPaymentIndex = index;

    await _paymentRepository.deletePayment(id);
    _payments = [..._payments]..removeAt(index);
    notifyListeners();
  }

  /// Restaura el último pago eliminado mediante [deletePayment].
  Future<void> restoreLastDeletedPayment() async {
    final toRestore = _lastDeletedPayment;
    if (toRestore == null) return;

    final restored = await _paymentRepository.restorePayment(toRestore);
    final insertAt = (_lastDeletedPaymentIndex ?? _payments.length).clamp(0, _payments.length);

    _payments = [..._payments]..insert(insertAt, restored);
    _lastDeletedPayment = null;
    _lastDeletedPaymentIndex = null;
    notifyListeners();
  }

  /// Filtra las deudas cargadas por [filter] y, si [query] no está vacío,
  /// por texto (coincidencia parcial e insensible a mayúsculas) contra la
  /// descripción de la deuda o el nombre de la persona asociada.
  ///
  /// [personNameResolver] resuelve un `personId` a su nombre; se recibe
  /// como parámetro en lugar de depender de `PeopleProvider` directamente,
  /// para mantener este provider desacoplado (ver doc de la clase). Si no
  /// se provee, la búsqueda por texto solo considera la descripción.
  List<Debt> filtered({
    String query = '',
    DebtFilter filter = DebtFilter.all,
    String Function(String personId)? personNameResolver,
  }) {
    final normalizedQuery = query.trim().toLowerCase();

    return _debts.where((debt) {
      final matchesFilter = switch (filter) {
        DebtFilter.all => true,
        DebtFilter.owedToMe => debt.type == DebtType.owedToMe,
        DebtFilter.iOwe => debt.type == DebtType.iOwe,
        DebtFilter.overdue =>
          debt.status == DebtStatus.open &&
              debt.dueDate != null &&
              debt.dueDate!.isBefore(DateTime.now()),
      };
      if (!matchesFilter) return false;
      if (normalizedQuery.isEmpty) return true;

      final personName = personNameResolver?.call(debt.personId) ?? '';
      return debt.description.toLowerCase().contains(normalizedQuery) ||
          personName.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}
