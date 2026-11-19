/// Repositorios fake en memoria para testear los providers de
/// `lib/providers/` sin sqflite ni frameworks de mocking, siguiendo el
/// estilo de testing ya usado en el resto del proyecto (fakes escritos a
/// mano). Replican el comportamiento observable de los `Local*Repository`
/// reales que consumen los providers: generación de id, bump de
/// `updatedAt`/`pendingSync` en `update*`, soft delete y `restore*`.
library;

import 'package:cuentas_claras/data/repositories/debt_repository.dart';
import 'package:cuentas_claras/data/repositories/payment_repository.dart';
import 'package:cuentas_claras/data/repositories/person_repository.dart';
import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/models/payment.dart';
import 'package:cuentas_claras/models/person.dart';

class FakePersonRepository implements PersonRepository {
  final List<Person> people = [];
  int _counter = 0;

  @override
  Future<Person> createPerson({required String name, String? phone, String? note}) async {
    final person = Person(
      id: 'person-${_counter++}',
      name: name,
      phone: phone,
      note: note,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );
    people.add(person);
    return person;
  }

  @override
  Future<Person?> getPersonById(String id) async {
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  @override
  Future<List<Person>> getAllPeople({bool includeDeleted = false}) async {
    return people.where((person) => includeDeleted || !person.deleted).toList();
  }

  @override
  Future<Person> updatePerson(Person person) async {
    final updated = person.copyWith(updatedAt: DateTime.now(), pendingSync: true);
    _replaceOrAdd(updated);
    return updated;
  }

  @override
  Future<void> deletePerson(String id) async {
    final index = people.indexWhere((person) => person.id == id);
    if (index == -1) return;
    people[index] = people[index].copyWith(deleted: true, pendingSync: true, updatedAt: DateTime.now());
  }

  @override
  Future<Person> restorePerson(Person original) async {
    final restored = original.copyWith(deleted: false, pendingSync: true, updatedAt: DateTime.now());
    _replaceOrAdd(restored);
    return restored;
  }

  void _replaceOrAdd(Person person) {
    final index = people.indexWhere((existing) => existing.id == person.id);
    if (index == -1) {
      people.add(person);
    } else {
      people[index] = person;
    }
  }
}

class FakeDebtRepository implements DebtRepository {
  final List<Debt> debts = [];
  int _counter = 0;

  @override
  Future<Debt> createDebt({
    required String personId,
    required DebtType type,
    required String description,
    required int amountCents,
    DateTime? createdAt,
    DateTime? dueDate,
    DebtStatus status = DebtStatus.open,
  }) async {
    final now = DateTime.now();
    final debt = Debt(
      id: 'debt-${_counter++}',
      personId: personId,
      type: type,
      description: description,
      amountCents: amountCents,
      createdAt: createdAt ?? now,
      dueDate: dueDate,
      status: status,
      updatedAt: now,
      pendingSync: true,
    );
    debts.add(debt);
    return debt;
  }

  @override
  Future<Debt?> getDebtById(String id) async {
    for (final debt in debts) {
      if (debt.id == id) return debt;
    }
    return null;
  }

  @override
  Future<List<Debt>> getAllDebts({bool includeDeleted = false}) async {
    return debts.where((debt) => includeDeleted || !debt.deleted).toList();
  }

  @override
  Future<List<Debt>> getDebtsForPerson(String personId, {bool includeDeleted = false}) async {
    return debts
        .where((debt) => debt.personId == personId && (includeDeleted || !debt.deleted))
        .toList();
  }

  @override
  Future<Debt> updateDebt(Debt debt) async {
    final updated = debt.copyWith(updatedAt: DateTime.now(), pendingSync: true);
    _replaceOrAdd(updated);
    return updated;
  }

  @override
  Future<void> deleteDebt(String id) async {
    final index = debts.indexWhere((debt) => debt.id == id);
    if (index == -1) return;
    debts[index] = debts[index].copyWith(deleted: true, pendingSync: true, updatedAt: DateTime.now());
  }

  @override
  Future<Debt> restoreDebt(Debt original) async {
    final restored = original.copyWith(deleted: false, pendingSync: true, updatedAt: DateTime.now());
    _replaceOrAdd(restored);
    return restored;
  }

  void _replaceOrAdd(Debt debt) {
    final index = debts.indexWhere((existing) => existing.id == debt.id);
    if (index == -1) {
      debts.add(debt);
    } else {
      debts[index] = debt;
    }
  }
}

class FakePaymentRepository implements PaymentRepository {
  final List<Payment> payments = [];
  int _counter = 0;

  @override
  Future<Payment> createPayment({
    required String debtId,
    required int amountCents,
    DateTime? date,
    String? note,
  }) async {
    final payment = Payment(
      id: 'payment-${_counter++}',
      debtId: debtId,
      amountCents: amountCents,
      date: date ?? DateTime.now(),
      note: note,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );
    payments.add(payment);
    return payment;
  }

  @override
  Future<Payment?> getPaymentById(String id) async {
    for (final payment in payments) {
      if (payment.id == id) return payment;
    }
    return null;
  }

  @override
  Future<List<Payment>> getAllPayments({bool includeDeleted = false}) async {
    return payments.where((payment) => includeDeleted || !payment.deleted).toList();
  }

  @override
  Future<List<Payment>> getPaymentsForDebt(String debtId, {bool includeDeleted = false}) async {
    return payments
        .where((payment) => payment.debtId == debtId && (includeDeleted || !payment.deleted))
        .toList();
  }

  @override
  Future<Payment> updatePayment(Payment payment) async {
    final updated = payment.copyWith(updatedAt: DateTime.now(), pendingSync: true);
    _replaceOrAdd(updated);
    return updated;
  }

  @override
  Future<void> deletePayment(String id) async {
    final index = payments.indexWhere((payment) => payment.id == id);
    if (index == -1) return;
    payments[index] =
        payments[index].copyWith(deleted: true, pendingSync: true, updatedAt: DateTime.now());
  }

  @override
  Future<Payment> restorePayment(Payment original) async {
    final restored = original.copyWith(deleted: false, pendingSync: true, updatedAt: DateTime.now());
    _replaceOrAdd(restored);
    return restored;
  }

  void _replaceOrAdd(Payment payment) {
    final index = payments.indexWhere((existing) => existing.id == payment.id);
    if (index == -1) {
      payments.add(payment);
    } else {
      payments[index] = payment;
    }
  }
}
