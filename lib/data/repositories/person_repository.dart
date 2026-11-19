import '../../models/person.dart';

/// Puerto (en el sentido de arquitectura hexagonal) que expone la capa de
/// datos a providers/pantallas. La UI depende únicamente de esta interfaz,
/// nunca de `PersonLocalDataSource` directamente: así, el día de mañana se
/// puede reemplazar (o decorar, por ejemplo con un `SyncRepository` que
/// además empuje cambios a Firestore) la implementación sin tocar ni una
/// línea del código que consume el repositorio.
abstract class PersonRepository {
  /// Crea una persona nueva. El repositorio decide `id` (uuid v4),
  /// `updatedAt` y `pendingSync = true`; quien llama solo aporta los
  /// campos de negocio.
  Future<Person> createPerson({required String name, String? phone, String? note});

  /// Busca una persona por id.
  Future<Person?> getPersonById(String id);

  /// Devuelve todas las personas (excluye eliminadas por defecto).
  Future<List<Person>> getAllPeople({bool includeDeleted = false});

  /// Actualiza una persona existente. El repositorio bump-ea `updatedAt` y
  /// vuelve a marcar `pendingSync = true`, sin importar qué haya pasado
  /// quien llama en esos campos.
  Future<Person> updatePerson(Person person);

  /// Elimina (soft delete) una persona: la marca `deleted = true` y
  /// `pendingSync = true`, sin borrar la fila físicamente.
  Future<void> deletePerson(String id);

  /// Restaura una persona previamente eliminada, re-persistiendo [original]
  /// con `deleted = false`. Pensado para el flujo de "Deshacer" tras un
  /// borrado accidental (ver `PeopleProvider.restoreLastDeleted`).
  Future<Person> restorePerson(Person original);
}
