import 'package:flutter/material.dart';

import '../../../../core/dependencias.dart';
import '../../../../core/errores.dart';
import '../../../../core/fechas.dart';
import '../../../diario/domain/categoria.dart';
import '../../../diario/presentation/widgets/animo_visual.dart';
import '../../../diario/presentation/widgets/categoria_visual.dart';
import '../../../diario/presentation/widgets/mapa_osm.dart';
import '../../domain/publicacion.dart';
import '../widgets/widgets_comunidad.dart';

/// Detalle de una publicación de la comunidad. Recibe la [Publicacion] como
/// argumento de la ruta y al volver devuelve si hubo cambios
/// (`true` = cambió el "me gusta", `'eliminada'` = se borró).
class DetallePublicacionPage extends StatefulWidget {
  const DetallePublicacionPage({super.key, required this.publicacion});
  final Publicacion publicacion;

  @override
  State<DetallePublicacionPage> createState() => _DetallePublicacionPageState();
}

class _DetallePublicacionPageState extends State<DetallePublicacionPage> {
  late final Dependencias _dep = AppScope.of(context);
  late Publicacion _p = widget.publicacion;
  bool? _marcado;
  bool _ocupado = false;
  bool _cambio = false;

  bool get _esMia => _p.usuarioId == _dep.preferencias.usuarioRemotoId;

  void _avisar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _meGusta() async {
    final usuario = _dep.preferencias.usuarioRemotoId;
    if (usuario == null) {
      _avisar('Registra tu alias para reaccionar.');
      return;
    }
    setState(() => _ocupado = true);
    try {
      final r = await _dep.comunidad.alternarMeGusta(_p.id, usuarioId: usuario);
      setState(() {
        _p = _p.conMeGusta(r.total);
        _marcado = r.marcado;
        _cambio = true;
      });
    } on FallaApp catch (f) {
      _avisar(f.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined),
        title: const Text('¿Quitar de la comunidad?'),
        content: const Text('Se borrará del servidor. La entrada sigue en tu diario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await _dep.comunidad.eliminar(_p.id, usuarioId: _dep.preferencias.usuarioRemotoId!);
      // La entrada local deja de estar publicada (ya no tiene id remoto).
      final locales = await _dep.repositorio.obtenerTodas();
      for (final e in locales.where((e) => e.remotoId == _p.id)) {
        await _dep.repositorio.guardar(e.sinPublicar());
      }
      if (mounted) Navigator.pop(context, 'eliminada');
    } on FallaApp catch (f) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      _avisar(f.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ubicacion = _p.ubicacion;
    return PopScope<Object?>(
      canPop: false,
      // Devuelve a la pantalla anterior si algo cambió.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambio ? true : null);
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 300,
              actions: [
                if (_esMia)
                  IconButton(
                    tooltip: 'Quitar de la comunidad',
                    onPressed: _ocupado ? null : _eliminar,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(tag: _p.etiquetaHero, child: ImagenRemota(publicacion: _p)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_p.titulo,
                        style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('por @${_p.alias}', style: tema.textTheme.titleSmall),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.event_outlined),
                          label: Text('${Fechas.corta(_p.fecha)}, ${Fechas.hora(_p.fecha)}'),
                        ),
                        Chip(
                          avatar: Icon(Categoria.porId(_p.categoriaId).iconoMaterial,
                              color: Color(_p.categoriaColor)),
                          label: Text(_p.categoria),
                        ),
                        Chip(
                          avatar: Icon(_p.animo.icono, color: _p.animo.color),
                          label: Text(_p.animo.etiqueta),
                        ),
                        Chip(
                          avatar: const Icon(Icons.star_rounded, color: Colors.amber),
                          label: Text('${_p.calificacion}/10'),
                        ),
                        if (_p.gasto > 0)
                          Chip(
                            avatar: const Icon(Icons.payments_outlined),
                            label: Text('\$${_p.gasto.toStringAsFixed(2)}'),
                          ),
                        if (_p.favorita)
                          const Chip(avatar: Icon(Icons.favorite, color: Colors.pink), label: Text('Favorita')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SelectableText(_p.texto, style: tema.textTheme.bodyLarge?.copyWith(height: 1.5)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _ocupado ? null : _meGusta,
                        icon: Icon(_marcado == true ? Icons.favorite : Icons.favorite_border,
                            color: Colors.pink),
                        label: Text('Me gusta · ${_p.meGusta}'),
                      ),
                    ),
                    if (ubicacion != null) ...[
                      const SizedBox(height: 24),
                      Text('¿Dónde fue?', style: tema.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      MapaUbicacion(ubicacion: ubicacion),
                      const SizedBox(height: 8),
                      Text(ubicacion.coordenadasTexto, style: tema.textTheme.bodySmall),
                    ],
                    const SizedBox(height: 16),
                    Text('Publicado el ${Fechas.corta(_p.publicadoEn)} · id #${_p.id} en MySQL',
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
