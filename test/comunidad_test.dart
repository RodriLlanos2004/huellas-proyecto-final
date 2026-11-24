import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:huellas/core/errores.dart';
import 'package:huellas/features/comunidad/data/api_comunidad_http.dart';
import 'package:huellas/features/comunidad/data/bitacora_sincronizacion.dart';
import 'package:huellas/features/comunidad/data/servicio_sincronizacion.dart';
import 'package:huellas/features/comunidad/domain/publicacion.dart';
import 'package:huellas/features/diario/data/almacen_imagenes.dart';
import 'package:huellas/features/diario/domain/estado_animo.dart';

import 'fakes.dart';

/// JSON tal como lo devuelve FastAPI (GET /api/publicaciones/{id}).
const _jsonServidor = {
  'id': 15,
  'usuario_id': 3,
  'alias': 'rodri',
  'categoria_id': 2,
  'categoria': 'Comida',
  'categoria_icono': 'restaurant',
  'categoria_color': '#E07A4F',
  'id_local': 4,
  'titulo': 'Cochinita',
  'texto': 'Desayuno en el mercado.',
  'fecha': '2026-11-20T09:15:00',
  'animo': 'feliz',
  'calificacion': 10,
  'gasto': 85.5,
  'favorita': true,
  'latitud': 20.967,
  'longitud': -89.623,
  'foto_url': 'http://10.0.2.2:8000/fotos/abc.jpg',
  'publicado_en': '2026-11-21T10:00:00',
  'me_gusta': 2,
};

