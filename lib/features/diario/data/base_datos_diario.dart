import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/categoria.dart';

/// Abre, crea y migra la base de datos SQLite del diario.
///
/// Entidades (tablas):
///   * `categorias`       catálogo de categorías (6 filas fijas).
///   * `entradas`         cada día registrado; `categoria_id` es llave foránea.
///   * `sincronizaciones` historial de publicaciones en el servidor web.
///
/// Se abre una sola vez (perezosamente) y la misma conexión se reutiliza
/// en toda la app. En las pruebas se inyecta otra fábrica (FFI en memoria).
class BaseDatosDiario {
  BaseDatosDiario({DatabaseFactory? fabrica, String? ruta})
      : _fabrica = fabrica ?? databaseFactory,
        _rutaFija = ruta;

  static const nombreArchivo = 'huellas.db';

  /// v1: solo `entradas`. v2: categorías, campos del formulario y sincronizaciones.
  static const version = 2;

  static const tablaEntradas = 'entradas';
  static const tablaCategorias = 'categorias';
  static const tablaSincronizaciones = 'sincronizaciones';

  final DatabaseFactory _fabrica;
  final String? _rutaFija;
  Future<Database>? _apertura;

  /// Conexión abierta. Si dos llamadas llegan a la vez, ambas esperan la misma apertura.
  Future<Database> get conexion => _apertura ??= _abrir();

  Future<Database> _abrir() async {
    final ruta = _rutaFija ?? p.join(await _fabrica.getDatabasesPath(), nombreArchivo);
    return abrirEn(_fabrica, ruta, version: version);
  }

  /// Visible para las pruebas de migración (abrir primero en v1 y luego en v2).
  static Future<Database> abrirEn(DatabaseFactory fabrica, String ruta, {required int version}) =>
      fabrica.openDatabase(
        ruta,
        options: OpenDatabaseOptions(
          version: version,
          // SQLite no revisa llaves foráneas a menos que se active en cada conexión.
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, v) async {
            await _crearV1(db);
            if (v >= 2) await _migrarAV2(db);
          },
          onUpgrade: (db, anterior, nueva) async {
            if (anterior < 2 && nueva >= 2) await _migrarAV2(db);
          },
        ),
      );

  static Future<void> _crearV1(Database db) async {
    await db.execute('''
      CREATE TABLE $tablaEntradas (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo      TEXT    NOT NULL,
        texto       TEXT    NOT NULL,
        fecha       INTEGER NOT NULL,
        animo       TEXT    NOT NULL,
        imagen      TEXT,
        latitud     REAL,
        longitud    REAL,
        precision_m REAL,
        metadatos   TEXT    NOT NULL DEFAULT '{}'
      )
    ''');
    await db.execute('CREATE INDEX idx_entradas_fecha ON $tablaEntradas(fecha DESC)');
  }

  /// Migración a la versión 2 sin perder las entradas existentes.
  static Future<void> _migrarAV2(Database db) async {
    final lote = db.batch();
    lote.execute('''
      CREATE TABLE $tablaCategorias (
        id     INTEGER PRIMARY KEY,
        nombre TEXT    NOT NULL UNIQUE,
        icono  TEXT    NOT NULL,
        color  INTEGER NOT NULL
      )
    ''');
    for (final c in Categoria.predeterminadas) {
      lote.insert(tablaCategorias, c.toMap());
    }
    // ALTER TABLE no admite REFERENCES con valor por defecto cuando las llaves
    // foráneas están activas; la relación se valida en la app y en las pruebas.
    lote.execute('ALTER TABLE $tablaEntradas ADD COLUMN categoria_id INTEGER NOT NULL '
        'DEFAULT ${Categoria.idOtro}');
    lote.execute('ALTER TABLE $tablaEntradas ADD COLUMN calificacion INTEGER NOT NULL DEFAULT 7 '
        'CHECK (calificacion BETWEEN 1 AND 10)');
    lote.execute('ALTER TABLE $tablaEntradas ADD COLUMN gasto REAL NOT NULL DEFAULT 0 '
        'CHECK (gasto >= 0)');
    lote.execute('ALTER TABLE $tablaEntradas ADD COLUMN favorita INTEGER NOT NULL DEFAULT 0');
    lote.execute('ALTER TABLE $tablaEntradas ADD COLUMN publicar INTEGER NOT NULL DEFAULT 0');
    lote.execute('ALTER TABLE $tablaEntradas ADD COLUMN remoto_id INTEGER');
    lote.execute('CREATE INDEX idx_entradas_categoria ON $tablaEntradas(categoria_id)');
    lote.execute('''
      CREATE TABLE $tablaSincronizaciones (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha    INTEGER NOT NULL,
        enviadas INTEGER NOT NULL,
        fallidas INTEGER NOT NULL,
        servidor TEXT    NOT NULL,
        detalle  TEXT    NOT NULL DEFAULT ''
      )
    ''');
    await lote.commit(noResult: true);
  }

  Future<void> cerrar() async {
    final apertura = _apertura;
    _apertura = null;
    if (apertura != null) await (await apertura).close();
  }
}
