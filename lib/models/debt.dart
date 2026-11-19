/// Valor centinela usado por [Debt.copyWith] para distinguir "no se pasó
/// este parámetro" de "se pasó explícitamente `null`" en `dueDate`.
const Object _unset = Object();

/// Tipo de deuda, agnóstico de idioma/UI. Las etiquetas legibles en
/// español ("Me deben" / "Debo") viven en `lib/utils/debt_type_label.dart`,
/// no aquí, para que el modelo de dominio no dependa de la presentación.
enum DebtType { owedToMe, iOwe }

/// Estado de una deuda.
enum DebtStatus { open, paid }

String _debtTypeToStorage(DebtType type) {
  switch (type) {
    case DebtType.owedToMe:
      return 'owed_to_me';
    case DebtType.iOwe:
      return 'i_owe';
  }
}

DebtType _debtTypeFromStorage(String value) {
  switch (value) {
    case 'owed_to_me':
      return DebtType.owedToMe;
    case 'i_owe':
      return DebtType.iOwe;
    default:
      throw ArgumentError.value(value, 'type', 'Tipo de deuda desconocido.');
  }
}

String _debtStatusToStorage(DebtStatus status) {
  switch (status) {
    case DebtStatus.open:
      return 'open';
    case DebtStatus.paid:
      return 'paid';
  }
}

DebtStatus _debtStatusFromStorage(String value) {
  switch (value) {
    case 'open':
      return DebtStatus.open;
    case 'paid':
      return DebtStatus.paid;
    default:
      throw ArgumentError.value(
        value,
        'status',
        'Estado de deuda desconocido.',
      );
  }
}

/// Representa una deuda entre el usuario y una [Person] (identificada por
/// [personId]): dinero que le prestaron ([DebtType.owedToMe]) o dinero que
/// debe ([DebtType.iOwe]).
class Debt {
  final String id;
  final String personId;
  final DebtType type;
  final String description;
  final int amountCents;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DebtStatus status;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  Debt._({
    required this.id,
    required this.personId,
    required this.type,
    required this.description,
    required this.amountCents,
    required this.createdAt,
    this.dueDate,
    required this.status,
    required this.updatedAt,
    required this.pendingSync,
    required this.deleted,
  });

  /// Factory que valida invariantes de dominio antes de construir la
  /// instancia: [amountCents] debe ser mayor a cero (una deuda de $0 o
  /// negativa no tiene sentido de negocio).
  factory Debt({
    required String id,
    required String personId,
    required DebtType type,
    required String description,
    required int amountCents,
    required DateTime createdAt,
    DateTime? dueDate,
    DebtStatus status = DebtStatus.open,
    required DateTime updatedAt,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError.value(
        amountCents,
        'amountCents',
        'El monto de la deuda debe ser mayor a cero.',
      );
    }
    return Debt._(
      id: id,
      personId: personId,
      type: type,
      description: description,
      amountCents: amountCents,
      createdAt: createdAt,
      dueDate: dueDate,
      status: status,
      updatedAt: updatedAt,
      pendingSync: pendingSync,
      deleted: deleted,
    );
  }

  Debt copyWith({
    String? id,
    String? personId,
    DebtType? type,
    String? description,
    int? amountCents,
    DateTime? createdAt,
    Object? dueDate = _unset,
    DebtStatus? status,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return Debt(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      type: type ?? this.type,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      createdAt: createdAt ?? this.createdAt,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      deleted: deleted ?? this.deleted,
    );
  }

  /// Convierte la instancia a un mapa con claves snake_case para
  /// `sqflite`. Fechas como milisegundos desde epoch y booleanos como
  /// enteros 0/1 (convención sqflite, ya que SQLite no tiene tipos
  /// nativos `DateTime`/`bool`).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_id': personId,
      'type': _debtTypeToStorage(type),
      'description': description,
      'amount_cents': amountCents,
      'created_at': createdAt.millisecondsSinceEpoch,
      'due_date': dueDate?.millisecondsSinceEpoch,
      'status': _debtStatusToStorage(status),
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'pending_sync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      type: _debtTypeFromStorage(map['type'] as String),
      description: map['description'] as String,
      amountCents: map['amount_cents'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      dueDate: map['due_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
      status: _debtStatusFromStorage(map['status'] as String),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      pendingSync: (map['pending_sync'] as int) == 1,
      deleted: (map['deleted'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Debt &&
        other.id == id &&
        other.personId == personId &&
        other.type == type &&
        other.description == description &&
        other.amountCents == amountCents &&
        other.createdAt == createdAt &&
        other.dueDate == dueDate &&
        other.status == status &&
        other.updatedAt == updatedAt &&
        other.pendingSync == pendingSync &&
        other.deleted == deleted;
  }

  @override
  int get hashCode => Object.hash(
        id,
        personId,
        type,
        description,
        amountCents,
        createdAt,
        dueDate,
        status,
        updatedAt,
        pendingSync,
        deleted,
      );

  @override
  String toString() =>
      'Debt(id: $id, personId: $personId, type: $type, '
      'description: $description, amountCents: $amountCents, '
      'createdAt: $createdAt, dueDate: $dueDate, status: $status, '
      'updatedAt: $updatedAt, pendingSync: $pendingSync, deleted: $deleted)';
}
