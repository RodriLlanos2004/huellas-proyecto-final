import 'categoria.dart';
import 'estado_animo.dart';
import 'metadatos_entrada.dart';
import 'ubicacion.dart';

/// Entidad principal: un día registrado en el diario (tabla `entradas`).
///
/// Es inmutable; para modificarla se usa [copyWith]. Sabe convertirse a
/// un mapa de SQLite ([toMap]/[EntradaDiario.fromMap]) y a JSON
/// ([toJson]/[EntradaDiario.fromJson]) para el respaldo exportable.
class EntradaDiario {
  const EntradaDiario({
    this.id,
    required this.titulo,
    required this.texto,
    required this.fecha,
    this.animo = EstadoAnimo.tranquilo,
    this.imagen,
    this.ubicacion,
    this.metadatos = const MetadatosEntrada(),
    this.categoriaId = Categoria.idOtro,
    this.calificacion = 7,
    this.gasto = 0,
    this.favorita = false,
    this.publicar = false,
    this.remotoId,
  });

  /// Reglas de negocio de los campos numéricos (RN-04 y RN-05).
  static const calificacionMinima = 1;
  static const calificacionMaxima = 10;
  static const gastoMaximo = 100000.0;

  /// Clave primaria en SQLite; es null mientras la entrada no se ha guardado.
  final int? id;
  final String titulo;
  final String texto;
  final DateTime fecha;
  final EstadoAnimo animo;

  /// Nombre del archivo de imagen dentro de la carpeta privada de la app.
  /// Se guarda solo el nombre, no la ruta absoluta, porque en iOS la ruta
  /// del contenedor de la app cambia entre instalaciones y actualizaciones.
  final String? imagen;
  final Ubicacion? ubicacion;
  final MetadatosEntrada metadatos;

  /// Llave foránea a la tabla `categorias`.
  final int categoriaId;

  /// Qué tan bueno fue el día, de 1 a 10.
  final int calificacion;

  /// Dinero gastado ese día, en pesos.
  final double gasto;

  final bool favorita;

  /// El usuario quiere compartir la entrada en Huellas Comunidad.
  final bool publicar;

  /// Id de la publicación en el servidor; null mientras no se ha subido.
  final int? remotoId;

  Categoria get categoria => Categoria.porId(categoriaId);
  bool get publicada => remotoId != null;
  bool get pendienteDePublicar => publicar && remotoId == null;

  bool get tieneImagen => imagen != null;
  bool get tieneUbicacion => ubicacion != null;

  /// Etiqueta compartida por el Hero de la lista y el del detalle.
  String get etiquetaHero => 'huella-imagen-${id ?? fecha.microsecondsSinceEpoch}';

  EntradaDiario copyWith({
    int? id,
    String? titulo,
    String? texto,
    DateTime? fecha,
    EstadoAnimo? animo,
    String? imagen,
    Ubicacion? ubicacion,
    MetadatosEntrada? metadatos,
    int? categoriaId,
    int? calificacion,
    double? gasto,
    bool? favorita,
    bool? publicar,
    int? remotoId,
  }) =>
      EntradaDiario(
        id: id ?? this.id,
        titulo: titulo ?? this.titulo,
        texto: texto ?? this.texto,
        fecha: fecha ?? this.fecha,
        animo: animo ?? this.animo,
        imagen: imagen ?? this.imagen,
        ubicacion: ubicacion ?? this.ubicacion,
        metadatos: metadatos ?? this.metadatos,
        categoriaId: categoriaId ?? this.categoriaId,
        calificacion: calificacion ?? this.calificacion,
        gasto: gasto ?? this.gasto,
        favorita: favorita ?? this.favorita,
        publicar: publicar ?? this.publicar,
        remotoId: remotoId ?? this.remotoId,
      );

