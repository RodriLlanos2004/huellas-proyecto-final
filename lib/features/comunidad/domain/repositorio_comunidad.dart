import 'dart:io';

import '../../diario/domain/entrada_diario.dart';
import 'estadisticas_comunidad.dart';
import 'publicacion.dart';

/// Usuario registrado en el servidor.
class UsuarioComunidad {
  const UsuarioComunidad({required this.id, required this.alias});
  final int id;
  final String alias;
}

/// Contrato del servicio web de Huellas Comunidad.
///
/// La implementación real usa HTTP + JSON ([ApiComunidadHttp]); las pruebas
/// usan una versión en memoria. Todos los errores se reportan como `FallaRed`.
abstract interface class RepositorioComunidad {
  /// GET /api/salud. Devuelve la versión de MySQL si el servidor responde.
  Future<String> probarConexion();

  /// POST /api/usuarios
  Future<UsuarioComunidad> registrarUsuario({required String alias, required String dispositivo});

  /// GET /api/publicaciones
  Future<PaginaPublicaciones> obtenerPublicaciones({int? categoriaId, String? texto, int? usuarioId});

  /// GET /api/publicaciones/{id}
  Future<Publicacion> obtenerPublicacion(int id);

  /// POST /api/publicaciones (multipart: datos JSON + foto opcional)
  Future<Publicacion> publicar(EntradaDiario entrada, {required int usuarioId, File? foto});

  /// POST /api/publicaciones/{id}/me-gusta
  Future<EstadoMeGusta> alternarMeGusta(int publicacionId, {required int usuarioId});

  /// DELETE /api/publicaciones/{id}
  Future<void> eliminar(int publicacionId, {required int usuarioId});

  /// GET /api/estadisticas
  Future<EstadisticasComunidad> obtenerEstadisticas();
}
