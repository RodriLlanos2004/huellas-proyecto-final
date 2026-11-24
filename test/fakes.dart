import 'dart:io';

import 'package:huellas/core/dependencias.dart';
import 'package:huellas/core/dispositivo/servicio_dictado.dart';
import 'package:huellas/core/dispositivo/servicio_imagenes.dart';
import 'package:huellas/core/dispositivo/servicio_mapas_externos.dart';
import 'package:huellas/core/dispositivo/servicio_permisos.dart';
import 'package:huellas/core/dispositivo/servicio_ubicacion.dart';
import 'package:huellas/core/errores.dart';
import 'package:huellas/features/comunidad/data/bitacora_sincronizacion.dart';
import 'package:huellas/features/comunidad/domain/estadisticas_comunidad.dart';
import 'package:huellas/features/comunidad/domain/publicacion.dart';
import 'package:huellas/features/comunidad/domain/repositorio_comunidad.dart';
import 'package:huellas/features/diario/domain/categoria.dart';
import 'package:huellas/features/diario/domain/estado_animo.dart';
import 'package:huellas/features/diario/domain/registro_sincronizacion.dart';
import 'package:huellas/features/diario/data/almacen_imagenes.dart';
import 'package:huellas/features/diario/data/servicio_respaldo.dart';
import 'package:huellas/features/diario/domain/entrada_diario.dart';
import 'package:huellas/features/diario/domain/metadatos_entrada.dart';
import 'package:huellas/features/diario/domain/repositorio_diario.dart';
import 'package:huellas/features/diario/domain/ubicacion.dart';
import 'package:huellas/features/seguridad/data/preferencias_app.dart';
import 'package:huellas/features/seguridad/data/servicio_biometrico.dart';

/// Repositorio en memoria. Si [fallar] es true, simula un error de SQLite.
class RepositorioFalso implements RepositorioDiario {
  RepositorioFalso([List<EntradaDiario>? iniciales]) : entradas = [...?iniciales];
  final List<EntradaDiario> entradas;
  bool fallar = false;
  int _siguienteId = 100;

  void _quizaFallar() {
    if (fallar) throw const FallaAlmacenamiento('No se pudo leer tu diario. Intenta de nuevo.');
  }

  @override
  Future<List<EntradaDiario>> obtenerTodas() async {
    _quizaFallar();
    return [...entradas]..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  @override
  Future<EntradaDiario?> obtenerPorId(int id) async =>
      entradas.where((e) => e.id == id).firstOrNull;

  @override
  Future<EntradaDiario> guardar(EntradaDiario entrada) async {
    _quizaFallar();
    final guardada = entrada.copyWith(id: entrada.id ?? _siguienteId++);
    entradas.add(guardada);
    return guardada;
  }

  @override
  Future<void> eliminar(int id) async => entradas.removeWhere((e) => e.id == id);

  @override
  Future<List<EntradaDiario>> pendientesDePublicar() async =>
      entradas.where((e) => e.pendienteDePublicar).toList();

  @override
  Future<void> marcarPublicada(int id, int remotoId) async {
    final i = entradas.indexWhere((e) => e.id == id);
    entradas[i] = entradas[i].copyWith(remotoId: remotoId);
  }

  @override
  Future<List<Categoria>> obtenerCategorias() async => Categoria.predeterminadas;

  final sincronizaciones = <RegistroSincronizacion>[];

  @override
  Future<RegistroSincronizacion> registrarSincronizacion(RegistroSincronizacion r) async {
    sincronizaciones.add(r);
    return r;
  }

  @override
  Future<List<RegistroSincronizacion>> obtenerSincronizaciones() async =>
      sincronizaciones.reversed.toList();
}

class PreferenciasEnMemoria implements PreferenciasApp {
  @override
  bool bloqueoActivo = false;
  @override
  String servidorUrl = 'http://servidor.prueba';
  @override
  String dispositivoId = 'abcdef0123456789';
  @override
  String? alias;
  @override
  int? usuarioRemotoId;
  @override
  Future<void> guardarServidorUrl(String url) async {
    servidorUrl = url;
    usuarioRemotoId = null;
  }

