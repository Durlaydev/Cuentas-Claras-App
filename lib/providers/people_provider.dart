import 'package:flutter/foundation.dart';

import '../data/repositories/debt_repository.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/person_repository.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../utils/balance_calculator.dart';

/// Responsable de la lista de personas que se muestra en la pantalla
/// principal ("Personas") y de su saldo neto individual.
///
/// Existe como provider propio (en lugar de vivir dentro de
/// [PersonRepository] o de `DebtsProvider`) porque su responsabilidad es de
/// presentación: decide qué personas mostrar, en qué estado (cargando,
/// error) y con qué saldo. Para calcular ese saldo sin acoplarse a
/// `DebtsProvider` (cada provider debe poder testearse y evolucionar de
/// forma aislada), este provider también carga una copia de todas las
/// deudas y pagos: es el costo de mantener los providers desacoplados
/// entre sí en una app chica donde cargar todo en memoria es aceptable.
class PeopleProvider extends ChangeNotifier {
  PeopleProvider(
    this._personRepository,
    this._debtRepository,
    this._paymentRepository,
  );

  final PersonRepository _personRepository;
  final DebtRepository _debtRepository;
  final PaymentRepository _paymentRepository;

  List<Person> _people = [];
  List<Debt> _debts = [];
  List<Payment> _payments = [];

  bool isLoading = false;
  String? errorMessage;

  /// Última persona eliminada y su posición original en la lista, guardadas
  /// en memoria para poder restaurarla desde un SnackBar "Deshacer". Solo se
  /// conserva la última: si se borra una segunda persona antes de deshacer
  /// la primera, la primera deja de poder restaurarse (comportamiento
  /// esperado de un "Deshacer" simple, no una pila de deshacer).
  Person? _lastDeleted;
  int? _lastDeletedIndex;

  /// Copia de solo lectura de la lista de personas actualmente visibles
  /// (no incluye a las eliminadas).
  List<Person> get people => List.unmodifiable(_people);

  /// Carga todas las personas no eliminadas, junto con todas las deudas y
  /// pagos de la app (necesarios para [netBalanceForPerson]).
  Future<void> loadPeople() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final people = await _personRepository.getAllPeople();
      final debts = await _debtRepository.getAllDebts();
      final payments = await _paymentRepository.getAllPayments();
      _people = people;
      _debts = debts;
      _payments = payments;
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPerson({required String name, String? phone, String? note}) async {
    final person = await _personRepository.createPerson(name: name, phone: phone, note: note);
    _people = [..._people, person];
    notifyListeners();
  }

  Future<void> updatePerson(Person person) async {
    final updated = await _personRepository.updatePerson(person);
    _people = [
      for (final existing in _people) if (existing.id == updated.id) updated else existing,
    ];
    notifyListeners();
  }

  /// Elimina (soft delete) a la persona con id [id] y la saca de la lista
  /// visible. Guarda una copia en memoria para que [restoreLastDeleted]
  /// pueda deshacer la acción.
  Future<void> deletePerson(String id) async {
    final index = _people.indexWhere((person) => person.id == id);
    if (index == -1) return;

    _lastDeleted = _people[index];
    _lastDeletedIndex = index;

    await _personRepository.deletePerson(id);
    _people = [..._people]..removeAt(index);
    notifyListeners();
  }

  /// Restaura la última persona eliminada mediante [deletePerson] (pensado
  /// para el botón "Deshacer" de un SnackBar). No hace nada si no hay nada
  /// pendiente de restaurar.
  Future<void> restoreLastDeleted() async {
    final toRestore = _lastDeleted;
    if (toRestore == null) return;

    final restored = await _personRepository.restorePerson(toRestore);
    final insertAt = (_lastDeletedIndex ?? _people.length).clamp(0, _people.length);

    _people = [..._people]..insert(insertAt, restored);
    _lastDeleted = null;
    _lastDeletedIndex = null;
    notifyListeners();
  }

  /// Saldo neto de la persona [personId], calculado con las deudas y pagos
  /// cargados por [loadPeople]. Positivo = te deben, negativo = debes.
  int netBalanceForPerson(String personId) {
    final debtsForPerson = _debts.where((debt) => debt.personId == personId).toList();
    return personNetBalanceCents(debtsForPerson, _payments);
  }
}
