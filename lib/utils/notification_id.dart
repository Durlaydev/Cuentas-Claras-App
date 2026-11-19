/// Deriva un id entero determinístico y no negativo a partir de un
/// identificador de tipo String (por ejemplo, el id de una deuda).
///
/// El plugin `flutter_local_notifications` requiere ids de tipo `int` para
/// programar y cancelar notificaciones, mientras que en el resto de la
/// aplicación los identificadores de dominio son `String` (uuid). Esta
/// función convierte un `String` en un `int` positivo de 31 bits usando el
/// `hashCode` de Dart, de modo que el mismo String siempre produce el mismo
/// id (necesario para poder cancelar más adelante la notificación asociada).
///
/// Riesgo de colisión: dos strings distintos podrían producir el mismo id
/// si sus hashes coinciden. Para una aplicación de aprendizaje este riesgo
/// es aceptable, pero en un sistema de producción real se debería mantener
/// una tabla de mapeo explícita (id de dominio -> id entero) para garantizar
/// unicidad y evitar que dos recordatorios se pisen entre sí.
int deriveNotificationId(String id) => id.hashCode & 0x7fffffff;
