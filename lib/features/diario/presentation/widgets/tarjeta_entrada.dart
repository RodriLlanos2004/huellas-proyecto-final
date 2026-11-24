import 'package:flutter/material.dart';

import '../../../../core/fechas.dart';
import '../../domain/entrada_diario.dart';
import 'animo_visual.dart';
import 'categoria_visual.dart';
import 'imagen_entrada.dart';

/// Tarjeta de una entrada en la lista. La miniatura vuela al detalle con Hero.
class TarjetaEntrada extends StatelessWidget {
  const TarjetaEntrada({super.key, required this.entrada, required this.alTocar});

  final EntradaDiario entrada;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
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
                  tag: entrada.etiquetaHero,
                  child: ImagenEntrada(nombre: entrada.imagen, radio: 14, miniatura: true),
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
                          child: Text(entrada.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        Icon(entrada.animo.icono, color: entrada.animo.color, size: 22),
                      ],
                    ),
                    Text('${Fechas.corta(entrada.fecha)} · ${Fechas.hora(entrada.fecha)}',
                        style: tema.textTheme.bodySmall?.copyWith(color: secundario)),
                    const SizedBox(height: 4),
                    Text(entrada.texto, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(child: ChipCategoria.de(entrada.categoria)),
                        const SizedBox(width: 8),
                        if (entrada.tieneUbicacion)
                          Icon(Icons.place_outlined, size: 16, color: secundario),
                        if (entrada.metadatos.usoDictado)
                          Icon(Icons.mic_none, size: 16, color: secundario),
                        const Spacer(),
                        if (entrada.favorita)
                          const Icon(Icons.favorite, size: 16, color: Colors.pink),
                        if (entrada.publicada)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.cloud_done_outlined,
                                size: 16, color: tema.colorScheme.primary),
                          )
                        else if (entrada.pendienteDePublicar)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.cloud_upload_outlined, size: 16, color: secundario),
                          ),
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
