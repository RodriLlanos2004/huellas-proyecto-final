import 'package:flutter/widgets.dart';

/// Nombres de las rutas de la app (Named Routes).
///
/// Centralizarlos evita errores de escritura y documenta en un solo lugar
/// todas las pantallas. El generador que convierte cada nombre en una página
/// vive en `app.dart`.
abstract final class Rutas {
  static const bloqueo = '/bloqueo';
  static const lista = '/';
  static const detalle = '/detalle';
  static const nueva = '/nueva';
  static const mapa = '/mapa';
  static const ajustes = '/ajustes';
  static const comunidad = '/comunidad';
  static const publicacion = '/comunidad/publicacion';
  static const sincronizaciones = '/sincronizaciones';
}

/// Observador global de rutas. La lista del diario lo usa para recargarse
/// cada vez que el usuario regresa a ella desde otra pantalla.
final RouteObserver<ModalRoute<void>> observadorRutas = RouteObserver<ModalRoute<void>>();
