import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/local/debt_local_datasource.dart';
import '../data/local/payment_local_datasource.dart';
import '../data/local/person_local_datasource.dart';
import '../data/remote/debt_remote_datasource.dart';
import '../data/remote/payment_remote_datasource.dart';
import '../data/remote/person_remote_datasource.dart';
import '../models/debt.dart';
import '../models/payment.dart';
import '../models/person.dart';

/// Orquesta la sincronización offline-first entre las tablas locales
/// (`sqflite`) y Firestore, para personas, deudas y pagos.
///
/// Depende únicamente de los puertos (`PersonLocalPort`, `PersonRemotePort`,
/// etc.), nunca de las implementaciones concretas de `sqflite`/Firestore.
/// Esto es lo que permite testear toda la lógica de resolución de
/// conflictos con fakes en memoria, sin tocar una base de datos real ni la
/// red (ver `test/services/sync_service_test.dart`).
///
/// Nota de diseño: la lógica de push/pull se repite tres veces (una por
/// entidad) en lugar de generalizarse con genéricos sobre los modelos de
/// dominio. Es a propósito: los modelos (`Person`, `Debt`, `Payment`) no
/// comparten una interfaz común y no corresponde agregarles una solo para
/// esto, así que un poco de duplicación explícita es más simple de leer
/// que una abstracción genérica forzada.
class SyncService {
  SyncService({
    required PersonLocalPort personLocal,
    required DebtLocalPort debtLocal,
    required PaymentLocalPort paymentLocal,
    required PersonRemotePort personRemote,
    required DebtRemotePort debtRemote,
    required PaymentRemotePort paymentRemote,
    Connectivity? connectivity,
  }) : _personLocal = personLocal,
       _debtLocal = debtLocal,
       _paymentLocal = paymentLocal,
       _personRemote = personRemote,
       _debtRemote = debtRemote,
       _paymentRemote = paymentRemote,
       _connectivity = connectivity ?? Connectivity();

  final PersonLocalPort _personLocal;
  final DebtLocalPort _debtLocal;
  final PaymentLocalPort _paymentLocal;
  final PersonRemotePort _personRemote;
  final DebtRemotePort _debtRemote;
  final PaymentRemotePort _paymentRemote;
  final Connectivity _connectivity;

  /// Indica si el dispositivo tiene alguna conectividad de red.
  ///
  /// `connectivity_plus` 7.x cambió `checkConnectivity()` para que devuelva
  /// `List<ConnectivityResult>` en lugar de un único valor (un dispositivo
  /// puede tener, por ejemplo, wifi y datos móviles a la vez). Se considera
  /// "online" si esa lista no contiene únicamente `ConnectivityResult.none`.
  Future<bool> isOnline() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Empuja a Firestore todos los registros locales pendientes de
  /// sincronizar (`pending_sync = 1`) de las tres entidades.
  Future<void> pushPending(String uid) async {
    await _pushPersonsPending(uid);
    await _pushDebtsPending(uid);
    await _pushPaymentsPending(uid);
  }

  /// Sube las personas pendientes una por una.
  ///
  /// Si la subida de un registro puntual falla, el error se registra y se
  /// continúa con el resto del lote: un solo registro corrupto o con un
  /// problema transitorio (por ejemplo, un timeout de red) no debería
  /// impedir que el resto de los cambios pendientes se sincronicen.
  Future<void> _pushPersonsPending(String uid) async {
    final List<Person> pending = await _personLocal.getPendingSync();
    for (final Person person in pending) {
      try {
        await _personRemote.upsert(uid, person.toMap());
        await _personLocal.markSynced(person.id);
      } catch (error, stackTrace) {
        debugPrint(
          'SyncService: fallo al subir Person(${person.id}): $error\n$stackTrace',
        );
      }
    }
  }

  /// Sube las deudas pendientes una por una (ver comentario de
  /// [_pushPersonsPending] sobre por qué un fallo individual no aborta el
  /// resto del lote).
  Future<void> _pushDebtsPending(String uid) async {
    final List<Debt> pending = await _debtLocal.getPendingSync();
    for (final Debt debt in pending) {
      try {
        await _debtRemote.upsert(uid, debt.toMap());
        await _debtLocal.markSynced(debt.id);
      } catch (error, stackTrace) {
        debugPrint(
          'SyncService: fallo al subir Debt(${debt.id}): $error\n$stackTrace',
        );
      }
    }
  }

  /// Sube los pagos pendientes uno por uno (ver comentario de
  /// [_pushPersonsPending] sobre por qué un fallo individual no aborta el
  /// resto del lote).
  Future<void> _pushPaymentsPending(String uid) async {
    final List<Payment> pending = await _paymentLocal.getPendingSync();
    for (final Payment payment in pending) {
      try {
        await _paymentRemote.upsert(uid, payment.toMap());
        await _paymentLocal.markSynced(payment.id);
      } catch (error, stackTrace) {
        debugPrint(
          'SyncService: fallo al subir Payment(${payment.id}): $error\n$stackTrace',
        );
      }
    }
  }

