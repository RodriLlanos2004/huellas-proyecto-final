import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:path/path.dart' as p;

import '../../../core/errores.dart';
import '../../diario/domain/entrada_diario.dart';
import '../domain/estadisticas_comunidad.dart';
import '../domain/publicacion.dart';
import '../domain/repositorio_comunidad.dart';

/// Cliente del servicio web REST (FastAPI + MySQL) con el paquete `http`.
///
/// * Todas las peticiones tienen tiempo límite: una red lenta no congela la app.
/// * Las excepciones técnicas (SocketException, TimeoutException,
///   ClientException) y las respuestas 4xx/5xx se convierten en [FallaRed]
///   con un mensaje en español.
class ApiComunidadHttp implements RepositorioComunidad {
  ApiComunidadHttp({
    required this._servidor,
    http.Client? cliente,
    this.limite = const Duration(seconds: 10),
  }) : _cliente = cliente ?? http.Client();

  /// Se lee en cada petición: si el usuario cambia la URL en Ajustes, aplica de inmediato.
  final String Function() _servidor;
  final http.Client _cliente;
  final Duration limite;

  Uri _uri(String ruta, [Map<String, String>? consulta]) {
    final base = _servidor().trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$ruta').replace(queryParameters: consulta);
  }

  static const _json = {'Content-Type': 'application/json; charset=utf-8'};

