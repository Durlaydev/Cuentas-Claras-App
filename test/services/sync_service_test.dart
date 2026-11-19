import 'package:flutter_test/flutter_test.dart';

import 'package:cuentas_claras/data/local/debt_local_datasource.dart';
import 'package:cuentas_claras/data/local/payment_local_datasource.dart';
import 'package:cuentas_claras/data/local/person_local_datasource.dart';
import 'package:cuentas_claras/data/remote/debt_remote_datasource.dart';
import 'package:cuentas_claras/data/remote/payment_remote_datasource.dart';
import 'package:cuentas_claras/data/remote/person_remote_datasource.dart';
import 'package:cuentas_claras/models/debt.dart';
import 'package:cuentas_claras/models/payment.dart';
import 'package:cuentas_claras/models/person.dart';
import 'package:cuentas_claras/services/sync_service.dart';

/// Fake en memoria de [PersonLocalPort]. Reemplaza a `sqflite` en los
/// tests: mismo contrato (mismos métodos), sin base de datos real.
class FakePersonLocalDataSource implements PersonLocalPort {
  final Map<String, Person> store = {};
  final List<String> markSyncedCalls = [];

  @override
  Future<void> insert(Person person) async => store[person.id] = person;

  @override
  Future<void> update(Person person) async => store[person.id] = person;

  @override
  Future<Person?> getById(String id) async => store[id];

  @override
  Future<List<Person>> getPendingSync() async =>
      store.values.where((p) => p.pendingSync).toList();

  @override
  Future<void> markSynced(String id) async {
    markSyncedCalls.add(id);
    final existing = store[id];
    if (existing != null) {
      store[id] = existing.copyWith(pendingSync: false);
    }
  }
}

/// Fake en memoria de [PersonRemotePort]. [failingIds] simula ids cuya
/// subida (`upsert`) falla, para probar la resiliencia ante fallos
/// parciales de `pushPending`.
class FakePersonRemoteDataSource implements PersonRemotePort {
  FakePersonRemoteDataSource({this.failingIds = const {}});

  final Set<String> failingIds;
  final Map<String, Map<String, dynamic>> store = {};
  final List<String> upsertCalls = [];

  void seedRemote(Map<String, dynamic> data) {
    store[data['id'] as String] = data;
  }

