import 'package:flutter/material.dart';

import '../../../../core/fechas.dart';
import '../../../diario/domain/categoria.dart';
import '../../../diario/presentation/widgets/animo_visual.dart';
import '../../../diario/presentation/widgets/categoria_visual.dart';
import '../../domain/publicacion.dart';

/// Foto descargada del servidor (Image.network) con estados de carga y error.
class ImagenRemota extends StatelessWidget {
  const ImagenRemota({super.key, required this.publicacion, this.radio = 0, this.miniatura = false});

  final Publicacion publicacion;
  final double radio;
  final bool miniatura;

  @override
  Widget build(BuildContext context) {
    final url = publicacion.fotoUrl;
    final respaldo = _SinFoto(publicacion: publicacion, miniatura: miniatura);
    final escala = MediaQuery.devicePixelRatioOf(context);
    final Widget contenido = url == null
        ? respaldo
        : Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: miniatura ? (180 * escala).round() : null,
            loadingBuilder: (context, hijo, progreso) => progreso == null
                ? hijo
                : Stack(fit: StackFit.expand, children: [
                    respaldo,
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
            errorBuilder: (_, _, _) => respaldo,
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radio), child: contenido);
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto({required this.publicacion, required this.miniatura});
  final Publicacion publicacion;
  final bool miniatura;

  @override
  Widget build(BuildContext context) {
    final color = Color(publicacion.categoriaColor);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Categoria.porId(publicacion.categoriaId).iconoMaterial,
            color: Colors.white70, size: miniatura ? 30 : 64),
      ),
    );
  }
}

ChipCategoria chipDePublicacion(Publicacion p) => ChipCategoria(
      nombre: p.categoria,
      icono: Categoria.porId(p.categoriaId).iconoMaterial,
      color: Color(p.categoriaColor),
    );

/// Elemento de la lista de la comunidad.
class TarjetaPublicacion extends StatelessWidget {
  const TarjetaPublicacion({super.key, required this.publicacion, required this.alTocar});

  final Publicacion publicacion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final p = publicacion;
    final secundario = tema.colorScheme.onSurfaceVariant;
    return Card(
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Hero(
                  tag: p.etiquetaHero,
                  child: ImagenRemota(publicacion: p, radio: 14, miniatura: true),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        Icon(p.animo.icono, color: p.animo.color, size: 22),
                      ],
                    ),
                    Text('@${p.alias} · ${Fechas.corta(p.fecha)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(color: secundario)),
                    const SizedBox(height: 4),
                    Text(p.texto, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(child: chipDePublicacion(p)),
                        const Spacer(),
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        Text(' ${p.calificacion}', style: tema.textTheme.labelMedium),
                        const SizedBox(width: 10),
                        Icon(Icons.favorite, size: 15, color: p.meGusta > 0 ? Colors.pink : secundario),
                        Text(' ${p.meGusta}', style: tema.textTheme.labelMedium),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Celda de la cuadrícula (galería) de la comunidad.
class CeldaPublicacion extends StatelessWidget {
  const CeldaPublicacion({super.key, required this.publicacion, required this.alTocar});

  final Publicacion publicacion;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = publicacion;
    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(tag: p.etiquetaHero, child: ImagenRemota(publicacion: p, miniatura: true)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment(0, 0.1),
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('@${p.alias}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                    Text(' ${p.calificacion}',
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
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
