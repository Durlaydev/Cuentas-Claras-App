import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/models/payment.dart';
import 'package:cuentas_claras/providers/people_provider.dart';
import 'package:cuentas_claras/utils/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakePersonRepository personRepository;
  late FakeDebtRepository debtRepository;
  late FakePaymentRepository paymentRepository;
  late PeopleProvider provider;

  setUp(() {
    personRepository = FakePersonRepository();
    debtRepository = FakeDebtRepository();
    paymentRepository = FakePaymentRepository();
    provider = PeopleProvider(personRepository, debtRepository, paymentRepository);
  });

  test('loadPeople fetches all people and updates loading/error state', () async {
    await personRepository.createPerson(name: 'Ana');
    await personRepository.createPerson(name: 'Beto');

    expect(provider.isLoading, isFalse);

    final future = provider.loadPeople();
    expect(provider.isLoading, isTrue);
    await future;

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNull);
    expect(provider.people.map((p) => p.name).toSet(), {'Ana', 'Beto'});
  });

  test('addPerson persists via el repositorio y actualiza el estado en memoria', () async {
    await provider.loadPeople();

    await provider.addPerson(name: 'Carla', phone: '111', note: 'nota');

    expect(provider.people.length, 1);
    expect(provider.people.single.name, 'Carla');
    expect(provider.people.single.phone, '111');
    expect(personRepository.people.length, 1);
  });

  test('updatePerson persiste los cambios y actualiza la lista visible', () async {
    final person = await personRepository.createPerson(name: 'Ana');
    await provider.loadPeople();

    await provider.updatePerson(person.copyWith(name: 'Ana María'));

    expect(provider.people.single.name, 'Ana María');
    expect(personRepository.people.single.name, 'Ana María');
  });

  test('deletePerson saca a la persona de la lista visible y restoreLastDeleted la recupera', () async {
    final person = await personRepository.createPerson(name: 'Ana');
    await provider.loadPeople();

    await provider.deletePerson(person.id);
    expect(provider.people, isEmpty);
    expect(personRepository.people.single.deleted, isTrue);

    await provider.restoreLastDeleted();
    expect(provider.people.map((p) => p.id), [person.id]);
    expect(provider.people.single.deleted, isFalse);
  });

  test('restoreLastDeleted no hace nada si no hay nada pendiente de restaurar', () async {
    await provider.loadPeople();

    await provider.restoreLastDeleted();

    expect(provider.people, isEmpty);
  });

  test('netBalanceForPerson coincide con personNetBalanceCents para datos conocidos', () async {
    final person = await personRepository.createPerson(name: 'Ana');
    final debt = Debt(
      id: 'debt-1',
      personId: person.id,
      type: DebtType.owedToMe,
      description: 'Almuerzo',
      amountCents: 5000,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    debtRepository.debts.add(debt);
    final payment = Payment(
      id: 'payment-1',
      debtId: debt.id,
      amountCents: 2000,
      date: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );
    paymentRepository.payments.add(payment);

    await provider.loadPeople();

    final expected = personNetBalanceCents([debt], [payment]);
    expect(expected, 3000);
    expect(provider.netBalanceForPerson(person.id), expected);
  });
}
