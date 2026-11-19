import 'package:cloud_firestore/cloud_firestore.dart';

/// Puerto (interfaz) con las operaciones remotas sobre pagos que necesita
/// `SyncService`. Permite que los tests de sincronización usen un fake en
/// memoria en vez de tocar Firestore real (`flutter test` nunca debe hacer
/// llamadas de red).
abstract class PaymentRemotePort {
  /// Sube (crea o actualiza) el documento identificado por `data['id']`.
  /// [data] es el resultado de `Payment.toMap()`.
  Future<void> upsert(String uid, Map<String, dynamic> data);

  /// Trae los documentos de la colección de pagos del usuario [uid]. Si
  /// [since] es `null` trae todos los documentos; si no, solo los que
  /// tengan `updated_at` estrictamente posterior (sincronización
  /// incremental).
  Future<List<Map<String, dynamic>>> fetchAllSince(
    String uid,
    DateTime? since,
  );
}

/// Implementación real sobre Cloud Firestore. Los documentos remotos viven
/// en `users/{uid}/payments`, en espejo con la tabla local `payments` (ver
/// `firestore.rules` en la raíz del proyecto).
class PaymentRemoteDataSource implements PaymentRemotePort {
  PaymentRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _collectionName = 'payments';

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection(_collectionName);

  @override
  Future<void> upsert(String uid, Map<String, dynamic> data) async {
    final String id = data['id'] as String;
    // `merge: true` para no pisar campos escritos por otro dispositivo
    // entre la lectura y la escritura de este; el conflicto real por campo
    // se resuelve del lado del cliente en `SyncService` (last-write-wins
    // por `updated_at`), aquí solo se asegura la escritura del documento.
    await _collection(uid).doc(id).set(data, SetOptions(merge: true));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAllSince(
    String uid,
    DateTime? since,
  ) async {
    Query<Map<String, dynamic>> query = _collection(uid);
    if (since != null) {
      query = query.where(
        'updated_at',
        isGreaterThan: since.millisecondsSinceEpoch,
      );
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data();
      // El id es el nombre del documento, no necesariamente un campo
      // propio; se inyecta aquí para que el resto del pipeline de sync
      // (que trabaja con `toMap()`/`fromMap()`) siempre lo encuentre.
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
