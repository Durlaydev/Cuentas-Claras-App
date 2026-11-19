import 'package:cuentas_claras/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  Person buildPerson({
    String id = 'p1',
    String name = 'Juan Perez',
    String? phone = '+54 9 11 1234-5678',
    String? note = 'Amigo del trabajo',
    DateTime? updatedAtOverride,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    return Person(
      id: id,
      name: name,
      phone: phone,
      note: note,
      updatedAt: updatedAtOverride ?? updatedAt,
      pendingSync: pendingSync,
      deleted: deleted,
    );
  }

  test('pendingSync es true por defecto y deleted false por defecto', () {
    final person = Person(id: 'p1', name: 'Ana', updatedAt: updatedAt);
    expect(person.pendingSync, isTrue);
    expect(person.deleted, isFalse);
    expect(person.phone, isNull);
    expect(person.note, isNull);
  });

  test('toMap produce las columnas snake_case esperadas', () {
    final person = buildPerson();
    final map = person.toMap();

    expect(map['id'], 'p1');
    expect(map['name'], 'Juan Perez');
    expect(map['phone'], '+54 9 11 1234-5678');
    expect(map['note'], 'Amigo del trabajo');
    expect(map['updated_at'], updatedAt.millisecondsSinceEpoch);
    expect(map['pending_sync'], 1);
    expect(map['deleted'], 0);
  });

  test('fromMap(toMap(x)) es igual a x (round-trip)', () {
    final person = buildPerson();
    final roundTripped = Person.fromMap(person.toMap());

    expect(roundTripped, person);
  });

  test('round-trip preserva booleanos en false/false', () {
    final person = buildPerson(pendingSync: false, deleted: true);
    final roundTripped = Person.fromMap(person.toMap());

    expect(roundTripped, person);
    expect(roundTripped.pendingSync, isFalse);
    expect(roundTripped.deleted, isTrue);
  });

  test('copyWith actualiza únicamente los campos indicados', () {
    final person = buildPerson();
    final updated = person.copyWith(name: 'Otro Nombre');

    expect(updated.name, 'Otro Nombre');
    expect(updated.id, person.id);
    expect(updated.phone, person.phone);
  });

  test('copyWith permite limpiar campos opcionales a null explícitamente', () {
    final person = buildPerson();
    final updated = person.copyWith(phone: null, note: null);

    expect(updated.phone, isNull);
    expect(updated.note, isNull);
  });

  test('dos instancias con el mismo contenido son iguales', () {
    final a = buildPerson();
    final b = buildPerson();

    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('instancias con contenido distinto no son iguales', () {
    final a = buildPerson();
    final b = buildPerson(name: 'Otra Persona');

    expect(a == b, isFalse);
  });
}
