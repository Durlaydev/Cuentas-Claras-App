import 'package:uuid/uuid.dart';

import '../../models/person.dart';
import '../local/person_local_datasource.dart';
import 'person_repository.dart';

/// Implementación de [PersonRepository] respaldada por sqflite local
/// ([PersonLocalDataSource]). Es la única capa que sabe generar ids y
/// manejar los metadatos de sincronización offline-first.
class LocalPersonRepository implements PersonRepository {
  LocalPersonRepository(this._dataSource, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final PersonLocalDataSource _dataSource;
  final Uuid _uuid;

  @override
  Future<Person> createPerson({required String name, String? phone, String? note}) async {
    final person = Person(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      note: note,
      updatedAt: DateTime.now(),
      pendingSync: true,
    );
    await _dataSource.insert(person);
    return person;
  }

  @override
  Future<Person?> getPersonById(String id) => _dataSource.getById(id);

  @override
  Future<List<Person>> getAllPeople({bool includeDeleted = false}) =>
      _dataSource.getAll(includeDeleted: includeDeleted);

  @override
  Future<Person> updatePerson(Person person) async {
    final updated = person.copyWith(updatedAt: DateTime.now(), pendingSync: true);
    await _dataSource.update(updated);
    return updated;
  }

  @override
  Future<void> deletePerson(String id) => _dataSource.delete(id);

  @override
  Future<Person> restorePerson(Person original) async {
    final restored = original.copyWith(deleted: false, updatedAt: DateTime.now(), pendingSync: true);
    await _dataSource.update(restored);
    return restored;
  }
}