  /// Trae de Firestore los cambios remotos de las tres entidades y los
  /// aplica localmente con resolución de conflictos "last-write-wins".
  ///
  /// [since] permite traer solo lo modificado después de esa fecha
  /// (sincronización incremental); si es `null` trae todo.
  Future<void> pullRemote(String uid, {DateTime? since}) async {
    await _pullPersons(uid, since);
    await _pullDebts(uid, since);
    await _pullPayments(uid, since);
  }

  /// Aplica last-write-wins a las personas remotas.
  ///
  /// Regla de resolución: si no hay fila local, o si `updated_at` del
  /// remoto es estrictamente mayor al local, el remoto gana y se
  /// sobrescribe localmente. Si el local es igual o más nuevo, se lo deja
  /// intacto (el remoto queda descartado por ser un dato viejo/stale).
  ///
  /// Importante: la entidad reconstruida a partir del remoto siempre se
  /// escribe con `pendingSync: false`, sin importar qué haya en el mapa
  /// remoto. Si no se hiciera esto, un dato que acaba de bajar del
  /// servidor quedaría marcado como "pendiente de subir" y el próximo
  /// `pushPending` lo volvería a subir innecesariamente, generando un loop
  /// infinito de push/pull entre el cliente y Firestore.
  Future<void> _pullPersons(String uid, DateTime? since) async {
    final List<Map<String, dynamic>> remoteRows = await _personRemote
        .fetchAllSince(uid, since);
    for (final Map<String, dynamic> remoteMap in remoteRows) {
      final String id = remoteMap['id'] as String;
      final int remoteUpdatedAt = (remoteMap['updated_at'] as num).toInt();
      final Person? local = await _personLocal.getById(id);

      final bool remoteWins =
          local == null ||
          remoteUpdatedAt > local.updatedAt.millisecondsSinceEpoch;
      if (!remoteWins) {
        continue;
      }

      final Person incoming = Person.fromMap(
        remoteMap,
      ).copyWith(pendingSync: false);
      if (local == null) {
        await _personLocal.insert(incoming);
      } else {
        await _personLocal.update(incoming);
      }
    }
  }

  /// Aplica last-write-wins a las deudas remotas (ver comentario de
  /// [_pullPersons] para el detalle de la regla de resolución y por qué
  /// `pendingSync` siempre se fuerza a `false`).
  Future<void> _pullDebts(String uid, DateTime? since) async {
    final List<Map<String, dynamic>> remoteRows = await _debtRemote
        .fetchAllSince(uid, since);
    for (final Map<String, dynamic> remoteMap in remoteRows) {
      final String id = remoteMap['id'] as String;
      final int remoteUpdatedAt = (remoteMap['updated_at'] as num).toInt();
      final Debt? local = await _debtLocal.getById(id);

      final bool remoteWins =
          local == null ||
          remoteUpdatedAt > local.updatedAt.millisecondsSinceEpoch;
      if (!remoteWins) {
        continue;
      }

      final Debt incoming = Debt.fromMap(
        remoteMap,
      ).copyWith(pendingSync: false);
      if (local == null) {
        await _debtLocal.insert(incoming);
      } else {
        await _debtLocal.update(incoming);
      }
    }
  }

  /// Aplica last-write-wins a los pagos remotos (ver comentario de
  /// [_pullPersons] para el detalle de la regla de resolución y por qué
  /// `pendingSync` siempre se fuerza a `false`).
  Future<void> _pullPayments(String uid, DateTime? since) async {
    final List<Map<String, dynamic>> remoteRows = await _paymentRemote
        .fetchAllSince(uid, since);
    for (final Map<String, dynamic> remoteMap in remoteRows) {
      final String id = remoteMap['id'] as String;
      final int remoteUpdatedAt = (remoteMap['updated_at'] as num).toInt();
      final Payment? local = await _paymentLocal.getById(id);

      final bool remoteWins =
          local == null ||
          remoteUpdatedAt > local.updatedAt.millisecondsSinceEpoch;
      if (!remoteWins) {
        continue;
      }

      final Payment incoming = Payment.fromMap(
        remoteMap,
      ).copyWith(pendingSync: false);
      if (local == null) {
        await _paymentLocal.insert(incoming);
      } else {
        await _paymentLocal.update(incoming);
      }
    }
  }

  /// Sincronización completa de conveniencia: si hay conectividad, primero
  /// sube lo pendiente y después baja los cambios remotos.
  Future<void> fullSync(String uid) async {
    if (!await isOnline()) {
      return;
    }
    await pushPending(uid);
    await pullRemote(uid);
  }
}
