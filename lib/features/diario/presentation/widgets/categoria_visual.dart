import 'package:flutter/material.dart';

import '../../domain/categoria.dart';

/// Traduce la clave de ícono guardada en SQLite/MySQL a un ícono de Material.
IconData iconoDeCategoria(String clave) => switch (clave) {
      'flight' => Icons.flight_takeoff,
      'restaurant' => Icons.restaurant,
      'school' => Icons.school_outlined,
      'family' => Icons.family_restroom,
      'sports' => Icons.directions_run,
      _ => Icons.bookmark_outline,
    };

extension CategoriaVisual on Categoria {
  IconData get iconoMaterial => iconoDeCategoria(icono);
  Color get colorMaterial => Color(color);
}

/// Etiqueta compacta con el ícono y el nombre de la categoría.
class ChipCategoria extends StatelessWidget {
  const ChipCategoria({super.key, required this.nombre, required this.icono, required this.color});

  ChipCategoria.de(Categoria c, {super.key})
      : nombre = c.nombre,
        icono = c.iconoMaterial,
        color = c.colorMaterial;

  final String nombre;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
