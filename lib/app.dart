import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/dependencias.dart';
import 'core/rutas.dart';
import 'core/tema.dart';
import 'features/ajustes/presentation/ajustes_page.dart';
import 'features/comunidad/domain/publicacion.dart';
import 'features/comunidad/presentation/pages/comunidad_page.dart';
import 'features/comunidad/presentation/pages/detalle_publicacion_page.dart';
import 'features/comunidad/presentation/pages/sincronizaciones_page.dart';
import 'features/diario/domain/entrada_diario.dart';
import 'features/diario/presentation/pages/detalle_entrada_page.dart';
import 'features/diario/presentation/pages/formulario_entrada_page.dart';
import 'features/diario/presentation/pages/lista_diario_page.dart';
import 'features/diario/presentation/pages/mapa_recuerdos_page.dart';
import 'features/seguridad/presentation/bloqueo_page.dart';

/// Widget raíz. Configura el tema, las rutas nombradas y el bloqueo al volver
/// de segundo plano (WidgetsBindingObserver).
class HuellasApp extends StatefulWidget {
  const HuellasApp({super.key, required this.dependencias, this.rutaInicial});
  final Dependencias dependencias;

  /// Permite a las pruebas abrir una pantalla concreta. Si es null se decide
  /// entre bloqueo o lista según las preferencias.
  final String? rutaInicial;

  @override
  State<HuellasApp> createState() => _HuellasAppState();
}

class _HuellasAppState extends State<HuellasApp> with WidgetsBindingObserver {
  final _navegador = GlobalKey<NavigatorState>();
  DateTime? _enSegundoPlanDesde;

  /// Tiempo en segundo plano tras el cual se vuelve a pedir la huella.
  /// Un minuto permite tomar una foto con la cámara sin que la app se bloquee.
  static const _tiempoDeGracia = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    switch (estado) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _enSegundoPlanDesde ??= DateTime.now();
      case AppLifecycleState.resumed:
        final desde = _enSegundoPlanDesde;
        _enSegundoPlanDesde = null;
        if (desde != null && DateTime.now().difference(desde) >= _tiempoDeGracia) _bloquear();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _bloquear() {
    final dep = widget.dependencias;
    if (!dep.preferencias.bloqueoActivo || dep.bloqueoVisible.value) return;
    _navegador.currentState?.pushNamed(Rutas.bloqueo, arguments: true);
  }

  /// Convierte un nombre de ruta en su pantalla.
  static Route<dynamic> _generarRuta(RouteSettings ajustes) {
    final Widget pagina;
    switch (ajustes.name) {
      case Rutas.bloqueo:
        pagina = BloqueoPage(esReanudacion: ajustes.arguments == true);
      case Rutas.lista:
        pagina = const ListaDiarioPage();
      case Rutas.nueva:
        pagina = const FormularioEntradaPage();
      case Rutas.detalle:
        final entrada = ajustes.arguments;
        if (entrada is! EntradaDiario) return _rutaDesconocida(ajustes);
        pagina = DetalleEntradaPage(entrada: entrada);
      case Rutas.mapa:
        pagina = const MapaRecuerdosPage();
      case Rutas.ajustes:
        pagina = const AjustesPage();
      case Rutas.comunidad:
        pagina = const ComunidadPage();
      case Rutas.publicacion:
        // La publicación viaja como argumento desde la lista o la cuadrícula.
        final publicacion = ajustes.arguments;
        if (publicacion is! Publicacion) return _rutaDesconocida(ajustes);
        pagina = DetallePublicacionPage(publicacion: publicacion);
      case Rutas.sincronizaciones:
        pagina = const SincronizacionesPage();
      default:
        return _rutaDesconocida(ajustes);
    }
    return MaterialPageRoute<dynamic>(
      settings: ajustes,
      // El formulario se presenta como diálogo de pantalla completa (botón X).
      fullscreenDialog: ajustes.name == Rutas.nueva,
      builder: (_) => pagina,
    );
  }

  static Route<dynamic> _rutaDesconocida(RouteSettings ajustes) => MaterialPageRoute<dynamic>(
        settings: ajustes,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Página no encontrada')),
          body: Center(child: Text('La ruta "${ajustes.name}" no existe.')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dep = widget.dependencias;
    return AppScope(
      dependencias: dep,
      child: MaterialApp(
        title: 'Huellas',
        debugShowCheckedModeBanner: false,
        theme: TemaHuellas.claro(),
        darkTheme: TemaHuellas.oscuro(),
        navigatorKey: _navegador,
        // Textos de Material (selectores de fecha y hora, tooltips) en español.
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorObservers: [observadorRutas],
        initialRoute:
            widget.rutaInicial ?? (dep.preferencias.bloqueoActivo ? Rutas.bloqueo : Rutas.lista),
        // Por defecto, una ruta inicial "/bloqueo" apilaría también "/" debajo.
        // Así solo se crea la pantalla pedida y la lista no se carga antes de autenticar.
        onGenerateInitialRoutes: (inicial) => [_generarRuta(RouteSettings(name: inicial))],
        onGenerateRoute: _generarRuta,
      ),
    );
  }
}
