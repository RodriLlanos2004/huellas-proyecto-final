import 'package:flutter/foundation.dart';

import '../../../core/errores.dart';
import '../../diario/data/almacen_imagenes.dart';
import '../../diario/domain/registro_sincronizacion.dart';
import '../../diario/domain/repositorio_diario.dart';
import '../../seguridad/data/preferencias_app.dart';
import '../domain/repositorio_comunidad.dart';
import 'bitacora_sincronizacion.dart';

/// Resultado que la pantalla muestra al terminar.
class ResultadoSincronizacion {
  const ResultadoSincronizacion({required this.registro, required this.errores});
  final RegistroSincronizacion registro;
  final List<String> errores;

  int get enviadas => registro.enviadas;
  int get fallidas => registro.fallidas;
}

/// Sube al servidor las entradas marcadas como "publicar" que aún no tienen
/// id remoto, y deja constancia en SQLite (tabla `sincronizaciones`) y en el
/// archivo plano de bitácora.
///
/// Reglas de negocio:
///  * RN-06 Solo se publican entradas con la casilla "Publicar" activa.
///  * RN-07 Una entrada se publica una sola vez (se guarda su `remoto_id`).
///  * RN-08 Hace falta un alias registrado antes de publicar.
///  * RN-14 Cada intento, exitoso o no, queda registrado.
class ServicioSincronizacion {
  ServicioSincronizacion({
    required this._diario,
    required this._comunidad,
    required this._preferencias,
    required this._imagenes,
    required this._bitacora,
  });

  final RepositorioDiario _diario;
  final RepositorioComunidad _comunidad;
  final PreferenciasApp _preferencias;
  final AlmacenImagenes _imagenes;
  final BitacoraSincronizacion _bitacora;

  /// Garantiza que el usuario exista en el servidor actual y devuelve su id.
  Future<int> _usuario() async {
    final id = _preferencias.usuarioRemotoId;
    if (id != null) return id;
    final alias = _preferencias.alias;
    if (alias == null) {
      throw const FallaRed('Primero elige tu alias de la comunidad en Ajustes.');
    }
    // Se cambió de servidor: se vuelve a registrar el mismo alias.
    final usuario = await _comunidad.registrarUsuario(
        alias: alias, dispositivo: _preferencias.dispositivoId);
    await _preferencias.guardarUsuario(alias: usuario.alias, id: usuario.id);
    return usuario.id;
  }

  Future<ResultadoSincronizacion> sincronizar({DateTime Function()? reloj}) async {
    final ahora = reloj ?? DateTime.now;
    final servidor = _preferencias.servidorUrl;
    final pendientes = await _diario.pendientesDePublicar();
    final errores = <String>[];
    var enviadas = 0;

    try {
      final usuarioId = pendientes.isEmpty ? null : await _usuario();
      for (final entrada in pendientes) {
        try {
          final foto = entrada.imagen == null ? null : _imagenes.archivo(entrada.imagen!);
          final publicada = await _comunidad.publicar(entrada, usuarioId: usuarioId!, foto: foto);
          await _diario.marcarPublicada(entrada.id!, publicada.id);
          enviadas++;
        } on FallaRed catch (f) {
          errores.add('${entrada.titulo}: ${f.mensaje}');
          // Sin conexión no tiene caso intentar las demás.
          if (f.sinConexion) break;
        }
      }
    } on FallaRed catch (f) {
      errores.add(f.mensaje);
    }

    final fallidas = pendientes.length - enviadas;
    final registro = await _diario.registrarSincronizacion(RegistroSincronizacion(
      fecha: ahora(),
      enviadas: enviadas,
      fallidas: fallidas,
      servidor: servidor,
      detalle: errores.isEmpty
          ? (pendientes.isEmpty ? 'No había entradas pendientes' : 'Todo publicado')
          : errores.join(' | '),
    ));
    await _bitacora.agregar(registro);
    debugPrint('Sincronización: $enviadas enviadas, $fallidas fallidas');
    return ResultadoSincronizacion(registro: registro, errores: errores);
  }
}