  @override
  Future<void> guardarUsuario({required String alias, required int id}) async {
    this.alias = alias;
    usuarioRemotoId = id;
  }

  @override
  DateTime? ultimoRespaldo;
  @override
  Future<void> guardarBloqueoActivo(bool activo) async => bloqueoActivo = activo;
  @override
  Future<void> guardarUltimoRespaldo(DateTime momento) async => ultimoRespaldo = momento;
}

class BiometriaFalsa implements ServicioBiometrico {
  BiometriaFalsa({this.resultado = ResultadoAutenticacion.exito});
  ResultadoAutenticacion resultado;
  int intentos = 0;
  @override
  Future<DisponibilidadBiometrica> disponibilidad() async => DisponibilidadBiometrica.biometria;
  @override
  Future<ResultadoAutenticacion> autenticar(String motivo) async {
    intentos++;
    return resultado;
  }
}

class UbicacionFalsa implements ServicioUbicacion {
  FallaApp? falla;
  Ubicacion valor = const Ubicacion(latitud: 21.0419, longitud: -89.6211, precisionMetros: 8);
  @override
  Future<Ubicacion> obtenerActual({Duration limite = const Duration(seconds: 12)}) async {
    final f = falla;
    if (f != null) throw f;
    return valor;
  }
}

class DictadoFalso implements ServicioDictado {
  FallaApp? fallaAlPreparar;
  String frase = 'Hoy fue un gran día';
  @override
  bool escuchando = false;
  @override
  Future<void> preparar() async {
    final f = fallaAlPreparar;
    if (f != null) throw f;
  }

  @override
  Future<void> escuchar({
    required void Function(String texto, bool esFinal) alReconocer,
    required void Function() alTerminar,
    required void Function(String mensaje) alFallar,
    void Function(double nivel)? alCambiarNivel,
  }) async {
    escuchando = true;
    alCambiarNivel?.call(6);
    alReconocer(frase, true);
    escuchando = false;
    alTerminar();
  }

  @override
  Future<void> detener() async => escuchando = false;
  @override
  Future<void> cancelar() async => escuchando = false;
}

class ImagenesFalsas implements ServicioImagenes {
  @override
  Future<ImagenSeleccionada?> seleccionar(OrigenImagen origen) async => null;
  @override
  Future<ImagenSeleccionada?> recuperarPerdida() async => null;
}

class MapasFalsos implements ServicioMapasExternos {
  Ubicacion? abierta;
  @override
  Future<bool> abrir(Ubicacion ubicacion) async {
    abierta = ubicacion;
    return true;
  }
}

class PermisosFalsos implements ServicioPermisos {
  int aperturas = 0;
  @override
  Future<bool> abrirAjustesApp() async => ++aperturas > 0;
  @override
  Future<bool> abrirAjustesUbicacion() async => ++aperturas > 0;
}

/// Servicio web en memoria. Si [sinConexion] es true, todo falla como sin red.
class ComunidadFalsa implements RepositorioComunidad {
  ComunidadFalsa([List<Publicacion>? iniciales]) : publicaciones = [...?iniciales];
  final List<Publicacion> publicaciones;
  bool sinConexion = false;
  final publicadas = <EntradaDiario>[];
  int _siguiente = 500;

  void _quizaFallar() {
    if (sinConexion) throw const FallaRed('No hay conexión con el servidor de Huellas Comunidad.');
  }

  @override
  Future<String> probarConexion() async {
    _quizaFallar();
    return '8.4.0';
  }

  @override
  Future<UsuarioComunidad> registrarUsuario({required String alias, required String dispositivo}) async {
    _quizaFallar();
    return UsuarioComunidad(id: 42, alias: alias);
  }

  @override
  Future<PaginaPublicaciones> obtenerPublicaciones({int? categoriaId, String? texto, int? usuarioId}) async {
    _quizaFallar();
    final lista = publicaciones.where((p) => categoriaId == null || p.categoriaId == categoriaId).toList();
    return PaginaPublicaciones(total: lista.length, elementos: lista);
  }

