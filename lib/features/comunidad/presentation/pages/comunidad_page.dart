import 'package:flutter/material.dart';

import '../../../../core/dependencias.dart';
import '../../../../core/errores.dart';
import '../../../../core/rutas.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/estados_vista.dart';
import '../../../diario/domain/categoria.dart';
import '../../../diario/presentation/widgets/animo_visual.dart';
import '../../../diario/domain/estado_animo.dart';
import '../../../diario/presentation/widgets/categoria_visual.dart';
import '../../data/servicio_sincronizacion.dart';
import '../../domain/estadisticas_comunidad.dart';
import '../../domain/publicacion.dart';
import '../widgets/dialogo_alias.dart';
import '../widgets/widgets_comunidad.dart';

/// Huellas Comunidad: consulta lo que está guardado en MySQL a través del
/// servicio web y permite publicar las entradas pendientes.
///
/// Tres pestañas sobre los mismos datos: lista (ListView), galería (GridView)
/// y estadísticas calculadas en el servidor.
class ComunidadPage extends StatefulWidget {
  const ComunidadPage({super.key});

  @override
  State<ComunidadPage> createState() => _ComunidadPageState();
}

class _ComunidadPageState extends State<ComunidadPage> {
  late final Dependencias _dep = AppScope.of(context);

  Future<PaginaPublicaciones>? _publicaciones;
  Future<EstadisticasComunidad>? _estadisticas;
  int? _categoriaId;
  int _pendientes = 0;
  bool _sincronizando = false;

  bool get _registrado => _dep.preferencias.alias != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_publicaciones == null && _registrado) _cargar();
  }

  /// Consulta de nuevo el servidor (y cuenta las entradas locales pendientes).
  void _cargar() {
    setState(() {
      // ignore() evita un error "no manejado" si la pestaña que usa el Future
      // aún no se ha construido; el FutureBuilder igual recibe el error.
      _publicaciones = _dep.comunidad.obtenerPublicaciones(categoriaId: _categoriaId)..ignore();
      _estadisticas = _dep.comunidad.obtenerEstadisticas()..ignore();
    });
    _contarPendientes();
  }

  Future<void> _contarPendientes() async {
    try {
      final n = (await _dep.repositorio.pendientesDePublicar()).length;
      if (mounted) setState(() => _pendientes = n);
    } on FallaApp {
      // No es crítico: el botón solo muestra el número.
    }
  }

  void _filtrar(int? categoriaId) {
    _categoriaId = categoriaId;
    setState(() {
      _publicaciones = _dep.comunidad.obtenerPublicaciones(categoriaId: categoriaId)..ignore();
    });
  }

  Future<void> _unirse() async {
    if (await mostrarDialogoAlias(context) && mounted) _cargar();
  }

  Future<void> _sincronizar() async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    final ResultadoSincronizacion r;
    try {
      r = await _dep.sincronizacion.sincronizar();
    } on FallaApp catch (f) {
      if (mounted) {
        setState(() => _sincronizando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.mensaje)));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _sincronizando = false);
    _cargar();
    await _mostrarResultado(r);
  }

  Future<void> _mostrarResultado(ResultadoSincronizacion r) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(r.registro.exitosa ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
          title: Text(r.enviadas == 0 && r.fallidas == 0
              ? 'Todo está al día'
              : '${r.enviadas} publicada${r.enviadas == 1 ? '' : 's'}'
                  '${r.fallidas > 0 ? ', ${r.fallidas} pendiente${r.fallidas == 1 ? '' : 's'}' : ''}'),
          content: Text(r.errores.isEmpty
              ? (r.enviadas == 0
                  ? 'No hay entradas marcadas para publicar. Activa "Publicar en Huellas Comunidad" al crear una entrada.'
                  : 'Tus entradas ya están en la base de datos del servidor.')
              : r.errores.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(this.context, Rutas.sincronizaciones);
              },
              child: const Text('Ver historial'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
          ],
        ),
      );

  Future<void> _abrir(Publicacion p) async {
    // La publicación completa viaja como argumento a la pantalla de detalle.
    final cambio = await Navigator.pushNamed(context, Rutas.publicacion, arguments: p);
    if (!mounted || cambio == null) return;
    if (cambio == 'eliminada') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminó "${p.titulo}" de la comunidad')),
      );
    }
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    if (!_registrado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Huellas Comunidad')),
        drawer: const AppDrawer(rutaActual: Rutas.comunidad),
        body: EstadoVacio(
          icono: Icons.public,
          titulo: 'Únete a Huellas Comunidad',
          mensaje: 'Comparte los recuerdos que tú elijas y mira los de otras personas. '
              'Solo necesitas un alias.',
          accion: FilledButton.icon(
            onPressed: _unirse,
            icon: const Icon(Icons.alternate_email),
            label: const Text('Elegir mi alias'),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Huellas Comunidad'),
          actions: [
            IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargar),
            IconButton(
              tooltip: 'Historial de sincronización',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.pushNamed(context, Rutas.sincronizaciones),
            ),
          ],
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.view_list_outlined), text: 'Lista'),
            Tab(icon: Icon(Icons.grid_view_outlined), text: 'Galería'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Estadísticas'),
          ]),
        ),
        drawer: const AppDrawer(rutaActual: Rutas.comunidad),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _sincronizando ? null : _sincronizar,
          icon: _sincronizando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Badge(
                  isLabelVisible: _pendientes > 0,
                  label: Text('$_pendientes'),
                  child: const Icon(Icons.cloud_upload_outlined),
                ),
          label: Text(_sincronizando ? 'Publicando…' : 'Sincronizar'),
        ),
        body: Column(
          children: [
            _Encabezado(alias: _dep.preferencias.alias!, servidor: _dep.preferencias.servidorUrl),
            _FiltroCategorias(seleccionada: _categoriaId, alCambiar: _filtrar),
            Expanded(
              child: TabBarView(children: [
                _ConPublicaciones(
                  futuro: _publicaciones,
                  alReintentar: _cargar,
                  alSincronizar: _sincronizar,
                  constructor: (pagina) => RefreshIndicator(
                    onRefresh: () async => _cargar(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: pagina.elementos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => TarjetaPublicacion(
                        publicacion: pagina.elementos[i],
                        alTocar: () => _abrir(pagina.elementos[i]),
                      ),
                    ),
                  ),
                ),
                _ConPublicaciones(
                  futuro: _publicaciones,
                  alReintentar: _cargar,
                  alSincronizar: _sincronizar,
                  constructor: (pagina) => RefreshIndicator(
                    onRefresh: () async => _cargar(),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: pagina.elementos.length,
                      itemBuilder: (context, i) => CeldaPublicacion(
                        publicacion: pagina.elementos[i],
                        alTocar: () => _abrir(pagina.elementos[i]),
                      ),
                    ),
                  ),
                ),
                _VistaEstadisticas(futuro: _estadisticas, alReintentar: _cargar),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banda superior con la imagen de fondo de la app, el alias y el servidor.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.alias, required this.servidor});
  final String alias;
  final String servidor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/images/fondo_huellas.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Row(
          children: [
            Image.asset('assets/images/logo_huellas.png', width: 40, height: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hola, @$alias',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(servidor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Filtro horizontal por categoría (vuelve a consultar el servicio web).
class _FiltroCategorias extends StatelessWidget {
  const _FiltroCategorias({required this.seleccionada, required this.alCambiar});
  final int? seleccionada;
  final ValueChanged<int?> alCambiar;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: seleccionada == null,
              onSelected: (_) => alCambiar(null),
            ),
            for (final c in Categoria.predeterminadas) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: Icon(c.iconoMaterial, size: 18, color: c.colorMaterial),
                label: Text(c.nombre),
                selected: seleccionada == c.id,
                onSelected: (_) => alCambiar(c.id),
              ),
            ],
          ],
        ),
      );
}

