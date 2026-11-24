import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/dependencias.dart';
import 'core/dispositivo/servicio_dictado.dart';
import 'core/dispositivo/servicio_imagenes.dart';
import 'core/dispositivo/servicio_mapas_externos.dart';
import 'core/dispositivo/servicio_permisos.dart';
import 'core/dispositivo/servicio_ubicacion.dart';
import 'features/comunidad/data/api_comunidad_http.dart';
import 'features/comunidad/data/bitacora_sincronizacion.dart';
import 'features/diario/data/almacen_imagenes.dart';
import 'features/diario/data/base_datos_diario.dart';
import 'features/diario/data/repositorio_diario_sqlite.dart';
import 'features/diario/data/servicio_respaldo.dart';
import 'features/seguridad/data/preferencias_app.dart';
import 'features/seguridad/data/servicio_biometrico.dart';

/// Raíz de composición: aquí se eligen las implementaciones concretas.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Red de seguridad: un error no capturado se registra en lugar de cerrar la app.
  PlatformDispatcher.instance.onError = (error, pila) {
    debugPrint('Error no capturado: $error\n$pila');
    return true;
  };

  try {
    final imagenes = AlmacenImagenes();
    await imagenes.inicializar();
    final repositorio = RepositorioDiarioSqlite(BaseDatosDiario());
    final preferencias = await PreferenciasCompartidas.cargar();

    final dependencias = Dependencias(
      repositorio: repositorio,
      imagenesGuardadas: imagenes,
      respaldo: ServicioRespaldo(repositorio),
      preferencias: preferencias,
      biometria: ServicioBiometricoLocalAuth(),
      ubicacion: ServicioUbicacionGeolocator(),
      dictado: ServicioDictadoSpeech(),
      imagenes: ServicioImagenesPicker(),
      mapas: ServicioMapasUrlLauncher(),
      permisos: ServicioPermisosSistema(),
      comunidad: ApiComunidadHttp(servidor: () => preferencias.servidorUrl),
      bitacora: BitacoraSincronizacion(),
    );
    runApp(HuellasApp(dependencias: dependencias));
  } on Object catch (e) {
    runApp(_ErrorDeArranque(error: e));
  }
}

/// Pantalla mínima si algo falla antes de construir la app.
class _ErrorDeArranque extends StatelessWidget {
  const _ErrorDeArranque({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Huellas no pudo iniciar.\n\n$error', textAlign: TextAlign.center),
            ),
          ),
        ),
      );
}
