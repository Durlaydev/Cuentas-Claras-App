/// Valor centinela usado por [Person.copyWith] para distinguir "no se
/// pasó este parámetro" de "se pasó explícitamente `null`", de modo que
/// los campos opcionales (`phone`, `note`) puedan limpiarse a `null`.
const Object _unset = Object();

/// Representa a una persona con la que se registran deudas o préstamos.
///
/// Además de sus datos propios, cada modelo del dominio transporta los
/// campos de sincronización offline-first (`updatedAt`, `pendingSync`,
/// `deleted`) que usará más adelante la capa de sincronización.
class Person {
  final String id;
  final String name;
  final String? phone;
  final String? note;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  const Person({
    required this.id,
    required this.name,
    this.phone,
    this.note,
    required this.updatedAt,
    this.pendingSync = true,
    this.deleted = false,
  });

  Person copyWith({
    String? id,
    String? name,
    Object? phone = _unset,
    Object? note = _unset,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Convierte la instancia a un mapa con claves snake_case, listo para
  /// insertarse como fila en una tabla `sqflite`. Las fechas se guardan
  /// como milisegundos desde epoch (`updated_at`) y los booleanos como
  /// enteros 0/1 (`pending_sync`, `deleted`), que es la convención que
  /// usa sqflite ya que SQLite no tiene tipos nativos `DateTime`/`bool`.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'note': note,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'pending_sync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      note: map['note'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      pendingSync: (map['pending_sync'] as int) == 1,
      deleted: (map['deleted'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Person &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.note == note &&
        other.updatedAt == updatedAt &&
        other.pendingSync == pendingSync &&
        other.deleted == deleted;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, phone, note, updatedAt, pendingSync, deleted);

  @override
  String toString() =>
      'Person(id: $id, name: $name, phone: $phone, note: $note, '
      'updatedAt: $updatedAt, pendingSync: $pendingSync, deleted: $deleted)';
}
