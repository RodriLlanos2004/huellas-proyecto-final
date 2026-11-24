import '../../diario/domain/estado_animo.dart';
import '../../diario/domain/ubicacion.dart';

/// Una entrada publicada en Huellas Comunidad, tal como la devuelve el
/// servicio web (vista `v_publicaciones` de MySQL).
class Publicacion {
  const Publicacion({
    required this.id,
    required this.usuarioId,
    required this.alias,
    required this.categoriaId,
    required this.categoria,
    required this.categoriaColor,
    required this.titulo,
    required this.texto,
    required this.fecha,
    required this.animo,
    required this.calificacion,
    required this.gasto,
    required this.favorita,
    required this.meGusta,
    required this.publicadoEn,
    this.ubicacion,
    this.fotoUrl,
  });

  final int id;
  final int usuarioId;
  final String alias;
  final int categoriaId;
  final String categoria;

  /// Color en formato ARGB, convertido desde "#RRGGBB".
  final int categoriaColor;
  final String titulo;
  final String texto;
  final DateTime fecha;
  final EstadoAnimo animo;
  final int calificacion;
  final double gasto;
  final bool favorita;
  final int meGusta;
  final DateTime publicadoEn;
  final Ubicacion? ubicacion;
  final String? fotoUrl;

  String get etiquetaHero => 'publicacion-$id';

  Publicacion conMeGusta(int total) => Publicacion(
        id: id,
        usuarioId: usuarioId,
        alias: alias,
        categoriaId: categoriaId,
        categoria: categoria,
        categoriaColor: categoriaColor,
        titulo: titulo,
        texto: texto,
        fecha: fecha,
        animo: animo,
        calificacion: calificacion,
        gasto: gasto,
        favorita: favorita,
        meGusta: total,
        publicadoEn: publicadoEn,
        ubicacion: ubicacion,
        fotoUrl: fotoUrl,
      );

  factory Publicacion.fromJson(Map<String, dynamic> json) {
    final lat = json['latitud'] as num?;
    final lng = json['longitud'] as num?;
    return Publicacion(
      id: json['id'] as int,
      usuarioId: json['usuario_id'] as int,
      alias: json['alias'] as String,
      categoriaId: json['categoria_id'] as int,
      categoria: json['categoria'] as String,
      categoriaColor: colorDesdeHex(json['categoria_color'] as String?),
      titulo: json['titulo'] as String,
      texto: json['texto'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      animo: EstadoAnimo.desdeNombre(json['animo'] as String?),
      calificacion: json['calificacion'] as int,
      gasto: (json['gasto'] as num).toDouble(),
      favorita: json['favorita'] as bool? ?? false,
      meGusta: json['me_gusta'] as int? ?? 0,
      publicadoEn: DateTime.parse(json['publicado_en'] as String),
      ubicacion: (lat == null || lng == null)
          ? null
          : Ubicacion(latitud: lat.toDouble(), longitud: lng.toDouble()),
      fotoUrl: json['foto_url'] as String?,
    );
  }

  /// "#00796B" -> 0xFF00796B. Un valor inválido regresa gris.
  static int colorDesdeHex(String? hex) {
    final limpio = (hex ?? '').replaceFirst('#', '');
    final valor = int.tryParse(limpio, radix: 16);
    if (limpio.length != 6 || valor == null) return 0xFF757575;
    return 0xFF000000 | valor;
  }
}

/// Resultado paginado de GET /api/publicaciones.
class PaginaPublicaciones {
  const PaginaPublicaciones({required this.total, required this.elementos});
  final int total;
  final List<Publicacion> elementos;

  factory PaginaPublicaciones.fromJson(Map<String, dynamic> json) => PaginaPublicaciones(
        total: json['total'] as int,
        elementos: [
          for (final e in json['elementos'] as List<dynamic>)
            Publicacion.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Respuesta de POST /api/publicaciones/{id}/me-gusta.
class EstadoMeGusta {
  const EstadoMeGusta({required this.total, required this.marcado});
  final int total;
  final bool marcado;
}
