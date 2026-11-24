import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/errores.dart';
import '../domain/categoria.dart';
import '../domain/entrada_diario.dart';
import '../domain/registro_sincronizacion.dart';
import '../domain/repositorio_diario.dart';
import 'base_datos_diario.dart';

/// Implementación del repositorio con SQLite (`sqflite`).
class RepositorioDiarioSqlite implements RepositorioDiario {
  RepositorioDiarioSqlite(this._bd);

  final BaseDatosDiario _bd;
  static const _tabla = BaseDatosDiario.tablaEntradas;

  /// Ejecuta una operación y traduce los errores técnicos a [FallaAlmacenamiento].
  Future<T> _ejecutar<T>(String accion, Future<T> Function(Database db) operacion) async {
    try {
      return await operacion(await _bd.conexion);
    } on DatabaseException catch (e) {
      debugPrint('SQLite falló al $accion: $e');
      throw FallaAlmacenamiento('No se pudo $accion. Intenta de nuevo.', e);
    }
  }

  @override
  Future<List<EntradaDiario>> obtenerTodas() => _ejecutar('leer tu diario', (db) async {
        final filas = await db.query(_tabla, orderBy: 'fecha DESC, id DESC');
        final entradas = <EntradaDiario>[];
        for (final fila in filas) {
          // Un registro dañado no debe impedir que se vean los demás.
          try {
            entradas.add(EntradaDiario.fromMap(fila));
          } on Object catch (e) {
            debugPrint('Registro ${fila['id']} ignorado por estar dañado: $e');
          }
        }
        return entradas;
      });

  @override
  Future<EntradaDiario?> obtenerPorId(int id) => _ejecutar('leer la entrada', (db) async {
        final filas = await db.query(_tabla, where: 'id = ?', whereArgs: [id], limit: 1);
        return filas.isEmpty ? null : EntradaDiario.fromMap(filas.first);
      });

  @override
  Future<EntradaDiario> guardar(EntradaDiario entrada) => _ejecutar('guardar la entrada', (db) async {
        _validar(entrada);
        if (entrada.id == null) {
          final id = await db.insert(_tabla, entrada.toMap());
          return entrada.copyWith(id: id);
        }
        await db.update(_tabla, entrada.toMap(), where: 'id = ?', whereArgs: [entrada.id]);
        return entrada;
      });

  @override
  Future<void> eliminar(int id) => _ejecutar('eliminar la entrada', (db) async {
        await db.delete(_tabla, where: 'id = ?', whereArgs: [id]);
      });

  @override
  Future<List<EntradaDiario>> pendientesDePublicar() =>
      _ejecutar('buscar entradas por publicar', (db) async {
        final filas = await db.query(_tabla,
            where: 'publicar = 1 AND remoto_id IS NULL', orderBy: 'fecha ASC, id ASC');
        return [for (final f in filas) EntradaDiario.fromMap(f)];
      });

  @override
  Future<void> marcarPublicada(int id, int remotoId) =>
      _ejecutar('marcar la entrada como publicada', (db) async {
        await db.update(_tabla, {'remoto_id': remotoId}, where: 'id = ?', whereArgs: [id]);
      });

  @override
  Future<List<Categoria>> obtenerCategorias() => _ejecutar('leer las categorías', (db) async {
        final filas = await db.query(BaseDatosDiario.tablaCategorias, orderBy: 'id');
        return [for (final f in filas) Categoria.fromMap(f)];
      });

  @override
  Future<RegistroSincronizacion> registrarSincronizacion(RegistroSincronizacion registro) =>
      _ejecutar('registrar la sincronización', (db) async {
        final id = await db.insert(BaseDatosDiario.tablaSincronizaciones, registro.toMap());
        return RegistroSincronizacion.fromMap({...registro.toMap(), 'id': id});
      });

  @override
  Future<List<RegistroSincronizacion>> obtenerSincronizaciones() =>
      _ejecutar('leer el historial de sincronización', (db) async {
        final filas = await db.query(BaseDatosDiario.tablaSincronizaciones,
            orderBy: 'fecha DESC, id DESC');
        return [for (final f in filas) RegistroSincronizacion.fromMap(f)];
      });

  /// Reglas de negocio que se revisan antes de escribir (además de los CHECK de SQLite).
  static void _validar(EntradaDiario e) {
    if (e.titulo.trim().isEmpty) {
      throw const FallaAlmacenamiento('La entrada necesita un título.');
    }
    if (e.calificacion < EntradaDiario.calificacionMinima ||
        e.calificacion > EntradaDiario.calificacionMaxima) {
      throw const FallaAlmacenamiento('La calificación debe estar entre 1 y 10.');
    }
    if (e.gasto < 0 || e.gasto > EntradaDiario.gastoMaximo) {
      throw const FallaAlmacenamiento('El gasto debe estar entre 0 y 100,000.');
    }
    if (!Categoria.predeterminadas.any((c) => c.id == e.categoriaId)) {
      throw const FallaAlmacenamiento('La categoría elegida no existe.');
    }
    if (e.fecha.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      throw const FallaAlmacenamiento('La fecha del recuerdo no puede estar en el futuro.');
    }
  }
}