void main() {
  group('Publicacion.fromJson', () {
    test('convierte todos los campos del servicio web', () {
      final p = Publicacion.fromJson(_jsonServidor);
      expect(p.titulo, 'Cochinita');
      expect(p.categoriaColor, 0xFFE07A4F);
      expect(p.animo, EstadoAnimo.feliz);
      expect(p.gasto, 85.5);
      expect(p.ubicacion?.latitud, 20.967);
      expect(p.fecha, DateTime(2026, 11, 20, 9, 15));
    });

    test('sin coordenadas la ubicación es null y un color inválido es gris', () {
      final p = Publicacion.fromJson({
        ..._jsonServidor,
        'latitud': null,
        'longitud': null,
        'categoria_color': 'rojo',
      });
      expect(p.ubicacion, isNull);
      expect(p.categoriaColor, 0xFF757575);
    });
  });

  group('ApiComunidadHttp', () {
    ApiComunidadHttp api(MockClientHandler manejador) =>
        ApiComunidadHttp(servidor: () => 'http://servidor.prueba:8000/', cliente: MockClient(manejador));

    test('GET de publicaciones arma la URL con los filtros', () async {
      late Uri pedida;
      final r = await api((req) async {
        pedida = req.url;
        return http.Response(jsonEncode({'total': 1, 'elementos': [_jsonServidor]}), 200,
            headers: {'content-type': 'application/json'});
      }).obtenerPublicaciones(categoriaId: 2, texto: ' cochinita ');
      expect(pedida.path, '/api/publicaciones');
      expect(pedida.queryParameters, {'limite': '100', 'categoria_id': '2', 'q': 'cochinita'});
      expect(r.elementos.single.alias, 'rodri');
    });

    test('POST multipart envía los datos JSON de la entrada', () async {
      late String cuerpo;
      await api((req) async {
        cuerpo = req.body;
        return http.Response(jsonEncode(_jsonServidor), 201);
      }).publicar(entradaDeEjemplo(id: 4).copyWith(calificacion: 10, gasto: 85.5), usuarioId: 3);
      expect(cuerpo, contains('name="datos"'));
      expect(cuerpo, contains('"id_local":4'));
      expect(cuerpo, contains('"usuario_id":3'));
      expect(cuerpo, contains('"calificacion":10'));
    });

    test('un 409 muestra el detalle que envía el servidor', () async {
      final llamada = api((_) async =>
              http.Response(jsonEncode({'detail': 'Ese alias ya lo usa otra persona.'}), 409))
          .registrarUsuario(alias: 'rodri', dispositivo: 'abcdef012345');
      await expectLater(
        llamada,
        throwsA(isA<FallaRed>()
            .having((f) => f.codigo, 'codigo', 409)
            .having((f) => f.mensaje, 'mensaje', 'Ese alias ya lo usa otra persona.')),
      );
    });

    test('un 422 de validación se traduce a un mensaje legible', () async {
      final llamada = api((_) async => http.Response(
          jsonEncode({
            'detail': [
              {'loc': ['body', 'calificacion'], 'msg': 'Input should be less than or equal to 10'}
            ]
          }),
          422)).obtenerEstadisticas();
      await expectLater(llamada,
          throwsA(isA<FallaRed>().having((f) => f.mensaje, 'mensaje', contains('(calificacion)'))));
    });

    test('sin red se reporta FallaRed sin código', () async {
      final llamada = api((_) async => throw const SocketException('Connection refused'))
          .probarConexion();
      await expectLater(llamada, throwsA(isA<FallaRed>().having((f) => f.sinConexion, 'sinConexion', isTrue)));
    });
  });

  group('ServicioSincronizacion', () {
    late Directory carpeta;
    setUp(() async => carpeta = await Directory.systemTemp.createTemp('huellas_sync_'));
    tearDown(() => carpeta.delete(recursive: true));

    ServicioSincronizacion servicio(RepositorioFalso repo, ComunidadFalsa comunidad,
            PreferenciasEnMemoria prefs) =>
        ServicioSincronizacion(
          diario: repo,
          comunidad: comunidad,
          preferencias: prefs,
          imagenes: AlmacenImagenes(directorioBase: () async => carpeta),
          bitacora: BitacoraSincronizacion(directorioBase: () async => carpeta),
        );

    test('publica solo las pendientes, guarda el id remoto y escribe la bitácora', () async {
      final repo = RepositorioFalso([
        entradaDeEjemplo(id: 1).copyWith(publicar: true),
        entradaDeEjemplo(id: 2), // No marcada para publicar (RN-06).
        entradaDeEjemplo(id: 3).copyWith(publicar: true, remotoId: 99), // Ya publicada (RN-07).
      ]);
      final comunidad = ComunidadFalsa();
      final prefs = PreferenciasEnMemoria()..alias = 'rodri'..usuarioRemotoId = 42;

      final r = await servicio(repo, comunidad, prefs).sincronizar();

      expect(r.enviadas, 1);
      expect(r.fallidas, 0);
      expect(comunidad.publicadas.single.id, 1);
      expect(repo.entradas.firstWhere((e) => e.id == 1).remotoId, 500);
      expect(repo.sincronizaciones.single.exitosa, isTrue);

      final bitacora = await File('${carpeta.path}/${BitacoraSincronizacion.nombreArchivo}').readAsLines();
      expect(bitacora.first, 'fecha;enviadas;fallidas;resultado;servidor;detalle');
      expect(bitacora[1], contains(';1;0;OK;http://servidor.prueba;'));
    });

    test('sin alias no se publica nada y el intento queda registrado', () async {
      final repo = RepositorioFalso([entradaDeEjemplo().copyWith(publicar: true)]);
      final r = await servicio(repo, ComunidadFalsa(), PreferenciasEnMemoria()).sincronizar();
      expect(r.enviadas, 0);
      expect(r.fallidas, 1);
      expect(r.errores.single, contains('alias'));
      expect(repo.sincronizaciones.single.exitosa, isFalse);
    });

    test('si cambió el servidor vuelve a registrar el alias antes de publicar', () async {
      final repo = RepositorioFalso([entradaDeEjemplo().copyWith(publicar: true)]);
      final prefs = PreferenciasEnMemoria()..alias = 'rodri'; // Sin id en este servidor.
      final r = await servicio(repo, ComunidadFalsa(), prefs).sincronizar();
      expect(r.enviadas, 1);
      expect(prefs.usuarioRemotoId, 42);
    });

    test('sin conexión las entradas siguen pendientes', () async {
      final repo = RepositorioFalso([
        entradaDeEjemplo(id: 1).copyWith(publicar: true),
        entradaDeEjemplo(id: 2).copyWith(publicar: true),
      ]);
      final prefs = PreferenciasEnMemoria()..alias = 'rodri'..usuarioRemotoId = 42;
      final r = await servicio(repo, ComunidadFalsa()..sinConexion = true, prefs).sincronizar();
      expect(r.enviadas, 0);
      expect(r.fallidas, 2);
      expect(await repo.pendientesDePublicar(), hasLength(2));
    });
  });
}
