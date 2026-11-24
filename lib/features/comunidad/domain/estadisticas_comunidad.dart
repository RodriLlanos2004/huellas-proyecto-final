import 'publicacion.dart';

/// Totales por categoría calculados en MySQL (GROUP BY).
class EstadisticaCategoria {
  const EstadisticaCategoria({
    required this.categoriaId,
    required this.categoria,
    required this.color,
    required this.total,
    required this.promedioCalificacion,
    required this.gastoTotal,
  });

  final int categoriaId;
  final String categoria;
  final int color;
  final int total;
  final double? promedioCalificacion;
  final double gastoTotal;

  factory EstadisticaCategoria.fromJson(Map<String, dynamic> json) => EstadisticaCategoria(
        categoriaId: json['categoria_id'] as int,
        categoria: json['categoria'] as String,
        color: Publicacion.colorDesdeHex(json['color'] as String?),
        total: json['total'] as int,
        promedioCalificacion: (json['promedio_calificacion'] as num?)?.toDouble(),
        gastoTotal: (json['gasto_total'] as num).toDouble(),
      );
}

/// Respuesta de GET /api/estadisticas.
class EstadisticasComunidad {
  const EstadisticasComunidad({
    required this.totalPublicaciones,
    required this.totalUsuarios,
    required this.promedioCalificacion,
    required this.gastoTotal,
    required this.porCategoria,
    required this.porAnimo,
  });

  final int totalPublicaciones;
  final int totalUsuarios;
  final double? promedioCalificacion;
  final double gastoTotal;
  final List<EstadisticaCategoria> porCategoria;
  final Map<String, int> porAnimo;

  factory EstadisticasComunidad.fromJson(Map<String, dynamic> json) => EstadisticasComunidad(
        totalPublicaciones: json['total_publicaciones'] as int,
        totalUsuarios: json['total_usuarios'] as int,
        promedioCalificacion: (json['promedio_calificacion'] as num?)?.toDouble(),
        gastoTotal: (json['gasto_total'] as num).toDouble(),
        porCategoria: [
          for (final c in json['por_categoria'] as List<dynamic>)
            EstadisticaCategoria.fromJson(c as Map<String, dynamic>),
        ],
        porAnimo: {
          for (final e in (json['por_animo'] as Map<String, dynamic>).entries) e.key: e.value as int,
        },
      );
}