  /// Copia que deja de estar publicada (se borró del servidor). copyWith no
  /// puede poner `remotoId` en null, por eso existe este método.
  EntradaDiario sinPublicar() => EntradaDiario(
        id: id,
        titulo: titulo,
        texto: texto,
        fecha: fecha,
        animo: animo,
        imagen: imagen,
        ubicacion: ubicacion,
        metadatos: metadatos,
        categoriaId: categoriaId,
        calificacion: calificacion,
        gasto: gasto,
        favorita: favorita,
      );

  // ---------- SQLite ----------

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'titulo': titulo,
        'texto': texto,
        'fecha': fecha.millisecondsSinceEpoch,
        'animo': animo.name,
        'imagen': imagen,
        'latitud': ubicacion?.latitud,
        'longitud': ubicacion?.longitud,
        'precision_m': ubicacion?.precisionMetros,
        'metadatos': metadatos.aTexto(),
        'categoria_id': categoriaId,
        'calificacion': calificacion,
        'gasto': gasto,
        // SQLite no tiene tipo booleano: se guarda 0 o 1.
        'favorita': favorita ? 1 : 0,
        'publicar': publicar ? 1 : 0,
        'remoto_id': remotoId,
      };

  factory EntradaDiario.fromMap(Map<String, Object?> mapa) {
    final lat = mapa['latitud'] as num?;
    final lng = mapa['longitud'] as num?;
    return EntradaDiario(
      id: mapa['id'] as int?,
      titulo: mapa['titulo'] as String,
      texto: mapa['texto'] as String,
      fecha: DateTime.fromMillisecondsSinceEpoch(mapa['fecha'] as int),
      animo: EstadoAnimo.desdeNombre(mapa['animo'] as String?),
      imagen: mapa['imagen'] as String?,
      ubicacion: (lat == null || lng == null)
          ? null
          : Ubicacion(
              latitud: lat.toDouble(),
              longitud: lng.toDouble(),
              precisionMetros: (mapa['precision_m'] as num?)?.toDouble(),
            ),
      metadatos: MetadatosEntrada.desdeTexto(mapa['metadatos'] as String?),
      categoriaId: mapa['categoria_id'] as int? ?? Categoria.idOtro,
      calificacion: mapa['calificacion'] as int? ?? 7,
      gasto: (mapa['gasto'] as num?)?.toDouble() ?? 0,
      favorita: mapa['favorita'] == 1,
      publicar: mapa['publicar'] == 1,
      remotoId: mapa['remoto_id'] as int?,
    );
  }

  // ---------- JSON ----------

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'texto': texto,
        'fecha': fecha.toIso8601String(),
        'animo': animo.name,
        'imagen': imagen,
        'ubicacion': ubicacion?.toJson(),
        'metadatos': metadatos.toJson(),
        'categoriaId': categoriaId,
        'calificacion': calificacion,
        'gasto': gasto,
        'favorita': favorita,
        'publicar': publicar,
        'remotoId': remotoId,
      };

  factory EntradaDiario.fromJson(Map<String, dynamic> json) => EntradaDiario(
        id: json['id'] as int?,
        titulo: json['titulo'] as String,
        texto: json['texto'] as String,
        fecha: DateTime.parse(json['fecha'] as String),
        animo: EstadoAnimo.desdeNombre(json['animo'] as String?),
        imagen: json['imagen'] as String?,
        ubicacion: json['ubicacion'] == null
            ? null
            : Ubicacion.fromJson(json['ubicacion'] as Map<String, dynamic>),
        metadatos: json['metadatos'] == null
            ? const MetadatosEntrada()
            : MetadatosEntrada.fromJson(json['metadatos'] as Map<String, dynamic>),
        categoriaId: json['categoriaId'] as int? ?? Categoria.idOtro,
        calificacion: json['calificacion'] as int? ?? 7,
        gasto: (json['gasto'] as num?)?.toDouble() ?? 0,
        favorita: json['favorita'] as bool? ?? false,
        publicar: json['publicar'] as bool? ?? false,
        remotoId: json['remotoId'] as int?,
      );
}
