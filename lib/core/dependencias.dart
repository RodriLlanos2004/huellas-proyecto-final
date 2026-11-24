import 'package:flutter/widgets.dart';

import '../features/comunidad/data/bitacora_sincronizacion.dart';
import '../features/comunidad/data/servicio_sincronizacion.dart';
import '../features/comunidad/domain/repositorio_comunidad.dart';
import '../features/diario/data/almacen_imagenes.dart';
import '../features/diario/data/servicio_respaldo.dart';
import '../features/diario/domain/repositorio_diario.dart';
import '../features/seguridad/data/preferencias_app.dart';
import '../features/seguridad/data/servicio_biometrico.dart';
import 'dispositivo/servicio_dictado.dart';
import 'dispositivo/servicio_imagenes.dart';
import 'dispositivo/servicio_mapas_externos.dart';
import 'dispositivo/servicio_permisos.dart';
import 'dispositivo/servicio_ubicacion.dart';

/// Contenedor de dependencias de la app.
///
/// Las pantallas solo conocen interfaces (RepositorioDiario, ServicioUbicacion…).
/// Las implementaciones concretas se eligen una sola vez en `main.dart`
/// (raíz de composición) y en las pruebas se sustituyen por versiones falsas.
class Dependencias {
  Dependencias({
    required this.repositorio,
    required this.imagenesGuardadas,
    required this.respaldo,
    required this.preferencias,
    required this.biometria,
    required this.ubicacion,
    required this.dictado,
    required this.imagenes,
    required this.mapas,
    required this.permisos,
    required this.comunidad,
    required this.bitacora,
  });

  final RepositorioDiario repositorio;
  final AlmacenImagenes imagenesGuardadas;
  final ServicioRespaldo respaldo;
  final PreferenciasApp preferencias;
  final ServicioBiometrico biometria;
  final ServicioUbicacion ubicacion;
  final ServicioDictado dictado;
  final ServicioImagenes imagenes;
  final ServicioMapasExternos mapas;
  final ServicioPermisos permisos;

  /// Servicio web de Huellas Comunidad (HTTP + MySQL en el servidor).
  final RepositorioComunidad comunidad;

  /// Archivo plano con el historial de sincronizaciones.
  final BitacoraSincronizacion bitacora;

  /// Se arma con las demás dependencias; no necesita pasarse al constructor.
  late final ServicioSincronizacion sincronizacion = ServicioSincronizacion(
    diario: repositorio,
    comunidad: comunidad,
    preferencias: preferencias,
    imagenes: imagenesGuardadas,
    bitacora: bitacora,
  );

  /// Indica si la pantalla de bloqueo ya está visible, para no apilarla dos veces.
  final ValueNotifier<bool> bloqueoVisible = ValueNotifier<bool>(false);
}

/// Expone [Dependencias] a todo el árbol de widgets.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.dependencias, required super.child});

  final Dependencias dependencias;

  static Dependencias of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No hay un AppScope arriba en el árbol de widgets');
    return scope!.dependencias;
  }

  // Las dependencias no cambian durante la vida de la app.
  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
