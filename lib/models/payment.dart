/// Valor centinela usado por [Payment.copyWith] para distinguir "no se
/// pasó este parámetro" de "se pasó explícitamente `null`" en `note`.
const Object _unset = Object();

/// Representa un pago (parcial o total) aplicado a una [Debt] específica
/// (identificada por [debtId]).
class Payment {
  final String id;
  final String debtId;
  final int amountCents;
  final DateTime date;
  final String? note;
  final DateTime updatedAt;
  final bool pendingSync;
  final bool deleted;

  Payment._({
    required this.id,
    required this.debtId,
    required this.amountCents,
    required this.date,
    this.note,
    required this.updatedAt,
    required this.pendingSync,
    required this.deleted,
  });

  /// Factory que valida invariantes de dominio: [amountCents] debe ser
  /// mayor a cero (un pago de $0 o negativo no tiene sentido de negocio).
  factory Payment({
    required String id,
    required String debtId,
    required int amountCents,
    required DateTime date,
    String? note,
    required DateTime updatedAt,
    bool pendingSync = true,
    bool deleted = false,
  }) {
    if (amountCents <= 0) {
      throw ArgumentError.value(
        amountCents,
        'amountCents',
        'El monto del pago debe ser mayor a cero.',
      );
    }
    return Payment._(
      id: id,
      debtId: debtId,
      amountCents: amountCents,
      date: date,
      note: note,
      updatedAt: updatedAt,
      pendingSync: pendingSync,
      deleted: deleted,
    );
  }

  Payment copyWith({
    String? id,
    String? debtId,
    int? amountCents,
    DateTime? date,
    Object? note = _unset,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? deleted,
  }) {
    return Payment(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      note: identical(note, _unset) ? this.note : note as String?,
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
      'debt_id': debtId,
      'amount_cents': amountCents,
      'date': date.millisecondsSinceEpoch,
      'note': note,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'pending_sync': pendingSync ? 1 : 0,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      debtId: map['debt_id'] as String,
      amountCents: map['amount_cents'] as int,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      note: map['note'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      pendingSync: (map['pending_sync'] as int) == 1,
      deleted: (map['deleted'] as int) == 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Payment &&
        other.id == id &&
        other.debtId == debtId &&
        other.amountCents == amountCents &&
        other.date == date &&
        other.note == note &&
        other.updatedAt == updatedAt &&
        other.pendingSync == pendingSync &&
        other.deleted == deleted;
  }

  @override
  int get hashCode => Object.hash(
        id,
        debtId,
        amountCents,
        date,
        note,
        updatedAt,
        pendingSync,
        deleted,
      );

  @override
  String toString() =>
      'Payment(id: $id, debtId: $debtId, amountCents: $amountCents, '
      'date: $date, note: $note, updatedAt: $updatedAt, '
      'pendingSync: $pendingSync, deleted: $deleted)';
}