/// FutureBuilder común de la lista y la galería: carga, error, vacío y datos.
class _ConPublicaciones extends StatelessWidget {
  const _ConPublicaciones({
    required this.futuro,
    required this.constructor,
    required this.alReintentar,
    required this.alSincronizar,
  });

  final Future<PaginaPublicaciones>? futuro;
  final Widget Function(PaginaPublicaciones pagina) constructor;
  final VoidCallback alReintentar;
  final VoidCallback alSincronizar;

  @override
  Widget build(BuildContext context) => FutureBuilder<PaginaPublicaciones>(
        future: futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EstadoCargando(mensaje: 'Consultando el servidor…');
          }
          if (snapshot.hasError) {
            return EstadoError(mensaje: mensajeDeError(snapshot.error), alReintentar: alReintentar);
          }
          final pagina = snapshot.data;
          if (pagina == null || pagina.elementos.isEmpty) {
            return EstadoVacio(
              icono: Icons.travel_explore,
              titulo: 'Aún no hay publicaciones',
              mensaje: 'Marca "Publicar en Huellas Comunidad" en una entrada y sincroniza.',
              accion: FilledButton.tonalIcon(
                onPressed: alSincronizar,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Sincronizar ahora'),
              ),
            );
          }
          return constructor(pagina);
        },
      );
}

/// Pestaña de estadísticas (consultas GROUP BY en MySQL).
class _VistaEstadisticas extends StatelessWidget {
  const _VistaEstadisticas({required this.futuro, required this.alReintentar});
  final Future<EstadisticasComunidad>? futuro;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return FutureBuilder<EstadisticasComunidad>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const EstadoCargando(mensaje: 'Calculando estadísticas…');
        }
        if (snapshot.hasError) {
          return EstadoError(mensaje: mensajeDeError(snapshot.error), alReintentar: alReintentar);
        }
        final e = snapshot.data!;
        final maximo = e.porCategoria.fold<int>(1, (m, c) => c.total > m ? c.total : m);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Row(
              children: [
                _Cifra(valor: '${e.totalPublicaciones}', etiqueta: 'publicaciones'),
                const SizedBox(width: 8),
                _Cifra(valor: '${e.totalUsuarios}', etiqueta: 'personas'),
                const SizedBox(width: 8),
                _Cifra(
                    valor: e.promedioCalificacion?.toStringAsFixed(1) ?? '–',
                    etiqueta: 'calificación media'),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text('\$${e.gastoTotal.toStringAsFixed(2)}'),
                subtitle: const Text('Gasto total registrado por la comunidad'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Por categoría', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final c in e.porCategoria)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(iconoDeCategoria(Categoria.porId(c.categoriaId).icono),
                            size: 18, color: Color(c.color)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.categoria)),
                        Text('${c.total}'
                            '${c.promedioCalificacion == null ? '' : '  ·  ★ ${c.promedioCalificacion!.toStringAsFixed(1)}'}',
                            style: tema.textTheme.labelLarge),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: c.total / maximo,
                        minHeight: 10,
                        color: Color(c.color),
                        backgroundColor: Color(c.color).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text('Estados de ánimo', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in EstadoAnimo.values)
                  Chip(
                    avatar: Icon(a.icono, color: a.color),
                    label: Text('${a.etiqueta}: ${e.porAnimo[a.name] ?? 0}'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Card(
        color: tema.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(valor,
                  style: tema.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: tema.colorScheme.onPrimaryContainer)),
              Text(etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: tema.textTheme.labelSmall?.copyWith(color: tema.colorScheme.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}