  /// Ejecuta la petición y devuelve el cuerpo JSON ya decodificado.
  Future<dynamic> _enviar(String accion, Future<http.Response> Function() peticion) async {
    final http.Response r;
    try {
      r = await peticion().timeout(limite);
    } on TimeoutException catch (e) {
      throw FallaRed('El servidor tardó demasiado al $accion. Revisa tu conexión.', causa: e);
    } on SocketException catch (e) {
      throw FallaRed('No hay conexión con el servidor de Huellas Comunidad. '
          '¿Está encendido y la dirección es correcta?', causa: e);
    } on http.ClientException catch (e) {
      throw FallaRed('No se pudo $accion: la conexión se interrumpió.', causa: e);
    } on FormatException catch (e) {
      throw FallaRed('La dirección del servidor no es válida.', causa: e);
    } on ArgumentError catch (e) {
      throw FallaRed('La dirección del servidor no es válida.', causa: e);
    }

    final cuerpo = utf8.decode(r.bodyBytes);
    dynamic datos;
    if (cuerpo.isNotEmpty) {
      try {
        datos = jsonDecode(cuerpo);
      } on FormatException catch (e) {
        throw FallaRed('El servidor respondió algo que no es JSON.', codigo: r.statusCode, causa: e);
      }
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return datos;

    debugPrint('HTTP ${r.statusCode} al $accion: $cuerpo');
    throw FallaRed(_mensajeDeError(accion, r.statusCode, datos), codigo: r.statusCode);
  }

  /// FastAPI responde {"detail": "texto"} o {"detail": [{"msg": ...}, ...]} (422).
  static String _mensajeDeError(String accion, int codigo, dynamic datos) {
    final detalle = datos is Map ? datos['detail'] : null;
    if (detalle is String) return detalle;
    if (detalle is List && detalle.isNotEmpty) {
      final primero = detalle.first;
      if (primero is Map && primero['msg'] is String) {
        final campo = (primero['loc'] as List?)?.lastOrNull;
        return 'Dato rechazado${campo == null ? '' : ' ($campo)'}: ${primero['msg']}';
      }
    }
    return switch (codigo) {
      404 => 'No se encontró lo que se buscaba en el servidor.',
      503 => 'La base de datos del servidor no está disponible.',
      >= 500 => 'El servidor tuvo un problema al $accion.',
      _ => 'No se pudo $accion (código $codigo).',
    };
  }

  /// Campos que se envían al publicar. Coinciden con `PublicacionEntrada` del backend.
  static Map<String, dynamic> datosPublicacion(EntradaDiario e, int usuarioId) => {
        'usuario_id': usuarioId,
        'categoria_id': e.categoriaId,
        'id_local': e.id,
        'titulo': e.titulo,
        'texto': e.texto,
        'fecha': e.fecha.toIso8601String(),
        'animo': e.animo.name,
        'calificacion': e.calificacion,
        'gasto': e.gasto,
        'favorita': e.favorita,
        'latitud': e.ubicacion?.latitud,
        'longitud': e.ubicacion?.longitud,
      };

  @override
  Future<String> probarConexion() async {
    final datos = await _enviar('probar la conexión', () => _cliente.get(_uri('/api/salud')));
    return (datos as Map<String, dynamic>)['mysql'] as String? ?? 'MySQL';
  }

  @override
  Future<UsuarioComunidad> registrarUsuario({required String alias, required String dispositivo}) async {
    final datos = await _enviar(
      'registrar tu alias',
      () => _cliente.post(_uri('/api/usuarios'),
          headers: _json, body: jsonEncode({'alias': alias, 'dispositivo': dispositivo})),
    ) as Map<String, dynamic>;
    return UsuarioComunidad(id: datos['id'] as int, alias: datos['alias'] as String);
  }

  @override
  Future<PaginaPublicaciones> obtenerPublicaciones({int? categoriaId, String? texto, int? usuarioId}) async {
    final consulta = <String, String>{
      'limite': '100',
      if (categoriaId != null) 'categoria_id': '$categoriaId',
      if (usuarioId != null) 'usuario_id': '$usuarioId',
      if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
    };
    final datos = await _enviar('consultar la comunidad',
        () => _cliente.get(_uri('/api/publicaciones', consulta)));
    return PaginaPublicaciones.fromJson(datos as Map<String, dynamic>);
  }

  @override
  Future<Publicacion> obtenerPublicacion(int id) async {
    final datos = await _enviar('consultar la publicación',
        () => _cliente.get(_uri('/api/publicaciones/$id')));
    return Publicacion.fromJson(datos as Map<String, dynamic>);
  }

  @override
  Future<Publicacion> publicar(EntradaDiario entrada, {required int usuarioId, File? foto}) async {
    if (entrada.id == null) throw ArgumentError('La entrada debe estar guardada antes de publicarse');
    final datos = await _enviar('publicar "${entrada.titulo}"', () async {
      final peticion = http.MultipartRequest('POST', _uri('/api/publicaciones'))
        ..fields['datos'] = jsonEncode(datosPublicacion(entrada, usuarioId));
      if (foto != null && await foto.exists()) {
        final extension = p.extension(foto.path).toLowerCase();
        peticion.files.add(await http.MultipartFile.fromPath(
          'foto',
          foto.path,
          contentType: MediaType('image', extension == '.png' ? 'png' : 'jpeg'),
        ));
      }
      return http.Response.fromStream(await _cliente.send(peticion));
    });
    return Publicacion.fromJson(datos as Map<String, dynamic>);
  }

  @override
  Future<EstadoMeGusta> alternarMeGusta(int publicacionId, {required int usuarioId}) async {
    final datos = await _enviar(
      'marcar me gusta',
      () => _cliente.post(_uri('/api/publicaciones/$publicacionId/me-gusta'),
          headers: _json, body: jsonEncode({'usuario_id': usuarioId})),
    ) as Map<String, dynamic>;
    return EstadoMeGusta(total: datos['me_gusta'] as int, marcado: datos['marcado'] as bool);
  }

  @override
  Future<void> eliminar(int publicacionId, {required int usuarioId}) => _enviar(
        'eliminar la publicación',
        () => _cliente.delete(
            _uri('/api/publicaciones/$publicacionId', {'usuario_id': '$usuarioId'})),
      );

  @override
  Future<EstadisticasComunidad> obtenerEstadisticas() async {
    final datos = await _enviar('consultar las estadísticas',
        () => _cliente.get(_uri('/api/estadisticas')));
    return EstadisticasComunidad.fromJson(datos as Map<String, dynamic>);
  }
}
