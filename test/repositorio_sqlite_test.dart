import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huellas/features/diario/data/base_datos_diario.dart';
import 'package:huellas/features/diario/data/repositorio_diario_sqlite.dart';
import 'package:huellas/core/errores.dart';
import 'package:huellas/features/diario/domain/categoria.dart';
import 'package:huellas/features/diario/domain/entrada_diario.dart';
import 'package:huellas/features/diario/domain/registro_sincronizacion.dart';
import 'package:huellas/features/diario/domain/ubicacion.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pruebas del repositorio contra un SQLite real en memoria (sqflite_common_ffi).
void main() {
  sqfliteFfiInit();
  late BaseDatosDiario bd;
  late RepositorioDiarioSqlite repo;

  setUp(() {
    bd = BaseDatosDiario(fabrica: databaseFactoryFfi, ruta: inMemoryDatabasePath);
    repo = RepositorioDiarioSqlite(bd);
  });

  tearDown(() => bd.cerrar());

  EntradaDiario entrada(String titulo, DateTime fecha, {Ubicacion? ubicacion}) =>
      EntradaDiario(titulo: titulo, texto: 'texto de $titulo', fecha: fecha, ubicacion: ubicacion);

  test('guardar asigna id y la entrada se puede leer de nuevo', () async {
    final guardada = await repo.guardar(entrada('Uno', DateTime(2026, 11, 1),
        ubicacion: const Ubicacion(latitud: 21.0, longitud: -89.6)));
    expect(guardada.id, isNotNull);
    final leida = await repo.obtenerPorId(guardada.id!);
    expect(leida?.titulo, 'Uno');
    expect(leida?.ubicacion?.latitud, 21.0);
  });

  test('obtenerTodas ordena de la más reciente a la más antigua', () async {
    await repo.guardar(entrada('Vieja', DateTime(2026, 1, 1)));
    await repo.guardar(entrada('Nueva', DateTime(2026, 11, 1)));
    final todas = await repo.obtenerTodas();
    expect(todas.map((e) => e.titulo), ['Nueva', 'Vieja']);
  });

  test('guardar con id existente actualiza en lugar de duplicar', () async {
    final g = await repo.guardar(entrada('Original', DateTime(2026)));
    await repo.guardar(g.copyWith(titulo: 'Editada'));
    final todas = await repo.obtenerTodas();
    expect(todas, hasLength(1));
    expect(todas.single.titulo, 'Editada');
  });

  test('eliminar borra la entrada', () async {
    final g = await repo.guardar(entrada('Borrar', DateTime(2026)));
    await repo.eliminar(g.id!);
    expect(await repo.obtenerTodas(), isEmpty);
  });

  test('un registro dañado se ignora sin perder los demás', () async {
    await repo.guardar(entrada('Sana', DateTime(2026)));
    final db = await bd.conexion;
    // Fecha guardada como texto: fromMap fallará al convertirla.
    await db.insert(BaseDatosDiario.tablaEntradas,
        {'titulo': 'Dañada', 'texto': 'x', 'fecha': 'no-es-fecha', 'animo': 'feliz'});
    final todas = await repo.obtenerTodas();
    expect(todas.map((e) => e.titulo), ['Sana']);
  });

  test('la base nueva trae el catálogo de 6 categorías', () async {
    final categorias = await repo.obtenerCategorias();
    expect(categorias.map((c) => c.nombre), ['Viajes', 'Comida', 'Escuela', 'Familia', 'Deporte', 'Otro']);
  });

  test('los campos numéricos, lógicos y la categoría se guardan y se leen', () async {
    final g = await repo.guardar(entrada('Tacos', DateTime(2026, 11, 2))
        .copyWith(categoriaId: 2, calificacion: 9, gasto: 120.5, favorita: true, publicar: true));
    final leida = (await repo.obtenerPorId(g.id!))!;
    expect(leida.categoria.nombre, 'Comida');
    expect(leida.calificacion, 9);
    expect(leida.gasto, 120.5);
    expect(leida.favorita, isTrue);
    expect(leida.publicar, isTrue);
  });

  test('pendientes de publicar y marcar como publicada', () async {
    final a = await repo.guardar(entrada('A', DateTime(2026, 11, 1)).copyWith(publicar: true));
    await repo.guardar(entrada('B', DateTime(2026, 11, 2)));
    expect((await repo.pendientesDePublicar()).map((e) => e.titulo), ['A']);
    await repo.marcarPublicada(a.id!, 77);
    expect(await repo.pendientesDePublicar(), isEmpty);
    expect((await repo.obtenerPorId(a.id!))!.remotoId, 77);
  });

  test('las reglas de negocio impiden guardar datos inválidos', () async {
    final base = entrada('X', DateTime(2026, 11, 1));
    expect(() => repo.guardar(base.copyWith(calificacion: 11)), throwsA(isA<FallaAlmacenamiento>()));
    expect(() => repo.guardar(base.copyWith(gasto: -5)), throwsA(isA<FallaAlmacenamiento>()));
    expect(() => repo.guardar(base.copyWith(categoriaId: 99)), throwsA(isA<FallaAlmacenamiento>()));
    expect(() => repo.guardar(base.copyWith(fecha: DateTime.now().add(const Duration(days: 2)))),
        throwsA(isA<FallaAlmacenamiento>()));
  });

  test('el historial de sincronizaciones se lee del más reciente al más antiguo', () async {
    for (final dia in [1, 3, 2]) {
      await repo.registrarSincronizacion(RegistroSincronizacion(
          fecha: DateTime(2026, 11, dia), enviadas: dia, fallidas: 0, servidor: 'http://x'));
    }
    final historial = await repo.obtenerSincronizaciones();
    expect(historial.map((r) => r.enviadas), [3, 2, 1]);
    expect(historial.first.id, isNotNull);
  });

  test('migrar de la versión 1 a la 2 conserva las entradas', () async {
    final ruta = '${Directory.systemTemp.path}/huellas_migracion_${DateTime.now().microsecondsSinceEpoch}.db';
    final v1 = await BaseDatosDiario.abrirEn(databaseFactoryFfi, ruta, version: 1);
    await v1.insert(BaseDatosDiario.tablaEntradas, {
      'titulo': 'De la versión 1',
      'texto': 'Entrada antigua',
      'fecha': DateTime(2026, 11, 10).millisecondsSinceEpoch,
      'animo': 'feliz',
    });
    await v1.close();

    final bdV2 = BaseDatosDiario(fabrica: databaseFactoryFfi, ruta: ruta);
    final repoV2 = RepositorioDiarioSqlite(bdV2);
    final todas = await repoV2.obtenerTodas();
    expect(todas.single.titulo, 'De la versión 1');
    expect(todas.single.categoriaId, Categoria.idOtro);
    expect(todas.single.calificacion, 7);
    expect(await repoV2.obtenerCategorias(), hasLength(6));
    await bdV2.cerrar();
    await File(ruta).delete();
  });
}