  @override
  Future<void> upsert(String uid, Map<String, dynamic> data) async {
    final String id = data['id'] as String;
    upsertCalls.add(id);
    if (failingIds.contains(id)) {
      throw Exception('Fallo simulado al subir $id');
    }
    store[id] = data;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllSince(
    String uid,
    DateTime? since,
  ) async {
    Iterable<Map<String, dynamic>> rows = store.values;
    if (since != null) {
      rows = rows.where(
        (row) => (row['updated_at'] as int) > since.millisecondsSinceEpoch,
      );
    }
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}

/// Fakes vacíos de deudas y pagos: `SyncService` necesita los seis puertos
/// para construirse, pero estos tests de conflicto se centran en personas;
/// no tener filas en estos fakes es un `pushPending`/`pullRemote` no-op
/// para esas dos entidades, lo cual es el comportamiento correcto.
class FakeDebtLocalDataSource implements DebtLocalPort {
  final Map<String, Debt> store = {};

  @override
  Future<void> insert(Debt debt) async => store[debt.id] = debt;

  @override
  Future<void> update(Debt debt) async => store[debt.id] = debt;

  @override
  Future<Debt?> getById(String id) async => store[id];

  @override
  Future<List<Debt>> getPendingSync() async =>
      store.values.where((d) => d.pendingSync).toList();

  @override
  Future<void> markSynced(String id) async {
    final existing = store[id];
    if (existing != null) {
      store[id] = existing.copyWith(pendingSync: false);
    }
  }
}

class FakeDebtRemoteDataSource implements DebtRemotePort {
  final Map<String, Map<String, dynamic>> store = {};

  @override
  Future<void> upsert(String uid, Map<String, dynamic> data) async {
    store[data['id'] as String] = data;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllSince(
    String uid,
    DateTime? since,
  ) async {
    Iterable<Map<String, dynamic>> rows = store.values;
    if (since != null) {
      rows = rows.where(
        (row) => (row['updated_at'] as int) > since.millisecondsSinceEpoch,
      );
    }
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}

class FakePaymentLocalDataSource implements PaymentLocalPort {
  final Map<String, Payment> store = {};

  @override
  Future<void> insert(Payment payment) async => store[payment.id] = payment;

  @override
  Future<void> update(Payment payment) async => store[payment.id] = payment;

  @override
  Future<Payment?> getById(String id) async => store[id];

  @override
  Future<List<Payment>> getPendingSync() async =>
      store.values.where((p) => p.pendingSync).toList();

  @override
  Future<void> markSynced(String id) async {
    final existing = store[id];
    if (existing != null) {
      store[id] = existing.copyWith(pendingSync: false);
    }
  }
}

class FakePaymentRemoteDataSource implements PaymentRemotePort {
  final Map<String, Map<String, dynamic>> store = {};

  @override
  Future<void> upsert(String uid, Map<String, dynamic> data) async {
    store[data['id'] as String] = data;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllSince(
    String uid,
    DateTime? since,
  ) async {
    Iterable<Map<String, dynamic>> rows = store.values;
    if (since != null) {
      rows = rows.where(
        (row) => (row['updated_at'] as int) > since.millisecondsSinceEpoch,
      );
    }
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }
}

const String _uid = 'test-uid';

SyncService _buildSyncService({
  required FakePersonLocalDataSource personLocal,
  required FakePersonRemoteDataSource personRemote,
}) {
  return SyncService(
    personLocal: personLocal,
    debtLocal: FakeDebtLocalDataSource(),
    paymentLocal: FakePaymentLocalDataSource(),
    personRemote: personRemote,
    debtRemote: FakeDebtRemoteDataSource(),
    paymentRemote: FakePaymentRemoteDataSource(),
  );
}

void main() {
  group('SyncService.pullRemote - last-write-wins', () {
    test('el remoto gana cuando su updated_at es más nuevo', () async {
      final DateTime t1 = DateTime(2026, 1, 1);
      final DateTime t2 = DateTime(2026, 1, 2);

      final FakePersonLocalDataSource personLocal = FakePersonLocalDataSource();
      final Person localPerson = Person(
        id: 'p1',
        name: 'Nombre viejo',
        updatedAt: t1,
        pendingSync: false,
      );
      personLocal.store[localPerson.id] = localPerson;

      final FakePersonRemoteDataSource personRemote =
          FakePersonRemoteDataSource();
      personRemote.seedRemote({
        'id': 'p1',
        'name': 'Nombre nuevo',
        'phone': null,
        'note': null,
        'updated_at': t2.millisecondsSinceEpoch,
        'pending_sync': 0,
        'deleted': 0,
      });

      final SyncService sync = _buildSyncService(
        personLocal: personLocal,
        personRemote: personRemote,
      );

      await sync.pullRemote(_uid);

      final Person? updated = await personLocal.getById('p1');
      expect(updated, isNotNull);
      expect(updated!.name, 'Nombre nuevo');
      expect(updated.updatedAt, t2);
    });

    test('el local gana cuando es más nuevo que el remoto (stale ignorado)', () async {
      final DateTime t3 = DateTime(2026, 1, 10);
      final DateTime t4 = DateTime(2026, 1, 5);

      final FakePersonLocalDataSource personLocal = FakePersonLocalDataSource();
      final Person localPerson = Person(
        id: 'p2',
        name: 'Nombre local vigente',
        updatedAt: t3,
        pendingSync: false,
      );
      personLocal.store[localPerson.id] = localPerson;

      final FakePersonRemoteDataSource personRemote =
          FakePersonRemoteDataSource();
      personRemote.seedRemote({
        'id': 'p2',
        'name': 'Nombre remoto viejo',
        'phone': null,
        'note': null,
        'updated_at': t4.millisecondsSinceEpoch,
        'pending_sync': 0,
        'deleted': 0,
      });

      final SyncService sync = _buildSyncService(
        personLocal: personLocal,
        personRemote: personRemote,
      );

      await sync.pullRemote(_uid);

      final Person? unchanged = await personLocal.getById('p2');
      expect(unchanged, isNotNull);
      expect(unchanged!.name, 'Nombre local vigente');
      expect(unchanged.updatedAt, t3);
    });

    test('sin fila local, se inserta directamente el remoto', () async {
      final DateTime remoteUpdatedAt = DateTime(2026, 1, 3);

      final FakePersonLocalDataSource personLocal = FakePersonLocalDataSource();
      final FakePersonRemoteDataSource personRemote =
          FakePersonRemoteDataSource();
      personRemote.seedRemote({
        'id': 'p3',
        'name': 'Persona solo remota',
        'phone': null,
        'note': null,
        'updated_at': remoteUpdatedAt.millisecondsSinceEpoch,
        'pending_sync': 0,
        'deleted': 0,
      });

      final SyncService sync = _buildSyncService(
        personLocal: personLocal,
        personRemote: personRemote,
      );

      await sync.pullRemote(_uid);

      final Person? inserted = await personLocal.getById('p3');
      expect(inserted, isNotNull);
      expect(inserted!.name, 'Persona solo remota');
    });

    test(
      'los registros bajados del remoto nunca quedan con pending_sync = true '
      '(evita el loop infinito de push/pull)',
      () async {
        final DateTime t1 = DateTime(2026, 1, 1);
        final DateTime t2 = DateTime(2026, 1, 2);

        final FakePersonLocalDataSource personLocal =
            FakePersonLocalDataSource();
        personLocal.store['p4'] = Person(
          id: 'p4',
          name: 'Antes de sincronizar',
          updatedAt: t1,
          pendingSync: false,
        );

        final FakePersonRemoteDataSource personRemote =
            FakePersonRemoteDataSource();
        // El documento remoto trae `pending_sync: 1` (por ejemplo, porque
        // el otro dispositivo lo subió mientras aún estaba pendiente en su
        // propia base local). Aun así, localmente debe quedar en `false`.
        personRemote.seedRemote({
          'id': 'p4',
          'name': 'Después de sincronizar',
          'phone': null,
          'note': null,
          'updated_at': t2.millisecondsSinceEpoch,
          'pending_sync': 1,
          'deleted': 0,
        });

        final SyncService sync = _buildSyncService(
          personLocal: personLocal,
          personRemote: personRemote,
        );

        await sync.pullRemote(_uid);

        final Person? result = await personLocal.getById('p4');
        expect(result, isNotNull);
        expect(
          result!.pendingSync,
          isFalse,
          reason:
              'Un dato que acaba de bajar del servidor no debe quedar '
              'marcado como pendiente de subir, o el próximo pushPending '
              'lo volvería a subir en un loop infinito.',
        );
      },
    );
  });

  group('SyncService.pushPending', () {
    test(
      'un registro local pendiente sin contraparte remota se sube y se '
      'marca como sincronizado',
      () async {
        final FakePersonLocalDataSource personLocal =
            FakePersonLocalDataSource();
        final Person pendingPerson = Person(
          id: 'p5',
          name: 'Creada offline',
          updatedAt: DateTime(2026, 1, 1),
          pendingSync: true,
        );
        personLocal.store[pendingPerson.id] = pendingPerson;

        final FakePersonRemoteDataSource personRemote =
            FakePersonRemoteDataSource();

        final SyncService sync = _buildSyncService(
          personLocal: personLocal,
          personRemote: personRemote,
        );

        await sync.pushPending(_uid);

        expect(personRemote.upsertCalls, contains('p5'));
        expect(personRemote.store['p5']!['name'], 'Creada offline');
        expect(personLocal.markSyncedCalls, contains('p5'));
        expect((await personLocal.getById('p5'))!.pendingSync, isFalse);
      },
    );

    test(
      'si la subida de un registro falla, el resto del lote se sigue '
      'subiendo (resiliencia ante fallos parciales)',
      () async {
        final FakePersonLocalDataSource personLocal =
            FakePersonLocalDataSource();
        final DateTime now = DateTime(2026, 1, 1);
        personLocal.store['ok-1'] = Person(
          id: 'ok-1',
          name: 'Primera',
          updatedAt: now,
          pendingSync: true,
        );
        personLocal.store['fails'] = Person(
          id: 'fails',
          name: 'Falla al subir',
          updatedAt: now,
          pendingSync: true,
        );
        personLocal.store['ok-2'] = Person(
          id: 'ok-2',
          name: 'Tercera',
          updatedAt: now,
          pendingSync: true,
        );

        final FakePersonRemoteDataSource personRemote =
            FakePersonRemoteDataSource(failingIds: {'fails'});

        final SyncService sync = _buildSyncService(
          personLocal: personLocal,
          personRemote: personRemote,
        );

        await sync.pushPending(_uid);

        // Los tres intentos de subida se hicieron...
        expect(
          personRemote.upsertCalls,
          containsAll(<String>['ok-1', 'fails', 'ok-2']),
        );
        // ...pero solo los dos que no fallaron quedaron sincronizados.
        expect(personLocal.markSyncedCalls, containsAll(<String>['ok-1', 'ok-2']));
        expect(personLocal.markSyncedCalls, isNot(contains('fails')));
        expect((await personLocal.getById('ok-1'))!.pendingSync, isFalse);
        expect((await personLocal.getById('ok-2'))!.pendingSync, isFalse);
        expect((await personLocal.getById('fails'))!.pendingSync, isTrue);
      },
    );
  });
}