  @override
  Future<Publicacion> obtenerPublicacion(int id) async => publicaciones.firstWhere((p) => p.id == id);

  @override
  Future<Publicacion> publicar(EntradaDiario entrada, {required int usuarioId, File? foto}) async {
    _quizaFallar();
    publicadas.add(entrada);
    final p = publicacionDeEjemplo(id: _siguiente++, titulo: entrada.titulo);
    publicaciones.add(p);
    return p;
  }

  @override
  Future<EstadoMeGusta> alternarMeGusta(int publicacionId, {required int usuarioId}) async =>
      const EstadoMeGusta(total: 1, marcado: true);

  @override
  Future<void> eliminar(int publicacionId, {required int usuarioId}) async =>
      publicaciones.removeWhere((p) => p.id == publicacionId);

  @override
  Future<EstadisticasComunidad> obtenerEstadisticas() async {
    _quizaFallar();
    return EstadisticasComunidad(
      totalPublicaciones: publicaciones.length,
      totalUsuarios: 1,
      promedioCalificacion: 9,
      gastoTotal: 120,
      porCategoria: const [],
      porAnimo: const {'feliz': 1},
    );
  }
}

Publicacion publicacionDeEjemplo({int id = 1, String titulo = 'Cenote Xlacah', int categoriaId = 1}) =>
    Publicacion(
      id: id,
      usuarioId: 7,
      alias: 'ana',
      categoriaId: categoriaId,
      categoria: Categoria.porId(categoriaId).nombre,
      categoriaColor: 0xFF00796B,
      titulo: titulo,
      texto: 'Nadamos en el cenote de Dzibilchaltún.',
      fecha: DateTime(2026, 11, 20, 12),
      animo: EstadoAnimo.feliz,
      calificacion: 9,
      gasto: 120,
      favorita: true,
      meGusta: 3,
      publicadoEn: DateTime(2026, 11, 21),
    );

/// Bitácora sin disco: en testWidgets el reloj es falso y la E/S real no termina.
class BitacoraEnMemoria extends BitacoraSincronizacion {
  final lineas = <String>[];
  @override
  Future<void> agregar(RegistroSincronizacion registro) async => lineas.add(registro.aLineaBitacora());
  @override
  Future<String> leer() async => lineas.join('\n');
}

/// Construye un contenedor de dependencias completamente falso.
Dependencias dependenciasFalsas({
  ComunidadFalsa? comunidad,
  RepositorioFalso? repositorio,
  UbicacionFalsa? ubicacion,
  DictadoFalso? dictado,
  BiometriaFalsa? biometria,
  PreferenciasEnMemoria? preferencias,
}) {
  final repo = repositorio ?? RepositorioFalso();
  return Dependencias(
    repositorio: repo,
    imagenesGuardadas: AlmacenImagenes(directorioBase: () async => Directory.systemTemp),
    respaldo: ServicioRespaldo(repo, directorioBase: () async => Directory.systemTemp),
    preferencias: preferencias ?? PreferenciasEnMemoria(),
    biometria: biometria ?? BiometriaFalsa(),
    ubicacion: ubicacion ?? UbicacionFalsa(),
    dictado: dictado ?? DictadoFalso(),
    imagenes: ImagenesFalsas(),
    mapas: MapasFalsos(),
    permisos: PermisosFalsos(),
    comunidad: comunidad ?? ComunidadFalsa(),
    bitacora: BitacoraEnMemoria(),
  );
}

EntradaDiario entradaDeEjemplo({int id = 1, String titulo = 'Paseo por Paseo de Montejo'}) =>
    EntradaDiario(
      id: id,
      titulo: titulo,
      texto: 'Caminé con mis amigos y probamos marquesitas.',
      fecha: DateTime(2026, 11, 10 + id, 18, 30),
      ubicacion: const Ubicacion(latitud: 20.9802, longitud: -89.6196, precisionMetros: 12),
      metadatos: const MetadatosEntrada(usoDictado: true, segundosDictado: 7),
    );
