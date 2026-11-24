import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huellas/app.dart';
import 'package:huellas/core/dependencias.dart';
import 'package:huellas/core/errores.dart';
import 'package:huellas/core/rutas.dart';
import 'package:huellas/features/diario/presentation/pages/formulario_entrada_page.dart';
import 'package:huellas/features/seguridad/data/servicio_biometrico.dart';

import 'fakes.dart';

/// Simula la pantalla de un teléfono (432 x 960 puntos lógicos) para que el
/// formulario completo quepa sin desplazarse.
void _pantallaDeTelefono(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

/// Monta solo el formulario, con un botón para abrirlo y comprobar el resultado.
Future<void> _abrirFormulario(WidgetTester tester, Dependencias dep) async {
  _pantallaDeTelefono(tester);
  await tester.pumpWidget(AppScope(
    dependencias: dep,
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute<bool>(builder: (_) => const FormularioEntradaPage())),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

/// Abre la app directamente en [ruta] (sin bloqueo) usando el generador real de rutas.
Widget _soloPagina(Dependencias dep, String ruta) => HuellasApp(dependencias: dep, rutaInicial: ruta);

void main() {
  testWidgets('lista vacía muestra la invitación a escribir', (tester) async {
    await tester.pumpWidget(HuellasApp(dependencias: dependenciasFalsas()));
    await tester.pumpAndSettle();
    expect(find.text('Tu diario está vacío'), findsOneWidget);
    expect(find.text('Nueva entrada'), findsOneWidget);
  });

  testWidgets('la lista muestra las entradas guardadas y el resumen', (tester) async {
    final repo = RepositorioFalso([entradaDeEjemplo(id: 1), entradaDeEjemplo(id: 2, titulo: 'Cenote')]);
    await tester.pumpWidget(HuellasApp(dependencias: dependenciasFalsas(repositorio: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Cenote'), findsOneWidget);
    expect(find.text('Paseo por Paseo de Montejo'), findsOneWidget);
    expect(find.text('lugares'), findsOneWidget);
  });

  testWidgets('si SQLite falla se muestra el error con botón Reintentar', (tester) async {
    final repo = RepositorioFalso()..fallar = true;
    await tester.pumpWidget(HuellasApp(dependencias: dependenciasFalsas(repositorio: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Algo salió mal'), findsOneWidget);

    repo.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Tu diario está vacío'), findsOneWidget);
  });

  testWidgets('el botón Nueva entrada abre el formulario y al guardar vuelve a la lista', (tester) async {
    _pantallaDeTelefono(tester);
    final repo = RepositorioFalso();
    await tester.pumpWidget(HuellasApp(dependencias: dependenciasFalsas(repositorio: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva entrada'));
    await tester.pumpAndSettle();
    expect(find.text('Agrega una foto de tu día'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Título del día'), 'Primer día');
    await tester.enterText(find.widgetWithText(TextFormField, '¿Qué pasó hoy?'), 'Todo bien.');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Entrada guardada en tu diario'), findsOneWidget);
    expect(find.text('Primer día'), findsOneWidget);
  });

  testWidgets('tocar una tarjeta abre el detalle con su mapa', (tester) async {
    _pantallaDeTelefono(tester);
    final repo = RepositorioFalso([entradaDeEjemplo()]);
    await tester.pumpWidget(HuellasApp(dependencias: dependenciasFalsas(repositorio: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paseo por Paseo de Montejo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¿Dónde fue?'), findsOneWidget);
    expect(find.text('Abrir en Google Maps'), findsOneWidget);
  });

  testWidgets('el drawer navega al mapa con rutas nombradas', (tester) async {
    _pantallaDeTelefono(tester);
    // La fuente de pruebas (cuadros del mismo ancho) es más ancha que Roboto.
    tester.platformDispatcher.textScaleFactorTestValue = 0.85;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(HuellasApp(dependencias: dependenciasFalsas()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa de recuerdos'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay lugares'), findsOneWidget);
  });

  testWidgets('con bloqueo activo, la app abre en la pantalla de huella', (tester) async {
    final prefs = PreferenciasEnMemoria()..bloqueoActivo = true;
    final bio = BiometriaFalsa(resultado: ResultadoAutenticacion.cancelado);
    await tester.pumpWidget(
        HuellasApp(dependencias: dependenciasFalsas(preferencias: prefs, biometria: bio)));
    await tester.pumpAndSettle();
    expect(find.text('Tu diario está protegido'), findsOneWidget);
    expect(find.textContaining('cancelada'), findsOneWidget);

    bio.resultado = ResultadoAutenticacion.exito;
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Mis huellas'), findsOneWidget);
  });

  testWidgets('el formulario valida los campos obligatorios', (tester) async {
    await _abrirFormulario(tester, dependenciasFalsas());
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ponle un título a tu día'), findsOneWidget);
    expect(find.text('Cuenta un poco de tu día'), findsOneWidget);
  });

  testWidgets('el dictado escribe en el campo de texto', (tester) async {
    await _abrirFormulario(tester, dependenciasFalsas());
    await tester.tap(find.byTooltip('Dictar con voz'));
    await tester.pumpAndSettle();
    expect(find.text('Hoy fue un gran día'), findsOneWidget);
  });

  testWidgets('micrófono negado muestra el aviso de permiso', (tester) async {
    final dictado = DictadoFalso()
      ..fallaAlPreparar = const FallaPermiso('Micrófono bloqueado', permanente: true);
    await _abrirFormulario(tester, dependenciasFalsas(dictado: dictado));
    await tester.tap(find.byTooltip('Dictar con voz'));
    await tester.pumpAndSettle();
    expect(find.text('Permiso necesario'), findsOneWidget);
    expect(find.text('Abrir ajustes'), findsOneWidget);
  });

  testWidgets('guardar captura el GPS y escribe en el repositorio', (tester) async {
    final repo = RepositorioFalso();
    await _abrirFormulario(tester, dependenciasFalsas(repositorio: repo));
    await tester.enterText(find.widgetWithText(TextFormField, 'Título del día'), 'Cenote Ik Kil');
    await tester.enterText(find.widgetWithText(TextFormField, '¿Qué pasó hoy?'), 'Nadamos un rato.');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();
    expect(repo.entradas, hasLength(1));
    expect(repo.entradas.single.ubicacion?.latitud, 21.0419);
  });

  testWidgets('sin permiso de GPS se ofrece guardar sin ubicación', (tester) async {
    final repo = RepositorioFalso();
    final gps = UbicacionFalsa()..falla = const FallaPermiso('Sin permiso de ubicación');
    await _abrirFormulario(tester, dependenciasFalsas(repositorio: repo, ubicacion: gps));
    await tester.enterText(find.widgetWithText(TextFormField, 'Título del día'), 'Sin GPS');
    await tester.enterText(find.widgetWithText(TextFormField, '¿Qué pasó hoy?'), 'Día en casa.');
    await tester.tap(find.byTooltip('Guardar'));
    // El indicador de progreso sigue girando detrás del diálogo: no se usa pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Permiso de ubicación'), findsOneWidget);
    await tester.tap(find.text('Guardar sin ubicación'));
    await tester.pumpAndSettle();
    expect(repo.entradas.single.ubicacion, isNull);
  });

  testWidgets('la calificación fuera de 1 a 10 se rechaza', (tester) async {
    final repo = RepositorioFalso();
    await _abrirFormulario(tester, dependenciasFalsas(repositorio: repo));
    await tester.enterText(find.widgetWithText(TextFormField, 'Título del día'), 'Examen');
    await tester.enterText(find.widgetWithText(TextFormField, '¿Qué pasó hoy?'), 'Estudié mucho.');
    await tester.scrollUntilVisible(find.text('Calificación'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.widgetWithText(TextFormField, 'Calificación'), '11');
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Debe ser de 1 a 10'), findsOneWidget);
    expect(repo.entradas, isEmpty);
  });

  testWidgets('los campos numéricos, la categoría y los lógicos llegan al repositorio', (tester) async {
    final repo = RepositorioFalso();
    await _abrirFormulario(tester, dependenciasFalsas(repositorio: repo));
    await tester.enterText(find.widgetWithText(TextFormField, 'Título del día'), 'Cochinita');
    await tester.enterText(find.widgetWithText(TextFormField, '¿Qué pasó hoy?'), 'Desayuno en el mercado.');

    await tester.scrollUntilVisible(find.text('Calificación'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'Otro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Calificación'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Gasto'), '85.50');
    await tester.scrollUntilVisible(find.text('Publicar en Huellas Comunidad'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Marcar como favorita'));
    await tester.tap(find.text('Publicar en Huellas Comunidad'));
    await tester.pump();
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    final e = repo.entradas.single;
    expect(e.categoriaId, 2);
    expect(e.calificacion, 10);
    expect(e.gasto, 85.5);
    expect(e.favorita, isTrue);
    expect(e.publicar, isTrue);
    expect(e.remotoId, isNull);
  });

  testWidgets('sin alias, la comunidad invita a registrarse y luego consulta el servidor', (tester) async {
    _pantallaDeTelefono(tester);
    final comunidad = ComunidadFalsa([publicacionDeEjemplo()]);
    final prefs = PreferenciasEnMemoria();
    await tester.pumpWidget(_soloPagina(
        dependenciasFalsas(comunidad: comunidad, preferencias: prefs), Rutas.comunidad));
    await tester.pumpAndSettle();
    expect(find.text('Únete a Huellas Comunidad'), findsOneWidget);

    await tester.tap(find.text('Elegir mi alias'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'ro');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Mínimo 3 caracteres'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'rodri_ll');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(prefs.usuarioRemotoId, 42);
    expect(find.text('Hola, @rodri_ll'), findsOneWidget);
    expect(find.text('Cenote Xlacah'), findsOneWidget);
  });

  testWidgets('la galería muestra la cuadrícula y abre el detalle con la publicación', (tester) async {
    _pantallaDeTelefono(tester);
    final prefs = PreferenciasEnMemoria()..alias = 'rodri'..usuarioRemotoId = 42;
    final comunidad = ComunidadFalsa([publicacionDeEjemplo(), publicacionDeEjemplo(id: 2, titulo: 'Tacos')]);
    await tester.pumpWidget(_soloPagina(
        dependenciasFalsas(comunidad: comunidad, preferencias: prefs), Rutas.comunidad));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    await tester.tap(find.text('Tacos'));
    await tester.pumpAndSettle();
    expect(find.text('por @ana'), findsOneWidget);
    expect(find.text('Me gusta · 3'), findsOneWidget);
    await tester.tap(find.text('Me gusta · 3'));
    await tester.pumpAndSettle();
    expect(find.text('Me gusta · 1'), findsOneWidget);
  });

  testWidgets('sincronizar publica las entradas pendientes y lo informa', (tester) async {
    _pantallaDeTelefono(tester);
    final prefs = PreferenciasEnMemoria()..alias = 'rodri'..usuarioRemotoId = 42;
    final repo = RepositorioFalso([entradaDeEjemplo().copyWith(publicar: true)]);
    final comunidad = ComunidadFalsa();
    await tester.pumpWidget(_soloPagina(
        dependenciasFalsas(comunidad: comunidad, preferencias: prefs, repositorio: repo),
        Rutas.comunidad));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay publicaciones'), findsOneWidget);

    await tester.tap(find.text('Sincronizar'));
    // Deja correr la animación del botón mientras dura la publicación.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    expect(find.text('1 publicada'), findsOneWidget);
    expect(repo.entradas.single.remotoId, 500);
    expect(repo.sincronizaciones.single.enviadas, 1);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Paseo por Paseo de Montejo'), findsOneWidget);
  });

  testWidgets('sin conexión la comunidad muestra el error con reintento', (tester) async {
    _pantallaDeTelefono(tester);
    final prefs = PreferenciasEnMemoria()..alias = 'rodri'..usuarioRemotoId = 42;
    final comunidad = ComunidadFalsa()..sinConexion = true;
    await tester.pumpWidget(_soloPagina(
        dependenciasFalsas(comunidad: comunidad, preferencias: prefs), Rutas.comunidad));
    await tester.pumpAndSettle();
    expect(find.text('Algo salió mal'), findsWidgets);
    expect(find.textContaining('No hay conexión'), findsWidgets);
  });

  test('las rutas nombradas son únicas', () {
    final rutas = {
      Rutas.bloqueo, Rutas.lista, Rutas.detalle, Rutas.nueva, Rutas.mapa, Rutas.ajustes,
      Rutas.comunidad, Rutas.publicacion, Rutas.sincronizaciones,
    };
    expect(rutas, hasLength(9));
  });
}
