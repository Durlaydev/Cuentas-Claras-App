import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;
import 'package:path_provider/path_provider.dart';

/// Gestor de la base de datos local SQLite
/// Implementa el patrón Singleton para asegurar una única instancia
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    
    if (Platform.isAndroid || Platform.isIOS) {
      // Para móviles, usar el directorio de la aplicación
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'cuentas_claras.db');
    } else {
      // Para escritorio (Windows, Mac, Linux)
      path = join(await getDatabasesPath(), 'cuentas_claras.db');
    }

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de personas
    await db.execute('''
      CREATE TABLE persons (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        note TEXT,
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabla de deudas
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        due_date INTEGER,
        status TEXT NOT NULL DEFAULT 'open',
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (person_id) REFERENCES persons (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de pagos
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        date INTEGER NOT NULL,
        note TEXT,
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE
      )
    ''');

    // Índices para mejorar el rendimiento
    await db.execute('CREATE INDEX idx_debts_person_id ON debts(person_id)');
    await db.execute('CREATE INDEX idx_payments_debt_id ON payments(debt_id)');
    await db.execute('CREATE INDEX idx_debts_type ON debts(type)');
    await db.execute('CREATE INDEX idx_debts_status ON debts(status)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ejemplo de migración: agregar una nueva columna
      // await db.execute('ALTER TABLE persons ADD COLUMN new_column TEXT');
    }
  }

  /// Cierra la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Limpia todas las tablas (útil para testing)
  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('payments');
      await txn.delete('debts');
      await txn.delete('persons');
    });
  }
}