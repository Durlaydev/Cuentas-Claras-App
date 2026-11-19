import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

/// Nombres de las tablas de la base de datos local. Se centralizan aquí
/// para que los data sources no repitan strings mágicos.
class AppDatabaseTables {
  static const String people = 'people';
  static const String debts = 'debts';
  static const String payments = 'payments';
}

/// Envoltorio sobre la base de datos `sqflite` de la app.
///
/// Expone un único punto de acceso ([database]) que abre (o crea, en el
/// primer uso) el archivo `cuentas_claras.db`. Se puede construir con un
/// [DatabaseFactory] y una ruta alternativos (por ejemplo
/// `databaseFactoryFfi` + `inMemoryDatabasePath` en tests), lo que evita
/// tocar el sistema de archivos real durante los tests y permite instancias
/// aisladas por test.
class AppDatabase {
  AppDatabase({sqflite.DatabaseFactory? databaseFactory, String? path})
    : _databaseFactory = databaseFactory,
      _path = path;

  /// Versión actual del esquema. Se incrementa cada vez que se agrega una
  /// migración en [_onUpgrade].
  static const int schemaVersion = 1;

  final sqflite.DatabaseFactory? _databaseFactory;
  final String? _path;

  sqflite.Database? _db;

  /// Devuelve la base de datos abierta, abriéndola (y creando el esquema
  /// si es la primera vez) de ser necesario.
  Future<sqflite.Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final opened = await _open();
    _db = opened;
    return opened;
  }

  Future<sqflite.Database> _open() async {
    final factory = _databaseFactory ?? sqflite.databaseFactory;
    final path = _path ?? p.join(await factory.getDatabasesPath(), 'cuentas_claras.db');
    return factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// `onCreate` solo se ejecuta la primera vez que se crea el archivo de
  /// base de datos (instalación nueva). Acá se define el esquema completo
  /// de la versión actual.
  Future<void> _onCreate(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppDatabaseTables.people} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        note TEXT,
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppDatabaseTables.debts} (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        due_date INTEGER,
        status TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (person_id) REFERENCES ${AppDatabaseTables.people} (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_debts_person_id ON ${AppDatabaseTables.debts} (person_id)',
    );

    await db.execute('''
      CREATE TABLE ${AppDatabaseTables.payments} (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (debt_id) REFERENCES ${AppDatabaseTables.debts} (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_payments_debt_id ON ${AppDatabaseTables.payments} (debt_id)',
    );
  }

  /// Stub de migraciones futuras. Mientras [schemaVersion] siga en 1 este
  /// método no se ejecuta nunca. Cuando se agregue un cambio de esquema
  /// (por ejemplo una columna nueva), se debe: 1) subir [schemaVersion],
  /// 2) agregar aquí un `if (oldVersion < N) { await db.execute('ALTER TABLE ...'); }`
  /// incremental por cada versión intermedia, para que un dispositivo que
  /// viene de cualquier versión anterior termine con el esquema correcto.
  Future<void> _onUpgrade(sqflite.Database db, int oldVersion, int newVersion) async {
    // Sin migraciones todavía: la versión 1 es la única que existió.
  }

  /// Cierra la conexión y libera la instancia cacheada, para que el
  /// próximo acceso a [database] vuelva a abrirla. Pensado para tests
  /// que necesitan aislar cada caso.
  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}
