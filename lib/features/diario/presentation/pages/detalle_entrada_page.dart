import 'package:flutter/material.dart';

import '../../../../core/dependencias.dart';
import '../../../../core/errores.dart';
import '../../../../core/fechas.dart';
import '../../domain/entrada_diario.dart';
import '../widgets/animo_visual.dart';
import '../widgets/categoria_visual.dart';
import '../widgets/imagen_entrada.dart';
import '../widgets/mapa_osm.dart';

/// Vista de detalle: imagen grande (destino del Hero), texto, mapa
/// interactivo y botón para abrir la ubicación en Google Maps.
class DetalleEntradaPage extends StatefulWidget {
  const DetalleEntradaPage({super.key, required this.entrada});
  final EntradaDiario entrada;

  @override
  State<DetalleEntradaPage> createState() => _DetalleEntradaPageState();
}

class _DetalleEntradaPageState extends State<DetalleEntradaPage> {
  bool _eliminando = false;

  EntradaDiario get _e => widget.entrada;

  Future<void> _abrirEnGoogleMaps() async {
    final abierta = await AppScope.of(context).mapas.abrir(_e.ubicacion!);
    if (!abierta && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró una app para abrir mapas.')),
      );
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('¿Eliminar esta entrada?'),
        content: Text('"${_e.titulo}" y su foto se borrarán de este dispositivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final dep = AppScope.of(context);
    setState(() => _eliminando = true);
    try {
      await dep.repositorio.eliminar(_e.id!);
      await dep.imagenesGuardadas.eliminar(_e.imagen);
      if (mounted) Navigator.pop(context, true);
    } on FallaApp catch (f) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ubicacion = _e.ubicacion;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            leading: const Padding(
              padding: EdgeInsets.all(6),
              child: _BotonSobreImagen(child: BackButton(color: Colors.white)),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: _BotonSobreImagen(
                  child: IconButton(
                    tooltip: 'Eliminar',
                    color: Colors.white,
                    onPressed: _eliminando ? null : _eliminar,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: _e.etiquetaHero,
                child: ImagenEntrada(nombre: _e.imagen),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_e.titulo,
                      style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.event_outlined),
                        label: Text('${Fechas.larga(_e.fecha)}, ${Fechas.hora(_e.fecha)}'),
                      ),
                      Chip(
                        avatar: Icon(_e.animo.icono, color: _e.animo.color),
                        label: Text(_e.animo.etiqueta),
                      ),
                      Chip(
                        avatar: Icon(_e.categoria.iconoMaterial, color: _e.categoria.colorMaterial),
                        label: Text(_e.categoria.nombre),
                      ),
                      Chip(
                        avatar: const Icon(Icons.star_rounded, color: Colors.amber),
                        label: Text('${_e.calificacion}/10'),
                      ),
                      if (_e.gasto > 0)
                        Chip(
                          avatar: const Icon(Icons.payments_outlined),
                          label: Text('\$${_e.gasto.toStringAsFixed(2)}'),
                        ),
                      if (_e.favorita)
                        const Chip(
                          avatar: Icon(Icons.favorite, color: Colors.pink),
                          label: Text('Favorita'),
                        ),
                      if (_e.publicada)
                        Chip(
                          avatar: const Icon(Icons.cloud_done_outlined),
                          label: Text('En la comunidad (#${_e.remotoId})'),
                        )
                      else if (_e.publicar)
                        const Chip(
                          avatar: Icon(Icons.cloud_upload_outlined),
                          label: Text('Pendiente de publicar'),
                        ),
                      if (_e.metadatos.usoDictado)
                        const Chip(avatar: Icon(Icons.mic_none), label: Text('Dictado por voz')),
                      if (_e.metadatos.origenImagen case final origen?)
                        Chip(
                          avatar: const Icon(Icons.photo_camera_outlined),
                          label: Text('Foto: ${origen.etiqueta}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SelectableText(_e.texto, style: tema.textTheme.bodyLarge?.copyWith(height: 1.5)),
                  const SizedBox(height: 28),
                  Text('¿Dónde fue?', style: tema.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (ubicacion == null)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.location_off_outlined),
                        title: Text('Esta entrada se guardó sin ubicación'),
                      ),
                    )
                  else ...[
                    MapaUbicacion(ubicacion: ubicacion),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 16, color: tema.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ubicacion.coordenadasTexto +
                                (ubicacion.precisionMetros == null
                                    ? ''
                                    : '  ·  ±${ubicacion.precisionMetros!.round()} m'),
                            style: tema.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _abrirEnGoogleMaps,
                        icon: const Icon(Icons.directions_outlined),
                        label: const Text('Abrir en Google Maps'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo circular translúcido para que los botones se vean sobre cualquier foto.
class _BotonSobreImagen extends StatelessWidget {
  const _BotonSobreImagen({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: child,
      );
}
